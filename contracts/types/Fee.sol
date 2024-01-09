// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {UFixed, UFixedLib} from "./UFixed.sol";

struct Fee {
    UFixed fractionalFee;
    uint256 fixedFee;
}

library FeeLib {

    function calculateFee(
        Fee memory fee,
        uint256 amount
    )
        public
        pure
        returns (
            uint256 feeAmount, 
            uint256 netAmount
        )
    {
        UFixed fractionalAmount = UFixedLib.toUFixed(amount) *
            fee.fractionalFee;
        feeAmount = fractionalAmount.toInt() + fee.fixedFee;
        netAmount = amount - feeAmount;
    }

    /// @dev Converts the uint256 to a fee struct.
    function toFee(
        UFixed fractionalFee,
        uint256 fixedFee
    ) public pure returns (Fee memory fee) {
        return Fee(fractionalFee, fixedFee);
    }

    /// @dev Return the percent fee struct (x%, 0)
    function percentageFee(uint8 percent) public pure returns (Fee memory fee) {
        return Fee(UFixedLib.toUFixed(percent, -2), 0);
    }

    /// @dev Return a zero fee struct (0, 0)
    function zeroFee() public pure returns (Fee memory fee) {
        return Fee(UFixed.wrap(0), 0);
    }

    // pure free functions for operators
    function feeIsSame(Fee memory a, Fee memory b) public pure returns (bool isSame) {
        return a.fixedFee == b.fixedFee && a.fractionalFee == b.fractionalFee;
    }

    function feeIsZero(Fee memory fee) public pure returns (bool) {
        return fee.fixedFee == 0 && UFixed.unwrap(fee.fractionalFee) == 0;
    }
}