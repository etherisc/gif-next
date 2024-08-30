// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "./Amount.sol";
import {UFixed, UFixedLib} from "./UFixed.sol";

struct Fee {
    UFixed fractionalFee;
    Amount fixedFee;
}

library FeeLib {

    /// @dev Return a zero fee struct (0, 0)
    function zero() public pure returns (Fee memory fee) {
        return Fee(UFixed.wrap(0), AmountLib.zero());
    }

    /// @dev Converts the uint256 to a fee struct.
    function toFee(
        UFixed fractionalFee,
        uint256 fixedFee
    ) public pure returns (Fee memory fee) {
        return Fee(fractionalFee, AmountLib.toAmount(fixedFee));
    }

    /// @dev Calculates fee and net amounts for the provided parameters
    function calculateFee(
        Fee memory fee,
        Amount amount
    )
        public
        pure
        returns (
            Amount feeAmount, 
            Amount netAmount
        )
    {
        netAmount = amount;
        if(gtz(fee)) {
            UFixed fractionalAmount = 
                amount.toUFixed() * fee.fractionalFee;
            feeAmount = AmountLib.toAmount(fractionalAmount.toInt()) + fee.fixedFee;
            netAmount = netAmount - feeAmount;
        }
    }

    /// @dev Return the percent fee struct (x%, 0)
    function percentageFee(uint8 percent) public pure returns (Fee memory fee) {
        return Fee(UFixedLib.toUFixed(percent, -2), AmountLib.zero());
    }

    // pure free functions for operators
    function eq(Fee memory a, Fee memory b) public pure returns (bool isSame) {
        return a.fixedFee == b.fixedFee && a.fractionalFee == b.fractionalFee;
    }

    function gtz(Fee memory fee) public pure returns (bool) {
        return UFixed.unwrap(fee.fractionalFee) > 0 || fee.fixedFee.gtz();
    }

    function eqz(Fee memory fee) public pure returns (bool) {
        return fee.fixedFee.eqz() && UFixed.unwrap(fee.fractionalFee) == 0;
    }
}