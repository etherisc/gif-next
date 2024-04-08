// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../../registry/IRegistry.sol";
import {Product} from "../../components/Product.sol";
import {IComponents} from "../module/IComponents.sol";
import {IDistributionComponent} from "../../components/IDistributionComponent.sol";
import {IInstance} from "../IInstance.sol";
import {IPolicy} from "../module/IPolicy.sol";
import {IPoolComponent} from "../../components/IPoolComponent.sol";
import {IRisk} from "../module/IRisk.sol";
import {IBundle} from "../module/IBundle.sol";
import {ISetup} from "../module/ISetup.sol";

import {TokenHandler} from "../../shared/TokenHandler.sol";

import {Amount, AmountLib} from "../../types/Amount.sol";
import {ClaimId, ClaimIdLib} from "../../types/ClaimId.sol";
import {Timestamp, TimestampLib, zeroTimestamp} from "../../types/Timestamp.sol";
import {UFixed, UFixedLib} from "../../types/UFixed.sol";
import {ObjectType, APPLICATION, DISTRIBUTION, PRODUCT, POOL, POLICY, BUNDLE, CLAIM} from "../../types/ObjectType.sol";
import {APPLIED, COLLATERALIZED, ACTIVE, KEEP_STATE, CLOSED, DECLINED, CONFIRMED} from "../../types/StateId.sol";
import {NftId, NftIdLib} from "../../types/NftId.sol";
import {PayoutId, PayoutIdLib} from "../../types/PayoutId.sol";
import {StateId} from "../../types/StateId.sol";
import {VersionPart} from "../../types/Version.sol";

