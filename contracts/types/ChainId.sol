// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

// bytes5 allows for chain ids up to 13 digits
type ChainId is bytes5;

// type bindings
using {
    eqChainId as ==,
    neChainId as !=,
    ChainIdLib.toInt
} for ChainId global;

// general pure free functions
function toChainId(uint256 chainId) pure returns(ChainId) { return ChainId.wrap(bytes5(uint40(chainId))); }

// pure free functions for operators
function eqChainId(ChainId a, ChainId b) pure returns(bool isSame) { return ChainId.unwrap(a) == ChainId.unwrap(b); }
function neChainId(ChainId a, ChainId b) pure returns(bool isDifferent) { return ChainId.unwrap(a) != ChainId.unwrap(b); }

// library functions that operate on user defined type
library ChainIdLib {
    function toInt(ChainId chainId) internal pure returns(uint256) { return uint256(uint40(ChainId.unwrap(chainId))); }
}
