// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IAccess} from "../authorization/IAccess.sol";
import {IBundle} from "../instance/module/IBundle.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IDistribution} from "../instance/module/IDistribution.sol";
import {IInstance} from "./IInstance.sol";
import {IKeyValueStore} from "../shared/IKeyValueStore.sol";
import {IOracle} from "../oracle/IOracle.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IRisk} from "../instance/module/IRisk.sol";
import {TimestampLib} from "../type/Timestamp.sol";

import {Amount} from "../type/Amount.sol";
import {BundleSet} from "./BundleSet.sol";
import {BUNDLE, COMPONENT, DISTRIBUTOR, DISTRIBUTION, FEE, PREMIUM, POLICY, POOL, PRODUCT} from "../type/ObjectType.sol";
import {ClaimId, ClaimIdLib} from "../type/ClaimId.sol";
import {DistributorType} from "../type/DistributorType.sol";
import {InstanceStore} from "./InstanceStore.sol";
import {Key32} from "../type/Key32.sol";
import {NftId} from "../type/NftId.sol";
import {PayoutId, PayoutIdLib} from "../type/PayoutId.sol";
import {ReferralId, ReferralStatus, ReferralLib, REFERRAL_OK, REFERRAL_ERROR_UNKNOWN, REFERRAL_ERROR_EXPIRED, REFERRAL_ERROR_EXHAUSTED} from "../type/Referral.sol";
import {RequestId} from "../type/RequestId.sol";
import {RiskId} from "../type/RiskId.sol";
import {RiskSet} from "./RiskSet.sol";
import {RoleId, INSTANCE_OWNER_ROLE} from "../type/RoleId.sol";
import {StateId} from "../type/StateId.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {UFixed, UFixedLib} from "../type/UFixed.sol";



