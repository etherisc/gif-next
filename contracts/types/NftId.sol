// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

// uint96 allows for chain ids up to 13 digits
type NftId is uint96;

// type bindings
using {
    eqNftId as ==,
    neNftId as !=,
    NftIdLib.toInt
} for NftId global;

// general pure free functions
function toNftId(uint256 id) pure returns(NftId) { return NftId.wrap(uint96(id)); }
function gtz(NftId a) pure returns(bool) { return NftId.unwrap(a) > 0; }

// pure free functions for operators
function eqNftId(NftId a, NftId b) pure returns(bool isSame) { return NftId.unwrap(a) == NftId.unwrap(b); }
function neNftId(NftId a, NftId b) pure returns(bool isDifferent) { return NftId.unwrap(a) != NftId.unwrap(b); }

// library functions that operate on user defined type
library NftIdLib {
    function toInt(NftId nftId) internal pure returns(uint256) { return uint256(NftId.unwrap(nftId)); }
}
