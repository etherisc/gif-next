// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../registry/IRegistry.sol";
import {Product} from "./Product.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IDistributionComponent} from "../distribution/IDistributionComponent.sol";
import {IInstance} from "../instance/IInstance.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";
import {IPoolComponent} from "../pool/IPoolComponent.sol";
import {IRisk} from "../instance/module/IRisk.sol";
import {IBundle} from "../instance/module/IBundle.sol";
import {ISetup} from "../instance/module/ISetup.sol";

import {TokenHandler} from "../shared/TokenHandler.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {ClaimId, ClaimIdLib} from "../type/ClaimId.sol";
import {Timestamp, TimestampLib, zeroTimestamp} from "../type/Timestamp.sol";
import {UFixed, UFixedLib} from "../type/UFixed.sol";
import {ObjectType, APPLICATION, DISTRIBUTION, PRODUCT, POOL, POLICY, BUNDLE, CLAIM, PRICE} from "../type/ObjectType.sol";
import {APPLIED, COLLATERALIZED, ACTIVE, KEEP_STATE, CLOSED, DECLINED, CONFIRMED} from "../type/StateId.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {PayoutId, PayoutIdLib} from "../type/PayoutId.sol";
import {StateId} from "../type/StateId.sol";
import {VersionPart} from "../type/Version.sol";

import {ComponentService} from "../shared/ComponentService.sol";
import {IApplicationService} from "./IApplicationService.sol";
import {IBundleService} from "../pool/IBundleService.sol";
import {IClaimService} from "./IClaimService.sol";
import {IDistributionService} from "../distribution/IDistributionService.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {IPolicyService} from "./IPolicyService.sol";
import {IPoolService} from "../pool/IPoolService.sol";
import {IPricingService} from "./IPricingService.sol";
import {IService} from "../shared/IService.sol";
import {Service} from "../shared/Service.sol";

