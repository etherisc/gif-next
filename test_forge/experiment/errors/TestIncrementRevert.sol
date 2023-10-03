// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {IIncrementRevert,IncrementRevert} from "../../../contracts/experiment/errors/IncrementRevert.sol";
import {Test} from "../../../lib/forge-std/src/Test.sol";

contract TestIncrementRevert is Test {
    IncrementRevert public inc;

    function setUp() public {
        inc = new IncrementRevert(5);
    }

    // solhint-disable-next-line func-name-mixedcase
    function testIncrement() public {
        inc.increment();
        inc.increment();
        inc.increment();
        inc.increment();
        vm.expectRevert(IIncrementRevert.ErrorMaximumValueExceed.selector);
        inc.increment();
    }

    // solhint-disable-next-line func-name-mixedcase
    function testIncrement2() public {
        vm.expectRevert(abi.encodeWithSelector(IIncrementRevert.ErrorIncrementTooLarge.selector, 10));
        inc.increment(10);
        
        inc.increment(2);
        inc.increment(2);
        vm.expectRevert(IIncrementRevert.ErrorMaximumValueExceed.selector);
        inc.increment(2);
    }

}
