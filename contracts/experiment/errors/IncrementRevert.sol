// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IIncrementRevert {
    error ErrorMaximumValueExceed();
    error ErrorIncrementTooLarge(uint256 value);
}

contract IncrementRevert is IIncrementRevert {
    uint256 private _limit;
    uint256 private _value;

    constructor(uint256 limit) {
        _limit = limit;
        _value = 0;
    }

    function getValue() external view returns (uint256) {
        return _value;
    }

    function increment() external returns (uint256) {
        if (_value + 1 >= _limit) {
            revert ErrorMaximumValueExceed();
        }
        _value += 1;
        return _value;
    }

    function increment(uint256 inc) external returns (uint256) {
        if (inc > 9) {
            revert ErrorIncrementTooLarge(inc);
        }

        if (_value + inc >= _limit) {
            revert ErrorMaximumValueExceed();
        }

        _value += inc;
        return _value;
    }

}
