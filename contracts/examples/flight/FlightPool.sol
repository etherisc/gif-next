// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IAuthorization} from "../../authorization/IAuthorization.sol";
import {IComponents} from "../../instance/module/IComponents.sol";

import {Amount, AmountLib} from "../../type/Amount.sol";
import {BasicPool} from "../../pool/BasicPool.sol";
import {FeeLib} from "../../type/Fee.sol";
import {NftId} from "../../type/NftId.sol";
import {Seconds, SecondsLib} from "../../type/Seconds.sol";
import {UFixedLib} from "../../type/UFixed.sol";


/// @dev FlightPool implements the pool for the flight delay product.
/// Only the pool owner is allowed to create and manage bundles.
contract FlightPool is
    BasicPool
{   
    constructor(
        address registry,
        NftId productNftId,
        string memory componentName,
        IAuthorization authorization
    ) 
    {
        address initialOwner = msg.sender;
        _intialize(
            registry,
            productNftId,
            componentName,
            IComponents.PoolInfo({
                maxBalanceAmount: AmountLib.max(),
                isInterceptingBundleTransfers: false,
                isProcessingConfirmedClaims: false,
                isExternallyManaged: false,
                isVerifyingApplications: false,
                collateralizationLevel: UFixedLib.one(),
                retentionLevel: UFixedLib.one()
            }),
            authorization,
            initialOwner);
    }

    function _intialize(
        address registry,
        NftId productNftId,
        string memory componentName,
        IComponents.PoolInfo memory poolInfo,
        IAuthorization authorization,
        address initialOwner
    )
        internal
        initializer
    {
        _initializeBasicPool(
            registry,
            productNftId,
            componentName,
            poolInfo,
            authorization,
            initialOwner);
    }

    function createBundle(
        Amount initialAmount
    )
        external
        virtual 
        restricted()
        onlyOwner()
        returns(NftId bundleNftId)
    {
        address owner = msg.sender;
        bundleNftId = _createBundle(
            owner,
            FeeLib.zero(),
            SecondsLib.fromDays(90),
            "" // filter
        );

        _stake(bundleNftId, initialAmount);
    }

    function approveTokenHandler(IERC20Metadata token, Amount amount) external restricted() onlyOwner() { _approveTokenHandler(token, amount); }
    function setWallet(address newWallet) external restricted() onlyOwner() { _setWallet(newWallet); }
}