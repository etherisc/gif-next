// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId} from "../../contracts/types/NftId.sol";
import {UFixed} from "../../contracts/types/UFixed.sol";
import {Fee, zeroFee} from "../../contracts/types/Fee.sol";
import {Pool} from "../../contracts/components/Pool.sol";


contract TestPool is Pool {

    constructor(
        address registry,
        NftId instanceNftid,
        address token,
        bool isVerifying,
        UFixed collateralizationLevel
    )
        Pool(registry, instanceNftid, token, isVerifying, collateralizationLevel)
    // solhint-disable-next-line no-empty-blocks
    {}
}