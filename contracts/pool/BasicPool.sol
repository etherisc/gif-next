// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount} from "../type/Amount.sol";
import {Fee} from "../type/Fee.sol";
import {IAuthorization} from "../authorization/IAuthorization.sol";
import {NftId} from "../type/NftId.sol";
import {BUNDLE} from "../type/ObjectType.sol";
import {RoleId} from "../type/RoleId.sol";
import {Seconds} from "../type/Seconds.sol";
import {Timestamp} from "../type/Timestamp.sol";

import {Pool} from "./Pool.sol";

abstract contract BasicPool is
    Pool
{

    function _initializeBasicPool(
        address registry,
        NftId instanceNftId,
        IAuthorization authorization,
        address token,
        string memory name,
        address initialOwner
    )
        internal
        virtual
        onlyInitializing()
    {
        _initializePool(
            registry, 
            instanceNftId, 
            name, 
            token, 
            authorization,
            false, // isInterceptingNftTransfers, 
            initialOwner, 
            "", // registryData
            ""); // componentData
    }

    function stake(
        NftId bundleNftId, 
        Amount amount
    )
        public
        virtual
        restricted()
        onlyBundleOwner(bundleNftId)
        onlyNftObjectType(bundleNftId, BUNDLE())
    {
        _stake(bundleNftId, amount);
    }


    function unstake(
        NftId bundleNftId, 
        Amount amount
    )
        public
        virtual
        restricted()
        onlyBundleOwner(bundleNftId)
        onlyNftObjectType(bundleNftId, BUNDLE())
    {
        _unstake(bundleNftId, amount);
    }


    function extend(
        NftId bundleNftId, 
        Seconds lifetimeExtension
    )
        public
        virtual
        restricted()
        onlyBundleOwner(bundleNftId)
        onlyNftObjectType(bundleNftId, BUNDLE())
        returns(Timestamp newExpiredAt)
    {
        return _extend(bundleNftId, lifetimeExtension);
    }


    function lockBundle(NftId bundleNftId)
        public
        virtual
        restricted()
        onlyBundleOwner(bundleNftId)
        onlyNftObjectType(bundleNftId, BUNDLE())
    {
        _lockBundle(bundleNftId);
    }


    function unlockBundle(NftId bundleNftId)
        public
        virtual
        restricted()
        onlyBundleOwner(bundleNftId)
        onlyNftObjectType(bundleNftId, BUNDLE())
    {
        _unlockBundle(bundleNftId);
    }


    function closeBundle(NftId bundleNftId)
        public
        virtual
        restricted()
        onlyBundleOwner(bundleNftId)
        onlyNftObjectType(bundleNftId, BUNDLE())
    {
        _closeBundle(bundleNftId);
    }


    function setBundleFee(
        NftId bundleNftId, 
        Fee memory fee
    )
        public
        virtual
        restricted()
        onlyBundleOwner(bundleNftId)
        onlyNftObjectType(bundleNftId, BUNDLE())
    {
        _setBundleFee(bundleNftId, fee);
    }


    function setMaxBalanceAmount(Amount maxBalanceAmount)
        public
        virtual
        restricted()
        onlyOwner()
    {
        _setMaxBalanceAmount(maxBalanceAmount);
    }


    function setBundleOwnerRole(RoleId bundleOwnerRole)
        public
        virtual
        restricted()
        onlyOwner()
    {
        _setBundleOwnerRole(bundleOwnerRole);
    }


    function setFees(
        Fee memory poolFee,
        Fee memory stakingFee,
        Fee memory performanceFee
    )
        public
        virtual
        restricted()
        onlyOwner()
    {
        _setPoolFees(poolFee, stakingFee, performanceFee);
    }
}
