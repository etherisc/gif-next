// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Amount} from "../type/Amount.sol";
import {ClaimId} from "../type/ClaimId.sol";
import {DistributorType} from "../type/DistributorType.sol";
import {Fee, FeeLib} from "../type/Fee.sol";
import {Key32} from "../type/Key32.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, COMPONENT, DISTRIBUTOR, DISTRIBUTION, INSTANCE, PRODUCT, POLICY, POOL, BUNDLE} from "../type/ObjectType.sol";
import {PayoutId} from "../type/PayoutId.sol";
import {ReferralId, ReferralStatus, ReferralLib, REFERRAL_OK, REFERRAL_ERROR_UNKNOWN, REFERRAL_ERROR_EXPIRED, REFERRAL_ERROR_EXHAUSTED} from "../type/Referral.sol";
import {RequestId} from "../type/RequestId.sol";
import {RiskId} from "../type/RiskId.sol";
import {RoleId} from "../type/RoleId.sol";
import {StateId} from "../type/StateId.sol";
import {UFixed, MathLib, UFixedLib} from "../type/UFixed.sol";
import {Version} from "../type/Version.sol";

import {IRegistry} from "../registry/IRegistry.sol";
import {IBundle} from "../instance/module/IBundle.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IDistribution} from "../instance/module/IDistribution.sol";
import {IInstance} from "./IInstance.sol";
import {IKeyValueStore} from "../shared/IKeyValueStore.sol";
import {IOracle} from "../oracle/IOracle.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";
import {IRisk} from "../instance/module/IRisk.sol";
import {TimestampLib} from "../type/Timestamp.sol";

import {InstanceStore} from "./InstanceStore.sol";


contract InstanceReader {

    error ErrorInstanceReaderAlreadyInitialized();
    error ErrorInstanceReaderInstanceAddressZero();

    bool private _initialized;

    IInstance internal _instance;
    InstanceStore internal _store;

    function initialize(address instance) public {
        if(_initialized) {
            revert ErrorInstanceReaderAlreadyInitialized();
        }

        if(instance == address(0)) {
            revert ErrorInstanceReaderInstanceAddressZero();
        }

        _instance = IInstance(instance);
        _store = _instance.getInstanceStore();

        _initialized = true;
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

    /// @dev returns true iff policy may be closed
    /// a policy can be closed all conditions below are met
    /// - policy exists
    /// - has been activated
    /// - is not yet closed
    /// - has no open claims
    /// - claim amount matches sum insured amount or is expired
    function policyIsCloseable(NftId policyNftId)
        public
        view
        returns (bool isCloseable)
    {
        IPolicy.PolicyInfo memory info = getPolicyInfo(policyNftId);

        if (info.productNftId.eqz()) { return false; } // not closeable: policy does not exist (or does not belong to this instance)
        if (info.activatedAt.eqz()) { return false; } // not closeable: not yet activated
        if (info.closedAt.gtz()) { return false; } // not closeable: already closed
        if (info.openClaimsCount > 0) { return false; } // not closeable: has open claims

        // closeable: if sum of claims matches sum insured a policy may be closed prior to the expiry date
        if (info.claimAmount == info.sumInsuredAmount) { return true; }

        // not closeable: not yet expired
        if (TimestampLib.blockTimestamp() < info.expiredAt) { return false; }

        // all conditionsl to close the policy are met
        return true; 
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

    function getTokenHandler(NftId componentNftId)
        public
        view
        returns (address tokenHandler)
    {
        bytes memory data = _store.getData(toComponentKey(componentNftId));

        if (data.length > 0) {
            IComponents.ComponentInfo memory info = abi.decode(data, (IComponents.ComponentInfo));
            return address(info.tokenHandler);
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

    function hasRole(address account, RoleId roleId) public view returns (bool isMember) {
        (isMember, ) = _instance.getInstanceAccessManager().hasRole(
            roleId.toInt(), account);
    }

    function toPolicyKey(NftId policyNftId) public pure returns (Key32) { 
        return policyNftId.toKey32(POLICY());
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

    // low level function
    function getInstance() external view returns (IInstance instance) {
        return _instance;
    }

    function getInstanceStore() external view returns (IKeyValueStore store) {
        return _store;
    }

    function toUFixed(uint256 value, int8 exp) public pure returns (UFixed) {
        return UFixedLib.toUFixed(value, exp);
    }

    function toInt(UFixed value) public pure returns (uint256) {
        return UFixedLib.toInt(value);
    }
}