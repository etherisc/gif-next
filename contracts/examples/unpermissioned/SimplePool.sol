// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "../../type/Amount.sol";
import {BasicPool} from "../../pool/BasicPool.sol";
import {BasicPoolAuthorization} from "../../pool/BasicPoolAuthorization.sol";
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
        address token,
        IAuthorization authorization,
        IComponents.PoolInfo memory poolInfo,
        address initialOwner
    ) 
    {
        initialize(
            registry,
            productNftId,
            token,
            authorization,
            poolInfo,
            initialOwner
        );
    }

    function initialize(
        address registry,
        NftId productNftId,
        address token,
        IAuthorization authorization,
        IComponents.PoolInfo memory poolInfo,
        address initialOwner
    )
        public
        virtual
        initializer()
    {
        _initializeBasicPool(
            registry,
            productNftId,
            authorization,
            token,
            "SimplePool",
            poolInfo,
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

}