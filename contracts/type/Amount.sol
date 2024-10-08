// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {UFixed, UFixedLib} from "./UFixed.sol";

/// @dev Targets: 100 trillion (worlds GDP) with 6 decimal places
/// 3 trillion USD (total crypto market cap) with 12 decimal places.
/// 2023 100 trillion USD => 100e12 * 1e6 = 1e20
/// 2024 2 trillion crypto market cap => 2e12 * 1e18 = 2e30
type Amount is uint96;

using {
    addAmount as +,
    subAmount as -,
    eqAmount as ==,
    nqAmount as !=,
    ltAmount as <,
    ltAmount as <=,
    gtAmount as >,
    gteAmount as >=,
    AmountLib.add,
    AmountLib.eq,
    AmountLib.eqz,
    AmountLib.gtz,
    AmountLib.gt,
    AmountLib.gte,
    AmountLib.multiplyWith,
    AmountLib.toInt,
    AmountLib.toUFixed
} for Amount global;

function addAmount(Amount a, Amount b) pure returns (Amount) {
    return AmountLib.add(a, b);
}

function subAmount(Amount a, Amount b) pure returns (Amount) {
    return AmountLib.sub(a, b);
}

function eqAmount(Amount a, Amount b) pure returns (bool) {
    return AmountLib.eq(a, b);
}

function nqAmount(Amount a, Amount b) pure returns (bool) {
    return !AmountLib.eq(a, b);
}

function ltAmount(Amount a, Amount b) pure returns (bool) {
    return AmountLib.lt(a, b);
}

function lteAmount(Amount a, Amount b) pure returns (bool) {
    return AmountLib.lte(a, b);
}

function gtAmount(Amount a, Amount b) pure returns (bool) {
    return AmountLib.gt(a, b);
}

function gteAmount(Amount a, Amount b) pure returns (bool) {
    return AmountLib.gte(a, b);
}

library AmountLib {

    error ErrorAmountLibValueTooBig(uint256 amount);

    function zero() public pure returns (Amount) {
        return Amount.wrap(0);
    }

    function max() public pure returns (Amount) {
        return Amount.wrap(_max());
    }

    /// @dev converts the uint amount into Amount
    /// function reverts if value is exceeding max Amount value
    function toAmount(uint256 amount) public pure returns (Amount) {
        if(amount > _max()) {
            revert ErrorAmountLibValueTooBig(amount);
        }

        return Amount.wrap(uint96(amount));
    }

    /// @dev return true if amount equals 0
    function eqz(Amount amount) public pure returns (bool) {
        return Amount.unwrap(amount) == 0;
    }

    /// @dev return true if amount1 equals amount2
    function eq(Amount amount1, Amount amount2) public pure returns (bool) {
        return Amount.unwrap(amount1) == Amount.unwrap(amount2);
    }

    /// @dev return true if amount a1 is less than a2
    function lt(Amount a1, Amount a2) public pure returns (bool) {
        return Amount.unwrap(a1) < Amount.unwrap(a2);
    }

    /// @dev return true if amount a1 is less or equal than a2
    function lte(Amount a1, Amount a2) public pure returns (bool) {
        return Amount.unwrap(a1) <= Amount.unwrap(a2);
    }

    /// @dev return true if amount a1 is greater than a2
    function gt(Amount a1, Amount a2) public pure returns (bool) {
        return Amount.unwrap(a1) > Amount.unwrap(a2);
    }

    /// @dev return true if amount a1 is greater or equal than a2
    function gte(Amount a1, Amount a2) public pure returns (bool) {
        return Amount.unwrap(a1) >= Amount.unwrap(a2);
    }

    /// @dev return minimum of a1 and a2.
    function min(Amount a1, Amount a2) public pure returns (Amount) {
        if (Amount.unwrap(a1) < Amount.unwrap(a2)) {
            return a1;
        }

        return a2;
    }

    /// @dev return true if amount is larger than 0
    function gtz(Amount amount) public pure returns (bool) {
        return Amount.unwrap(amount) > 0;
    }

    function add(Amount a1, Amount a2) public pure returns (Amount) {
        return Amount.wrap(Amount.unwrap(a1) + Amount.unwrap(a2));
    }

    function sub(Amount a1, Amount a2) public pure returns (Amount) {
        return Amount.wrap(Amount.unwrap(a1) - Amount.unwrap(a2));
    }

    function toInt(Amount amount) public pure returns (uint256) {
        return uint256(uint96(Amount.unwrap(amount)));
    }

    function toUFixed(Amount amount) public pure returns (UFixed) {
        return UFixedLib.toUFixed(Amount.unwrap(amount));
    }

    function multiplyWith(Amount amount, UFixed factor) public pure returns (Amount) {
        return toAmount((factor * UFixedLib.toUFixed(Amount.unwrap(amount))).toInt());
    }

    function _max() internal pure returns (uint96) {
        // IMPORTANT: type nees to match with actual definition for Amount
        return type(uint96).max;
    }
}