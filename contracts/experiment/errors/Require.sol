// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

contract Require {

    error AsmallerThanB_S();
    error AsmallerThanB_M(uint a);
    error AsmallerThanB_L(uint a, uint b);

    uint256 private _b;

    constructor() {
        _b = 42;
    }

    function isAlargerThanBRequire_S(uint a) external view returns(bool isLarger) {
        require(a > _b, "ERROR:ABC-001");

        return true;
    }

    function isAlargerThanBRequire_M(uint a) external view returns(bool isLarger) {
        require(a > _b, "ERROR:ABC-002:A_IS_SMALLER");

        return true;
    }

    function isAlargerThanBRequire_L(uint a) external view returns(bool isLarger) {
        require(a > _b, "ERROR:ABC-003:A_IS_SMALLER_THAN_B");

        return true;
    }
}