// SPDX-License-Identifier: APACHE-2.0
pragma solidity ^0.8.20;

// TODO cleanup imports
// import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {Test, console} from "../../../lib/forge-std/src/Test.sol";

import {InstanceAuthorizationV3} from "../../../contracts/instance/InstanceAuthorizationV3.sol";

// import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
// import {Fee, FeeLib} from "../../../contracts/type/Fee.sol";
// import {GifTest} from "../../base/GifTest.sol";
// import {InstanceAdmin} from "../../../contracts/instance/InstanceAdmin.sol";
// import {InstanceReader} from "../../../contracts/instance/InstanceReader.sol";
// import {NftId} from "../../../contracts/type/NftId.sol";
// import {UFixed, UFixedLib} from "../../../contracts/type/UFixed.sol";

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
        assertEq(instAuthz.getTargetRole(instAuthz.getMainTarget()).toInt(), 10, "unexpected main target role");
    }
}
