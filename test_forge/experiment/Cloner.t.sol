// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {Cloner, Mock1, Mock2} from "../../contracts/experiment/cloning/Cloner.sol";

contract ClonerTest is Test {
    Cloner public cloner;

    function setUp() public {
        cloner = new Cloner();
    }

    function test_clonerSetUp() public {
        console.log("cloner", address(cloner));
        console.log("mock1", address(cloner.mock1()));
        console.log("mock2", address(cloner.mock2()));
        console.log("mock1.getValue()", cloner.mock1().getValue());
        console.log("mock2.getValue()", cloner.mock2().getValue());

        assertEq(cloner.mock1().getValue(), 42, "unexpected cloner.mock1().getValue()");
        assertEq(cloner.mock2().getValue(), 42, "unexpected cloner.mock2().getValue()");
    }

    function test_clonerClonedMock1() public {
        address clonedAddress = cloner.createClone(address(cloner.mock1()));
        Mock1 clonedMock = Mock1(clonedAddress);

        assertTrue(clonedAddress != address(0), "cloned mock1 address zero");
        assertTrue(clonedAddress != address(cloner.mock1()), "cloned mock1 address same as mock1");
        assertEq(clonedMock.getValue(), cloner.mock1().getValue(), "unexpected getValue() for cloned mock1");
    }

    function test_clonerClonedMock2() public {
        address clonedAddress = cloner.createClone(address(cloner.mock2()));
        Mock2 clonedMock = Mock2(clonedAddress);

        assertTrue(clonedAddress != address(0), "cloned mock2 address zero");
        assertTrue(clonedAddress != address(cloner.mock2()), "cloned mock2 address same as mock2");
        assertEq(clonedMock.getValue(), 0, "unexpected getValue() for uninitialized cloned mock2");

        clonedMock.setValue(cloner.mock2().getValue());
        assertEq(clonedMock.getValue(), cloner.mock2().getValue(), "unexpected getValue() for cloned mock1");
    }
}
