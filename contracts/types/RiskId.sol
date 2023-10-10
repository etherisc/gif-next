// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Key32, KeyId, Key32Lib} from "./Key32.sol";
import {RISK} from "./ObjectType.sol";

type RiskId is bytes8;

// type bindings
using {
    eqRiskId as ==, 
    neRiskId as !=,
    RiskIdLib.toKey32
} for RiskId global;

// general pure free functions

// @dev Returns true iff risk ids a and b are identical
function eqRiskId(RiskId a, RiskId b) pure returns (bool isSame) {
    return RiskId.unwrap(a) == RiskId.unwrap(b);
}

// @dev Returns true iff risk ids a and b are different
function neRiskId(RiskId a, RiskId b) pure returns (bool isDifferent) {
    return RiskId.unwrap(a) != RiskId.unwrap(b);
}

library RiskIdLib {
    // @dev Converts a role string into a role id.
    function toRiskId(string memory risk) public pure returns (RiskId) {
        return RiskId.wrap(bytes8(keccak256(abi.encode(risk))));
    }

    /// @dev Returns the key32 value for the specified nft id and object type.
    function toKey32(RiskId id) public pure returns (Key32 key) {
        return Key32Lib.toKey32(RISK(), toKeyId(id));
    }

    /// @dev Returns the key id value for the specified nft id
    function toKeyId(RiskId id) public pure returns (KeyId keyId) {
        return KeyId.wrap(bytes31(RiskId.unwrap(id)));
    }
}