contract PolicyService is
    ComponentService, 
    IPolicyService
{
    using NftIdLib for NftId;
    using TimestampLib for Timestamp;

    IApplicationService internal _applicationService;
    IBundleService internal _bundleService;
    IClaimService internal _claimService;
    IDistributionService internal _distributionService;
    IPoolService internal _poolService;
    IPricingService internal _pricingService;

    event LogProductServiceSender(address sender);

    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        virtual override
        initializer
    {
        address registryAddress;
        address initialOwner;
        (registryAddress, initialOwner) = abi.decode(data, (address, address));

        initializeService(registryAddress, address(0), owner);

        VersionPart majorVersion = getVersion().toMajorPart();
        _poolService = IPoolService(getRegistry().getServiceAddress(POOL(), majorVersion));
        _bundleService = IBundleService(getRegistry().getServiceAddress(BUNDLE(), majorVersion));
        _claimService = IClaimService(getRegistry().getServiceAddress(CLAIM(), majorVersion));
        _applicationService = IApplicationService(getRegistry().getServiceAddress(APPLICATION(), majorVersion));
        _distributionService = IDistributionService(getRegistry().getServiceAddress(DISTRIBUTION(), majorVersion));
        _pricingService = IPricingService(getRegistry().getServiceAddress(PRICE(), majorVersion));

        registerInterface(type(IPolicyService).interfaceId);
    }


    function getDomain() public pure override returns(ObjectType) {
        return POLICY();
    }


    function _getAndVerifyInstanceAndProduct() internal view returns (Product product) {
        IRegistry.ObjectInfo memory productInfo;
        (, productInfo,) = _getAndVerifyCallingComponentAndInstance(PRODUCT());
        product = Product(productInfo.objectAddress);
    }


    function decline(
        NftId policyNftId
    )
        external
        override
    {
        revert();
    }


    /// @dev underwites application which includes the locking of the required collateral from the pool.
    function collateralize(
        NftId applicationNftId, // = policyNftId
        bool requirePremiumPayment,
        Timestamp activateAt
    )
        external 
        virtual override
    {
        // check caller is registered product
        (NftId productNftId,, IInstance instance) = _getAndVerifyCallingComponentAndInstance(PRODUCT());
        InstanceReader instanceReader = instance.getInstanceReader();

        // check policy matches with calling product
        IPolicy.PolicyInfo memory applicationInfo = instanceReader.getPolicyInfo(applicationNftId);
        if(applicationInfo.productNftId != productNftId) {
            revert ErrorPolicyServicePolicyProductMismatch(
                applicationNftId, 
                applicationInfo.productNftId, 
                productNftId);
        }

        // check policy is in state applied
        if (instanceReader.getPolicyState(applicationNftId) != APPLIED()) {
            revert ErrorPolicyServicePolicyStateNotApplied(applicationNftId);
        }
        
        StateId newPolicyState = COLLATERALIZED();

        // optional activation of policy
        if(activateAt > zeroTimestamp()) {
            newPolicyState = ACTIVE();
            applicationInfo.activatedAt = activateAt;
            applicationInfo.expiredAt = activateAt.addSeconds(applicationInfo.lifetime);
        }

        // lock bundle collateral
        Amount netPremiumAmount = AmountLib.zero(); // > 0 if immediate premium payment 

        // optional collection of premium
        if(requirePremiumPayment) {
            netPremiumAmount = _processPremiumByTreasury(
                instance, 
                applicationNftId, 
                applicationInfo.premiumAmount);

            applicationInfo.premiumPaidAmount = applicationInfo.premiumPaidAmount + applicationInfo.premiumAmount;
        }

        // store updated policy info
        instance.getInstanceStore().updatePolicy(applicationNftId, applicationInfo, newPolicyState);

        // lock collateral and update pool and bundle book keeping
        // pool retention level: fraction of sum insured that product will cover from pool funds directly
        // eg retention level 30%, payouts up to 30% of the sum insured will be made from the product's pool directly
        // for the remaining 70% the pool owns a policy that will cover claims that exceed the 30% of the sum insured
        // might also call pool component (for isVerifyingApplications pools)
        _poolService.lockCollateral(
            instance,
            productNftId,
            applicationNftId, 
            applicationInfo,
            netPremiumAmount); // for pool book keeping (fee + additional capital)

        // TODO: add logging
    }


    function calculateRequiredCollateral(
        UFixed collateralizationLevel, 
        Amount sumInsuredAmount
    )
        public 
        pure 
        virtual 
        returns(Amount collateralAmount)
    {
        UFixed collateralUFixed =  collateralizationLevel * sumInsuredAmount.toUFixed();
        return AmountLib.toAmount(collateralUFixed.toInt());
    } 

    function collectPremium(
        NftId policyNftId, 
        Timestamp activateAt
    )
        external 
        virtual
    {
        // check caller is registered product
        (NftId productNftId,, IInstance instance) = _getAndVerifyCallingComponentAndInstance(PRODUCT());
        InstanceReader instanceReader = instance.getInstanceReader();
        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);

        if (policyInfo.premiumPaidAmount == policyInfo.premiumAmount) {
            revert ErrorPolicyServicePremiumAlreadyPaid(policyNftId, policyInfo.premiumPaidAmount);
        }

        Amount unpaidPremiumAmount = policyInfo.premiumAmount - policyInfo.premiumPaidAmount;

        Amount netPremiumAmount = _processPremiumByTreasury(
                instance, 
                policyNftId, 
                unpaidPremiumAmount);

        policyInfo.premiumPaidAmount = policyInfo.premiumPaidAmount + unpaidPremiumAmount;

        _bundleService.increaseBalance(instance, policyInfo.bundleNftId, netPremiumAmount);
        instance.getInstanceStore().updatePolicy(policyNftId, policyInfo, KEEP_STATE());

        if(activateAt.gtz() && policyInfo.activatedAt.eqz()) {
            activate(policyNftId, activateAt);
        }

        // TODO: add logging
    }

    function activate(NftId policyNftId, Timestamp activateAt) public override {
        // check caller is registered product
        (,, IInstance instance) = _getAndVerifyCallingComponentAndInstance(PRODUCT());
        InstanceReader instanceReader = instance.getInstanceReader();

        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);

        require(
            policyInfo.activatedAt.eqz(),
            "ERROR:PRS-020:ALREADY_ACTIVATED");

        policyInfo.activatedAt = activateAt;
        policyInfo.expiredAt = activateAt.addSeconds(policyInfo.lifetime);

        instance.getInstanceStore().updatePolicy(policyNftId, policyInfo, ACTIVE());

        // TODO: add logging
    }


    function expire(
        NftId policyNftId
    )
        external
        override
        // solhint-disable-next-line no-empty-blocks
    {
        
    }

    function close(
        NftId policyNftId
    )
        external 
        override
    {
        (,, IInstance instance) = _getAndVerifyCallingComponentAndInstance(PRODUCT());
        InstanceReader instanceReader = instance.getInstanceReader();

        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);

        if (policyInfo.activatedAt.eqz()) {
            revert ErrorIPolicyServicePolicyNotActivated(policyNftId);
        }

        StateId state = instanceReader.getPolicyState(policyNftId);
        if (state != ACTIVE()) {
            revert ErrorIPolicyServicePolicyNotActive(policyNftId, state);
        }

        if (policyInfo.closedAt.gtz()) {
            revert ErrorIPolicyServicePolicyAlreadyClosed(policyNftId);
        }

        // TODO consider to allow for underpaid premiums (with the effects of reducing max payouts accordingly)
        if (!(policyInfo.premiumAmount == policyInfo.premiumPaidAmount)) {
            revert ErrorPolicyServicePremiumNotFullyPaid(policyNftId, policyInfo.premiumAmount, policyInfo.premiumPaidAmount);
        }

        if (policyInfo.openClaimsCount > 0) {
            revert ErrorIPolicyServiceOpenClaims(policyNftId, policyInfo.openClaimsCount);
        }

        policyInfo.closedAt = TimestampLib.blockTimestamp();

        _poolService.releaseCollateral(
            instance, 
            policyNftId, 
            policyInfo);

        instance.getInstanceStore().updatePolicy(policyNftId, policyInfo, CLOSED());
    }


    function _processPremiumByTreasury(
        IInstance instance,
        NftId policyNftId,
        Amount premiumExpectedAmount
    )
        internal
        returns (Amount netPremiumAmount)
    {
        // process token transfer(s)
        if(premiumExpectedAmount.eqz()) {
            return AmountLib.zero();
        }

        NftId productNftId = getRegistry().getObjectInfo(policyNftId).parentNftId;
        IPolicy.PolicyInfo memory policyInfo = instance.getInstanceReader().getPolicyInfo(policyNftId);
        IPolicy.Premium memory premium = _pricingService.calculatePremium(
            productNftId,
            policyInfo.riskId,
            policyInfo.sumInsuredAmount,
            policyInfo.lifetime,
            policyInfo.applicationData,
            policyInfo.bundleNftId,
            policyInfo.referralId
            );

        if (premium.premiumAmount != premiumExpectedAmount.toInt()) {
            revert ErrorPolicyServicePremiumMismatch(
                policyNftId, 
                premiumExpectedAmount, 
                AmountLib.toAmount(premium.premiumAmount));
        }

        address policyOwner = getRegistry().ownerOf(policyNftId);
        ISetup.ProductSetupInfo memory productSetupInfo = instance.getInstanceReader().getProductSetupInfo(productNftId);
        TokenHandler tokenHandler = productSetupInfo.tokenHandler;
        if (tokenHandler.getToken().allowance(policyOwner, address(tokenHandler)) < premium.premiumAmount) {
            revert ErrorIPolicyServiceInsufficientAllowance(policyOwner, address(tokenHandler), premium.premiumAmount);
        }

        Amount productFeeAmountToTransfer = AmountLib.toAmount(premium.productFeeFixAmount + premium.productFeeVarAmount);
        Amount distributionFeeAmountToTransfer = AmountLib.toAmount(premium.distributionFeeFixAmount + premium.distributionFeeVarAmount - premium.discountAmount);
        uint256 poolFeeAmountToTransfer = premium.poolFeeFixAmount + premium.poolFeeVarAmount;
        uint256 bundleFeeAmountToTransfer = premium.bundleFeeFixAmount + premium.bundleFeeVarAmount;
        Amount poolAmountToTransfer = AmountLib.toAmount(premium.netPremiumAmount + poolFeeAmountToTransfer + bundleFeeAmountToTransfer);

        netPremiumAmount = AmountLib.toAmount(premium.netPremiumAmount);

        // move product fee to product wallet
        {
            address productWallet = productSetupInfo.wallet;
            tokenHandler.transfer(policyOwner, productWallet, productFeeAmountToTransfer);
        }

        // move distribution fee to distribution wallet
        {
            ISetup.DistributionSetupInfo memory distributionSetupInfo = instance.getInstanceReader().getDistributionSetupInfo(productSetupInfo.distributionNftId);
            address distributionWallet = distributionSetupInfo.wallet;
            tokenHandler.transfer(policyOwner, distributionWallet, distributionFeeAmountToTransfer);
            _distributionService.processSale(productSetupInfo.distributionNftId, policyInfo.referralId, premium, distributionFeeAmountToTransfer);
        }
        
        // move netpremium, bundleFee and poolFee to pool wallet
        {
            address poolWallet = instance.getInstanceReader().getComponentInfo(productSetupInfo.poolNftId).wallet;
            tokenHandler.transfer(policyOwner, poolWallet, poolAmountToTransfer);
            _poolService.processSale(policyInfo.bundleNftId, premium, poolAmountToTransfer);
        }

        // validate total amount transferred
        {
            Amount totalTransferred = distributionFeeAmountToTransfer + poolAmountToTransfer + productFeeAmountToTransfer;

            if (premium.premiumAmount != totalTransferred.toInt()) {
                revert ErrorPolicyServiceTransferredPremiumMismatch(
                    policyNftId, 
                    AmountLib.toAmount(premium.premiumAmount), 
                    totalTransferred);
            }
        }

        // TODO: add logging
    }
}