import {ComponentService} from "../base/ComponentService.sol";
import {IApplicationService} from "./IApplicationService.sol";
import {IBundleService} from "./IBundleService.sol";
import {IClaimService} from "./IClaimService.sol";
import {IDistributionService} from "./IDistributionService.sol";
import {InstanceReader} from "../InstanceReader.sol";
import {IPolicyService} from "./IPolicyService.sol";
import {IPoolService} from "./IPoolService.sol";
import {IService} from "../../shared/IService.sol";
import {Service} from "../../shared/Service.sol";


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

        registerInterface(type(IPolicyService).interfaceId);
    }


    function getDomain() public pure override returns(ObjectType) {
        return POLICY();
    }


    function _getAndVerifyInstanceAndProduct() internal view returns (Product product) {
        IRegistry.ObjectInfo memory productInfo;
        (, productInfo,) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
        product = Product(productInfo.objectAddress);
    }


    function decline(
        NftId policyNftId
    )
        external
        override
    {
        require(false, "ERROR:PRS-235:NOT_YET_IMPLEMENTED");
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
        (NftId productNftId,, IInstance instance) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
        InstanceReader instanceReader = instance.getInstanceReader();

        // check policy matches with calling product
        IPolicy.PolicyInfo memory applicationInfo = instanceReader.getPolicyInfo(applicationNftId);
        require(applicationInfo.productNftId == productNftId, "POLICY_PRODUCT_MISMATCH");

        // check policy is in state applied
        require(instanceReader.getPolicyState(applicationNftId) == APPLIED(), "ERROR:PRS-021:STATE_NOT_APPLIED");
        
        StateId newPolicyState = COLLATERALIZED();

        // optional activation of policy
        if(activateAt > zeroTimestamp()) {
            newPolicyState = ACTIVE();
            applicationInfo.activatedAt = activateAt;
            applicationInfo.expiredAt = activateAt.addSeconds(applicationInfo.lifetime);
        }

        // lock bundle collateral
        uint256 netPremiumAmount = 0; // > 0 if immediate premium payment 

        // optional collection of premium
        if(requirePremiumPayment) {
            netPremiumAmount = _processPremiumByTreasury(
                instance, 
                applicationNftId, 
                applicationInfo.premiumAmount);

            applicationInfo.premiumPaidAmount += applicationInfo.premiumAmount;
        }

        // store updated policy info
        instance.updatePolicy(applicationNftId, applicationInfo, newPolicyState);

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


    function calculateRequiredCollateral(UFixed collateralizationLevel, uint256 sumInsuredAmount) public pure override returns(uint256 collateralAmount) {
        UFixed sumInsuredUFixed = UFixedLib.toUFixed(sumInsuredAmount);
        UFixed collateralUFixed =  collateralizationLevel * sumInsuredUFixed;
        return collateralUFixed.toInt();
    } 

    function collectPremium(NftId policyNftId, Timestamp activateAt) external override {
        // check caller is registered product
        (NftId productNftId,, IInstance instance) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
        InstanceReader instanceReader = instance.getInstanceReader();
        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);

        if (policyInfo.premiumPaidAmount == policyInfo.premiumAmount) {
            revert ErrorIPolicyServicePremiumAlreadyPaid(policyNftId, policyInfo.premiumPaidAmount);
        }

        uint256 unpaidPremiumAmount = policyInfo.premiumAmount - policyInfo.premiumPaidAmount;

        uint256 netPremiumAmount = _processPremiumByTreasury(
                instance, 
                policyNftId, 
                unpaidPremiumAmount);

        policyInfo.premiumPaidAmount += unpaidPremiumAmount;

        _bundleService.increaseBalance(instance, policyInfo.bundleNftId, netPremiumAmount);
        instance.updatePolicy(policyNftId, policyInfo, KEEP_STATE());

        if(activateAt.gtz() && policyInfo.activatedAt.eqz()) {
            activate(policyNftId, activateAt);
        }

        // TODO: add logging
    }

    function activate(NftId policyNftId, Timestamp activateAt) public override {
        // check caller is registered product
        (,, IInstance instance) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
        InstanceReader instanceReader = instance.getInstanceReader();

        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);

        require(
            policyInfo.activatedAt.eqz(),
            "ERROR:PRS-020:ALREADY_ACTIVATED");

        policyInfo.activatedAt = activateAt;
        policyInfo.expiredAt = activateAt.addSeconds(policyInfo.lifetime);

        instance.updatePolicy(policyNftId, policyInfo, ACTIVE());

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
        (,, IInstance instance) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
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
        if (policyInfo.premiumAmount != policyInfo.premiumPaidAmount) {
            revert ErrorIPolicyServicePremiumNotFullyPaid(policyNftId, policyInfo.premiumAmount, policyInfo.premiumPaidAmount);
        }

        if (policyInfo.openClaimsCount > 0) {
            revert ErrorIPolicyServiceOpenClaims(policyNftId, policyInfo.openClaimsCount);
        }

        policyInfo.closedAt = TimestampLib.blockTimestamp();

        _poolService.releaseCollateral(
            instance, 
            policyNftId, 
            policyInfo);

        instance.updatePolicy(policyNftId, policyInfo, CLOSED());
    }

    function submitClaim(
        NftId policyNftId, 
        Amount claimAmount,
        bytes memory claimData
    )
        external
        virtual
        returns (ClaimId claimId)
    {
        (
            IInstance instance,
            InstanceReader instanceReader,
            IPolicy.PolicyInfo memory policyInfo
        ) = _verifyCallerWithPolicy(policyNftId);

        // check policy is in its active period
        if(policyInfo.activatedAt.eqz() || TimestampLib.blockTimestamp() >= policyInfo.expiredAt) {
            revert ErrorPolicyServicePolicyNotOpen(policyNftId);
        }

        // check policy including this claim is still within sum insured
        if(policyInfo.payoutAmount.toInt() + claimAmount.toInt() > policyInfo.sumInsuredAmount) {
            revert ErrorPolicyServiceClaimExceedsSumInsured(
                policyNftId, 
                AmountLib.toAmount(policyInfo.sumInsuredAmount), 
                AmountLib.toAmount(policyInfo.payoutAmount.toInt() + claimAmount.toInt()));
        }

        // create new claim
        claimId = ClaimIdLib.toClaimId(policyInfo.claimsCount + 1);
        _claimService.submit(instance, policyNftId, claimId, claimAmount, claimData);

        // update and save policy info with instance
        policyInfo.claimsCount += 1;
        policyInfo.openClaimsCount += 1;
        instance.updatePolicy(policyNftId, policyInfo, KEEP_STATE());

        emit LogPolicyServiceClaimSubmitted(policyNftId, claimId, claimAmount);
    }

    function confirmClaim(
        NftId policyNftId, 
        ClaimId claimId,
        Amount confirmedAmount
    )
        external
    {
        (
            IInstance instance,
            InstanceReader instanceReader,
            IPolicy.PolicyInfo memory policyInfo
        ) = _verifyCallerWithPolicy(policyNftId);

        // check/update claim info
        _claimService.confirm(instance, instanceReader, policyNftId, claimId, confirmedAmount);

        // update and save policy info with instance
        instance.updatePolicy(policyNftId, policyInfo, CONFIRMED());

        emit LogPolicyServiceClaimConfirmed(policyNftId, claimId, confirmedAmount);
    }

    function declineClaim(
        NftId policyNftId, 
        ClaimId claimId
    )
        external
    {
        (
            IInstance instance,
            InstanceReader instanceReader,
            IPolicy.PolicyInfo memory policyInfo
        ) = _verifyCallerWithPolicy(policyNftId);

        // check/update claim info
        _claimService.decline(instance, instanceReader, policyNftId, claimId);

        // update and save policy info with instance
        policyInfo.openClaimsCount -= 1;
        instance.updatePolicy(policyNftId, policyInfo, KEEP_STATE());

        emit LogPolicyServiceClaimDeclined(policyNftId, claimId);
    }

    function closeClaim(
        NftId policyNftId, 
        ClaimId claimId
    )
        external
    {
        (
            IInstance instance,
            InstanceReader instanceReader,
            IPolicy.PolicyInfo memory policyInfo
        ) = _verifyCallerWithPolicy(policyNftId);

        // check/update claim info
        _claimService.close(instance, instanceReader, policyNftId, claimId);

        // update and save policy info with instance
        policyInfo.openClaimsCount -= 1;
        instance.updatePolicy(policyNftId, policyInfo, KEEP_STATE());

        emit LogPolicyServiceClaimClosed(policyNftId, claimId);
    }

    function _verifyCallerWithPolicy(
        NftId policyNftId
    )
        internal
        returns (
            IInstance instance,
            InstanceReader instanceReader,
            IPolicy.PolicyInfo memory policyInfo
        )
    {
        NftId productNftId;
        (productNftId,, instance) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
        instanceReader = instance.getInstanceReader();

        // check caller(product) policy match
        policyInfo = instanceReader.getPolicyInfo(policyNftId);
        if(policyInfo.productNftId != productNftId) {
            revert ErrorPolicyServicePolicyProductMismatch(policyNftId, 
            policyInfo.productNftId, 
            productNftId);
        }
    }

    function _getPoolNftId(
        IInstance instance,
        NftId productNftId
    )
        internal
        view
        returns (NftId poolNftid)
    {
        InstanceReader instanceReader = instance.getInstanceReader();
        ISetup.ProductSetupInfo memory productSetupInfo = instanceReader.getProductSetupInfo(productNftId);
        return productSetupInfo.poolNftId;
    }


    function _processPremiumByTreasury(
        IInstance instance,
        NftId policyNftId,
        uint256 premiumExpectedAmount
    )
        internal
        returns (uint256 netPremiumAmount)
    {
        // process token transfer(s)
        if(premiumExpectedAmount > 0) {
            NftId productNftId = getRegistry().getObjectInfo(policyNftId).parentNftId;
            ISetup.ProductSetupInfo memory productSetupInfo = instance.getInstanceReader().getProductSetupInfo(productNftId);
            IPolicy.PolicyInfo memory policyInfo = instance.getInstanceReader().getPolicyInfo(policyNftId);
            TokenHandler tokenHandler = productSetupInfo.tokenHandler;
            address policyOwner = getRegistry().ownerOf(policyNftId);
            address poolWallet = instance.getInstanceReader().getComponentInfo(productSetupInfo.poolNftId).wallet;
            IPolicy.Premium memory premium = _applicationService.calculatePremium(
                productNftId,
                policyInfo.riskId,
                policyInfo.sumInsuredAmount,
                policyInfo.lifetime,
                policyInfo.applicationData,
                policyInfo.bundleNftId,
                policyInfo.referralId
                );

            if (premium.premiumAmount != premiumExpectedAmount) {
                revert ErrorIPolicyServicePremiumMismatch(
                    policyNftId, 
                    premiumExpectedAmount, 
                    premium.premiumAmount);
            }

            // move product fee to product wallet
            address productWallet = productSetupInfo.wallet;
            if (tokenHandler.getToken().allowance(policyOwner, address(tokenHandler)) < premium.premiumAmount) {
                revert ErrorIPolicyServiceInsufficientAllowance(policyOwner, address(tokenHandler), premium.premiumAmount);
            }
            tokenHandler.transfer(policyOwner, productWallet, premium.productFeeFixAmount + premium.productFeeVarAmount);

            // move distribution fee to distribution wallet
            ISetup.DistributionSetupInfo memory distributionSetupInfo = instance.getInstanceReader().getDistributionSetupInfo(productSetupInfo.distributionNftId);
            address distributionWallet = distributionSetupInfo.wallet;
            uint256 distributionFeeAmountToTransfer = premium.distributionFeeFixAmount + premium.distributionFeeVarAmount - premium.discountAmount;
            tokenHandler.transfer(policyOwner, distributionWallet, distributionFeeAmountToTransfer);
            _distributionService.processSale(productSetupInfo.distributionNftId, policyInfo.referralId, premium, distributionFeeAmountToTransfer);
            
            // move netpremium to pool wallet
            tokenHandler.transfer(policyOwner, poolWallet, premium.netPremiumAmount);
            
            // TODO: move pool related tokens too
            // TODO: move bundle related tokens too
            netPremiumAmount = premium.netPremiumAmount;
        }

        // TODO: add logging
    }
}
