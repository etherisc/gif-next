// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {UFixed} from "./UFixed.sol";

struct Fee {
    UFixed fractionalFee;
    uint256 fixedFee;
}

// general pure free functions
/// @dev Converts the uint256 to a NftId.
function toFee(UFixed fractionalFee, uint256 fixedFee) pure returns (Fee memory fee) {
    return Fee(fractionalFee, fixedFee);
}

/// @dev Return the NftId zero (0)
function zeroFee() pure returns (Fee memory fee) {
    return Fee(UFixed.wrap(0), 0);
}

// pure free functions for operators
function feeIsSame(Fee memory a, Fee memory b) pure returns (bool isSame) {
    return a.fixedFee == b.fixedFee && a.fractionalFee == b.fractionalFee;
}


function feeIsZero(Fee memory fee) pure returns(bool) {
    return fee.fixedFee == 0 && UFixed.unwrap(fee.fractionalFee) == 0;
}