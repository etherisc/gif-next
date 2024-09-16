// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ShortString, ShortStrings} from "@openzeppelin/contracts/utils/ShortStrings.sol";

type Str is bytes32;

using {
    StrEq as ==,
    StrNe as !=,
    StrLib.toString,
    StrLib.length
} for Str global;

// pure free function needed for the operator overloading
function StrEq(Str s1, Str s2) pure returns (bool) {
    return StrLib.eq(s1, s2);
}

// pure free function needed for the operator overloading
function StrNe(Str s1, Str s2) pure returns (bool) {
    return StrLib.ne(s1, s2);
}

library StrLib {


    /// @dev converts the provided string into a short string.
    /// uses ShortStrings.toShortString
    function toStr(string memory str) public pure returns (Str) {
        return Str.wrap(ShortString.unwrap(ShortStrings.toShortString(str)));
    }

    /// @dev return true iff s1 equals s2
    function eq(Str s1, Str s2) public pure returns (bool) {
        return Str.unwrap(s1) == Str.unwrap(s2);
    }

    /// @dev return true iff s1 differs from s2
    function ne(Str s1, Str s2) public pure returns (bool) {
        return Str.unwrap(s1) != Str.unwrap(s2);
    }

    /// @dev return true iff s1 equals from s2
    function eq(string memory s1, string memory s2) public pure returns (bool) {
        return keccak256(bytes(s1)) == keccak256(bytes(s2));
    }

    /// @dev return true iff s1 differs s2
    function ne(string memory s1, string memory s2) public pure returns (bool) {
        return !eq(s1, s2);
    }

    /// @dev converts the provided short string into a string.
    /// uses ShortStrings.toString
    function toString(Str str) public pure returns (string memory) {
        return ShortStrings.toString(ShortString.wrap(Str.unwrap(str)));
    }

    /// @dev converts the provided short string into a string.
    /// uses ShortStrings.byteLength
    function length(Str str) public pure returns (uint256 byteLength) {
        return ShortStrings.byteLength(ShortString.wrap(Str.unwrap(str)));
    }

    /// @dev Returns the provied int as a string
    function uintToString(uint256 value) public pure returns (string memory name) {

        if (value == 0) {
            return "0";
        }

        uint256 temp = value;
        uint256 digits = 0;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);
        uint256 index = digits - 1;

        temp = value;
        while (temp != 0) {
            buffer[index] = bytes1(uint8(48 + temp % 10));
            temp /= 10;

            if (index > 0) {
                index--;
            }
        }

        return string(buffer);
    }
}