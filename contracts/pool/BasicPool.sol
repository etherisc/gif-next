// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount} from "../type/Amount.sol";
import {Fee} from "../type/Fee.sol";
import {IAuthorization} from "../authorization/IAuthorization.sol";
import {IComponents} from "../instance/module/IComponents.sol";
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
        NftId productNftId,
        string memory name,
        IComponents.PoolInfo memory poolInfo,
        IAuthorization authorization,
        address initialOwner
    )
        internal
        virtual
        onlyInitializing()
    {
        __Pool_init(
            productNftId, 
            name, 
            poolInfo, 
            authorization,
            initialOwner);
    }

    function stake(
        NftId bundleNftId, 
        Amount amount
    )
        public
        virtual
        restricted()
        onlyBundleOwner(bundleNftId) // TODO single modifier to check everything about given arbitrary nftId
        onlyNftOfType(bundleNftId, BUNDLE()) // TODO service will check this
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
        onlyNftOfType(bundleNftId, BUNDLE())
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
        onlyNftOfType(bundleNftId, BUNDLE())
        returns(Timestamp newExpiredAt)
    {
        return _extend(bundleNftId, lifetimeExtension);
    }


    function setBundleLocked(NftId bundleNftId, bool locked)
        public
        virtual
        restricted()
        onlyBundleOwner(bundleNftId)
        onlyNftOfType(bundleNftId, BUNDLE())
    {
        _setBundleLocked(bundleNftId, locked);
    }


    function closeBundle(NftId bundleNftId)
        public
        virtual
        restricted()
        onlyBundleOwner(bundleNftId)
        onlyNftOfType(bundleNftId, BUNDLE())
    {
        _closeBundle(bundleNftId);
    }


    /// @dev Updates the bundle feeds to the specified values.
    /// @param bundleNftId the bundle Nft Id
    /// @param fee the new fee values
    function setBundleFee(
        NftId bundleNftId, 
        Fee memory fee
    )
        public
        virtual
        restricted()
        onlyBundleOwner(bundleNftId)
        onlyNftOfType(bundleNftId, BUNDLE())
    {
        _setBundleFee(bundleNftId, fee);
    }


    /// @dev Withdraw bundle feeds for the given bundle.
    /// @param bundleNftId the bundle Nft Id
    /// @param amount the amount to withdraw. If set to AMOUNT_MAX, the full commission available is withdrawn
    /// @return withdrawnAmount the effective withdrawn amount
    function withdrawBundleFees(NftId bundleNftId, Amount amount) 
        external 
        virtual
        restricted()
        onlyBundleOwner(bundleNftId)
        onlyNftOfType(bundleNftId, BUNDLE())
        returns (Amount withdrawnAmount) 
    {
        return _withdrawBundleFees(bundleNftId, amount);
    }


    function setMaxBalanceAmount(Amount maxBalanceAmount)
        public
        virtual
        restricted()
        onlyOwner()
    {
        _setMaxBalanceAmount(maxBalanceAmount);
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
