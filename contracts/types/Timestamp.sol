// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

type Timestamp is uint40;

using {
    gtTimestamp as >,
    gteTimestamp as >=,
    ltTimestamp as <,
    lteTimestamp as <=,
    eqTimestamp as ==,
    neqTimestamp as !=
} for Timestamp global;

/// @dev return true if Timestamp a is after Timestamp b
function gtTimestamp(Timestamp a, Timestamp b) pure returns(bool) { return Timestamp.unwrap(a) > Timestamp.unwrap(b); }
/// @dev return true if Timestamp a is after or equal to Timestamp b
function gteTimestamp(Timestamp a, Timestamp b) pure returns(bool) { return Timestamp.unwrap(a) >= Timestamp.unwrap(b); }

/// @dev return true if Timestamp a is before Timestamp b
function ltTimestamp(Timestamp a, Timestamp b) pure returns(bool) { return Timestamp.unwrap(a) < Timestamp.unwrap(b); }
/// @dev return true if Timestamp a is before or equal to Timestamp b
function lteTimestamp(Timestamp a, Timestamp b) pure returns(bool) { return Timestamp.unwrap(a) <= Timestamp.unwrap(b); }

/// @dev return true if Timestamp a is equal to Timestamp b
function eqTimestamp(Timestamp a, Timestamp b) pure returns(bool) { return Timestamp.unwrap(a) == Timestamp.unwrap(b); }
/// @dev return true if Timestamp a is not equal to Timestamp b
function neqTimestamp(Timestamp a, Timestamp b) pure returns(bool) { return Timestamp.unwrap(a) != Timestamp.unwrap(b); }

/// @dev Converts the uint256 to a Timestamp.
function toTimestamp(uint256 timestamp) pure returns(Timestamp) { return Timestamp.wrap(uint40(timestamp));}

function blockTimestamp() view returns(Timestamp) { return toTimestamp(block.timestamp); }

/// @dev Return the Timestamp zero (0)
function zeroTimestamp() pure returns(Timestamp) { return toTimestamp(0); }

library TimestampLib {
    /// @dev return true if Timestamp a is after Timestamp b
    function gt(Timestamp a, Timestamp b) internal pure returns(bool isAfter) { return gtTimestamp(a, b); }
    /// @dev return true if Timestamp a is after or the same than Timestamp b
    function gte(Timestamp a, Timestamp b) internal pure returns(bool isAfterOrSame) { return gteTimestamp(a, b); }

    /// @dev return true if Timestamp a is before Timestamp b
    function lt(Timestamp a, Timestamp b) internal pure returns(bool isBefore) { return ltTimestamp(a, b); }
    /// @dev return true if Timestamp a is before or the same than Timestamp b
    function lte(Timestamp a, Timestamp b) internal pure returns(bool isBeforeOrSame) { return lteTimestamp(a, b); }

    /// @dev return true if Timestamp a is equal to Timestamp b
    function eq(Timestamp a, Timestamp b) internal pure returns(bool isSame) { return eqTimestamp(a, b); }
    /// @dev return true if Timestamp a is not equal to Timestamp b
    function ne(Timestamp a, Timestamp b) internal pure returns(bool isDifferent) { return neqTimestamp(a, b); }

    function toInt(Timestamp timestamp) internal pure returns(uint256) { return uint256(uint40(Timestamp.unwrap(timestamp))); }
}
