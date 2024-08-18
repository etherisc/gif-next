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
import {Service} from "../shared/Service.sol";
import {StateId} from "../type/StateId.sol";
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
            address(instanceReader.getComponentInfo(productNftId).token),
            productNftId,
            applicationNftId,
            applicationInfo.bundleNftId,
            applicationInfo.sumInsuredAmount);

        // optional activation of policy
        if(activateAt > TimestampLib.zero()) {
            applicationInfo = _activate(applicationNftId, applicationInfo, activateAt);
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
        NftId poolNftId = getRegistry().getObjectInfo(bundleNftId).parentNftId;
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
        if (instanceReader.getPremiumInfoState(policyNftId) == PAID()) {
            revert ErrorPolicyServicePremiumAlreadyPaid(policyNftId);
        }

        // check funds and allowance of policy holder
        IPolicy.PremiumInfo memory premium = instanceReader.getPremiumInfo(policyNftId);
        TokenHandler tokenHandler = _getTokenHandler(instanceReader, policyInfo.productNftId);        
        _checkPremiumBalanceAndAllowance(
            tokenHandler.TOKEN(), 
            address(tokenHandler),
            getRegistry().ownerOf(policyNftId), 
            premium.premiumAmount);

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
            policyInfo = _activate(policyNftId, policyInfo, activateAt);
        }

        instance.getInstanceStore().updatePolicy(policyNftId, policyInfo, KEEP_STATE());
        instance.getInstanceStore().updatePremiumState(policyNftId, PAID());

        // log premium collection before interactions with token
        emit LogPolicyServicePolicyPremiumCollected(policyNftId, premium.premiumAmount);

        // interactions
        _transferFunds(instanceReader, policyNftId, policyInfo.productNftId, premium);
    }


    /// @inheritdoc IPolicyService
    function activate(NftId policyNftId, Timestamp activateAt)
        external
        virtual
        nonReentrant()
    {
        // checks
        (
            IInstance instance,,
            IPolicy.PolicyInfo memory policyInfo
        ) = _getAndVerifyCallerForPolicy(policyNftId);

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
    function expire(
        NftId policyNftId,
        Timestamp expireAt
    )
        external
        virtual
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
        if (!policyIsCloseable(instanceReader, policyNftId)) {
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
            address(instanceReader.getComponentInfo(productNftId).token),
            policyNftId, 
            policyInfo);

        // TODO consider to also set expiredAt to current block timestamp if that timestamp is still in the futue

        // update policy state to closed
        policyInfo.closedAt = TimestampLib.blockTimestamp();
        instance.getInstanceStore().updatePolicy(policyNftId, policyInfo, CLOSED());

        // unlink policy from risk and bundle
        NftId poolNftId = getRegistry().getObjectInfo(bundleNftId).parentNftId;
        instance.getRiskSet().unlinkPolicy(productNftId, riskId, policyNftId);
        instance.getBundleSet().unlinkPolicy(poolNftId, bundleNftId, policyNftId);

        emit LogPolicyServicePolicyClosed(policyNftId);
    }


    function policyIsCloseable(InstanceReader instanceReader, NftId policyNftId)
        public
        view
        returns (bool isCloseable)
    {
        // policy already closed
        if (instanceReader.getPolicyState(policyNftId) == CLOSED()) {
            return false;
        }

        IPolicy.PolicyInfo memory info = instanceReader.getPolicyInfo(policyNftId);
        
        if (info.productNftId.eqz()) { return false; } // not closeable: policy does not exist (or does not belong to this instance)
        if (info.activatedAt.eqz()) { return false; } // not closeable: not yet activated
        if (info.openClaimsCount > 0) { return false; } // not closeable: has open claims

        // closeable: if sum of claims matches sum insured a policy may be closed prior to the expiry date
        if (info.claimAmount == info.sumInsuredAmount) { return true; }

        // not closeable: not yet expired
        if (TimestampLib.blockTimestamp() < info.expiredAt) { return false; }

        // all conditions to close the policy are met
        return true; 
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
        // checks
        // check policy is active
        StateId policyState = instance.getInstanceReader().getPolicyState(policyNftId);
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

        // effects
        // update policyInfo with new expiredAt timestamp
        Timestamp originalExpiredAt = policyInfo.expiredAt;
        policyInfo.expiredAt = expiredAt;
        instance.getInstanceStore().updatePolicy(policyNftId, policyInfo, KEEP_STATE());

        emit LogPolicyServicePolicyExpirationUpdated(policyNftId, originalExpiredAt, expiredAt);

        // interactions
        // callback to policy holder if applicable
        _policyHolderPolicyExpired(policyNftId, expiredAt);
    }

    // TODO cleanup
    // /// @dev Calculates the premium and updates all counters in the other services.
    // /// Only book keeping, no token transfers.
    // function _processPremium(
    //     IInstance instance,
    //     NftId applicationNftId,
    //     IPolicy.PolicyInfo memory applicationInfo,
    //     IPolicy.PremiumInfo memory premium
    // )
    //     internal
    //     virtual
    // {
    //     // update the counters
    //     _processSale(
    //         instanceReader, 
    //         instance.getInstanceStore(), 
    //         productNftId, 
    //         applicationInfo.bundleNftId, 
    //         applicationInfo.referralId, 
    //         premium);
    // }


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

        productNftId = productInfo.nftId;
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