// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "../../type/Amount.sol";
import {BasicPool} from "../../pool/BasicPool.sol";
import {BasicPoolAuthorization} from "../../pool/BasicPoolAuthorization.sol";
import {Fee} from "../../type/Fee.sol";
import {IAuthorization} from "../../authorization/IAuthorization.sol";
import {NftId} from "../../type/NftId.sol";
import {Seconds} from "../../type/Timestamp.sol";
import {UFixed} from "../../type/UFixed.sol";

contract SimplePool is
    BasicPool
{
    
    constructor(
        address registry,
        NftId instanceNftId,
        address token,
        IAuthorization authorization,
        address initialOwner
    ) 
    {
        initialize(
            registry,
            instanceNftId,
            token,
            authorization,
            initialOwner
        );
    }

    function initialize(
        address registry,
        NftId instanceNftId,
        address token,
        IAuthorization authorization,
        address initialOwner
    )
        public
        virtual
        initializer()
    {
        _initializeBasicPool(
            registry,
            instanceNftId,
            authorization,
            token,
            "SimplePool",
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