// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Amount, AmountLib} from "../../type/Amount.sol";
import {BasicPool} from "../../pool/BasicPool.sol";
import {Fee} from "../../type/Fee.sol";
import {IAuthorization} from "../../authorization/IAuthorization.sol";
import {IComponents} from "../../instance/module/IComponents.sol";
import {NftId} from "../../type/NftId.sol";
import {Seconds} from "../../type/Timestamp.sol";
import {UFixed} from "../../type/UFixed.sol";

contract SimplePool is
    BasicPool
{
    
    constructor(
        address registry,
        NftId productNftId,
        IComponents.PoolInfo memory poolInfo,
        IAuthorization authorization,
        address initialOwner
    ) 
    {
        initialize(
            registry,
            productNftId,
            poolInfo,
            authorization,
            initialOwner
        );
    }


    function initialize(
        address registry,
        NftId productNftId,
        IComponents.PoolInfo memory poolInfo,
        IAuthorization authorization,
        address initialOwner
    )
        public
        virtual
        initializer()
    {
        _initializeBasicPool(
            registry,
            productNftId,
            "SimplePool",
            poolInfo,
            authorization,
            initialOwner);
    }


    function createBundle(
        Fee memory fee,
        uint256 initialAmount,
        Seconds lifetime,
        bytes calldata filter
    )
        external
        virtual 
        returns(NftId bundleNftId, uint256 netStakedAmountInt)
    {
        address owner = msg.sender;
        Amount netStakedAmount;
        bundleNftId = _createBundle(
            owner,
            fee,
            lifetime,
            filter
        );
        netStakedAmount = _stake(bundleNftId, AmountLib.toAmount(initialAmount));
        netStakedAmountInt = netStakedAmount.toInt();
    }


    function fundPoolWallet(
        Amount amount
    )
        external
    {
        _fundPoolWallet(amount);
    }


    function defundPoolWallet(
        Amount amount
    )
        external
    {
        _defundPoolWallet(amount);
    }


    function approveTokenHandler(IERC20Metadata token, Amount amount) external restricted() onlyOwner() { _approveTokenHandler(token, amount); }
    function setLocked(bool locked) external onlyOwner() { _setLocked(locked); }
    function setWallet(address newWallet) external restricted() onlyOwner() { _setWallet(newWallet); }
}