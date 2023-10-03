// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {IRevert,Revert} from "../../../contracts/experiment/errors/Revert.sol";
import {Test} from "../../../lib/forge-std/src/Test.sol";

contract TestRevert is Test {
    Revert public rev;

    function setUp() public {
        rev = new Revert();
    }

    // solhint-disable-next-line func-name-mixedcase
    function testIsAlargerThanBRevert_S() public {
        rev.isAlargerThanBRevert_S(50);

        vm.expectRevert(IRevert.Error001AsmallerThanB_S.selector);
        rev.isAlargerThanBRevert_S(10);
    }

    // solhint-disable-next-line func-name-mixedcase
    function testIsAlargerThanBRevert_M() public {
        rev.isAlargerThanBRevert_M(50);

        vm.expectRevert(abi.encodeWithSelector(IRevert.Error002AsmallerThanB_M.selector, 10));
        rev.isAlargerThanBRevert_M(10);

        expectError(IRevert.Error002AsmallerThanB_M.selector, 0);
        rev.isAlargerThanBRevert_M(0);
    }

    function expectError(bytes4 selector, uint arg1) internal {
        vm.expectRevert(abi.encodeWithSelector(selector, arg1));
    }

}
