// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {DistributorType} from "../types/DistributorType.sol";
import {Fee, FeeLib} from "../types/Fee.sol";
import {Key32} from "../types/Key32.sol";
import {NftId} from "../types/NftId.sol";
import {ObjectType, DISTRIBUTOR, DISTRIBUTION, INSTANCE, PRODUCT, POLICY, POOL, TREASURY} from "../types/ObjectType.sol";
import {ReferralId, ReferralStatus, ReferralLib, REFERRAL_OK, REFERRAL_ERROR_UNKNOWN, REFERRAL_ERROR_EXPIRED, REFERRAL_ERROR_EXHAUSTED} from "../types/Referral.sol";
import {Registerable} from "../shared/Registerable.sol";
import {RiskId} from "../types/RiskId.sol";
import {UFixed, MathLib, UFixedLib} from "../types/UFixed.sol";
import {Version} from "../types/Version.sol";

import {IRegistry} from "../registry/IRegistry.sol";
import {IDistribution} from "../instance/module/IDistribution.sol";
import {IInstance} from "./IInstance.sol";
import {IKeyValueStore} from "../instance/base/IKeyValueStore.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";
import {IRisk} from "../instance/module/IRisk.sol";
import {ISetup} from "../instance/module/ISetup.sol";
import {ITreasury} from "../instance/module/ITreasury.sol";
import {TimestampLib} from "../types/Timestamp.sol";


contract InstanceReader {

    IRegistry internal _registry;
    NftId internal _instanceNftId;
    IInstance internal _instance;
    IKeyValueStore internal _store;

    constructor(
        address registry, 
        NftId instanceNftId
    )
    {
        require(
            address(registry) != address(0),
            "ERROR:CRD-001:REGISTRY_ZERO");

        require(
            instanceNftId.gtz(),
            "ERROR:CRD-002:NFT_ID_ZERO");

        _registry = IRegistry(registry);
        _instanceNftId = instanceNftId;
        IRegistry.ObjectInfo memory instanceInfo = _registry.getObjectInfo(_instanceNftId);

        require(
            instanceInfo.objectType == INSTANCE(), 
            "ERROR:CRD-003:PARENT_NOT_INSTANCE");

        _instance = IInstance(instanceInfo.objectAddress);
        _store = IKeyValueStore(instanceInfo.objectAddress);
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

    function getTokenHandler(NftId productNftId)
        public
        view
        returns (address tokenHandler)
    {
        bytes memory data = _store.getData(toTreasuryKey(productNftId));

        if (data.length > 0) {
            ITreasury.TreasuryInfo memory info = abi.decode(data, (ITreasury.TreasuryInfo));
            return address(info.tokenHandler);
        }
    }

    function getTreasuryInfo(NftId productNftId)
        public 
        view 
        returns (ITreasury.TreasuryInfo memory info)
    {
        bytes memory data = _store.getData(toTreasuryKey(productNftId));
        if (data.length > 0) {
            return abi.decode(data, (ITreasury.TreasuryInfo));
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

    function getDistributionSetupInfo(NftId distributionNftId)
        public
        view
        returns (ISetup.DistributionSetupInfo memory info)
    {
        bytes memory data = _store.getData(toDistributionKey(distributionNftId));
        if (data.length > 0) {
            return abi.decode(data, (ISetup.DistributionSetupInfo));
        }
    }

    function getPoolSetupInfo(NftId poolNftId)
        public
        view
        returns (ISetup.PoolSetupInfo memory info)
    {
        bytes memory data = _store.getData(toPoolKey(poolNftId));
        if (data.length > 0) {
            return abi.decode(data, (ISetup.PoolSetupInfo));
        }
    }

    function getProductSetupInfo(NftId productNftId)
        public
        view
        returns (ISetup.ProductSetupInfo memory info)
    {
        bytes memory data = _store.getData(toProductKey(productNftId));
        if (data.length > 0) {
            return abi.decode(data, (ISetup.ProductSetupInfo));
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


    function getMetadata(Key32 key)
        public 
        view 
        returns (IKeyValueStore.Metadata memory metadata)
    {
        return _store.getMetadata(key);
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


    function toTreasuryKey(NftId productNftId) public pure returns (Key32) { 
        return productNftId.toKey32(TREASURY());
    }


    function toPolicyKey(NftId policyNftId) public pure returns (Key32) { 
        return policyNftId.toKey32(POLICY());
    }


    function toDistributorKey(NftId distributorNftId) public pure returns (Key32) { 
        return distributorNftId.toKey32(DISTRIBUTOR());
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

    function getInstanceNftId() external view returns (NftId nftId) {
        return _instanceNftId;
    }

    function toUFixed(uint256 value, int8 exp) public pure returns (UFixed) {
        return UFixedLib.toUFixed(value, exp);
    }

    function toInt(UFixed value) public pure returns (uint256) {
        return UFixedLib.toInt(value);
    }
}
