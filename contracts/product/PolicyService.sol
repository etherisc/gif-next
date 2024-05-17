// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IRegistry} from "../registry/IRegistry.sol";
import {Product} from "./Product.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IDistributionComponent} from "../distribution/IDistributionComponent.sol";
import {IInstance} from "../instance/IInstance.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";
import {IPoolComponent} from "../pool/IPoolComponent.sol";
import {IRisk} from "../instance/module/IRisk.sol";
import {IBundle} from "../instance/module/IBundle.sol";

import {TokenHandler} from "../shared/TokenHandler.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {ClaimId, ClaimIdLib} from "../type/ClaimId.sol";
import {Timestamp, TimestampLib, zeroTimestamp} from "../type/Timestamp.sol";
import {UFixed, UFixedLib} from "../type/UFixed.sol";
import {ObjectType, APPLICATION, COMPONENT, DISTRIBUTION, PRODUCT, POOL, POLICY, BUNDLE, CLAIM, PRICE} from "../type/ObjectType.sol";
import {APPLIED, COLLATERALIZED, ACTIVE, KEEP_STATE, CLOSED, DECLINED, CONFIRMED} from "../type/StateId.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {PayoutId, PayoutIdLib} from "../type/PayoutId.sol";
import {ReferralId} from "../type/Referral.sol";
import {StateId} from "../type/StateId.sol";
import {VersionPart} from "../type/Version.sol";

import {ComponentVerifyingService} from "../shared/ComponentVerifyingService.sol";
import {IApplicationService} from "./IApplicationService.sol";
import {IBundleService} from "../pool/IBundleService.sol";
import {IClaimService} from "./IClaimService.sol";
import {IComponentService} from "../shared/IComponentService.sol";
import {IDistributionService} from "../distribution/IDistributionService.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {InstanceStore} from "../instance/InstanceStore.sol";
import {IPolicyService} from "./IPolicyService.sol";
import {IPoolService} from "../pool/IPoolService.sol";
import {IPricingService} from "./IPricingService.sol";
import {IService} from "../shared/IService.sol";
import {Service} from "../shared/Service.sol";

