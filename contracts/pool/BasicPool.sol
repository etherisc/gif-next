// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "../type/Amount.sol";
import {InstanceLinkedComponent} from "../shared/InstanceLinkedComponent.sol";
import {Fee, FeeLib} from "../type/Fee.sol";
import {IAuthorization} from "../authorization/IAuthorization.sol";
import {IBundleService} from "./IBundleService.sol";
import {IPoolComponent} from "./IPoolComponent.sol";
import {IPoolService} from "./IPoolService.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IComponentService} from "../shared/IComponentService.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {BUNDLE, COMPONENT, POOL} from "../type/ObjectType.sol";
import {RoleId, PUBLIC_ROLE} from "../type/RoleId.sol";
import {Seconds} from "../type/Seconds.sol";
import {Timestamp} from "../type/Timestamp.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {UFixed, UFixedLib} from "../type/UFixed.sol";

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
        returns(Timestamp newExpiredAt)
    {
        return _extend(bundleNftId, lifetimeExtension);
    }


    function lockBundle(NftId bundleNftId)
        public
        virtual
        restricted()
        onlyBundleOwner(bundleNftId)
    {
        _lockBundle(bundleNftId);
    }


    function unlockBundle(NftId bundleNftId)
        public
        virtual
        restricted()
        onlyBundleOwner(bundleNftId)
    {
        _unlockBundle(bundleNftId);
    }


    function close(NftId bundleNftId)
        public
        virtual
        restricted()
        onlyBundleOwner(bundleNftId)
    {
        _close(bundleNftId);
    }


    function setBundleFee(
        NftId bundleNftId, 
        Fee memory fee
    )
        public
        virtual
        restricted()
        onlyBundleOwner(bundleNftId)
    {
        _setBundleFee(bundleNftId, fee);
    }


    function setMaxCapitalAmount(Amount maxCapitalAmount)
        public
        virtual
        restricted()
        onlyOwner()
    {
        _setMaxCapitalAmount(maxCapitalAmount);
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
