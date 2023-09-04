// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

/// @dev bytes5 (uint40) allows for chain ids up to 13 digits
type ChainId is bytes5;

// type bindings
using {eqChainId as ==, neChainId as !=, ChainIdLib.toInt} for ChainId global;

// general pure free functions
/// @dev Converts the uint256 to a ChainId.
function toChainId(uint256 chainId) pure returns (ChainId) {
    return ChainId.wrap(bytes5(uint40(chainId)));
}

/// @dev Return the ChainId for the chain the contract is deployed to
function thisChainId() view returns (ChainId) {
    return toChainId(block.chainid);
}

// pure free functions for operators
/// @dev Returns true if the values are equal (==).
function eqChainId(ChainId a, ChainId b) pure returns (bool isSame) {
    return ChainId.unwrap(a) == ChainId.unwrap(b);
}

/// @dev Returns true if the values are not equal (!=).
function neChainId(ChainId a, ChainId b) pure returns (bool isDifferent) {
    return ChainId.unwrap(a) != ChainId.unwrap(b);
}

// library functions that operate on user defined type
library ChainIdLib {
    /// @dev Converts the ChainId to a uint256.
    function toInt(ChainId chainId) internal pure returns (uint256) {
        return uint256(uint40(ChainId.unwrap(chainId)));
    }
}
