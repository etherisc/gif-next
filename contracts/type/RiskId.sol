// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Key32, KeyId, Key32Lib} from "./Key32.sol";
import {RISK} from "./ObjectType.sol";

type RiskId is bytes8;

// type bindings
using {
    eqRiskId as ==, 
    neRiskId as !=,
    RiskIdLib.eq,
    RiskIdLib.eqz,
    RiskIdLib.toInt,
    RiskIdLib.toKeyId,
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
    function zero() public pure returns (RiskId) {
        return RiskId.wrap(bytes8(0));
    }

    // @dev Converts a risk id into a uint256.
    function toInt(RiskId riskId) public pure returns (uint256) {
        return uint64(RiskId.unwrap(riskId));
    }

    // @dev Converts a risk id string into a risk id.
    function toRiskId(string memory risk) public pure returns (RiskId) {
        return RiskId.wrap(bytes8(keccak256(abi.encode(risk))));
    }

    /// @dev Returns the key32 value for the specified risk id.
    function toKey32(RiskId riskId) public pure returns (Key32 key) {
        return Key32Lib.toKey32(RISK(), toKeyId(riskId));
    }

    /// @dev Returns the key id value for the specified nft id
    function toKeyId(RiskId id) public pure returns (KeyId keyId) {
        return KeyId.wrap(bytes31(RiskId.unwrap(id)));
    }

    function toRiskId(KeyId keyId) public pure returns (RiskId riskId) {
        riskId = RiskId.wrap(bytes8(KeyId.unwrap(keyId)));
        assert(toInt(riskId) < 2**64);
    }

    function eq(RiskId a, RiskId b) public pure returns (bool isSame) {
        return eqRiskId(a, b);
    }

    function eqz(RiskId a) public pure returns (bool isZero) {
        return eqRiskId(a, zero());
    }
}
