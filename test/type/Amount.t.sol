// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {Amount, AmountLib} from "../../contracts/type/Amount.sol";
import {UFixed, UFixedLib} from "../../contracts/type/Amount.sol";

contract AmountTest is Test {

    function test_amountToIntHappyCase() public {
        uint96 amount = 1691321541;
        assertEq(AmountLib.toAmount(amount).toInt(), amount, "unexpected amount");
    }

    function test_amountToUFixedHappyCase() public {
        uint256 amountInt = 1691321541;
        UFixed amountUFixedIn = UFixedLib.toUFixed(amountInt);
        Amount amount = AmountLib.toAmount(amountUFixedIn.toInt());
        assertEq(amount.toInt(), amountInt, "unexpected amount");

        UFixed amountUFixedOut = amount.toUFixed();
        assertEq(amountUFixedIn.toInt(), amountUFixedOut.toInt(), "non-matching UFixed values");
        assertTrue(amountUFixedIn == amountUFixedOut, "UFixed in and out not '=='");
    }

    function test_amountZero() public {
        assertEq(AmountLib.zero().toInt(), 0, "zero not 0");
        assertTrue(AmountLib.zero().eqz(), "zero not eqz");
    }

    function test_amountMax() public {
        uint96 amountMax = uint96(AmountLib.max().toInt());
        assertEq(amountMax, type(uint96).max, "unexpected max value");
        assertEq(AmountLib.toAmount(amountMax).toInt(), amountMax, "unexpected amount");
        assertTrue(AmountLib.max().gtz(), "max not gtz");
    }

    function test_amountEqz() public {
        assertTrue(AmountLib.toAmount(0).eqz(), "0 not zero");
        assertFalse(AmountLib.toAmount(1).eqz(), "1 is zero");
    }

    function test_amountGtz() public {
        assertTrue(AmountLib.toAmount(1).gtz(), "1 == zero");
        assertFalse(AmountLib.toAmount(0).gtz(), "0 > zero");
    }

    function test_amountToIntDurationTooBig() public {
        uint256 amount = AmountLib.max().toInt() + 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                AmountLib.ErrorAmountLibValueTooBig.selector,
                amount));

        AmountLib.toAmount(amount);
    }

    function test_amountUnderflow() public {
        Amount a = AmountLib.toAmount(1);
        Amount b = AmountLib.toAmount(2);

        // "panic: arithmetic underflow or overflow (0x11)"
        vm.expectRevert();
        Amount c = a - b;
    }

    function test_amountOverflow() public {
        Amount a = AmountLib.max();
        Amount b = AmountLib.toAmount(1);

        // "panic: arithmetic underflow or overflow (0x11)"
        vm.expectRevert();
        Amount c = a + b;
    }
}
