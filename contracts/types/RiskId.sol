// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

type RiskId is bytes12;

// type bindings
using {
    eqRiskId as ==, 
    neRiskId as !=
} for RiskId global;


// @dev Converts a risk string into a risk id.
function toRiskId(bytes memory specification) pure returns (RiskId) {
    return RiskId.wrap(bytes12(keccak256(specification)));
}

// @dev Returns true iff risk ids a and b are identical
function eqRiskId(RiskId a, RiskId b) pure returns (bool isSame) {
    return RiskId.unwrap(a) == RiskId.unwrap(b);
}

// @dev Returns true iff risk ids a and b are different
function neRiskId(RiskId a, RiskId b) pure returns (bool isDifferent) {
    return RiskId.unwrap(a) != RiskId.unwrap(b);
}
