// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Fee} from "../../contracts/types/Fee.sol";
import {NftId} from "../../contracts/types/NftId.sol";
import {Distribution} from "../../contracts/components/Distribution.sol";


contract TestDistribution is Distribution {

    constructor(
        address registry,
        NftId instanceNftid,
        address token,
        bool isVerifying,
        Fee memory distributionFee,
        address initialOwner
    )
        Distribution(registry, instanceNftid, token, isVerifying, distributionFee, initialOwner)
    // solhint-disable-next-line no-empty-blocks
    {}
}