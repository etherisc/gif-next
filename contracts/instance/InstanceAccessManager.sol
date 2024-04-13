// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ShortString, ShortStrings} from "@openzeppelin/contracts/utils/ShortStrings.sol";

import {RoleId, RoleIdLib, ADMIN_ROLE, PUBLIC_ROLE, INSTANCE_SERVICE_ROLE, INSTANCE_OWNER_ROLE, INSTANCE_ROLE} from "../type/RoleId.sol";
import {TimestampLib} from "../type/Timestamp.sol";
import {NftId} from "../type/NftId.sol";

import {AccessManagerUpgradeableInitializeable} from "../shared/AccessManagerUpgradeableInitializeable.sol";

import {IRegistry} from "../registry/IRegistry.sol";

import {IInstance} from "./IInstance.sol";
import {IAccess} from "./module/IAccess.sol";

contract InstanceAccessManager is
    AccessManagedUpgradeable
{
    event LogRoleCreation(RoleId roleId, ShortString name, IAccess.Type rtype);
    event LogTargetCreation(address target, ShortString name, IAccess.Type ttype, bool isLocked);

    using RoleIdLib for RoleId;

    string public constant ADMIN_ROLE_NAME = "AdminRole";
    string public constant PUBLIC_ROLE_NAME = "PublicRole";
    string public constant INSTANCE_ROLE_NAME = "InstanceRole";
    string public constant INSTANCE_OWNER_ROLE_NAME = "InstanceOwnerRole";

    uint64 public constant CUSTOM_ROLE_ID_MIN = 10000; // MUST be even
    uint32 public constant EXECUTION_DELAY = 0;

    // role specific state
    mapping(RoleId roleId => IAccess.RoleInfo info) internal _roleInfo;
    mapping(RoleId roleId => EnumerableSet.AddressSet roleMembers) internal _roleMembers; 
    mapping(ShortString name => RoleId roleId) internal _roleIdForName;
    RoleId [] internal _roleIds;
    uint64 _idNext;

    // target specific state
    mapping(address target => IAccess.TargetInfo info) internal _targetInfo;
    mapping(ShortString name => address target) internal _targetAddressForName;
    address [] internal _targets;

    AccessManagerUpgradeableInitializeable internal _accessManager;
    IRegistry internal _registry;

    modifier restrictedToRoleAdmin(RoleId roleId) {
        RoleId admin = getRoleAdmin(roleId);
        (bool inRole, uint32 executionDelay) = _accessManager.hasRole(admin.toInt(), _msgSender());
        assert(executionDelay == 0); // to be sure no delayed execution functionality is used
        if (!inRole) {
            revert IAccess.ErrorIAccessCallerIsNotRoleAdmin(_msgSender(), roleId);
        }
        _;
    }

    // instance owner is granted upon instance nft minting in callback function
    function initialize(address instanceAddress) external initializer 
    {
        IInstance instance = IInstance(instanceAddress);
        IRegistry registry = instance.getRegistry();
        address authority = instance.authority();

        __AccessManaged_init(authority);

        _accessManager = AccessManagerUpgradeableInitializeable(authority);
        _registry = registry;
        _idNext = CUSTOM_ROLE_ID_MIN;

        _createRole(ADMIN_ROLE(), ADMIN_ROLE_NAME, IAccess.Type.Core);
        _createRole(PUBLIC_ROLE(), PUBLIC_ROLE_NAME, IAccess.Type.Core);
        _createRole(INSTANCE_ROLE(), INSTANCE_ROLE_NAME, IAccess.Type.Core);
        _createRole(INSTANCE_OWNER_ROLE(), INSTANCE_OWNER_ROLE_NAME, IAccess.Type.Gif);// TODO should be of core type

        // assume `this` is already a member of ADMIN_ROLE
        EnumerableSet.add(_roleMembers[ADMIN_ROLE()], address(this));

        grantRole(INSTANCE_ROLE(), instanceAddress);
        setRoleAdmin(INSTANCE_OWNER_ROLE(), INSTANCE_ROLE());
    }

    //--- Role ------------------------------------------------------//
    // ADMIN_ROLE
    // assume all core roles are know at deployment time
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
        setRoleAdmin(roleId, admin);
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

        // TODO works without this -> why?
        setRoleAdmin(roleId, admin);
        setRoleAdmin(admin, INSTANCE_OWNER_ROLE());
    }

    // ADMIN_ROLE
    // assume used by instance service only during instance cloning
    // assume used only by this.createRole(), this.createGifRole() afterwards
    function setRoleAdmin(RoleId roleId, RoleId admin) 
        public 
        restricted()
    {
        if (!roleExists(roleId)) {
            revert IAccess.ErrorIAccessRoleIdDoesNotExist(roleId);
        }

        if(_roleInfo[roleId].rtype == IAccess.Type.Core) {
            revert IAccess.ErrorIAccessRoleTypeInvalid(roleId, IAccess.Type.Core);
        }

        if (!roleExists(admin)) {
            revert IAccess.ErrorIAccessRoleIdDoesNotExist(admin);
        }        

        _roleInfo[roleId].admin = admin;      
    }

    // TODO core role can be granted only to 1 member
    function grantRole(RoleId roleId, address member) 
        public
        restrictedToRoleAdmin(roleId) 
        returns (bool granted) 
    {
        if (!roleExists(roleId)) {
            revert IAccess.ErrorIAccessRoleIdDoesNotExist(roleId);
        }

        granted = EnumerableSet.add(_roleMembers[roleId], member);
        if(granted) {
            _accessManager.grantRole(roleId.toInt(), member, EXECUTION_DELAY);
        }    
    }

    function revokeRole(RoleId roleId, address member)
        external 
        restrictedToRoleAdmin(roleId) 
        returns (bool) 
    {
        return _revokeRole(roleId, member);
    }

    // INSTANCE_OWNER_ROLE
    // IMPORTANT: unbounded function, revoke all or revert
    // Instance owner role decides what to do in case of custom role admin bening revoked, e.g.:
    // 1) revoke custom role from ALL members
    // 2) revoke custom role admin from ALL members
    // 3) 1) + 2)
    // 4) revoke only 1 member of custom role admin
    function revokeRoleAllMembers(RoleId roleId) 
        external
        restrictedToRoleAdmin(roleId) 
        returns (bool revoked)
    {
        if (!roleExists(roleId)) {
            revert IAccess.ErrorIAccessRoleIdDoesNotExist(roleId);
        }

        uint memberCount = EnumerableSet.length(_roleMembers[roleId]);
        for(uint memberIdx = 0; memberIdx < memberCount; memberIdx++)
        {
            address member = EnumerableSet.at(_roleMembers[roleId], memberIdx);
            EnumerableSet.remove(_roleMembers[roleId], member);
            _accessManager.revokeRole(roleId.toInt(), member);
        }  
    }

    /// @dev not restricted function by intention
    /// the restriction to role members is already enforced by the call to the access manager
    function renounceRole(RoleId roleId) 
        external 
        returns (bool) 
    {
        IAccess.Type rtype = _roleInfo[roleId].rtype;
        if(rtype == IAccess.Type.Core || rtype == IAccess.Type.Gif) {
            revert IAccess.ErrorIAccessRoleTypeInvalid(roleId, rtype);
        }

        address member = msg.sender;
        // cannot use accessManger.renounce as it directly checks against msg.sender
        return _revokeRole(roleId, member);
    }

    function roleExists(RoleId roleId) public view returns (bool exists) {
        return _roleInfo[roleId].createdAt.gtz();
    }
    // TODO returns ADMIN_ROLE id for non existent roleId
    function getRoleAdmin(RoleId roleId) public view returns(RoleId admin) {
        return _roleInfo[roleId].admin;
    }

    function getRoleInfo(RoleId roleId) external view returns (IAccess.RoleInfo memory info) {
        return _roleInfo[roleId];
    }

    function roleMembers(RoleId roleId) public view returns (uint256 numberOfMembers) {
        return EnumerableSet.length(_roleMembers[roleId]);
    }

    function getRoleId(uint256 idx) external view returns (RoleId roleId) {
        return _roleIds[idx];
    }

    // TODO returns ADMIN_ROLE id for non existent name
    function getRoleIdForName(string memory name) external view returns (RoleId roleId) {
        return _roleIdForName[ShortStrings.toShortString(name)];
    }

    function roleMember(RoleId roleId, uint256 idx) external view returns (address member) {
        return EnumerableSet.at(_roleMembers[roleId], idx);
    }

    function hasRole(RoleId roleId, address account) external view returns (bool accountHasRole) {
        (accountHasRole, ) = _accessManager.hasRole(roleId.toInt(), account);
    }

    function roles() external view returns (uint256 numberOfRoles) {
        return _roleIds.length;
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
        restricted()
    {
        ShortString nameShort = ShortStrings.toShortString(targetName);
        address target = _targetAddressForName[nameShort];

        // not custom target
        if(_targetInfo[target].ttype == IAccess.Type.Custom) {
            revert IAccess.ErrorIAccessTargetTypeInvalid(target, IAccess.Type.Custom);
        }

        // not custom role
        if(_roleInfo[roleId].rtype == IAccess.Type.Custom) {
            revert IAccess.ErrorIAccessRoleTypeInvalid(roleId, IAccess.Type.Custom);
        }

        _setTargetFunctionRole(target, nameShort, selectors, roleId);
    }

    // INSTANCE_OWNER_ROLE
    // gif role for gif target
    // gif role for custom target
    // custom role for gif target
    // custom role for custom target
    // TODO instance owner can mess with gif target (component) -> e.g. set custom role for function intendent to work with gif role
    function setTargetFunctionRole(
        string memory targetName,
        bytes4[] calldata selectors,
        RoleId roleId
    ) 
        public 
        virtual 
        restricted() 
    {
        ShortString nameShort = ShortStrings.toShortString(targetName);
        address target = _targetAddressForName[nameShort];

        // not core target
        if(_targetInfo[target].ttype == IAccess.Type.Core) {
            revert IAccess.ErrorIAccessTargetTypeInvalid(target, IAccess.Type.Core);
        }

        // not core role
        if(_roleInfo[roleId].rtype == IAccess.Type.Core) {
            revert IAccess.ErrorIAccessRoleTypeInvalid(roleId, IAccess.Type.Core);
        }

        _setTargetFunctionRole(target, nameShort, selectors, roleId);
    }

    function getTargetAddress(string memory targetName) public view returns(address targetAddress) {
        ShortString nameShort = ShortStrings.toShortString(targetName);
        return _targetAddressForName[nameShort];
    }

    function isTargetLocked(address target) public view returns (bool locked) {
        return _targetInfo[target].isLocked;
    }

    function targetExists(address target) public view returns (bool exists) {
        return _targetInfo[target].createdAt.gtz();
    }

    function getTargetInfo(address target) public view returns (IAccess.TargetInfo memory) {
        return _targetInfo[target];
    }

    //--- Role internal view/pure functions --------------------------------------//
    function _createRole(RoleId roleId, string memory roleName, IAccess.Type rtype) 
        internal
    {
        ShortString name = ShortStrings.toShortString(roleName);
        _validateRole(roleId, name, rtype);

        if(roleExists(roleId)) {
            revert IAccess.ErrorIAccessRoleIdExists(roleId);
        }

        if (_roleIdForName[name].gtz()) {
            revert IAccess.ErrorIAccessRoleNameExists(roleId, _roleIdForName[name], name);
        }

        _roleInfo[roleId] = IAccess.RoleInfo(
            name,
            rtype,
            ADMIN_ROLE(),
            TimestampLib.blockTimestamp(),
            TimestampLib.blockTimestamp()
        );
        _roleIdForName[name] = roleId;
        _roleIds.push(roleId);

        emit LogRoleCreation(roleId, name, rtype);
    }

    function _validateRole(RoleId roleId, ShortString name, IAccess.Type rtype)
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

        // role name checks
        if (ShortStrings.byteLength(name) == 0) {
            revert IAccess.ErrorIAccessRoleNameEmpty(roleId);
        }
    }

    function _revokeRole(RoleId roleId, address member)
        internal
        returns(bool revoked)
    {
        if (!roleExists(roleId)) {
            revert IAccess.ErrorIAccessRoleIdDoesNotExist(roleId);
        }

        revoked = EnumerableSet.remove(_roleMembers[roleId], member);
        if(revoked) {
            _accessManager.revokeRole(roleId.toInt(), member);
        }
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
    function _createTarget(address target, string memory targetName, IAccess.Type ttype) 
        internal 
    {
        ShortString name = ShortStrings.toShortString(targetName);
        _validateTarget(target, name, ttype);

        if (_targetInfo[target].createdAt.gtz()) {
            revert IAccess.ErrorIAccessTargetExists(target, _targetInfo[target].name);
        }

        if (_targetAddressForName[name] != address(0)) {
            revert IAccess.ErrorIAccessTargetNameExists(
                target, 
                _targetAddressForName[name], 
                name);
        }

        bool isLocked = _accessManager.isTargetClosed(target);// sync with state in access manager
        _targetInfo[target] = IAccess.TargetInfo(
            name,
            ttype,
            isLocked,
            TimestampLib.blockTimestamp(),
            TimestampLib.blockTimestamp()
        );
        _targetAddressForName[name] = target;
        _targets.push(target);

        emit LogTargetCreation(target, name, ttype, isLocked); 
    }

    function _validateTarget(address target, ShortString name, IAccess.Type ttype) 
        internal 
        view 
    {
        address targetAuthority = AccessManagedUpgradeable(target).authority();
        if(targetAuthority != authority()) {
            revert IAccess.ErrorIAccessTargetAuthorityInvalid(target, targetAuthority);
        }

        if (ShortStrings.byteLength(name) == 0) {
            revert IAccess.ErrorIAccessTargetNameEmpty(target);
        }
    }

    // IMPORTANT: instance access manager MUST be of Core type -> otherwise can be locked forever
    function _setTargetLocked(address target, bool locked) internal
    {
        IAccess.Type targetType = _targetInfo[target].ttype;
        if(target == address(0) || targetType == IAccess.Type.NotInitialized) {
            revert IAccess.ErrorIAccessTargetDoesNotExist(target);
        }

        if(targetType == IAccess.Type.Core) {
            revert IAccess.ErrorIAccessTargetTypeInvalid(target, targetType);
        }

        _targetInfo[target].isLocked = locked;
        _accessManager.setTargetClosed(target, locked);
    }

    function _setTargetFunctionRole(
        address target,
        ShortString name,
        bytes4[] calldata selectors,
        RoleId roleId
    ) 
        internal
    {
        if (target == address(0)) {
            revert IAccess.ErrorIAccessTargetDoesNotExist(target);
        }

        if (!roleExists(roleId)) {
            revert IAccess.ErrorIAccessRoleIdDoesNotExist(roleId);
        }

        uint64 roleIdInt = RoleId.unwrap(roleId);
        _accessManager.setTargetFunctionRole(target, selectors, roleIdInt);
    }

    function canCall(
        address caller,
        address target,
        bytes4 selector
    ) public view virtual returns (bool immediate, uint32 delay) {
        return _accessManager.canCall(caller, target, selector);
    }
}