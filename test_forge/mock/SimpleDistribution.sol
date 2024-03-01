// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Distribution} from "../../contracts/components/Distribution.sol";
import {NftId} from "../../contracts/types/NftId.sol";
import {Fee} from "../../contracts/types/Fee.sol";

contract SimpleDistribution is Distribution {
    
    constructor(
        address registry,
        NftId instanceNftId,
        address token,
        bool verifying,
        Fee memory distributionFee,
        address initialOwner
    ) Distribution (
        registry,
        instanceNftId,
        "SimpleDistribution",
        token,
        verifying,
        distributionFee,
        initialOwner, 
        ""
    ) {
    }
}