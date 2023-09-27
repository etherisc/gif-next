// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

// uint96 allows for chain ids up to 13 digits
type NftId is uint96;

// type bindings
using {
    eqNftId as ==, 
    neNftId as !=, 
    NftIdLib.toInt,
    NftIdLib.gtz,
    NftIdLib.eqz
} for NftId global;

// general pure free functions
/// @dev Converts the uint256 to a NftId.
function toNftId(uint256 id) pure returns (NftId) {
    return NftId.wrap(uint96(id));
}

/// @dev Return the NftId zero (0)
function zeroNftId() pure returns (NftId) {
    return NftId.wrap(0);
}

// pure free functions for operators
function eqNftId(NftId a, NftId b) pure returns (bool isSame) {
    return NftId.unwrap(a) == NftId.unwrap(b);
}

function neNftId(NftId a, NftId b) pure returns (bool isDifferent) {
    return NftId.unwrap(a) != NftId.unwrap(b);
}

// library functions that operate on user defined type
library NftIdLib {
    /// @dev Converts the NftId to a uint256.
    function toInt(NftId nftId) public pure returns (uint96) {
        return uint96(NftId.unwrap(nftId));
    }

    /// @dev Returns true if the value is non-zero (> 0).
    function gtz(NftId a) public pure returns (bool) {
        return NftId.unwrap(a) > 0;
    }

    /// @dev Returns true if the value is zero (== 0).
    function eqz(NftId a) public pure returns (bool) {
        return NftId.unwrap(a) == 0;
    }

    /// @dev Returns true if the values are equal (==).
    function eq(NftId a, NftId b) public pure returns (bool isSame) {
        return eqNftId(a, b);
    }
}
