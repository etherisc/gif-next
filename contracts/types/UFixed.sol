// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @dev UFixed is a fixed point number with 18 decimals precision.
type UFixed is uint256;

using {
    addUFixed as +,
    subUFixed as -,
    mulUFixed as *,
    divUFixed as /,
    gtUFixed as >,
    gteUFixed as >=,
    ltUFixed as <,
    lteUFixed as <=,
    eqUFixed as ==,
    UFixedMathLib.toInt
} for UFixed global;

function addUFixed(UFixed a, UFixed b) pure returns (UFixed) {
    return UFixed.wrap(UFixed.unwrap(a) + UFixed.unwrap(b));
}

function subUFixed(UFixed a, UFixed b) pure returns (UFixed) {
    require(a >= b, "ERROR:UFM-010:NEGATIVE_RESULT");
    return UFixed.wrap(UFixed.unwrap(a) - UFixed.unwrap(b));
}

function mulUFixed(UFixed a, UFixed b) pure returns (UFixed) {
    return
        UFixed.wrap(Math.mulDiv(UFixed.unwrap(a), UFixed.unwrap(b), 10 ** 18));
}

function divUFixed(UFixed a, UFixed b) pure returns (UFixed) {
    require(UFixed.unwrap(b) > 0, "ERROR:UFM-020:DIVISOR_ZERO");

    return
        UFixed.wrap(Math.mulDiv(UFixed.unwrap(a), 10 ** 18, UFixed.unwrap(b)));
}

function gtUFixed(UFixed a, UFixed b) pure returns (bool isGreaterThan) {
    return UFixed.unwrap(a) > UFixed.unwrap(b);
}

function gteUFixed(UFixed a, UFixed b) pure returns (bool isGreaterThan) {
    return UFixed.unwrap(a) >= UFixed.unwrap(b);
}

function ltUFixed(UFixed a, UFixed b) pure returns (bool isGreaterThan) {
    return UFixed.unwrap(a) < UFixed.unwrap(b);
}

function lteUFixed(UFixed a, UFixed b) pure returns (bool isGreaterThan) {
    return UFixed.unwrap(a) <= UFixed.unwrap(b);
}

function eqUFixed(UFixed a, UFixed b) pure returns (bool isEqual) {
    return UFixed.unwrap(a) == UFixed.unwrap(b);
}

function gtzUFixed(UFixed a) pure returns (bool isZero) {
    return UFixed.unwrap(a) > 0;
}

function eqzUFixed(UFixed a) pure returns (bool isZero) {
    return UFixed.unwrap(a) == 0;
}

function deltaUFixed(UFixed a, UFixed b) pure returns (UFixed) {
    if (a > b) {
        return a - b;
    }

    return b - a;
}

library UFixedMathLib {
    int8 public constant EXP = 18;
    uint256 public constant MULTIPLIER = 10 ** uint256(int256(EXP));
    uint256 public constant MULTIPLIER_HALF = MULTIPLIER / 2;

    /// @dev returns the rounding mode DOWN - 0.4 becomes 0, 0.5 becomes 0, 0.6 becomes 0
    function ROUNDING_DOWN() public pure returns (uint8) {
        return uint8(0);
    }

    /// @dev returns the rounding mode UP - 0.4 becomes 1, 0.5 becomes 1, 0.6 becomes 1
    function ROUNDING_UP() public pure returns (uint8) {
        return uint8(1);
    }

    /// @dev returns the rounding mode HALF_UP - 0.4 becomes 0, 0.5 becomes 1, 0.6 becomes 1
    function ROUNDING_HALF_UP() public pure returns (uint8) {
        return uint8(2);
    }

    /// @dev Converts the uint256 to a UFixed.
    function toUFixed(uint256 a) public pure returns (UFixed) {
        return UFixed.wrap(a * MULTIPLIER);
    }

    /// @dev Converts the uint256 to a UFixed with given exponent.
    function toUFixed(uint256 a, int8 exp) public pure returns (UFixed) {
        require(EXP + exp >= 0, "ERROR:FM-010:EXPONENT_TOO_SMALL");
        require(EXP + exp <= 64, "ERROR:FM-011:EXPONENT_TOO_LARGE");

        return UFixed.wrap(a * 10 ** uint8(EXP + exp));
    }

    /// @dev returns the decimals precision of the UFixed type
    function decimals() public pure returns (uint256) {
        return uint8(EXP);
    }

    /// @dev Converts a UFixed to a uint256.
    function toInt(UFixed a) public pure returns (uint256) {
        return toIntWithRounding(a, ROUNDING_HALF_UP());
    }

    /// @dev Converts a UFixed to a uint256 with given rounding mode.
    function toIntWithRounding(UFixed a, uint8 rounding) public pure returns (uint256) {
        if (rounding == ROUNDING_HALF_UP()) {
            return
                Math.mulDiv(
                    UFixed.unwrap(a) + MULTIPLIER_HALF,
                    1,
                    MULTIPLIER,
                    Math.Rounding.Floor
                );
        } else if (rounding == ROUNDING_DOWN()) {
            return
                Math.mulDiv(
                    UFixed.unwrap(a),
                    1,
                    MULTIPLIER,
                    Math.Rounding.Floor
                );
        } else {
            return
                Math.mulDiv(UFixed.unwrap(a), 1, MULTIPLIER, Math.Rounding.Ceil);
        }
    }

    /// @dev adds two UFixed numbers
    function add(UFixed a, UFixed b) public pure returns (UFixed) {
        return addUFixed(a, b);
    }

    /// @dev subtracts two UFixed numbers
    function sub(UFixed a, UFixed b) public pure returns (UFixed) {
        return subUFixed(a, b);
    }

    /// @dev multiplies two UFixed numbers
    function mul(UFixed a, UFixed b) public pure returns (UFixed) {
        return mulUFixed(a, b);
    }

    /// @dev divides two UFixed numbers
    function div(UFixed a, UFixed b) public pure returns (UFixed) {
        return divUFixed(a, b);
    }

    /// @dev return true if UFixed a is greater than UFixed b
    function gt(UFixed a, UFixed b) public pure returns (bool isGreaterThan) {
        return gtUFixed(a, b);
    }

    /// @dev return true if UFixed a is greater than or equal to UFixed b
    function gte(UFixed a, UFixed b) public pure returns (bool isGreaterThan) {
        return gteUFixed(a, b);
    }

    /// @dev return true if UFixed a is less than UFixed b
    function lt(UFixed a, UFixed b) public pure returns (bool isGreaterThan) {
        return ltUFixed(a, b);
    }

    /// @dev return true if UFixed a is less than or equal to UFixed b
    function lte(UFixed a, UFixed b) public pure returns (bool isGreaterThan) {
        return lteUFixed(a, b);
    }

    /// @dev return true if UFixed a is equal to UFixed b
    function eq(UFixed a, UFixed b) public pure returns (bool isEqual) {
        return eqUFixed(a, b);
    }

    /// @dev return true if UFixed a is not zero
    function gtz(UFixed a) public pure returns (bool isZero) {
        return gtzUFixed(a);
    }

    /// @dev return true if UFixed a is zero
    function eqz(UFixed a) public pure returns (bool isZero) {
        return eqzUFixed(a);
    }

    function zero() public pure returns (UFixed) {
        return UFixed.wrap(0);
    }

    /// @dev return the absolute delta between two UFixed numbers
    function delta(UFixed a, UFixed b) public pure returns (UFixed) {
        return deltaUFixed(a, b);
    }
}
