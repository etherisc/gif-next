// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccessManaged} from "../../lib/openzeppelin-contracts/contracts/access/manager/IAccessManaged.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";


import {AccessManagerCloneable} from "../../contracts/authorization/AccessManagerCloneable.sol";
import {AccessManagedMock} from "../mock/AccessManagedMock.sol";
import {ContractLib} from "../../contracts/shared/ContractLib.sol";
import {RegistryAdmin} from "../../contracts/registry/RegistryAdmin.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {VersionPart, VersionPartLib} from "../../contracts/type/Version.sol";

contract AccessManagerCloneableTesting is AccessManagerCloneable {
    function setRelase(VersionPart release) public {
        _checkAndSetRelease(release);
    }
}

contract AccessManagerCloneableTest is Test {

    address public admin = makeAddr("accessManagerAdmin");
    AccessManagerCloneableTesting public accessManager;

    function setUp() public virtual {
        accessManager = new AccessManagerCloneableTesting();
        accessManager.initialize(admin);
        accessManager.setRelase(VersionPartLib.toVersionPart(3));
    }


    function test_addressManagerCloneableSetUp() public {
        assertTrue(ContractLib.isAuthority(address(accessManager)), "unexpected authority");
        assertEq(accessManager.getRelease().toInt(), 3, "unexpected release");
    }
}
