// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

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
    neUFixed as !=,
    UFixedLib.gt,
    UFixedLib.gtz,
    UFixedLib.toInt,
    UFixedLib.toInt1000
} for UFixed global;

// TODO move to UFixedLib and rename to zero()
function zeroUFixed() pure returns (UFixed zero) {
    return UFixed.wrap(0);
}

function addUFixed(UFixed a, UFixed b) pure returns (UFixed) {
    return UFixed.wrap(UFixed.unwrap(a) + UFixed.unwrap(b));
}

function subUFixed(UFixed a, UFixed b) pure returns (UFixed) {
    if (a < b) {
        revert UFixedLib.UFixedLibNegativeResult();
    }
    return UFixed.wrap(UFixed.unwrap(a) - UFixed.unwrap(b));
}

function mulUFixed(UFixed a, UFixed b) pure returns (UFixed) {
    return
        UFixed.wrap(MathLib.mulDiv(UFixed.unwrap(a), UFixed.unwrap(b), 10 ** 18));
}

function divUFixed(UFixed a, UFixed b) pure returns (UFixed) {
    if (UFixed.unwrap(b) == 0) {
        revert UFixedLib.UFixedLibDivisionByZero();
    }
    
    return
        UFixed.wrap(MathLib.mulDiv(UFixed.unwrap(a), 10 ** 18, UFixed.unwrap(b)));
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

function neUFixed(UFixed a, UFixed b) pure returns (bool isEqual) {
    return UFixed.unwrap(a) != UFixed.unwrap(b);
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

/// @dev copied from https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/utils/math/Math.sol
library MathLib {

    error MathLigMulDivOverflow();

    enum Rounding {
        Down, // Toward negative infinity
        Up, // Toward infinity
        Zero // Toward zero
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv)
     * with further edits by Uniswap Labs also under MIT license.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            if (denominator <= prod1) {
                revert MathLigMulDivOverflow();
            }
            
            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
            // See https://cs.stackexchange.com/q/138556/92363.

            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
            // in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

}

library UFixedLib {
    error UFixedLibNegativeResult();
    error UFixedLibDivisionByZero();

    error UFixedLibExponentTooSmall(int8 exp);
    error UFixedLibExponentTooLarge(int8 exp);

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
        if (EXP + exp < 0) {
            revert UFixedLibExponentTooSmall(exp);
        }
        if (EXP + exp > 64) {
            revert UFixedLibExponentTooLarge(exp);
        }
        
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

    /// @dev Converts a UFixed to a uint256.
    function toInt1000(UFixed a) public pure returns (uint256) {
        return toIntWithRounding(toUFixed(1000) * a, ROUNDING_HALF_UP());
    }

    /// @dev Converts a UFixed to a uint256 with given rounding mode.
    function toIntWithRounding(UFixed a, uint8 rounding) public pure returns (uint256) {
        if (rounding == ROUNDING_HALF_UP()) {
            return
                MathLib.mulDiv(
                    UFixed.unwrap(a) + MULTIPLIER_HALF,
                    1,
                    MULTIPLIER,
                    MathLib.Rounding.Down
                );
        } else if (rounding == ROUNDING_DOWN()) {
            return
                MathLib.mulDiv(
                    UFixed.unwrap(a),
                    1,
                    MULTIPLIER,
                    MathLib.Rounding.Down
                );
        } else {
            return
                MathLib.mulDiv(UFixed.unwrap(a), 1, MULTIPLIER, MathLib.Rounding.Up);
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

    function one() public pure returns (UFixed) {
        return UFixed.wrap(MULTIPLIER);
    }

    /// @dev return the absolute delta between two UFixed numbers
    function delta(UFixed a, UFixed b) public pure returns (UFixed) {
        return deltaUFixed(a, b);
    }
}
