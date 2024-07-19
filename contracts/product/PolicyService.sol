// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IRegistry} from "../registry/IRegistry.sol";
import {Product} from "./Product.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IInstance} from "../instance/IInstance.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";

import {TokenHandler} from "../shared/TokenHandler.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {Timestamp, TimestampLib, zeroTimestamp} from "../type/Timestamp.sol";
import {ObjectType, APPLICATION, COMPONENT, DISTRIBUTION, PRODUCT, POOL, POLICY, BUNDLE, CLAIM, PRICE} from "../type/ObjectType.sol";
import {APPLIED, COLLATERALIZED, KEEP_STATE, CLOSED, DECLINED} from "../type/StateId.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
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


    function decline(
        NftId applicationNftId // = policyNftId
    )
        external
        virtual override
    {
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
        

        // store updated policy info
        instance.getInstanceStore().updatePolicyState(
            applicationNftId, 
            DECLINED());

        emit LogPolicyServicePolicyDeclined(applicationNftId);
    }


    /// @inheritdoc IPolicyService
    function createPolicy(
        NftId applicationNftId, // = policyNftId
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
        
        // actual collateralizaion
        _poolService.lockCollateral(
            instance,
            address(instanceReader.getComponentInfo(productNftId).token),
            productNftId,
            applicationNftId,
            applicationInfo.bundleNftId,
            applicationInfo.sumInsuredAmount);

        // optional activation of policy
        if(activateAt > zeroTimestamp()) {
            applicationInfo = _activate(
                applicationNftId, 
                applicationInfo, 
                activateAt);
        }

        // update policy and set state to collateralized
        instance.getInstanceStore().updatePolicy(
            applicationNftId, 
            applicationInfo, 
            COLLATERALIZED());

        // calculate and store premium
        IPolicy.Premium memory premium = _pricingService.calculatePremium(
            productNftId,
            applicationInfo.riskId,
            applicationInfo.sumInsuredAmount,
            applicationInfo.lifetime,
            applicationInfo.applicationData,
            applicationInfo.bundleNftId,
            applicationInfo.referralId);

        instance.getInstanceStore().createPremium(
            applicationNftId,
            premium);

        // update referral counter 
        {
            IComponents.ProductInfo memory productInfo = instanceReader.getProductInfo(productNftId);
            _distributionService.processReferral(
                productInfo.distributionNftId, 
                applicationInfo.referralId);
        }
        
        // TODO add calling pool contract if it needs to validate application

        // TODO: add logging

        // TODO: add callback IPolicyHolder.policyActivated() if applicable
    }


    /// @inheritdoc IPolicyService
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
        if (!(stateId == COLLATERALIZED())) {
            revert ErrorPolicyServicePolicyStateNotCollateralized(policyNftId);
        }

        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);

        // check if premium is already collected
        if (policyInfo.premiumPaidAmount.gtz()) {
            revert ErrorPolicyServicePremiumAlreadyPaid(policyNftId, policyInfo.premiumPaidAmount);
        }

        IPolicy.Premium memory premium = instanceReader.getPremiumInfo(policyNftId); 
        policyInfo.premiumPaidAmount = AmountLib.toAmount(premium.premiumAmount);

        _processPremium(
            instance,
            policyNftId,
            policyInfo,
            premium);

        // optionally activate policy
        if(activateAt.gtz()) {
            policyInfo = _activate(policyNftId, policyInfo, activateAt);
        }

        instance.getInstanceStore().updatePolicy(policyNftId, policyInfo, KEEP_STATE());

        // TODO: add logging

        _transferFunds(instanceReader, policyNftId, policyInfo.productNftId, premium);

        // TODO: add callback IPolicyHolder.policyActivated() if applicable
    }

    /// @inheritdoc IPolicyService
    function activate(NftId policyNftId, Timestamp activateAt) public override {
        // check caller is registered product
        (,, IInstance instance) = _getAndVerifyActiveComponent(PRODUCT());
        InstanceReader instanceReader = instance.getInstanceReader();

        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        policyInfo = _activate(policyNftId, policyInfo, activateAt);

        instance.getInstanceStore().updatePolicy(policyNftId, policyInfo, KEEP_STATE());

        // TODO: add logging

        // TODO: add callback IPolicyHolder.policyActivated() if applicable
    }


    /// @inheritdoc IPolicyService
    function expire(
        NftId policyNftId,
        Timestamp expireAt
    )
        external
        override
        virtual
        returns (Timestamp expiredAt)
    {
        (NftId productNftId,, IInstance instance) = _getAndVerifyActiveComponent(PRODUCT());
        InstanceReader instanceReader = instance.getInstanceReader();

        // check policy matches with calling product
        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        if(policyInfo.productNftId != productNftId) {
            revert ErrorPolicyServicePolicyProductMismatch(
                policyNftId, 
                policyInfo.productNftId, 
                productNftId);
        }

        // check policy is active
        StateId policyState = instanceReader.getPolicyState(policyNftId);
        if (!_policyHasBeenActivated(policyState, policyInfo)) {
            revert ErrorPolicyServicePolicyNotActive(policyNftId, policyState);
        }

        // set return value to provided timestamp
        expiredAt = expireAt;

        // update expiredAt to current block timestamp if not set
        if (expiredAt.eqz()) {
            expiredAt = TimestampLib.blockTimestamp();
        }

        // check expiredAt represents a valid expiry time
        if (expiredAt >= policyInfo.expiredAt) {
            revert ErrorPolicyServicePolicyExpirationTooLate(policyNftId, policyInfo.expiredAt, expireAt);
        }
        if (expiredAt < TimestampLib.blockTimestamp()) {
            revert ErrorPolicyServicePolicyExpirationTooEarly(policyNftId, TimestampLib.blockTimestamp(), expireAt);
        }

        // update policyInfo with new expiredAt timestamp
        policyInfo.expiredAt = expiredAt;
        instance.getInstanceStore().updatePolicy(policyNftId, policyInfo, KEEP_STATE());

        emit LogPolicyServicePolicyExpirationUpdated(policyNftId, expiredAt);

        // TODO: add callback IPolicyHolder.policyExpired() if applicable
    }


    function close(
        NftId policyNftId
    )
        external 
        override
    {
        (,, IInstance instance) = _getAndVerifyActiveComponent(PRODUCT());
        InstanceReader instanceReader = instance.getInstanceReader();

        // check that policy has been activated
        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        StateId policyState = instanceReader.getPolicyState(policyNftId);
        if (!_policyHasBeenActivated(policyState, policyInfo)) {
            revert ErrorPolicyServicePolicyNotActive(policyNftId, policyState);
        }

        // check that policy has not already been closed
        if (policyInfo.closedAt.gtz()) {
            revert ErrorPolicyServicePolicyAlreadyClosed(policyNftId);
        }

        // check that policy does not have any open claims
        if (policyInfo.openClaimsCount > 0) {
            revert ErrorPolicyServiceOpenClaims(policyNftId, policyInfo.openClaimsCount);
        }

        // TODO consider to allow for underpaid premiums (with the effects of reducing max payouts accordingly)
        // TODO consider to remove requirement for fully paid premiums altogether
        if (!(policyInfo.premiumAmount == policyInfo.premiumPaidAmount)) {
            revert ErrorPolicyServicePremiumNotFullyPaid(policyNftId, policyInfo.premiumAmount, policyInfo.premiumPaidAmount);
        }

        // release (remaining) collateral that was blocked by policy
        _poolService.releaseCollateral(
            instance, 
            address(instanceReader.getComponentInfo(policyInfo.productNftId).token),
            policyNftId, 
            policyInfo);

        // TODO consider to also set expiredAt to current block timestamp if that timestamp is still in the futue

        // update policy state to closed
        policyInfo.closedAt = TimestampLib.blockTimestamp();
        instance.getInstanceStore().updatePolicy(policyNftId, policyInfo, CLOSED());

        // TODO add logging
    }


    /// @dev calculates the premium and updates all counters in the other services
    function _processPremium(
        IInstance instance,
        NftId applicationNftId,
        IPolicy.PolicyInfo memory applicationInfo,
        IPolicy.Premium memory premium
    )
        internal
        virtual
    {
        NftId productNftId = applicationInfo.productNftId;
        InstanceReader instanceReader = instance.getInstanceReader();

        // check if premium balance and allowance of policy holder is sufficient
        {
            TokenHandler tokenHandler = _getTokenHandler(instanceReader, productNftId);
            address policyHolder = getRegistry().ownerOf(applicationNftId);
        
            _checkPremiumBalanceAndAllowance(
                tokenHandler.getToken(), 
                address(tokenHandler),
                policyHolder, 
                AmountLib.toAmount(premium.premiumAmount));
        }

        // update the counters
        _processSale(
            instanceReader, 
            instance.getInstanceStore(), 
            productNftId, 
            applicationInfo.bundleNftId, 
            applicationInfo.referralId, 
            premium);
    }

    function _activate(
        NftId policyNftId, 
        IPolicy.PolicyInfo memory policyInfo,
        Timestamp activateAt
    )
        internal
        virtual
        view 
        returns (IPolicy.PolicyInfo memory)
    {
        // fail if policy has already been activated and activateAt is different
        if(! policyInfo.activatedAt.eqz() && activateAt != policyInfo.activatedAt) {
            revert ErrorPolicyServicePolicyAlreadyActivated(policyNftId);
        }

        // ignore if policy has already been activated and activateAt is the same
        if (policyInfo.activatedAt == activateAt) {
            return policyInfo;
        }

        policyInfo.activatedAt = activateAt;
        policyInfo.expiredAt = activateAt.addSeconds(policyInfo.lifetime);

        return policyInfo;
    }

    /// @dev update counters by calling the involved services
    function _processSale(
        InstanceReader instanceReader,
        InstanceStore instanceStore,
        NftId productNftId,
        NftId bundleNftId,
        ReferralId referralId,
        IPolicy.Premium memory premium
    )
        internal
        virtual
    {
        (NftId distributionNftId, , , ) = _getDistributionNftAndWallets(
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
    }


    /// @dev transfer the premium to the wallets the premium is distributed to
    function _transferFunds(
        InstanceReader instanceReader,
        NftId policyNftId,
        NftId productNftId,
        IPolicy.Premium memory premium
    )
        internal
        virtual
    {
        TokenHandler tokenHandler = _getTokenHandler(instanceReader, productNftId);
        address policyHolder = getRegistry().ownerOf(policyNftId);

        (
            ,
            address distributionWallet,
            address poolWallet,
            address productWallet
        ) = _getDistributionNftAndWallets(
            instanceReader, 
            productNftId);

        tokenHandler.collectTokensToThreeRecipients(
            policyHolder,
            productWallet,
            premium.productFeeAmount,
            distributionWallet,
            premium.distributionFeeAndCommissionAmount,
            poolWallet,
            premium.poolPremiumAndFeeAmount);
    }


    /// @dev checks that policy has been collateralized and has been activated.
    /// does not check if policy has been expired or closed.
    function _policyHasBeenActivated(
        StateId policyState,
        IPolicy.PolicyInfo memory policyInfo
    )
        internal
        view
        returns (bool)
    {
        if (policyState != COLLATERALIZED()) { return false; } 
        if (TimestampLib.blockTimestamp() < policyInfo.activatedAt) { return false; } 
        return true;
    }


    /// @dev checks the balance and allowance of the policy holder
    function _checkPremiumBalanceAndAllowance(
        IERC20Metadata token,
        address tokenHandlerAddress, 
        address policyHolder, 
        Amount premiumAmount
    )
        internal
        virtual
        view
    {
        uint256 premium = premiumAmount.toInt();
        uint256 balance = token.balanceOf(policyHolder);
        uint256 allowance = token.allowance(policyHolder, tokenHandlerAddress);
    
        if (balance < premium) {
            revert ErrorPolicyServiceBalanceInsufficient(policyHolder, premium, balance);
        }

        if (allowance < premium) {
            revert ErrorPolicyServiceAllowanceInsufficient(policyHolder, tokenHandlerAddress, premium, allowance);
        }
    }


    function _getTokenHandler(
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


    function _getAndVerifyInstanceAndProduct() internal view returns (Product product) {
        IRegistry.ObjectInfo memory productInfo;
        (, productInfo,) = _getAndVerifyActiveComponent(PRODUCT());
        product = Product(productInfo.objectAddress);
    }


    function _getDomain() internal pure override returns(ObjectType) {
        return POLICY();
    }
}