// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../../lib/forge-std/src/Test.sol";

import {IAccess} from "../../../contracts/authorization/IAccess.sol";
import {IAccessAdmin} from "../../../contracts/authorization/IAccessAdmin.sol";
import {IInstance} from "../../../contracts/instance/IInstance.sol";
import {INftOwnable} from "../../../contracts/shared/INftOwnable.sol";

import {ComponentService} from "../../../contracts/shared/ComponentService.sol";
import {GifTest} from "../../base/GifTest.sol";
import {FeeLib} from "../../../contracts/type/Fee.sol";
import {NftId, NftIdLib} from "../../../contracts/type/NftId.sol";
import {RoleId,RoleIdLib, ADMIN_ROLE, INSTANCE_OWNER_ROLE} from "../../../contracts/type/RoleId.sol";
import {SimplePool} from "../../../contracts/examples/unpermissioned/SimplePool.sol";
import {SimpleProduct} from "../../../contracts/examples/unpermissioned/SimpleProduct.sol";
import {TimestampLib} from "../../../contracts/type/Timestamp.sol";
import {UFixedLib} from "../../../contracts/type/UFixed.sol";

contract InstanceAuthzBaseTest is GifTest {

    //--- helper functions ----------------------------------------------------//

    function _createRole(string memory roleName, RoleId adminRole, uint32 maxMemberCount) internal returns (RoleId) {
        vm.prank(instanceOwner);
        return instance.createRole(roleName, adminRole, maxMemberCount);
    }


    function _printRoles() internal {
        for(uint256 i = 0; i < instanceReader.roles(); i++) {
            RoleId roleId = instanceReader.getRoleId(i);
            IAccess.RoleInfo memory roleInfo = instanceReader.getRoleInfo(roleId);
            console.log("role", i, roleId.toInt(), roleInfo.name.toString());
        }
    }


    function _printTargets() internal {
        for(uint256 i = 0; i < instanceReader.targets(); i++) {
            address target = instanceReader.getTargetAddress(i);
            IAccess.TargetInfo memory targetInfo = instanceReader.getTargetInfo(target);
            console.log("target", i, target, targetInfo.name.toString());
        }
    }
}