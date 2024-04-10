// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Amount, AmountLib} from "./Amount.sol";
import {UFixed, UFixedLib} from "./UFixed.sol";

struct Fee {
    UFixed fractionalFee;
    uint256 fixedFee;
}

library FeeLib {

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
            feeAmount = AmountLib.toAmount(fractionalAmount.toInt() + fee.fixedFee);
            netAmount = netAmount - feeAmount;
        }
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

    // TODO rename to zero
    /// @dev Return a zero fee struct (0, 0)
    function zeroFee() public pure returns (Fee memory fee) {
        return Fee(UFixed.wrap(0), 0);
    }

    // pure free functions for operators
    function feeIsSame(Fee memory a, Fee memory b) public pure returns (bool isSame) {
        return a.fixedFee == b.fixedFee && a.fractionalFee == b.fractionalFee;
    }

    function gtz(Fee memory fee) public pure returns (bool) {
        return UFixed.unwrap(fee.fractionalFee) > 0 || fee.fixedFee > 0;
    }

    function eqz(Fee memory fee) public pure returns (bool) {
        return fee.fixedFee == 0 && UFixed.unwrap(fee.fractionalFee) == 0;
    }
}