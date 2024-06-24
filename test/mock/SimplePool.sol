// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AmountLib} from "../../contracts/type/Amount.sol";
import {BasicPool} from "../../contracts/pool/BasicPool.sol";
import {BasicPoolAuthorization} from "../../contracts/pool/BasicPoolAuthorization.sol";
import {Fee} from "../../contracts/type/Fee.sol";
import {IAuthorization} from "../../contracts/authorization/IAuthorization.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {Seconds} from "../../contracts/type/Timestamp.sol";
import {UFixed} from "../../contracts/type/UFixed.sol";

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
        returns(NftId bundleNftId)
    {
        address owner = msg.sender;
        bundleNftId = _createBundle(
            owner,
            fee,
            AmountLib.toAmount(initialAmount),
            lifetime,
            filter
        );
    }

}