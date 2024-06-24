// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {BasicDistribution} from "../../contracts/distribution/BasicDistribution.sol";
import {BasicDistributionAuthorization} from "../../contracts/distribution/BasicDistributionAuthorization.sol";
import {Fee} from "../../contracts/type/Fee.sol";
import {IAuthorization} from "../../contracts/authorization/IAuthorization.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {ReferralId} from "../../contracts/type/Referral.sol";
import {Timestamp} from "../../contracts/type/Timestamp.sol";
import {UFixed} from "../../contracts/type/UFixed.sol";


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