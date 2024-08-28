// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../../lib/forge-std/src/Test.sol";

import {AccessManagedMock} from "../../mock/AccessManagedMock.sol";
import {IAccess} from "../../../contracts/authorization/IAccess.sol";
import {IAccessAdmin} from "../../../contracts/authorization/IAccessAdmin.sol";
import {IInstance} from "../../../contracts/instance/IInstance.sol";
import {INftOwnable} from "../../../contracts/shared/INftOwnable.sol";

import {InstanceAuthzBaseTest} from "./InstanceAuthzBase.t.sol";
import {RoleId, RoleIdLib, ADMIN_ROLE, INSTANCE_OWNER_ROLE} from "../../../contracts/type/RoleId.sol";
import {TimestampLib} from "../../../contracts/type/Timestamp.sol";


contract InstanceAuthzTargetsTest is InstanceAuthzBaseTest {

    function test_instanceAuthzTargetsSetup() public {
        _printRoles();
        _printTargets();

        // check initial roles
        assertEq(instanceAdmin.targets(), 16, "unexpected initial instance target count (admin)");
        assertEq(instanceReader.targets(), 16, "unexpected initial instance target count (reader)");
    }


    function test_instanceAuthzTargetsCreateNoRoleHappyCase() public {
        // GIVEN
        AccessManagedMock target = _deployAccessManagedMock();
        RoleId zeroRoleId = RoleIdLib.zero();
        string memory targetName = "MyTarget";
        uint256 initialTargetCount = instanceAdmin.targets();

        // WHEN + THEN
        vm.expectEmit(address(instance));
        emit IInstance.LogInstanceCustomTargetCreated(address(target), zeroRoleId, targetName);

        vm.prank(instanceOwner);
        instance.createTarget(address(target), zeroRoleId, targetName);

        // THEN
        assertTrue(instanceReader.targetExists(address(target)), "target not existing after create");
        assertEq(instanceAdmin.targets(), initialTargetCount + 1, "unexpected target count after create (admin)");
        assertEq(instanceReader.targets(), initialTargetCount + 1, "unexpected target count after create (reader)");

        IAccess.TargetInfo memory targetInfo = instanceReader.getTargetInfo(address(target));
        assertEq(targetInfo.name.toString(), "MyTarget", "unexpected target name");
        assertTrue(targetInfo.isCustom, "target type not custom");
        assertEq(targetInfo.createdAt.toInt(), TimestampLib.blockTimestamp().toInt(), "unexpected target creation time");
    }


    function test_instanceAuthzTargetsCreateWithRoleHappyCase() public {
    }   


    function test_instanceAuthzTargetsSetTargetLockedHappyCase() public {
    }

    //--- helper functions ----------------------------------------------------//

    function _deployAccessManagedMock() internal returns (AccessManagedMock accessManagedMock) {
        return _deployAccessManagedMock(instance.authority());
    }

    function _deployAccessManagedMock(address authority) internal returns (AccessManagedMock accessManagedMock) {
        accessManagedMock = new AccessManagedMock(instance.authority());
    }
}