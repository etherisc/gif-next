// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessAdmin} from "../authorization/AccessAdmin.sol";
import {IAccessAdmin} from "../authorization/IAccessAdmin.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IInstance} from "./IInstance.sol";
import {IService} from "../shared/IService.sol";
import {ObjectType, ObjectTypeLib, ALL, POOL, RELEASE} from "../type/ObjectType.sol";
import {RoleId, RoleIdLib, ADMIN_ROLE, PUBLIC_ROLE, INSTANCE_ROLE} from "../type/RoleId.sol";
import {VersionPart} from "../type/Version.sol";


contract InstanceAdminNew is
    AccessAdmin
{
    string public constant INSTANCE_ROLE_NAME = "InstanceRole";
    string public constant INSTANCE_OWNER_ROLE_NAME = "InstanceOwnerRole";

    string public constant INSTANCE_ADMIN_TARGET_NAME = "InstanceAdmin";
    string public constant INSTANCE_STORE_TARGET_NAME = "InstanceStore";
    string public constant INSTANCE_TARGET_NAME = "Instance";

    uint64 public constant CUSTOM_ROLE_ID_MIN = 10000; // MUST be even

    address _instance;
    IRegistry internal _registry;
    uint64 _idNext;

    bool private _setupCompleted;


    // instance owner role is granted upon instance nft minting in callback function
    function initialize(address instanceAddress)
        external
        initializer() 
    {
        _instance = instanceAddress;
        IInstance instance = IInstance(instanceAddress);

        _initializeAuthority(
            instance.authority());

        _registry = instance.getRegistry();
        _idNext = CUSTOM_ROLE_ID_MIN;

        _createInitialRoleSetup();
        _setupInstanceAdmin();
        _setupInstance();
    }


    function _setupInstanceAdmin()
        internal
    {
        // _createTarget(address(this), INSTANCE_ADMIN_TARGET_NAME, IAccess.Type.Core);
    }


    function _setupInstance()
        internal
    {
        // _createTarget(_instance, INSTANCE_TARGET_NAME, IAccess.Type.Core);

        // minimum configuration required for nft interception
        // _createRole(INSTANCE_ROLE(), INSTANCE_ROLE_NAME, IAccess.Type.Core);
        // _createRole(INSTANCE_OWNER_ROLE(), INSTANCE_OWNER_ROLE_NAME, IAccess.Type.Core);
        // _grantRole(INSTANCE_ROLE(), _instance);

        // bytes4[] memory instanceAdminInstanceSelectors = new bytes4[](1);
        // instanceAdminInstanceSelectors[0] = this.transferInstanceOwnerRole.selector;
        // _setTargetFunctionRole(address(this), instanceAdminInstanceSelectors, INSTANCE_ROLE());                
    }
}
