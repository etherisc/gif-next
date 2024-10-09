// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Test, console} from "../../lib/forge-std/src/Test.sol";

import {AccessManagerCloneable} from "../../contracts/authorization/AccessManagerCloneable.sol";
import {ContractLib} from "../../contracts/shared/ContractLib.sol";
import {VersionPart, VersionPartLib} from "../../contracts/type/Version.sol";


contract AccessManagerCloneableTest is Test {

    address public admin = makeAddr("accessManagerAdmin");
    AccessManagerCloneable public accessManager;

    function setUp() public virtual {
        VersionPart release = VersionPartLib.toVersionPart(3);
        accessManager = new AccessManagerCloneable();
        accessManager.initialize(admin, release);
    }


    function test_addressManagerCloneableSetUp() public {
        assertTrue(ContractLib.isAuthority(address(accessManager)), "unexpected authority");
        assertEq(accessManager.getRelease().toInt(), 3, "unexpected release");
    }
}
