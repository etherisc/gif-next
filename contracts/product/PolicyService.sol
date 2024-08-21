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
import {ReferralId} from "../type/Referral.sol";
import {RiskId} from "../type/RiskId.sol";
import {ComponentVerifyingService} from "../shared/ComponentVerifyingService.sol";
import {StateId} from "../type/StateId.sol";
import {Timestamp, TimestampLib} from "../type/Timestamp.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {VersionPart} from "../type/Version.sol";
import {PolicyLib} from "./PolicyLib.sol";


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

        InstanceReader reader = instance.getInstanceReader();
        InstanceStore store = instance.getInstanceStore();

        // check policy is in state applied
        if (reader.getPolicyState(applicationNftId) != APPLIED()) {
            revert ErrorPolicyServicePolicyStateNotApplied(applicationNftId);
        }

        // effects
        // optional activation of policy
        if(activateAt.gtz()) {
            applicationInfo = PolicyLib.activate(reader, applicationNftId, applicationInfo, activateAt);
        }

        // update policy and set state to collateralized
        store.updatePolicy(
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
        store.createPremium(
            applicationNftId,
            premium);

        // actual collateralizaion
        _poolService.lockCollateral(
            instance,
            address(reader.getComponentInfo(productNftId).token),
            productNftId,
            applicationNftId,
            bundleNftId,
            applicationInfo.sumInsuredAmount);

        // update referral counter if product has linked distributino component
        {
            IComponents.ProductInfo memory productInfo = reader.getProductInfo(productNftId);
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

        InstanceReader reader = instance.getInstanceReader();
        InstanceStore store = instance.getInstanceStore();

        // check policy is in state collateralized
        if (reader.getPolicyState(policyNftId) != COLLATERALIZED()) {
            revert ErrorPolicyServicePolicyStateNotCollateralized(policyNftId);
        }

        // check if premium has already been collected
        if (reader.getPremiumState(policyNftId) == PAID()) {
            revert ErrorPolicyServicePremiumAlreadyPaid(policyNftId);
        }

        // check funds and allowance of policy holder
        IPolicy.PremiumInfo memory premium = reader.getPremiumInfo(policyNftId);
        TokenHandler tokenHandler = _getTokenHandler(reader, policyInfo.productNftId);        
        _checkPremiumBalanceAndAllowance(
            tokenHandler.TOKEN(), 
            address(tokenHandler),
            getRegistry().ownerOf(policyNftId), 
            premium.premiumAmount);

        // effects
        _processSale(
            reader, 
            store, 
            productNftId, 
            policyInfo.bundleNftId, 
            policyInfo.referralId, 
            premium);

        // optionally activate policy
        if(activateAt.gtz()) {
            policyInfo = PolicyLib.activate(reader, policyNftId, policyInfo, activateAt);
        }

        store.updatePolicy(policyNftId, policyInfo, KEEP_STATE());
        store.updatePremiumState(policyNftId, PAID());

        // log premium collection before interactions with token
        emit LogPolicyServicePolicyPremiumCollected(policyNftId, premium.premiumAmount);

        // interactions
        _transferFunds(reader, policyNftId, productNftId, premium);
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

        InstanceReader reader = instance.getInstanceReader();
        InstanceStore store = instance.getInstanceStore();

        // checks + effects
        policyInfo = PolicyLib.activate(reader, policyNftId, policyInfo, activateAt);
        store.updatePolicy(policyNftId, policyInfo, KEEP_STATE());

        // log policy activation before interactions with policy holder
        emit LogPolicyServicePolicyActivated(policyNftId, policyInfo.activatedAt);

        // interactions
        // callback to policy holder if applicable
        _policyHolderPolicyActivated(policyNftId, policyInfo.activatedAt);
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

    // TODO expire() and expirePolicy() requires better naming (reflecting caller) 
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

        InstanceReader reader = instance.getInstanceReader();
        InstanceStore store = instance.getInstanceStore();
        address token = address(reader.getComponentInfo(productNftId).token);

        policyInfo = PolicyLib.close(
            reader, 
            policyNftId, 
            policyInfo);

        // effects
        // update policy state to closed
        store.updatePolicy(policyNftId, policyInfo, CLOSED());

        // release (remaining) collateral that was blocked by policy
        _poolService.releaseCollateral(
            instance, 
            token,
            policyNftId, 
            policyInfo);

        // unlink policy from risk and bundle
        RiskId riskId = policyInfo.riskId;
        NftId bundleNftId = policyInfo.bundleNftId;
        NftId poolNftId = getRegistry().getObjectInfo(bundleNftId).parentNftId;
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
        returns (Timestamp expiredAt)
    {
        InstanceReader reader = instance.getInstanceReader();
        InstanceStore store = instance.getInstanceStore();

        // checks
        Timestamp originalExpiredAt = policyInfo.expiredAt;
        policyInfo = PolicyLib.adjustExpiration(
            reader, 
            policyNftId, 
            policyInfo, 
            expireAt);
        expiredAt = policyInfo.expiredAt;

        // effects
        store.updatePolicy(policyNftId, policyInfo, KEEP_STATE());

        emit LogPolicyServicePolicyExpirationUpdated(policyNftId, originalExpiredAt, expiredAt);

        // interactions
        // callback to policy holder if applicable
        _policyHolderPolicyExpired(policyNftId, expiredAt);
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
    function _transferFunds(
        InstanceReader instanceReader,
        NftId policyNftId,
        NftId productNftId,
        IPolicy.PremiumInfo memory premium
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