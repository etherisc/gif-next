// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

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
    eqUFixed as ==
} for UFixed global;

function addUFixed(UFixed a, UFixed b) pure returns(UFixed) {
    return UFixed.wrap(UFixed.unwrap(a) + UFixed.unwrap(b));
}

function subUFixed(UFixed a, UFixed b) pure returns(UFixed) {
    require(a >= b, "ERROR:UFM-010:NEGATIVE_RESULT");
    return UFixed.wrap(UFixed.unwrap(a) - UFixed.unwrap(b));
}

function mulUFixed(UFixed a, UFixed b) pure returns(UFixed) {
    return UFixed.wrap(Math.mulDiv(UFixed.unwrap(a), UFixed.unwrap(b), 10 ** 18));
}

function divUFixed(UFixed a, UFixed b) pure returns(UFixed) {
    require(UFixed.unwrap(b) > 0, "ERROR:UFM-020:DIVISOR_ZERO");

    return UFixed.wrap(
        Math.mulDiv(
            UFixed.unwrap(a), 
            10 ** 18,
            UFixed.unwrap(b)));
}

function gtUFixed(UFixed a, UFixed b) pure returns(bool isGreaterThan) {
    return UFixed.unwrap(a) > UFixed.unwrap(b);
}

function gteUFixed(UFixed a, UFixed b) pure returns(bool isGreaterThan) {
    return UFixed.unwrap(a) >= UFixed.unwrap(b);
}

function ltUFixed(UFixed a, UFixed b) pure returns(bool isGreaterThan) {
    return UFixed.unwrap(a) < UFixed.unwrap(b);
}

function lteUFixed(UFixed a, UFixed b) pure returns(bool isGreaterThan) {
    return UFixed.unwrap(a) <= UFixed.unwrap(b);
}

function eqUFixed(UFixed a, UFixed b) pure returns(bool isEqual) {
    return UFixed.unwrap(a) == UFixed.unwrap(b);
}

function gtzUFixed(UFixed a) pure returns(bool isZero) {
    return UFixed.unwrap(a) > 0;
}

function eqzUFixed(UFixed a) pure returns(bool isZero) {
    return UFixed.unwrap(a) == 0;
}

function deltaUFixed(UFixed a, UFixed b) pure returns(UFixed) {
    if(a > b) {
        return a - b;
    }

    return b - a;
}

library UFixedMathLib {

    enum Rounding {
        /// @dev Round down - floor(value)
        Down, 
        /// @dev Round up - ceil(value)
        Up, 
        /// @dev Round half up - round(value)
        HalfUp 
    }

    int8 public constant EXP = 18;
    uint256 public constant MULTIPLIER = 10 ** uint256(int256(EXP));
    uint256 public constant MULTIPLIER_HALF = MULTIPLIER / 2;
    
    /// @dev Default rounding mode used by ftoi is HalfUp
    Rounding public constant ROUNDING_DEFAULT = Rounding.HalfUp;

    /// @dev returns the decimals precision of the UFixed type
    function decimals() public pure returns(uint256) {
        return uint8(EXP);
    }

    /// @dev Converts the uint256 to a UFixed.
    function itof(uint256 a)
        public
        pure
        returns(UFixed)
    {
        return UFixed.wrap(a * MULTIPLIER);
    }

    /// @dev Converts the uint256 to a UFixed with given exponent.
    function itof(uint256 a, int8 exp)
        public
        pure
        returns(UFixed)
    {
        require(EXP + exp >= 0, "ERROR:FM-010:EXPONENT_TOO_SMALL");
        require(EXP + exp <= 64, "ERROR:FM-011:EXPONENT_TOO_LARGE");

        return UFixed.wrap(a * 10 ** uint8(EXP + exp));
    }

    /// @dev Converts a UFixed to a uint256.
    function ftoi(UFixed a)
        public
        pure
        returns(uint256)
    {
        return ftoi(a, ROUNDING_DEFAULT);
    }

    /// @dev Converts a UFixed to a uint256 with given rounding mode.
    function ftoi(UFixed a, Rounding rounding)
        public
        pure
        returns(uint256)
    {
        if(rounding == Rounding.HalfUp) {
            return Math.mulDiv(UFixed.unwrap(a) + MULTIPLIER_HALF, 1, MULTIPLIER, Math.Rounding.Down);
        } else if(rounding == Rounding.Down) {
            return Math.mulDiv(UFixed.unwrap(a), 1, MULTIPLIER, Math.Rounding.Down);
        } else {
            return Math.mulDiv(UFixed.unwrap(a), 1, MULTIPLIER, Math.Rounding.Up);
        }
    }

    /// @dev adds two UFixed numbers
    function add(UFixed a, UFixed b) public pure returns(UFixed) {
        return addUFixed(a, b);
    }

    /// @dev subtracts two UFixed numbers
    function sub(UFixed a, UFixed b) public pure returns(UFixed) {
        return subUFixed(a, b);
    }

    /// @dev multiplies two UFixed numbers
    function mul(UFixed a, UFixed b) public pure returns(UFixed) {
        return mulUFixed(a, b);
    }

    /// @dev divides two UFixed numbers
    function div(UFixed a, UFixed b) public pure returns(UFixed) {
        return divUFixed(a, b);
    }

    /// @dev return true if UFixed a is greater than UFixed b
    function gt(UFixed a, UFixed b) public pure returns(bool isGreaterThan) {
        return gtUFixed(a, b);
    }

    /// @dev return true if UFixed a is greater than or equal to UFixed b
    function gte(UFixed a, UFixed b) public pure returns(bool isGreaterThan) {
        return gteUFixed(a, b);
    }

    /// @dev return true if UFixed a is less than UFixed b
    function lt(UFixed a, UFixed b) public pure returns(bool isGreaterThan) {
        return ltUFixed(a, b);
    }

    /// @dev return true if UFixed a is less than or equal to UFixed b
    function lte(UFixed a, UFixed b) public pure returns(bool isGreaterThan) {
        return lteUFixed(a, b);
    }

    /// @dev return true if UFixed a is equal to UFixed b
    function eq(UFixed a, UFixed b) public pure returns(bool isEqual) {
        return eqUFixed(a, b);
    }

    /// @dev return true if UFixed a is not zero
    function gtz(UFixed a) public pure returns(bool isZero) {
        return gtzUFixed(a);
    }

    /// @dev return true if UFixed a is zero
    function eqz(UFixed a) public pure returns(bool isZero) {
        return eqzUFixed(a);
    }

    function zero() public pure returns(UFixed) {
        return UFixed.wrap(0);
    }

    /// @dev return the absolute delta between two UFixed numbers
    function delta(UFixed a, UFixed b) public pure returns(UFixed) {
        return deltaUFixed(a, b);
    }
}
