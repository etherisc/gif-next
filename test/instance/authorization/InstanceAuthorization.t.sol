// SPDX-License-Identifier: APACHE-2.0
pragma solidity ^0.8.20;

import {Test, console} from "../../../lib/forge-std/src/Test.sol";

import {InstanceAuthorizationV3} from "../../../contracts/instance/InstanceAuthorizationV3.sol";


contract InstanceAuthorizationV3Instance is Test {

    InstanceAuthorizationV3 public instAuthz;

    function setUp() public {
        instAuthz = new InstanceAuthorizationV3();
    }

    function test_instanceAuthorizationSetup() public {
        assertTrue(address(instAuthz) != address(0), "instAuthz not set");

        // solhint-disable
        console.log("main target name:", instAuthz.getMainTargetName());
        console.log("main target name (via target):", instAuthz.getMainTarget().toString());
        console.log("main target role:", instAuthz.getTargetRole(instAuthz.getMainTarget()).toInt());
        // solhint-enable

        assertEq(instAuthz.getMainTargetName(), "Instance", "unexpected main target name");
        assertEq(instAuthz.getMainTarget().toString(), "Instance", "unexpected main target");
        // see AccessAdminLib.INSTANCE_ROLE_MIN
        assertEq(instAuthz.getTargetRole(instAuthz.getMainTarget()).toInt(), 100000, "unexpected main target role");
    }
}
