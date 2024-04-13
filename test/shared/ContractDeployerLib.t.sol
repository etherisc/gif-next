// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "../../lib/forge-std/src/Test.sol";

import {ContractDeployerLib} from "./ContractDeployerLib.sol";

contract FooWithConstructor {

    string public message;
    uint256 public value;

    constructor(
        string memory initialMessage,
        uint256 initialValue
    )
    {
        message = initialMessage;
        value = initialValue;
    }

    function setValue(uint256 newValue) external { value = newValue; }

    function getValue() external view returns (uint256) { return value; }

    function getMessage() external view returns (string memory) { return message; }

}

contract ContractDeployerLibTest is Test {

    string public constant INITIAL_MESSAGE = "Hi from test!";
    uint256 public constant INITIAL_VALUE = 42;

    bytes public byteCodeWithInitCode;
    bytes public encodedConstructorArguments;
    bytes public creationCode;
    bytes32 public creationCodeHash;

    FooWithConstructor public foo;
    address public fooAddress;

    function test_DeployFooHappyCase() public {

        // solhint-disable no-console
        console.log("byteCodeWithInitCode.length (a)", byteCodeWithInitCode.length);
        console.log("encodedConstructorArguments.length (b)", encodedConstructorArguments.length);
        console.log("creationCode.length (c)", creationCode.length);
        console.log("(a) + (b)", byteCodeWithInitCode.length + encodedConstructorArguments.length);
        // solhint-enable

        // check initial setup
        assertTrue(byteCodeWithInitCode.length > 0, "zero length byte code");
        assertTrue(encodedConstructorArguments.length > 0, "zero length encoded constructor arguments");
        assertTrue(creationCode.length > 0, "zero length creation code");

        assertTrue(creationCode.length > byteCodeWithInitCode.length, "creation code code shorter than byte code");
        assertTrue(creationCode.length > encodedConstructorArguments.length, "creation code code shorter than constructor arguments");
        assertEq(creationCode.length, byteCodeWithInitCode.length + encodedConstructorArguments.length, "creation code not sum of init code, byte code and constructor arguments");

        assertTrue(fooAddress != address(0), "foo address zero");
        assertEq(foo.getValue(), INITIAL_VALUE, "unexpected foo value");
        assertEq(foo.getMessage(), INITIAL_MESSAGE, "unexpected foo message");

        // modify value
        foo.setValue(INITIAL_VALUE + 1);

        // check updated value
        assertEq(foo.getValue(), INITIAL_VALUE + 1, "unexpected foo value after update");
    }

    function setUp() public {

        byteCodeWithInitCode = type(FooWithConstructor).creationCode;
        encodedConstructorArguments = abi.encode(
            INITIAL_MESSAGE,
            INITIAL_VALUE);

        creationCode = ContractDeployerLib.getCreationCode(
            byteCodeWithInitCode, 
            encodedConstructorArguments);

        creationCodeHash = ContractDeployerLib.getHash(creationCode);

        fooAddress = ContractDeployerLib.deploy(
            creationCode,
            creationCodeHash);

        foo = FooWithConstructor(fooAddress);
    }
}