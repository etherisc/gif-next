// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {UFixed, UFixedLib} from "./UFixed.sol";

type Amount is uint96;

using {
    AmountLib.eqz,
    AmountLib.gtz,
    AmountLib.toInt,
    AmountLib.add,
    AmountLib.toUFixed
} for Amount global;


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

    /// @dev return true if amount is larger than 0
    function gtz(Amount amount) public pure returns (bool) {
        return Amount.unwrap(amount) > 0;
    }

    function add(Amount a1, Amount a2) public pure returns (Amount) {
        return Amount.wrap(Amount.unwrap(a1) + Amount.unwrap(a2));
    }

    function toInt(Amount amount) public pure returns (uint256) {
        return uint256(uint96(Amount.unwrap(amount)));
    }

    function toUFixed(Amount amount) public pure returns (UFixed) {
        return UFixedLib.toUFixed(Amount.unwrap(amount));
    }

    function _max() internal pure returns (uint96) {
        // IMPORTANT: type nees to match with actual definition for Amount
        return type(uint96).max;
    }
}