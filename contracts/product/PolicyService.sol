// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IAccountingService} from "../accounting/IAccountingService.sol";
import {IComponentService} from "../shared/IComponentService.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IDistributionService} from "../distribution/IDistributionService.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {InstanceStore} from "../instance/InstanceStore.sol";
import {IInstance} from "../instance/IInstance.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";
import {IPolicyHolder} from "../shared/IPolicyHolder.sol";
import {IPolicyService} from "./IPolicyService.sol";
import {IPoolService} from "../pool/IPoolService.sol";
import {IPricingService} from "./IPricingService.sol";
import {IRegistry} from "../registry/IRegistry.sol";

import {Amount} from "../type/Amount.sol";
import {APPLIED, COLLATERALIZED, KEEP_STATE, CLOSED, DECLINED, PAID} from "../type/StateId.sol";
import {ContractLib} from "../shared/ContractLib.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, ACCOUNTING, COMPONENT, DISTRIBUTION, PRODUCT, POOL, POLICY, PRICE} from "../type/ObjectType.sol";
import {PolicyServiceLib} from "./PolicyServiceLib.sol";
import {ReferralId} from "../type/Referral.sol";
import {RiskId} from "../type/RiskId.sol";
import {ComponentVerifyingService} from "../shared/ComponentVerifyingService.sol";
import {StateId} from "../type/StateId.sol";
import {Timestamp, TimestampLib} from "../type/Timestamp.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {VersionPart} from "../type/Version.sol";


