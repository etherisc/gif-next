// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {UFixed, UFixedMathLib} from "../types/UFixed.sol";
import {Fee, toFee, zeroFee} from "../types/Fee.sol";

contract TestFee {

    function createFee(
        uint256 fractionalValue,
        int8 exponent,
        uint256 fixedValue
    )
        external 
        pure 
        returns(Fee memory fee)
    {
        return toFee(UFixedMathLib.toUFixed(fractionalValue, exponent), fixedValue);
    }

    function getZeroFee() external pure returns(Fee memory fee) {
        return zeroFee();
    }

}