contract InstanceReader {

    error ErrorInstanceReaderAlreadyInitialized();
    error ErrorInstanceReaderInstanceAddressZero();

    bool private _initialized = false;

    IRegistry internal _registry;
    IInstance internal _instance;

    InstanceStore internal _store;
    BundleSet internal _bundleSet;
    RiskSet internal _riskSet;

    /// @dev This initializer needs to be called from the instance itself.
    function initialize() public {
        if(_initialized) {
            revert ErrorInstanceReaderAlreadyInitialized();
        }

        initializeWithInstance(msg.sender);
    }

    function initializeWithInstance(address instanceAddress)
        public
    {
        if(_initialized) {
            revert ErrorInstanceReaderAlreadyInitialized();
        }

        _initialized = true;
        _instance = IInstance(instanceAddress);
        _registry = _instance.getRegistry();

        _store = _instance.getInstanceStore();
        _bundleSet = _instance.getBundleSet();
        _riskSet = _instance.getRiskSet();
    }


    // instance level functions

    function getRegistry() public view returns (IRegistry registry) {
        return _registry;
    }

    function getInstanceNftId() public view returns (NftId instanceNftid) {
        return _registry.getNftIdForAddress(address(_instance));
    }

    function getInstance() public view returns (IInstance instance) {
        return _instance;
    }

    function components() public view returns (uint256 componentCount) {
        return _instance.getInstanceAdmin().components();
    }

    function products() public view returns (uint256 productCount) {
        return _instance.products();
    }

    function getProductNftId(uint256 idx) public view returns (NftId productNftId) {
        return _instance.getProductNftId(idx);
    }

    // module specific functions

    function getPolicyInfo(NftId policyNftId)
        public
        view
        returns (IPolicy.PolicyInfo memory info)
    {
        bytes memory data = _store.getData(toPolicyKey(policyNftId));
        if (data.length > 0) {
            return abi.decode(data, (IPolicy.PolicyInfo));
        }
    }

    function getPolicyState(NftId policyNftId)
        public
        view
        returns (StateId state)
    {
        return _store.getState(toPolicyKey(policyNftId));
    }

    function getPremiumInfo(NftId policyNftId) 
        public
        view
        returns (IPolicy.PremiumInfo memory info)
    {
        bytes memory data = _store.getData(toPremiumKey(policyNftId));
        if (data.length > 0) {
            return abi.decode(data, (IPolicy.PremiumInfo));
        }
    }

    function getPremiumInfoState(NftId policyNftId) 
        public
        view
        returns (StateId state)
    {
        return _store.getState(toPremiumKey(policyNftId));
    }

    function bundles(NftId poolNftId)
        public
        view
        returns (uint256 bundleCount)
    {
        return _bundleSet.bundles(poolNftId);
    }

    function activeBundles(NftId poolNftId)
        public
        view
        returns (uint256 bundleCount)
    {
        return _bundleSet.activeBundles(poolNftId);
    }

    function getActiveBundleNftId(NftId poolNftId, uint256 idx)
        public
        view
        returns (NftId bundleNftId)
    {
        return _bundleSet.getActiveBundleNftId(poolNftId, idx);
    }

    function getBundleNftId(NftId poolNftId, uint256 idx)
        public
        view
        returns (NftId bundleNftId)
    {
        return _bundleSet.getBundleNftId(poolNftId, idx);
    }

    function getBundleState(NftId bundleNftId)
        public
        view
        returns (StateId state)
    {
        return _store.getState(toBundleKey(bundleNftId));
    }

    /// @dev Returns true iff policy is active.
    function policyIsActive(NftId policyNftId)
        public
        view
        returns (bool isCloseable)
    {
        IPolicy.PolicyInfo memory info = getPolicyInfo(policyNftId);

        if (info.productNftId.eqz()) { return false; } // not closeable: policy does not exist (or does not belong to this instance)
        if (info.activatedAt.eqz()) { return false; } // not closeable: not yet activated
        if (info.activatedAt > TimestampLib.blockTimestamp()) { return false; } // not yet active
        if (info.expiredAt <= TimestampLib.blockTimestamp()) { return false; } // already expired

        return true;
    }

    function claims(NftId policyNftId)
        public
        view
        returns (uint16 claimCount)
    {
        return getPolicyInfo(policyNftId).claimsCount;
    }


    function getClaimId(uint idx)
        public
        view
        returns (ClaimId claimId)
    {
        return ClaimIdLib.toClaimId(idx + 1);
    }

    function getClaimInfo(NftId policyNftId, ClaimId claimId)
        public
        view
        returns (IPolicy.ClaimInfo memory info)
    {
        bytes memory data = _store.getData(claimId.toKey32(policyNftId));
        if (data.length > 0) {
            return abi.decode(data, (IPolicy.ClaimInfo));
        }
    }


    function getClaimState(NftId policyNftId, ClaimId claimId)
        public
        view
        returns (StateId state)
    {
        return _store.getState(claimId.toKey32(policyNftId));
    }


    function payouts(NftId policyNftId, ClaimId claimId)
        public
        view
        returns (uint24 payoutCount)
    {
        return getClaimInfo(policyNftId, claimId).payoutsCount;
    }


    function getPayoutId(ClaimId claimId, uint24 idx)
        public
        view
        returns (PayoutId payoutId)
    {
        return PayoutIdLib.toPayoutId(claimId, idx + 1);
    }


    function getRemainingClaimableAmount(NftId policyNftId)
        public
        view
        returns (Amount remainingClaimableAmount)
    {
        IPolicy.PolicyInfo memory info = getPolicyInfo(policyNftId);
        return info.sumInsuredAmount - info.claimAmount;
    }

    function getPayoutInfo(NftId policyNftId, PayoutId payoutId)
        public
        view
        returns (IPolicy.PayoutInfo memory info)
    {
        bytes memory data = _store.getData(payoutId.toKey32(policyNftId));
        if (data.length > 0) {
            return abi.decode(data, (IPolicy.PayoutInfo));
        }
    }

    function getPayoutState(NftId policyNftId, PayoutId payoutId)
        public
        view
        returns (StateId state)
    {
        return _store.getState(payoutId.toKey32(policyNftId));
    }

    function risks(NftId productNftId)
        public
        view
        returns (uint256 riskCount)
    {
        return _riskSet.risks(productNftId);
    }

    function getRiskId(NftId productNftId, uint256 idx)
        public
        view
        returns (RiskId riskId)
    {
        return _riskSet.getRiskId(productNftId, idx);
    }

    function activeRisks(NftId productNftId)
        public
        view
        returns (uint256 activeRiskCount)
    {
        return _riskSet.activeRisks(productNftId);
    }

    function getActiveRiskId(NftId productNftId, uint256 idx)
        public
        view
        returns (RiskId riskId)
    {
        return _riskSet.getActiveRiskId(productNftId, idx);
    }

    function getRiskInfo(RiskId riskId)
        public 
        view 
        returns (IRisk.RiskInfo memory info)
    {
        bytes memory data = _store.getData(riskId.toKey32());
        if (data.length > 0) {
            return abi.decode(data, (IRisk.RiskInfo));
        }
    }

    function getRiskState(RiskId riskId)
        public 
        view 
        returns (StateId stateId)
    {
        bytes memory data = _store.getData(riskId.toKey32());
        return _store.getState(riskId.toKey32());
    }

    function policiesForRisk(RiskId riskId)
        public
        view
        returns (uint256 linkedPolicies)
    {
        return _riskSet.linkedPolicies(riskId);
    }

    function getPolicyNftIdForRisk(RiskId riskId, uint256 idx)
        public
        view
        returns (NftId linkedPolicyNftId)
    {
        return _riskSet.getLinkedPolicyNftId(riskId, idx);
    }


    function getToken(NftId componentNftId)
        public
        view
        returns (IERC20Metadata token)
    {
        TokenHandler tokenHandler = getTokenHandler(componentNftId);
        if (address(tokenHandler) != address(0)) {
            return tokenHandler.TOKEN();
        }
    }


    function getWallet(NftId componentNftId)
        public
        view
        returns (address wallet)
    {
        TokenHandler tokenHandler = getTokenHandler(componentNftId);
        if (address(tokenHandler) != address(0)) {
            return tokenHandler.getWallet();
        }
    }


    function getTokenHandler(NftId componentNftId)
        public
        view
        returns (TokenHandler tokenHandler)
    {
        bytes memory data = _store.getData(toComponentKey(componentNftId));
        if (data.length > 0) {
            return abi.decode(data, (IComponents.ComponentInfo)).tokenHandler;
        }
    }


    function getBundleInfo(NftId bundleNftId)
        public 
        view 
        returns (IBundle.BundleInfo memory info)
    {
        bytes memory data = _store.getData(toBundleKey(bundleNftId));
        if (data.length > 0) {
            return abi.decode(data, (IBundle.BundleInfo));
        }
    }

    function getDistributorTypeInfo(DistributorType distributorType)
        public 
        view 
        returns (IDistribution.DistributorTypeInfo memory info)
    {
        bytes memory data = _store.getData(distributorType.toKey32());
        if (data.length > 0) {
            return abi.decode(data, (IDistribution.DistributorTypeInfo));
        }
    }

    function getDistributorInfo(NftId distributorNftId)
        public
        view
        returns (IDistribution.DistributorInfo memory info)
    {
        bytes memory data = _store.getData(toDistributorKey(distributorNftId));
        if (data.length > 0) {
            return abi.decode(data, (IDistribution.DistributorInfo));
        }
    }

    function getBalanceAmount(NftId targetNftId) external view returns (Amount) { 
        return _store.getBalanceAmount(targetNftId);
    }

    function getLockedAmount(NftId targetNftId) external view returns (Amount) { 
        return _store.getLockedAmount(targetNftId);
    }

    function getFeeAmount(NftId targetNftId) external view returns (Amount) { 
        return _store.getFeeAmount(targetNftId);
    }

    function getComponentInfo(NftId componentNftId)
        public
        view
        returns (IComponents.ComponentInfo memory info)
    {
        bytes memory data = _store.getData(toComponentKey(componentNftId));
        if (data.length > 0) {
            return abi.decode(data, (IComponents.ComponentInfo));
        }
    }

    function getProductInfo(NftId productNftId)
        public
        view
        returns (IComponents.ProductInfo memory info)
    {
        bytes memory data = _store.getData(toProductKey(productNftId));
        if (data.length > 0) {
            return abi.decode(data, (IComponents.ProductInfo));
        }
    }

    function getFeeInfo(NftId productNftId)
        public
        view
        returns (IComponents.FeeInfo memory feeInfo)
    {
        bytes memory data = _store.getData(toFeeKey(productNftId));
        if (data.length > 0) {
            return abi.decode(data, (IComponents.FeeInfo));
        }
    }

    function getPoolInfo(NftId poolNftId)
        public
        view
        returns (IComponents.PoolInfo memory info)
    {
        bytes memory data = _store.getData(toPoolKey(poolNftId));
        if (data.length > 0) {
            return abi.decode(data, (IComponents.PoolInfo));
        }
    }

    function getReferralInfo(ReferralId referralId)
        public 
        view 
        returns (IDistribution.ReferralInfo memory info)
    {
        bytes memory data = _store.getData(referralId.toKey32());
        if (data.length > 0) {
            return abi.decode(data, (IDistribution.ReferralInfo));
        }
    }

    function getRequestInfo(RequestId requestId)
        public
        view
        returns (IOracle.RequestInfo memory requestInfo)
    {
        bytes memory data = _store.getData(requestId.toKey32());
        if (data.length > 0) {
            return abi.decode(data, (IOracle.RequestInfo));
        }
    }

    function getMetadata(Key32 key)
        public 
        view 
        returns (IKeyValueStore.Metadata memory metadata)
    {
        return _store.getMetadata(key);
    }

    function getState(Key32 key)
        public 
        view 
        returns (StateId state)
    {
        return _store.getMetadata(key).state;
    }


    function toReferralId(
        NftId distributionNftId,
        string memory referralCode
    )
        public
        pure 
        returns (ReferralId referralId)
    {
        return ReferralLib.toReferralId(
            distributionNftId, 
            referralCode);      
    }


    function getDiscountPercentage(ReferralId referralId)
        public
        view
        returns (
            UFixed discountPercentage, 
            ReferralStatus status
        )
    {
        IDistribution.ReferralInfo memory info = getReferralInfo(
            referralId);        

        if (info.expiryAt.eqz()) {
            return (
                UFixedLib.zero(),
                REFERRAL_ERROR_UNKNOWN());
        }

        if (info.expiryAt < TimestampLib.blockTimestamp()) {
            return (
                UFixedLib.zero(),
                REFERRAL_ERROR_EXPIRED());
        }

        if (info.usedReferrals >= info.maxReferrals) {
            return (
                UFixedLib.zero(),
                REFERRAL_ERROR_EXHAUSTED());
        }

        return (
            info.discountPercentage,
            REFERRAL_OK()
        );
    }


    function roles() public view returns (uint256) {
        return _instance.getInstanceAdmin().roles();
    }


    function getInstanceOwnerRole() public view returns (RoleId roleId) {
        return INSTANCE_OWNER_ROLE();
    }


    function getRoleId(uint256 idx) public view returns (RoleId roleId) {
        return _instance.getInstanceAdmin().getRoleId(uint64(idx));
    }


    function getRoleInfo(RoleId roleId) public view returns (IAccess.RoleInfo memory roleInfo) { 
        return _instance.getInstanceAdmin().getRoleInfo(roleId);
    }


    function hasRole(address account, RoleId roleId) public view returns (bool isMember) {
        return _instance.getInstanceAdmin().hasRole(account, roleId);
    }


    function hasAdminRole(address account, RoleId roleId) public view returns (bool isMember) {
        return _instance.getInstanceAdmin().hasAdminRole(account, roleId);
    }


    function isLocked(address target) public view returns (bool) {
        return _instance.getInstanceAdmin().isTargetLocked(target);
    }

    function toPolicyKey(NftId policyNftId) public pure returns (Key32) { 
        return policyNftId.toKey32(POLICY());
    }

    function toPremiumKey(NftId policyNftId) public pure returns (Key32) { 
        return policyNftId.toKey32(PREMIUM());
    }

    function toDistributorKey(NftId distributorNftId) public pure returns (Key32) { 
        return distributorNftId.toKey32(DISTRIBUTOR());
    }

    function toBundleKey(NftId poolNftId) public pure returns (Key32) { 
        return poolNftId.toKey32(BUNDLE());
    }

    function toComponentKey(NftId componentNftId) public pure returns (Key32) { 
        return componentNftId.toKey32(COMPONENT());
    }

    function toDistributionKey(NftId distributionNftId) public pure returns (Key32) { 
        return distributionNftId.toKey32(DISTRIBUTION());
    }

    function toPoolKey(NftId poolNftId) public pure returns (Key32) { 
        return poolNftId.toKey32(POOL());
    }

    function toProductKey(NftId productNftId) public pure returns (Key32) { 
        return productNftId.toKey32(PRODUCT());
    }

    function toFeeKey(NftId productNftId) public pure returns (Key32) { 
        return productNftId.toKey32(FEE());
    }

    // low level function

    function getInstanceStore() external view returns (IKeyValueStore store) {
        return _store;
    }

    function getBundleSet() external view returns (BundleSet bundleSet) {
        return _bundleSet;
    }

    function getRiskSet() external view returns (RiskSet riskSet) {
        return _riskSet;
    }

    function toUFixed(uint256 value, int8 exp) public pure returns (UFixed) {
        return UFixedLib.toUFixed(value, exp);
    }

    function toInt(UFixed value) public pure returns (uint256) {
        return UFixedLib.toInt(value);
    }
}