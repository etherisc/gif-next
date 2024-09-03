// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

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
import {Service} from "../shared/Service.sol";
import {Timestamp, TimestampLib} from "../type/Timestamp.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {VersionPart} from "../type/Version.sol";


contract PolicyService is
    Service, 
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
        (IInstance instance,,) = _getAndVerifyCallerForPolicy(applicationNftId);

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
        ) = _getAndVerifyCallerForPolicy(applicationNftId);

        // check policy is in state applied
        InstanceReader instanceReader = instance.getInstanceReader();
        if (instanceReader.getPolicyState(applicationNftId) != APPLIED()) {
            revert ErrorPolicyServicePolicyStateNotApplied(applicationNftId);
        }

        // effects
        // actual collateralizaion
        _poolService.lockCollateral(
            instance,
            address(instanceReader.getToken(productNftId)),
            productNftId,
            applicationNftId,
            applicationInfo.bundleNftId,
            applicationInfo.sumInsuredAmount);

        // optional activation of policy
        if(activateAt.gtz()) {
            applicationInfo = PolicyServiceLib.activate(applicationNftId, applicationInfo, activateAt);
        }

        // update policy and set state to collateralized
        instance.getInstanceStore().updatePolicy(
            applicationNftId, 
            applicationInfo, 
            COLLATERALIZED());

        // calculate and store premium
        RiskId riskId = applicationInfo.riskId;
        NftId bundleNftId = applicationInfo.bundleNftId;

        IPolicy.PremiumInfo memory premium = _pricingService.calculatePremium(
            productNftId,
            riskId,
            applicationInfo.sumInsuredAmount,
            applicationInfo.lifetime,
            applicationInfo.applicationData,
            bundleNftId,
            applicationInfo.referralId);

        premiumAmount = premium.fullPremiumAmount;
        instance.getInstanceStore().createPremium(
            applicationNftId,
            premium);

        // update referral counter if product has linked distributino component
        {
            IComponents.ProductInfo memory productInfo = instanceReader.getProductInfo(productNftId);
            if (productInfo.hasDistribution) {    
                _distributionService.processReferral(
                    productInfo.distributionNftId, 
                    applicationInfo.referralId);
            }
        }

        // link policy to risk and bundle
        NftId poolNftId = getRegistry().getParentNftId(bundleNftId);
        instance.getRiskSet().linkPolicy(productNftId, riskId, applicationNftId);
        instance.getBundleSet().linkPolicy(poolNftId, bundleNftId, applicationNftId);

        // log policy creation before interactions with token and policy holder
        emit LogPolicyServicePolicyCreated(applicationNftId, premium.premiumAmount, activateAt);

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
        ) = _getAndVerifyCallerForPolicy(policyNftId);

        // check policy is in state collateralized
        InstanceReader instanceReader = instance.getInstanceReader();
        if (instanceReader.getPolicyState(policyNftId) != COLLATERALIZED()) {
            revert ErrorPolicyServicePolicyStateNotCollateralized(policyNftId);
        }

        // check if premium has already been collected
        if (instanceReader.getPremiumState(policyNftId) == PAID()) {
            revert ErrorPolicyServicePremiumAlreadyPaid(policyNftId);
        }

        // check funds and allowance of policy holder
        IPolicy.PremiumInfo memory premium = instanceReader.getPremiumInfo(policyNftId);
        instanceReader.getTokenHandler(
            productNftId).checkBalanceAndAllowance(
                getRegistry().ownerOf(policyNftId), 
                premium.premiumAmount, 
                false);

        // )
        // _checkPremiumBalanceAndAllowance(
        //     tokenHandler.TOKEN(), 
        //     address(tokenHandler),
        //     getRegistry().ownerOf(policyNftId), 
        //     premium.premiumAmount);

        // effects
        _processSale(
            instanceReader, 
            instance.getInstanceStore(), 
            productNftId, 
            policyInfo.bundleNftId, 
            policyInfo.referralId, 
            premium);

        // optionally activate policy
        if(activateAt.gtz()) {
            policyInfo = PolicyServiceLib.activate(policyNftId, policyInfo, activateAt);
        }

        instance.getInstanceStore().updatePolicy(policyNftId, policyInfo, KEEP_STATE());
        instance.getInstanceStore().updatePremiumState(policyNftId, PAID());

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
        ) = _getAndVerifyCallerForPolicy(policyNftId);

        // effects
        policyInfo = PolicyServiceLib.activate(policyNftId, policyInfo, activateAt);
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
        restricted()
        nonReentrant()
    {
        // checks
        (
            IInstance instance,,
            IPolicy.PolicyInfo memory policyInfo
        ) = _getAndVerifyCallerForPolicy(policyNftId);

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
        ) = _getAndVerifyCallerForPolicy(policyNftId);

        // more checks, effects + interactions
        return _expire(
            instance,
            policyNftId,
            policyInfo,
            expireAt
        );
    }


    /// @inheritdoc IPolicyService
    function expirePolicy(
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
        ) = _getAndVerifyCallerForPolicy(policyNftId);
        InstanceReader instanceReader = instance.getInstanceReader();

        // check policy is in a closeable state
        if (!PolicyServiceLib.policyIsCloseable(instanceReader, policyNftId)) {
            revert ErrorPolicyServicePolicyNotCloseable(policyNftId);
        }

        // check that policy has been activated
        RiskId riskId = policyInfo.riskId;
        NftId bundleNftId = policyInfo.bundleNftId;

        if (instanceReader.getPremiumState(policyNftId) != PAID()) {
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
        policyInfo = PolicyServiceLib.expire(
            instance.getInstanceReader(),
            policyNftId,
            policyInfo,
            expireAt);

        instance.getInstanceStore().updatePolicy(policyNftId, policyInfo, KEEP_STATE());

        emit LogPolicyServicePolicyExpirationUpdated(policyNftId, policyInfo.expiredAt);

        // interactions
        // callback to policy holder if applicable
        _policyHolderPolicyExpired(policyNftId, policyInfo.expiredAt);
        return policyInfo.expiredAt;
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


    function  _getAndVerifyCallerForPolicy(NftId policyNftId)
        internal
        virtual
        view
        returns (
            IInstance instance,
            NftId productNftId,
            IPolicy.PolicyInfo memory policyInfo
        )
    {
        (
            IRegistry.ObjectInfo memory productInfo, 
            address instanceAddress
        ) = ContractLib.getAndVerifyComponent(
            getRegistry(), 
            msg.sender, // caller contract 
            PRODUCT(), // caller must be product
            true); // only active caller

        productNftId = productInfo.nftId; // calling product nft id
        instance = IInstance(instanceAddress);
        policyInfo = instance.getInstanceReader().getPolicyInfo(policyNftId);

        if (policyInfo.productNftId != productNftId) {
            revert ErrorPolicyServicePolicyProductMismatch(
                policyNftId, 
                productNftId,
                policyInfo.productNftId);
        }
    }


    function _getDomain() internal pure override returns(ObjectType) {
        return POLICY();
    }
}