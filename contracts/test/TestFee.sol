// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {UFixed, UFixedLib} from "../types/UFixed.sol";
import {Fee, FeeLib} from "../types/Fee.sol";

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
        return FeeLib.toFee(UFixedLib.toUFixed(fractionalValue, exponent), fixedValue);
    }

    function getZeroFee() external pure returns(Fee memory fee) {
        return FeeLib.zeroFee();
    }

}
