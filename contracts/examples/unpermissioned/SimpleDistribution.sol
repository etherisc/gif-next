// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {BasicDistribution} from "../../distribution/BasicDistribution.sol";
import {IAuthorization} from "../../authorization/IAuthorization.sol";
import {NftId} from "../../type/NftId.sol";


contract SimpleDistribution is
    BasicDistribution
{
    
    constructor(
        address registry,
        NftId instanceNftId,
        IAuthorization authorization,
        address initialOwner,
        address token
    ) 
    {
        initialize(
            registry,
            instanceNftId,
            authorization,
            initialOwner,
            "SimpleDistribution",
            token);
    }

    function initialize(
        address registry,
        NftId instanceNftId,
        IAuthorization authorization,
        address initialOwner,
        string memory name,
        address token
    )
        public
        virtual
        initializer()
    {
        _initializeBasicDistribution(
            registry,
            instanceNftId,
            authorization,
            initialOwner,
            name,
            token);
    }
}