contract PolicyService is
    ComponentVerifyingService, 
    IPolicyService
{
    IAccountingService private _accountingService;
    IComponentService internal _componentService;
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
            address authority,
            address registry
        ) = abi.decode(data, (address, address));

        __Service_init(authority, registry, owner);

        VersionPart majorVersion = getVersion().toMajorPart();
        _accountingService = IAccountingService(getRegistry().getServiceAddress(ACCOUNTING(), majorVersion));
        _componentService = IComponentService(getRegistry().getServiceAddress(COMPONENT(), majorVersion));
        _poolService = IPoolService(getRegistry().getServiceAddress(POOL(), majorVersion));
        _distributionService = IDistributionService(getRegistry().getServiceAddress(DISTRIBUTION(), majorVersion));
        _pricingService = IPricingService(getRegistry().getServiceAddress(PRICE(), majorVersion));

        _registerInterface(type(IPolicyService).interfaceId);
    }


    function decline(
        NftId applicationNftId // = policyNftId
    )
        external
        virtual
        restricted()
        nonReentrant()
    {
        // checks
        (IInstance instance,,) = _getAndVerifyCallingProductForPolicy(applicationNftId);

        // check policy is in state applied
        if (instance.getInstanceReader().getPolicyState(applicationNftId) != APPLIED()) {
            revert ErrorPolicyServicePolicyStateNotApplied(applicationNftId);
        }

        // effects
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
        virtual
        restricted()
        nonReentrant()
        returns (Amount premiumAmount)
    {
        // checks
        (
            IInstance instance,
            NftId productNftId,
            IPolicy.PolicyInfo memory applicationInfo
        ) = _getAndVerifyCallingProductForPolicy(applicationNftId);

        InstanceReader instanceReader = instance.getInstanceReader();
        InstanceStore instanceStore = instance.getInstanceStore();

        // check policy is in state applied
        if (instanceReader.getPolicyState(applicationNftId) != APPLIED()) {
            revert ErrorPolicyServicePolicyStateNotApplied(applicationNftId);
        }

        // effects
        // optional activation of policy
        if(activateAt.gtz()) {
            applicationInfo = _activate(applicationNftId, applicationInfo, activateAt);
        }

        // update policy and set state to collateralized
        instanceStore.updatePolicy(
            applicationNftId, 
            applicationInfo, 
            COLLATERALIZED());

        NftId bundleNftId = applicationInfo.bundleNftId;
        RiskId riskId = applicationInfo.riskId;

        // link policy to risk and bundle
        {
            NftId poolNftId = getRegistry().getObjectInfo(bundleNftId).parentNftId;
            instance.getRiskSet().linkPolicy(productNftId, riskId, applicationNftId);
            instance.getBundleSet().linkPolicy(poolNftId, bundleNftId, applicationNftId);
        }

        // calculate and store premium
        IPolicy.PremiumInfo memory premium = _pricingService.calculatePremium(
            productNftId,
            riskId,
            applicationInfo.sumInsuredAmount,
            applicationInfo.lifetime,
            applicationInfo.applicationData,
            bundleNftId,
            applicationInfo.referralId);

        premiumAmount = premium.fullPremiumAmount;
        instanceStore.createPremium(
            applicationNftId,
            premium);

        // actual collateralizaion
        _poolService.lockCollateral(
            instance,
            address(instanceReader.getComponentInfo(productNftId).token),
            productNftId,
            applicationNftId,
            bundleNftId,
            applicationInfo.sumInsuredAmount);

        // update referral counter if product has linked distributino component
        {
            IComponents.ProductInfo memory productInfo = instanceReader.getProductInfo(productNftId);
            if (productInfo.hasDistribution) {    
                _distributionService.processReferral(
                    productInfo.distributionNftId, 
                    applicationInfo.referralId);
            }
        }

        // log policy creation before interactions with token and policy holder
        emit LogPolicyServicePolicyCreated(applicationNftId, premium.premiumAmount, applicationInfo.activatedAt);

        // interactions
        // callback to policy holder if applicable
        _policyHolderPolicyActivated(applicationNftId, activateAt);
    }


    /// @inheritdoc IPolicyService
    function collectPremium(
        NftId policyNftId, 
        Timestamp activateAt
    )
        external 
        virtual
        restricted()
        nonReentrant()
    {
        // checks
        (
            IInstance instance,
            NftId productNftId,
            IPolicy.PolicyInfo memory policyInfo
        ) = _getAndVerifyCallingProductForPolicy(policyNftId);

        InstanceReader instanceReader = instance.getInstanceReader();
        InstanceStore instanceStore = instance.getInstanceStore();

        // check policy is in state collateralized
        if (instanceReader.getPolicyState(policyNftId) != COLLATERALIZED()) {
            revert ErrorPolicyServicePolicyStateNotCollateralized(policyNftId);
        }

        // check if premium has already been collected
        if (instanceReader.getPremiumInfoState(policyNftId) == PAID()) {
            revert ErrorPolicyServicePremiumAlreadyPaid(policyNftId);
        }

        // check funds and allowance of policy holder
        IPolicy.PremiumInfo memory premium = instanceReader.getPremiumInfo(policyNftId);
        instanceReader.getTokenHandler(
            productNftId).checkBalanceAndAllowance(
                getRegistry().ownerOf(policyNftId), 
                premium.premiumAmount, 
                false);


        // effects
        _processSale(
            instanceReader, 
            instanceStore, 
            productNftId, 
            policyInfo.bundleNftId, 
            policyInfo.referralId, 
            premium);

        // optionally activate policy
        if(activateAt.gtz()) {
            policyInfo = _activate(policyNftId, policyInfo, activateAt);
        }

        instanceStore.updatePolicy(policyNftId, policyInfo, KEEP_STATE());
        instanceStore.updatePremiumState(policyNftId, PAID());

        // log premium collection before interactions with token
        emit LogPolicyServicePolicyPremiumCollected(policyNftId, premium.premiumAmount);

        // interactions
        _transferPremiumAmounts(instanceReader, policyNftId, policyInfo.productNftId, premium);
    }


    /// @inheritdoc IPolicyService
    function activate(NftId policyNftId, Timestamp activateAt)
        external
        virtual
        restricted()
        nonReentrant()
    {
        // checks
        (
            IInstance instance,,
            IPolicy.PolicyInfo memory policyInfo
        ) = _getAndVerifyCallingProductForPolicy(policyNftId);

        // effects
        policyInfo = _activate(policyNftId, policyInfo, activateAt);
        instance.getInstanceStore().updatePolicy(policyNftId, policyInfo, KEEP_STATE());

        // log policy activation before interactions with policy holder
        emit LogPolicyServicePolicyActivated(policyNftId, activateAt);

        // interactions
        // callback to policy holder if applicable
        _policyHolderPolicyActivated(policyNftId, activateAt);
    }

    /// @inheritdoc IPolicyService
    function adjustActivation(
        NftId policyNftId,
        Timestamp newActivateAt
    )
        external
        virtual
        nonReentrant()
    {
        // checks
        (
            IInstance instance,,
            IPolicy.PolicyInfo memory policyInfo
        ) = _getAndVerifyCallingProductForPolicy(policyNftId);

        if (policyInfo.activatedAt.eqz()) {
            revert ErrorPolicyServicePolicyNotActivated(policyNftId);
        }

        if (newActivateAt < TimestampLib.blockTimestamp()) {
            revert ErrorPolicyServicePolicyActivationTooEarly(policyNftId, TimestampLib.blockTimestamp(), newActivateAt);
        }

        if (newActivateAt > policyInfo.expiredAt) {
            revert ErrorPolicyServicePolicyActivationTooLate(policyNftId, policyInfo.expiredAt, newActivateAt);
        }

        // effects
        policyInfo.activatedAt = newActivateAt;
        instance.getInstanceStore().updatePolicy(policyNftId, policyInfo, KEEP_STATE());

        // log policy activation before interactions with policy holder
        emit LogPolicyServicePolicyActivatedUpdated(policyNftId, newActivateAt);

        // interactions
        // callback to policy holder if applicable
        _policyHolderPolicyActivated(policyNftId, newActivateAt);
    }


    /// @inheritdoc IPolicyService
    function expire(
        NftId policyNftId,
        Timestamp expireAt
    )
        external
        virtual
        restricted()
        nonReentrant()
        returns (Timestamp expiredAt)
    {
        // checks
        (
            IInstance instance,,
            IPolicy.PolicyInfo memory policyInfo
        ) = _getAndVerifyCallingProductForPolicy(policyNftId);

        // more checks, effects + interactions
        return _expire(
            instance,
            policyNftId,
            policyInfo,
            expireAt
        );
    }


    /// @inheritdoc IPolicyService
    function expireFromService(
        IInstance instance,
        NftId policyNftId,
        Timestamp expireAt
    )
        external
        virtual
        restricted()
        nonReentrant()
        returns (Timestamp expiredAt)
    {
        // checks
        _checkNftType(policyNftId, POLICY());
        IPolicy.PolicyInfo memory policyInfo = instance.getInstanceReader().getPolicyInfo(
            policyNftId);

        // more checks, effects + interactions
        return _expire(
            instance,
            policyNftId,
            policyInfo,
            expireAt
        );
    }


    /// @inheritdoc IPolicyService
    function close(
        NftId policyNftId
    )
        external 
        virtual
        restricted()
        nonReentrant()
    {
        // checks
        (
            IInstance instance,
            NftId productNftId,
            IPolicy.PolicyInfo memory policyInfo
        ) = _getAndVerifyCallingProductForPolicy(policyNftId);
        InstanceReader instanceReader = instance.getInstanceReader();

        // check policy is in a closeable state
        if (!PolicyServiceLib.policyIsCloseable(instanceReader, policyNftId)) {
            revert ErrorPolicyServicePolicyNotCloseable(policyNftId);
        }

        // check that policy has been activated
        RiskId riskId = policyInfo.riskId;
        NftId bundleNftId = policyInfo.bundleNftId;

        if (instanceReader.getPremiumInfoState(policyNftId) != PAID()) {
            revert ErrorPolicyServicePremiumNotPaid(policyNftId, policyInfo.premiumAmount);
        }

        // effects
        // release (remaining) collateral that was blocked by policy
        _poolService.releaseCollateral(
            instance, 
            policyNftId, 
            policyInfo);

        // TODO consider to also set expiredAt to current block timestamp if that timestamp is still in the futue

        // update policy state to closed
        policyInfo.closedAt = TimestampLib.blockTimestamp();
        instance.getInstanceStore().updatePolicy(policyNftId, policyInfo, CLOSED());

        // unlink policy from risk and bundle
        NftId poolNftId = getRegistry().getParentNftId(bundleNftId);
        instance.getRiskSet().unlinkPolicy(productNftId, riskId, policyNftId);
        instance.getBundleSet().unlinkPolicy(poolNftId, bundleNftId, policyNftId);

        emit LogPolicyServicePolicyClosed(policyNftId);
    }

    /// @dev shared functionality for expire() and policyExpire().
    function _expire(
        IInstance instance,
        NftId policyNftId,
        IPolicy.PolicyInfo memory policyInfo,
        Timestamp expireAt
    )
        internal
        returns (Timestamp)
    {
        PolicyServiceLib.checkExpiration(
            expireAt,
            policyNftId,
            instance.getInstanceReader().getPolicyState(policyNftId),
            policyInfo);

        // effects
        // update policyInfo with new expiredAt timestamp
        if (expireAt.gtz()) {
            policyInfo.expiredAt = expireAt;
        } else {
            policyInfo.expiredAt = TimestampLib.blockTimestamp();
        }
        instance.getInstanceStore().updatePolicy(policyNftId, policyInfo, KEEP_STATE());

        emit LogPolicyServicePolicyExpirationUpdated(policyNftId, policyInfo.expiredAt);

        // interactions
        // callback to policy holder if applicable
        _policyHolderPolicyExpired(policyNftId, policyInfo.expiredAt);
        return policyInfo.expiredAt;
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
        IPolicy.PremiumInfo memory premium
    )
        internal
        virtual
    {
        (NftId distributionNftId,,,) = _getDistributionNftAndWallets(
            instanceReader, 
            productNftId);

        // update product fees, distribution and pool fees 
        _accountingService.increaseProductFees(
            instanceStore, 
            productNftId, 
            premium.productFeeVarAmount + premium.productFeeFixAmount);

        // update distribution fees and distributor commission and pool fees 
        if (!distributionNftId.eqz()) { // only call distribution service if a distribution component is connected to the product
            _distributionService.processSale(
                distributionNftId, 
                referralId, 
                premium);
        }

        // update pool and bundle fees 
        _poolService.processSale(
            bundleNftId, 
            premium);
    }


    /// @dev transfer the premium to the wallets the premium is distributed to
    function _transferPremiumAmounts(
        InstanceReader instanceReader,
        NftId policyNftId,
        NftId productNftId,
        IPolicy.PremiumInfo memory premium
    )
        internal
        virtual
    {
        address policyHolder = getRegistry().ownerOf(policyNftId);

        (
            ,
            address distributionWallet,
            address poolWallet,
            address productWallet
        ) = _getDistributionNftAndWallets(
            instanceReader, 
            productNftId);

        // step 1: collect premium amount from policy holder
        TokenHandler tokenHandler = instanceReader.getTokenHandler(productNftId);
        tokenHandler.pullToken(policyHolder, premium.premiumAmount);

        // step 2: push distribution fee to distribution wallet
        if (premium.distributionFeeAndCommissionAmount.gtz()) {
            tokenHandler.pushToken(distributionWallet, premium.distributionFeeAndCommissionAmount);
        }

        // step 3: push pool fee, bundle fee and pool premium to pool wallet
        if (premium.poolPremiumAndFeeAmount.gtz()) {
            tokenHandler.pushToken(poolWallet, premium.poolPremiumAndFeeAmount);
        }
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


    function _policyHolderPolicyActivated(
        NftId policyNftId,
        Timestamp activateAt
    )
        internal
        virtual
    {
        // immediately return if policy is not activated
        if (activateAt.eqz()) {
            return;
        }

        // get policy holder address
        IPolicyHolder policyHolder = _getPolicyHolder(policyNftId);

        // execute callback if policy holder implements IPolicyHolder
        if (address(policyHolder) != address(0)) {
            policyHolder.policyActivated(policyNftId, activateAt);
        }
    }


    function _policyHolderPolicyExpired(
        NftId policyNftId,
        Timestamp expiredAt
    )
        internal
        virtual
    {
        // immediately return if policy is not activated
        if (expiredAt.eqz()) {
            return;
        }

        // get policy holder address
        IPolicyHolder policyHolder = _getPolicyHolder(policyNftId);

        // execute callback if policy holder implements IPolicyHolder
        if (address(policyHolder) != address(0)) {
            policyHolder.policyExpired(policyNftId, expiredAt);
        }
    }


    function _getPolicyHolder(NftId policyNftId)
        internal 
        view 
        returns (IPolicyHolder policyHolder)
    {
        address policyHolderAddress = getRegistry().ownerOf(policyNftId);
        policyHolder = IPolicyHolder(policyHolderAddress);

        if (!ContractLib.isPolicyHolder(policyHolderAddress)) {
            policyHolder = IPolicyHolder(address(0));
        }
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
        productWallet = instanceReader.getComponentInfo(productNftId).tokenHandler.getWallet();
        poolWallet = instanceReader.getComponentInfo(productInfo.poolNftId).tokenHandler.getWallet();

        if (productInfo.hasDistribution) {
            distributionNftId = productInfo.distributionNftId;
            distributionWallet = instanceReader.getComponentInfo(distributionNftId).tokenHandler.getWallet();
        }
    }


    function  _getAndVerifyCallingProductForPolicy(NftId policyNftId)
        internal
        virtual
        view
        returns (
            IInstance instance,
            NftId productNftId,
            IPolicy.PolicyInfo memory policyInfo
        )
    {
        address instanceAddress;

        (
            productNftId, 
            instanceAddress
        ) = ContractLib.getAndVerifyComponentForObject(
                getRegistry(), msg.sender, policyNftId, POLICY(), getRelease(), true);

        instance = IInstance(instanceAddress);
        policyInfo = instance.getInstanceReader().getPolicyInfo(policyNftId);
    }

    function _getDomain() internal pure override returns(ObjectType) {
        return POLICY();
    }
}