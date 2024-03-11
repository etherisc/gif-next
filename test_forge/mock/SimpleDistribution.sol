// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Distribution} from "../../contracts/components/Distribution.sol";
import {NftId} from "../../contracts/types/NftId.sol";
import {Fee} from "../../contracts/types/Fee.sol";
import {UFixed} from "../../contracts/types/UFixed.sol";

contract SimpleDistribution is Distribution {
    
    constructor(
        address registry,
        NftId instanceNftId,
        address token,
        Fee memory distributionFee,
        address initialOwner
    ) 
    {
        initialize(
            registry,
            instanceNftId,
            "SimpleDistribution",
            token,
            distributionFee,
            initialOwner);
    }

    function initialize(
        address registry,
        NftId instanceNftId,
        string memory name,
        address token,
        Fee memory distributionFee,
        address initialOwner
    )
        public
        virtual
        initializer()
    {
        initializeDistribution(
            registry,
            instanceNftId,
            name,
            token,
            distributionFee,
            initialOwner,
            ""
        );
    }
}