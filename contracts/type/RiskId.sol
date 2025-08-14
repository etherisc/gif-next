// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Key32, KeyId, Key32Lib} from "./Key32.sol";
import {RISK} from "./ObjectType.sol";

type RiskId is uint64;

// type bindings
using {
    eqRiskId as ==, 
    neRiskId as !=,
    RiskIdLib.eq,
    RiskIdLib.eqz,
    RiskIdLib.gtz,
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
        return RiskId.wrap(uint64(0));
    }

    // @dev Converts a risk id into a uint256.
    function toInt(RiskId riskId) public pure returns (uint256) {
        return uint64(RiskId.unwrap(riskId));
    }

    // @dev Converts a risk id string with a product NftId into a risk id.
    function toRiskId(uint256 id) public pure returns (RiskId) {
        return RiskId.wrap(uint64(id));
    }

    /// @dev Returns the key32 value for the specified risk id.
    function toKey32(RiskId riskId) public pure returns (Key32 key) {
        return Key32Lib.toKey32(RISK(), toKeyId(riskId));
    }

    /// @dev Returns the key id value for the specified nft id
    function toKeyId(RiskId id) public pure returns (KeyId keyId) {
        return KeyId.wrap(bytes31(uint248(RiskId.unwrap(id))));
    }

    function toRiskId(KeyId keyId) public pure returns (RiskId riskId) {
        uint248 keyIdInt = uint248(bytes31(KeyId.unwrap(keyId)));
        assert(keyIdInt < type(uint64).max);
        return RiskId.wrap(uint64(keyIdInt));
    }

    function eq(RiskId a, RiskId b) public pure returns (bool isSame) {
        return eqRiskId(a, b);
    }

    function eqz(RiskId a) public pure returns (bool isZero) {
        return eqRiskId(a, zero());
    }

    function gtz(RiskId a) public pure returns (bool isZero) {
        return uint64(RiskId.unwrap(a)) > 0;
    }
}
