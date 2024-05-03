// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {RoleId, RoleIdLib, ADMIN_ROLE, PUBLIC_ROLE, INSTANCE_SERVICE_ROLE, INSTANCE_OWNER_ROLE, INSTANCE_ROLE} from "../type/RoleId.sol";
import {TimestampLib} from "../type/Timestamp.sol";
import {NftId} from "../type/NftId.sol";

import {AccessManagerExtendedInitializeable} from "../shared/AccessManagerExtendedInitializeable.sol";

import {IRegistry} from "../registry/IRegistry.sol";

import {IInstance} from "./IInstance.sol";
import {IAccess} from "./module/IAccess.sol";

contract InstanceAdmin is
    AccessManagedUpgradeable
{
    using RoleIdLib for RoleId;

    string public constant INSTANCE_ROLE_NAME = "InstanceRole";
    string public constant INSTANCE_OWNER_ROLE_NAME = "InstanceOwnerRole";

    string public constant INSTANCE_ADMIN_TARGET_NAME = "InstanceAdmin";

    uint64 public constant CUSTOM_ROLE_ID_MIN = 10000; // MUST be even
    uint32 public constant EXECUTION_DELAY = 0;

    mapping(address target => IAccess.Type) _targetType;
    mapping(RoleId roleId => IAccess.Type) _roleType;
    uint64 _idNext;

    AccessManagerExtendedInitializeable internal _accessManager;
    IInstance _instance;
    IRegistry internal _registry;

    // instance owner role is granted upon instance nft minting in callback function
    // assume this contract is already a member of ADMIN_ROLE, the only member
    function initialize(address instanceAddress) external initializer 
    {
        IInstance instance = IInstance(instanceAddress);
        IRegistry registry = instance.getRegistry();
        address authority = instance.authority();

        __AccessManaged_init(authority);

        _accessManager = AccessManagerExtendedInitializeable(authority);
        _instance = instance;
        _registry = registry;
        _idNext = CUSTOM_ROLE_ID_MIN;

        // minimum configuration required for nft interception
        _createRole(INSTANCE_ROLE(), INSTANCE_ROLE_NAME, IAccess.Type.Core);
        _createRole(INSTANCE_OWNER_ROLE(), INSTANCE_OWNER_ROLE_NAME, IAccess.Type.Core);
        _grantRole(INSTANCE_ROLE(), address(instance));

        _createTarget(address(this), INSTANCE_ADMIN_TARGET_NAME, IAccess.Type.Core);
        bytes4[] memory instanceAdminInstanceSelectors = new bytes4[](1);
        instanceAdminInstanceSelectors[0] = this.transferInstanceOwnerRole.selector;
        _setTargetFunctionRole(address(this), instanceAdminInstanceSelectors, INSTANCE_ROLE());                
    }

    //--- Role ------------------------------------------------------//
    // ADMIN_ROLE
    // assume all core roles are known at deployment time
    // assume core roles are set and granted only during instance cloning
    // assume core roles are never revoked -> core roles admin is never active after intialization
    function createCoreRole(RoleId roleId, string memory name)
        external
        restricted()
    {
        _createRole(roleId, name, IAccess.Type.Core);
    }

    // ADMIN_ROLE
    // assume gif roles can be revoked
    // assume admin is INSTANCE_OWNER_ROLE or INSTANCE_ROLE
    function createGifRole(RoleId roleId, string memory name, RoleId admin) 
        external
        restricted()
    {
        _createRole(roleId, name, IAccess.Type.Gif);
        _setRoleAdmin(roleId, admin);
    }

    // INSTANCE_OWNER_ROLE
    // TODO specify how many owners role can have -> many roles MUST have exactly 1 member?
    function createRole(string memory roleName, string memory adminName)
        external
        restricted()
        returns(RoleId roleId, RoleId admin)
    {
        (roleId, admin) = _getNextCustomRoleId();

        _createRole(roleId, roleName, IAccess.Type.Custom);
        _createRole(admin, adminName, IAccess.Type.Custom);

        _setRoleAdmin(roleId, admin);
        _setRoleAdmin(admin, INSTANCE_OWNER_ROLE());
    }

    // ADMIN_ROLE
    // assume used by instance service only during instance cloning
    // assume used only by this.createRole(), this.createGifRole() afterwards
    function setRoleAdmin(RoleId roleId, RoleId admin) 
        public 
        restricted()
    {
        _setRoleAdmin(roleId, admin);
    }

    // INSTANCE_ROLE
    function transferInstanceOwnerRole(address from, address to) external restricted() {
        // temp pre transfer checks
        assert(_accessManager.getRoleMembers(INSTANCE_ROLE().toInt()) == 1);
        (bool hasRole, uint executionDelay) = _accessManager.hasRole(INSTANCE_ROLE().toInt(), address(_instance));
        assert(hasRole);
        assert(executionDelay == 0);
        assert(_accessManager.getRoleAdmin(INSTANCE_OWNER_ROLE().toInt()) == ADMIN_ROLE().toInt());
        if(from != address(0)) { // nft transfer
            assert(_accessManager.getRoleMembers(INSTANCE_OWNER_ROLE().toInt()) == 1);
        } else { // nft minting 
            assert(_accessManager.getRoleMembers(INSTANCE_OWNER_ROLE().toInt()) == 0);            
        }

        // transfer
        assert(from != to);
        _grantRole(INSTANCE_OWNER_ROLE(), to);
        if(from != address(0)) { // nft transfer
            _revokeRole(INSTANCE_OWNER_ROLE(), from);
        }

        // temp post transfer checks
        assert(_accessManager.getRoleMembers(INSTANCE_OWNER_ROLE().toInt()) == 1);// temp
        (hasRole, executionDelay) = _accessManager.hasRole(INSTANCE_OWNER_ROLE().toInt(), to);
        assert(hasRole);
        assert(executionDelay == 0);
    }

    function hasRole(RoleId roleId, address account) 
        external 
        view 
        returns (bool accountHasRole) 
    {
        (accountHasRole, ) = _accessManager.hasRole(roleId.toInt(), account);
    }

    //--- Target ------------------------------------------------------//
    // ADMIN_ROLE
    // assume some core targets are registred (instance) while others are not (instance accesss manager, instance reader, bundle manager)
    function createCoreTarget(address target, string memory name) external restricted() {
        _createTarget(target, name, IAccess.Type.Core);
    }
    // INSTANCE_SERVICE_ROLE
    // TODO check for instance mismatch?
    function createGifTarget(address target, string memory name) external restricted() 
    {
        if(!_registry.isRegistered(target)) {
            revert IAccess.ErrorIAccessTargetNotRegistered(target);
        }

        _createTarget(target, name, IAccess.Type.Gif);
    }
    // INSTANCE_OWNER_ROLE
    // assume custom target.authority() is constant -> target MUST not be used with different instance access manager
    // assume custom target can not be registered as component -> each service which is doing component registration MUST register a gif target
    // assume custom target can not be registered as instance or service -> why?
    // TODO check target associated with instance owner or instance or instance components or components helpers
    function createTarget(address target, string memory name) external restricted() 
    {
        _createTarget(target, name, IAccess.Type.Custom);
    }

    // TODO instance owner locks component instead of revoking it access to the instance...
    function setTargetLockedByService(address target, bool locked)
        external 
        restricted // INSTANCE_SERVICE_ROLE
    {
        _setTargetLocked(target, locked);
    }

    function setTargetLockedByInstance(address target, bool locked)
        external
        restricted // INSTANCE_ROLE
    {
        _setTargetLocked(target, locked);
    }


    // allowed combinations of roles and targets:
    //1) set core role for core target 
    //2) set gif role for gif target  
    //3) set custom role for gif target
    //4) set custom role for custom target

    // ADMIN_ROLE if used only during initialization, works with:
    //      any roles for any targets
    // INSTANCE_SERVICE_ROLE if used not only during initilization, works with:
    //      core roles for core targets
    //      gif roles for gif targets
    function setCoreTargetFunctionRole(
        string memory targetName,
        bytes4[] calldata selectors,
        RoleId roleId
    ) 
        public 
        virtual 
        restricted
    {
        address target = _accessManager.getTargetAddress(targetName);
        // not custom target
        if(_targetType[target] == IAccess.Type.Custom) {
            revert IAccess.ErrorIAccessTargetTypeInvalid(target, IAccess.Type.Custom);
        }

        // not custom role
        if(_roleType[roleId] == IAccess.Type.Custom) {
            revert IAccess.ErrorIAccessRoleTypeInvalid(roleId, IAccess.Type.Custom);
        }

        _setTargetFunctionRole(target, selectors, roleId);
    }

    // INSTANCE_OWNER_ROLE
    // gif role for gif target
    // gif role for custom target
    // custom role for gif target -> need to prohibit
    // custom role for custom target
    // TODO instance owner can mess with gif target (component) -> e.g. set custom role for function intendent to work with gif role
    function setTargetFunctionRole(
        string memory targetName,
        bytes4[] calldata selectors,
        RoleId roleId// string memory roleName
    ) 
        public 
        virtual 
        restricted() 
    {
        address target = _accessManager.getTargetAddress(targetName);

        // not core target
        if(_targetType[target] == IAccess.Type.Core) {
            revert IAccess.ErrorIAccessTargetTypeInvalid(target, IAccess.Type.Core);
        }

        // not core role
        if(_roleType[roleId] == IAccess.Type.Core) {
            revert IAccess.ErrorIAccessRoleTypeInvalid(roleId, IAccess.Type.Core);
        }

        _setTargetFunctionRole(target, selectors, roleId);
    }

    function _setTargetFunctionRole(address target, bytes4[] memory selectors, RoleId roleId) internal {
        _accessManager.setTargetFunctionRole(target, selectors, roleId.toInt());
    }

    function isTargetLocked(address target) public view returns (bool locked) {
        return _accessManager.isTargetClosed(target);
    }

    //--- Role internal view/pure functions --------------------------------------//
    function _createRole(RoleId roleId, string memory name, IAccess.Type rtype) 
        internal
    {
        _validateRole(roleId, rtype);

        _roleType[roleId] = rtype;
        _accessManager.createRole(roleId.toInt(), name);
        //emit LogRoleCreation(roleId, name, rtype);
    }

    function _validateRole(RoleId roleId, IAccess.Type rtype)
        internal
        view
    {
        uint roleIdInt = roleId.toInt();
        if(rtype == IAccess.Type.Custom && roleIdInt < CUSTOM_ROLE_ID_MIN) {
            revert IAccess.ErrorIAccessRoleIdTooSmall(roleId);
        }

        if(
            rtype != IAccess.Type.Custom && 
            roleIdInt >= CUSTOM_ROLE_ID_MIN && 
            roleIdInt != PUBLIC_ROLE().toInt()) 
        {
            revert IAccess.ErrorIAccessRoleIdTooBig(roleId);
        }
    }

    function _grantRole(RoleId roleId, address account) internal {
        _accessManager.grantRole(roleId.toInt(), account, EXECUTION_DELAY);
    }

    function _revokeRole(RoleId roleId, address member)
        internal
        returns(bool revoked)
    {
        _accessManager.revokeRole(roleId.toInt(), member);
    }

    function _setRoleAdmin(RoleId roleId, RoleId admin) internal {
        if(_roleType[roleId] == IAccess.Type.Core) {
            revert IAccess.ErrorIAccessRoleTypeInvalid(roleId, IAccess.Type.Core);
        }

        _accessManager.setRoleAdmin(roleId.toInt(), admin.toInt());
    }

    function _getNextCustomRoleId() 
        internal 
        returns(RoleId roleId, RoleId admin) 
    {
        uint64 roleIdInt = _idNext;
        uint64 adminInt = roleIdInt + 1;

        _idNext = roleIdInt + 2;

        roleId = RoleIdLib.toRoleId(roleIdInt);
        admin = RoleIdLib.toRoleId(adminInt);
    }

    //--- Target internal view/pure functions --------------------------------------//
    function _createTarget(address target, string memory name, IAccess.Type ttype) 
        internal 
    {
        _validateTarget(target, ttype);
        _targetType[target] = ttype;
        _accessManager.createTarget(target, name);
        //emit LogTargetCreation(target, name, ttype, isLocked);
    }

    function _validateTarget(address target, IAccess.Type ttype) 
        internal 
        view 
    {}

    // IMPORTANT: instance access manager MUST be of Core type -> otherwise can be locked forever
    function _setTargetLocked(address target, bool locked) internal
    {
        IAccess.Type targetType = _targetType[target];

        if(
            targetType == IAccess.Type.NotInitialized ||
            targetType == IAccess.Type.Core
        ) {
            revert IAccess.ErrorIAccessTargetTypeInvalid(target, targetType);
        }

        _accessManager.setTargetClosed(target, locked);
    }
}