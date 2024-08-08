// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount} from "../../type/Amount.sol";
import {BasicPool} from "../../pool/BasicPool.sol";
import {Fee} from "../../type/Fee.sol";
import {IAuthorization} from "../../authorization/IAuthorization.sol";
import {NftId} from "../../type/NftId.sol";
import {Seconds} from "../../type/Timestamp.sol";

contract FirePool is
    BasicPool
{
    
    constructor(
        address registry,
        NftId fireProductNftId,
        string memory componentName,
        address token,
        IAuthorization authorization
    ) 
    {
        address initialOwner = msg.sender;
        _intialize(
            registry,
            fireProductNftId,
            componentName,
            token,
            authorization,
            initialOwner);
    }

    function _intialize(
        address registry,
        NftId fireProductNftId,
        string memory componentName,
        address token,
        IAuthorization authorization,
        address initialOwner
    )
        internal
        initializer
    {
        _initializeBasicPool(
            registry,
            fireProductNftId,
            authorization,
            token,
            componentName,
            initialOwner);
    }

    function createBundle(
        Fee memory fee,
        Amount initialAmount,
        Seconds lifetime
    )
        external
        virtual 
        restricted()
        returns(NftId bundleNftId, Amount netStakedAmount)
    {
        address owner = msg.sender;
        bundleNftId = _createBundle(
            owner,
            fee,
            lifetime,
            "" // filter
        );
        netStakedAmount = _stake(bundleNftId, initialAmount);
    }

}