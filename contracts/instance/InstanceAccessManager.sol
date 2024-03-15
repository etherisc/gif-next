// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ShortString, ShortStrings} from "@openzeppelin/contracts/utils/ShortStrings.sol";

import {RoleId, RoleIdLib, ADMIN_ROLE, PUBLIC_ROLE, INSTANCE_SERVICE_ROLE, INSTANCE_OWNER_ROLE} from "../types/RoleId.sol";
import {TimestampLib} from "../types/Timestamp.sol";
import {NftId} from "../types/NftId.sol";

import {AccessManagerUpgradeableInitializeable} from "./AccessManagerUpgradeableInitializeable.sol";

import {IAccess} from "./module/IAccess.sol";
import {IRegistry} from "../registry/IRegistry.sol";

contract InstanceAccessManager is
    AccessManagedUpgradeable
{
    using RoleIdLib for RoleId;

    string public constant ADMIN_ROLE_NAME = "AdminRole";
    string public constant PUBLIC_ROLE_NAME = "PublicRole";

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

    function initialize(address ozAccessManager, address registry) external initializer 
    {
        require(ozAccessManager != address(0));
        require(registry != address(0));

        __AccessManaged_init(ozAccessManager);

        _accessManager = AccessManagerUpgradeableInitializeable(ozAccessManager);
        _registry = IRegistry(registry);
        _idNext = CUSTOM_ROLE_ID_MIN;

        _createRole(ADMIN_ROLE(), ADMIN_ROLE_NAME, IAccess.Type.Core);
        _createRole(PUBLIC_ROLE(), PUBLIC_ROLE_NAME, IAccess.Type.Core);

        // assume `this` is already a member of ADMIN_ROLE
        // assume msg.sender is instance service which is also member of ADMIN_ROLE
        // assume instance service will renounce ADMIN_ROLE through ozAccessManager and should not be added to _roleMembers here
        EnumerableSet.add(_roleMembers[ADMIN_ROLE()], address(this));
        //EnumerableSet.add(_roleMembers[ADMIN_ROLE()], initialAdmin);
    }

    //--- Role ------------------------------------------------------//
    // assume all core roles are know at deployment time
    // assume core roles are set and granted only during instance cloning
    // assume core roles are never revoked or renounced -> core roles admin is never active after intialization
    function createCoreRole(RoleId roleId, string memory name)
        external
        restricted()
    {
        _createRole(roleId, name, IAccess.Type.Core);
    }
    // INSTANCE_SERVICE_ROLE
    // assume gif roles can be revoked or renounced
    // TODO who can be admin of gif role?
    function createGifRole(RoleId roleId, string memory name, RoleId admin) 
        external
        restricted()
    {
        _createRole(roleId, name, IAccess.Type.Gif);
        setRoleAdmin(roleId, admin);
    }

    // INSTANCE_OWNER_ROLE
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
            revert IAccess.ErrorIAccessRoleIdInvalid(roleId);
        }

        if(_roleInfo[roleId].rtype == IAccess.Type.Core) {
            revert IAccess.ErrorIAccessRoleTypeInvalid(roleId, _roleInfo[roleId].rtype);
        }

        if (!roleExists(admin)) {
            revert IAccess.ErrorIAccessRoleIdInvalid(admin);
        }        

        _roleInfo[roleId].admin = admin;      
    }

    function grantRole(RoleId roleId, address member) 
        public
        restrictedToRoleAdmin(roleId) 
        returns (bool granted) 
    {
        if (!roleExists(roleId)) {
            revert IAccess.ErrorIAccessRoleIdInvalid(roleId);
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

    /// @dev not restricted function by intention
    /// the restriction to role members is already enforced by the call to the access manager
    function renounceRole(RoleId roleId) 
        external 
        returns (bool) 
    {
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

    function getRoleInfo(RoleId roleId) external view returns (IAccess.RoleInfo memory role) {
        return _roleInfo[roleId];
    }

    function roleMembers(RoleId roleId) external view returns (uint256 numberOfMembers) {
        return EnumerableSet.length(_roleMembers[roleId]);
    }

    function getRoleId(uint256 idx) external view returns (RoleId roleId) {
        return _roleIds[idx];
    }

    // TODO now: for non existent name returns ADMIN_ROLE id
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

    function isCustomRoleAdmin(RoleId roleId) public pure returns (bool) {
        uint roleIdInt = roleId.toInt();
        return (
            roleIdInt >= CUSTOM_ROLE_ID_MIN &&
            roleIdInt % 2 == 1
        );
    }

    //--- Target ------------------------------------------------------//
    // ADMIN_ROLE
    // assume some core targets are registred (instance) while others are not (instance accesss manager, instance reader, bundle manager)
    function createCoreTarget(address target, string memory name) external restricted() {
        _createTarget(target, name, IAccess.Type.Core);
    }
    // INSTANCE_SERVICE_ROLE
    // assume gif target is registered and belongs to the same instance as instance access manager
    function createGifTarget(address target, string memory name) external restricted() 
    {
        _createTarget(target, name, IAccess.Type.Gif);
    }
    // INSTANCE_OWNER_ROLE
    // assume custom target.authority() is constant -> target can not be used with different instance access manager
    // assume custom target can not be registered as component -> each service which is doing component registration MUST register a gif target
    // assume custom target can not be registered as instance or service -> why?
    // TODO check target associated with instance owner or instance or instance components or components helpers
    function createTarget(address target, string memory name) 
        external 
        restricted() 
    {
        if(_registry.isRegistered(target)) {
            revert IAccess.ErrorIAccessTargetIsRegistered(target);
        }

        _createTarget(target, name, IAccess.Type.Custom);
    }
    // INSTANCE_SERVICE_ROLE
    // IMPORTANT: instance access manager MUST be of Core type -> otherwise will be locked forever
    function setTargetLocked(string memory targetName, bool locked) 
        external 
        restricted() 
    {
        ShortString nameShort = ShortStrings.toShortString(targetName);
        address target = _targetAddressForName[nameShort];
        
        if (target == address(0)) {
            revert IAccess.ErrorIAccessTargetDoesNotExist(nameShort);
        }

        if(_targetInfo[target].ttype == IAccess.Type.Core) {
            revert IAccess.ErrorIAccessTargetTypeInvalid(nameShort, _targetInfo[target].ttype);
        }
        // TODO isLocked is redundant but makes getTargetInfo() faster
        _targetInfo[target].isLocked = locked;
        _accessManager.setTargetClosed(target, locked);
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
            revert IAccess.ErrorIAccessTargetTypeInvalid(nameShort, _targetInfo[target].ttype);
        }

        // not custom role
        if(_roleInfo[roleId].rtype == IAccess.Type.Custom) {
            revert IAccess.ErrorIAccessRoleTypeInvalid(roleId, _roleInfo[roleId].rtype);
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
            revert IAccess.ErrorIAccessTargetTypeInvalid(nameShort, _targetInfo[target].ttype);
        }

        // not core role
        if(_roleInfo[roleId].rtype == IAccess.Type.Core) {
            revert IAccess.ErrorIAccessRoleTypeInvalid(roleId, _roleInfo[roleId].rtype);
        }

        _setTargetFunctionRole(target, nameShort, selectors, roleId);
    }

    function isTargetLocked(address target) public view returns (bool locked) {
        return _accessManager.isTargetClosed(target);
    }

    function targetExists(address target) public view returns (bool exists) {
        return _targetInfo[target].createdAt.gtz();
    }

    function getTargetInfo(address target) public view returns (IAccess.TargetInfo memory) {
        return _targetInfo[target];
    }


    //--- Interceptor ------------------------------------------------------------//
    // INSTANCE_ROLE or onlyInstance
    function transferOwnerRole(address from, address to) restricted external
    {
        bool revoked = this.revokeRole(INSTANCE_OWNER_ROLE(), from);
        bool granted = this.grantRole(INSTANCE_OWNER_ROLE(), to);
        if(!revoked || !granted) {
            revert();
        }
    }

    //--- Role internal view/pure functions --------------------------------------//

    function _createRole(RoleId roleId, string memory nameLong, IAccess.Type rtype) 
        internal
    {
        ShortString name = ShortStrings.toShortString(nameLong);
        _validateRole(roleId, name, rtype);

        if(roleExists(roleId)) {
            revert IAccess.ErrorIAccessRoleIdAlreadyExists(roleId);
        }

        if (_roleIdForName[name].gtz()) {
            revert IAccess.ErrorIAccessRoleNameNotUnique(_roleIdForName[name], name);
        }

        IAccess.RoleInfo memory role = IAccess.RoleInfo(
            name, 
            rtype,
            ADMIN_ROLE(),
            TimestampLib.blockTimestamp(),
            TimestampLib.blockTimestamp());

        _roleInfo[roleId] = role;
        _roleIdForName[role.name] = roleId;
        _roleIds.push(roleId);
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

    // INSTANCE_OWNER_ROLE
    // TODO prohibit renouncing Gif and Core roles?
    function _revokeRole(RoleId roleId, address member)
        internal
        returns(bool revoked)
    {
        if (!roleExists(roleId)) {
            revert IAccess.ErrorIAccessRoleIdInvalid(roleId);
        }

        revoked = EnumerableSet.remove(_roleMembers[roleId], member);
        if(revoked) {
            uint64 roleIdInt = roleId.toInt();
            _accessManager.revokeRole(roleIdInt, member);

            // revoke custom role if custom role admin is being revoked
            if(isCustomRoleAdmin(roleId)) {
                uint64 customRoleIdInt = roleIdInt - 1;
                RoleId customRoleId = RoleIdLib.toRoleId(customRoleIdInt);
                // loop through all custom role members
                uint memberCount = EnumerableSet.length(_roleMembers[customRoleId]);
                for(uint memberIdx = 0; memberIdx < memberCount; memberIdx++)
                {
                    member = EnumerableSet.at(_roleMembers[customRoleId], memberIdx);
                    bool revokedCustom = EnumerableSet.remove(_roleMembers[customRoleId], member);
                    if(revokedCustom) {
                        _accessManager.revokeRole(customRoleIdInt, member);
                    }
                }
            }
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

    function _createTarget(address target, string memory nameLong, IAccess.Type ttype) 
        internal 
    {
        ShortString name = ShortStrings.toShortString(nameLong);
        _validateTarget(target, name, ttype);

        if (_targetInfo[target].createdAt.gtz()) {
            revert IAccess.ErrorIAccessTargetAlreadyExists(target, _targetInfo[target].name);
        }

        if (_targetAddressForName[name] != address(0)) {
            revert IAccess.ErrorIAccessTargetNameExists(
                target, 
                _targetAddressForName[name], 
                name);
        }

        IAccess.TargetInfo memory info = IAccess.TargetInfo(
            name, 
            ttype,
            _accessManager.isTargetClosed(target), // sync with state in access manager
            TimestampLib.blockTimestamp(),
            TimestampLib.blockTimestamp());

        _targetInfo[target] = info;
        _targetAddressForName[info.name] = target;
        _targets.push(target);
    }

    function _validateTarget(address target, ShortString name, IAccess.Type ttype) 
        internal 
        view 
    {
        address targetAuthority = AccessManagedUpgradeable(target).authority();
        // TODO check depends on target upgradabillity
        if(targetAuthority != authority()) {
            revert IAccess.ErrorIAccessTargetAuthorityInvalid(target, targetAuthority);
        }

        if (ShortStrings.byteLength(name) == 0) {
            revert IAccess.ErrorIAccessTargetNameEmpty(target);
        }
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
            revert IAccess.ErrorIAccessTargetDoesNotExist(name);
        }

        if (!roleExists(roleId)) {
            revert IAccess.ErrorIAccessRoleIdInvalid(roleId);
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