contract PolicyService is
    ComponentVerifyingService, 
    IPolicyService
{
    using NftIdLib for NftId;
    using TimestampLib for Timestamp;

    IApplicationService internal _applicationService;
    IComponentService internal _componentService;
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
        (
            address registryAddress,, 
            //address managerAddress
            address authority
        ) = abi.decode(data, (address, address, address));

        initializeService(registryAddress, authority, owner);

        VersionPart majorVersion = getVersion().toMajorPart();
        _applicationService = IApplicationService(getRegistry().getServiceAddress(APPLICATION(), majorVersion));
        _bundleService = IBundleService(getRegistry().getServiceAddress(BUNDLE(), majorVersion));
        _componentService = IComponentService(getRegistry().getServiceAddress(COMPONENT(), majorVersion));
        _claimService = IClaimService(getRegistry().getServiceAddress(CLAIM(), majorVersion));
        _poolService = IPoolService(getRegistry().getServiceAddress(POOL(), majorVersion));
        _distributionService = IDistributionService(getRegistry().getServiceAddress(DISTRIBUTION(), majorVersion));
        _pricingService = IPricingService(getRegistry().getServiceAddress(PRICE(), majorVersion));

        registerInterface(type(IPolicyService).interfaceId);
    }


    function getDomain() public pure override returns(ObjectType) {
        return POLICY();
    }


    function _getAndVerifyInstanceAndProduct() internal view returns (Product product) {
        IRegistry.ObjectInfo memory productInfo;
        (, productInfo,) = _getAndVerifyActiveComponent(PRODUCT());
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

    event LogDebug(uint idx, string message);

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
        (NftId productNftId,, IInstance instance) = _getAndVerifyActiveComponent(PRODUCT());
        InstanceReader instanceReader = instance.getInstanceReader();

        // check policy is in state applied
        if (instanceReader.getPolicyState(applicationNftId) != APPLIED()) {
            revert ErrorPolicyServicePolicyStateNotApplied(applicationNftId);
        }

        // check policy matches with calling product
        IPolicy.PolicyInfo memory applicationInfo = instanceReader.getPolicyInfo(applicationNftId);
        if(applicationInfo.productNftId != productNftId) {
            revert ErrorPolicyServicePolicyProductMismatch(
                applicationNftId, 
                applicationInfo.productNftId, 
                productNftId);
        }
        
        StateId newPolicyState = COLLATERALIZED();

        // actual collateralizaion
        (
            Amount localCollateralAmount,
            Amount totalCollateralAmount
        ) = _poolService.lockCollateral(
            instance,
            productNftId,
            applicationNftId,
            applicationInfo.bundleNftId,
            applicationInfo.sumInsuredAmount);

        // optional activation of policy
        if(activateAt > zeroTimestamp()) {
            newPolicyState = ACTIVE();
            applicationInfo.activatedAt = activateAt;
            applicationInfo.expiredAt = activateAt.addSeconds(applicationInfo.lifetime);
        }

        // optional collection of premium
        if(requirePremiumPayment) {
            Amount premiumPaidAmount = _calculateAndCollectPremium(
                instance,
                applicationNftId,
                applicationInfo);

            applicationInfo.premiumPaidAmount = premiumPaidAmount;
        }

        // store updated policy info
        instance.getInstanceStore().updatePolicy(
            applicationNftId, 
            applicationInfo, 
            newPolicyState);

        // TODO add calling pool contract if it needs to validate application

        // TODO: add logging
    }


    function collectPremium(
        NftId policyNftId, 
        Timestamp activateAt
    )
        external 
        virtual
    {
        // check caller is registered product
        (,, IInstance instance) = _getAndVerifyActiveComponent(PRODUCT());
        InstanceReader instanceReader = instance.getInstanceReader();
        StateId stateId = instanceReader.getPolicyState(policyNftId);

        // check policy is in state collateralized or active
        if (!(stateId == COLLATERALIZED() || stateId == ACTIVE())) {
            revert ErrorPolicyServicePolicyStateNotCollateralizedOrApplied(policyNftId);
        }

        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);

        // check if premium is already collected
        if (policyInfo.premiumPaidAmount.gtz()) {
            revert ErrorPolicyServicePremiumAlreadyPaid(policyNftId, policyInfo.premiumPaidAmount);
        }

        policyInfo.premiumPaidAmount = _calculateAndCollectPremium(
                instance,
                policyNftId,
                policyInfo);

        instance.getInstanceStore().updatePolicy(policyNftId, policyInfo, KEEP_STATE());

        if(activateAt.gtz() && policyInfo.activatedAt.eqz()) {
            activate(policyNftId, activateAt);
        }

        // TODO: add logging
    }

    function activate(NftId policyNftId, Timestamp activateAt) public override {
        // check caller is registered product
        (,, IInstance instance) = _getAndVerifyActiveComponent(PRODUCT());
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
        (,, IInstance instance) = _getAndVerifyActiveComponent(PRODUCT());
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


    function _calculateAndCollectPremium(
        IInstance instance,
        NftId applicationNftId,
        IPolicy.PolicyInfo memory applicationInfo
    )
        internal
        virtual
        returns (
            Amount premiumPaidAmount
        )
    {
        NftId productNftId = applicationInfo.productNftId;

        // calculate premium details
        IPolicy.Premium memory premium = _pricingService.calculatePremium(
            productNftId,
            applicationInfo.riskId,
            applicationInfo.sumInsuredAmount,
            applicationInfo.lifetime,
            applicationInfo.applicationData,
            applicationInfo.bundleNftId,
            applicationInfo.referralId);


        // update financials and transfer premium tokens
        premiumPaidAmount = _processAndCollect(
            instance, 
            productNftId,
            applicationNftId, 
            applicationInfo.premiumAmount,
            applicationInfo.bundleNftId,
            applicationInfo.referralId,
            premium);
    }


    function _processAndCollect(
        IInstance instance,
        NftId productNftId,
        NftId policyNftId,
        Amount premiumExpectedAmount,
        NftId bundleNftId,
        ReferralId referralId,
        IPolicy.Premium memory premium
    )
        internal
        virtual
        returns (Amount premiumPaidAmount)
    {
        InstanceReader instanceReader = instance.getInstanceReader();
        TokenHandler tokenHandler = instanceReader.getComponentInfo(productNftId).tokenHandler;
        address policyHolder = getRegistry().ownerOf(policyNftId);
        premiumPaidAmount = AmountLib.toAmount(premium.premiumAmount);

        _checkPremiumBalanceAndAllowance(
            tokenHandler, 
            policyHolder, 
            premiumExpectedAmount,
            premiumPaidAmount);

        _processSaleAndTransferFunds(
            instanceReader, 
            instance.getInstanceStore(), 
            tokenHandler, 
            policyHolder, 
            productNftId, 
            bundleNftId, 
            referralId, 
            premium);
    }


    function _checkPremiumBalanceAndAllowance(
        TokenHandler tokenHandler, 
        address policyHolder, 
        Amount premiumExpectedAmount,
        Amount premiumPaidAmount
    )
        internal
        virtual
        view
    {
        // TODO decide how to handle this properly
        // not clear if this is the best way to handle this
        if (premiumExpectedAmount < premiumPaidAmount) {
            revert ErrorPolicyServicePremiumHigherThanExpected(premiumExpectedAmount, premiumPaidAmount);
        }

        uint256 premiumAmount = premiumPaidAmount.toInt();
        uint256 balance = tokenHandler.getToken().balanceOf(policyHolder);
        uint256 allowance = tokenHandler.getToken().allowance(policyHolder, address(tokenHandler));
    
        if (balance < premiumAmount) {
            revert ErrorPolicyServiceBalanceInsufficient(policyHolder, premiumAmount, balance);
        }

        if (allowance < premiumAmount) {
            revert ErrorPolicyServiceAllowanceInsufficient(policyHolder, address(tokenHandler), premiumAmount, allowance);
        }
    }


    function _processSaleAndTransferFunds(
        InstanceReader instanceReader,
        InstanceStore instanceStore,
        TokenHandler tokenHandler,
        address policyHolder,
        NftId productNftId,
        NftId bundleNftId,
        ReferralId referralId,
        IPolicy.Premium memory premium
    )
        internal
        virtual
    {
        (
            NftId distributionNftId,
            address distributionWallet,
            address poolWallet,
            address productWallet
        ) = _getDistributionNftAndWallets(
            instanceReader, 
            productNftId);

        // update product fees, distribution and pool fees 
        _componentService.increaseProductFees(
            instanceStore, 
            productNftId, 
            AmountLib.toAmount(premium.productFeeVarAmount + premium.productFeeFixAmount));

        // update distribution fees and distributor commission and pool fees 
        _distributionService.processSale(
            distributionNftId, 
            referralId, 
            premium);

        // update pool and bundle fees 
        _poolService.processSale(
            bundleNftId, 
            premium);

        // transfer premium amounts to target wallets
        tokenHandler.transfer(policyHolder, productWallet, premium.productFeeAmount);
        tokenHandler.transfer(policyHolder, distributionWallet, premium.distributionFeeAndCommissionAmount);
        tokenHandler.transfer(policyHolder, poolWallet, premium.poolPremiumAndFeeAmount);
    }


    function _getTokenHandlerAndProductWallet(
        InstanceReader instanceReader,
        NftId productNftId
    )
        internal 
        virtual
        view 
        returns (
            TokenHandler tokenHandler
        )
    {
        tokenHandler = instanceReader.getComponentInfo(productNftId).tokenHandler;
    }

    function _getDistributionNftAndWallets(
        InstanceReader instanceReader,
        NftId productNftId
    )
        internal 
        virtual
        view returns (
            NftId distributionNftId,
            address distributionWallet,
            address poolWallet,
            address productWallet
        )
    {
        IComponents.ProductInfo memory productInfo = instanceReader.getProductInfo(productNftId);
        distributionNftId = productInfo.distributionNftId;
        distributionWallet = instanceReader.getComponentInfo(distributionNftId).wallet;
        poolWallet = instanceReader.getComponentInfo(productInfo.poolNftId).wallet;
        productWallet = instanceReader.getComponentInfo(productNftId).wallet;
    }
}