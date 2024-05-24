// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IAccessAdmin} from "./IAccessAdmin.sol";
import {RoleId, RoleIdLib} from "../type/RoleId.sol";
import {Str, StrLib} from "../type/String.sol";
import {TimestampLib} from "../type/Timestamp.sol";


/**
 * @dev A generic access amin contract that implements role based access control based on OpenZeppelin's AccessManager contract.
 * The contract provides read functions to query all available roles, targets and access rights.
 * This contract works for both a constructor based deployment or a deployment based on cloning and initialization.
 */ 
contract AccessAdmin is
    AccessManagedUpgradeable,
    IAccessAdmin
{
    using EnumerableSet for EnumerableSet.AddressSet;

    string public constant ADMIN_ROLE_NAME = "AdminRole";
    string public constant PUBLIC_ROLE_NAME = "PublicRole";

    uint64 public constant MANAGER_ROLE = type(uint64).min + 1;
    string public constant MANAGER_ROLE_NAME = "ManagerRole";

    /// @dev the OpenZeppelin access manager driving the access admin contract
    AccessManager internal _authority;

    /// @dev stores the deployer address and allows to create initializers
    /// that are restricted to the deployer address.
    address internal _deployer;

    /// @dev required role for state changes to this contract
    RoleId internal _managerRoleId;

    /// @dev store role info per role id
    mapping(RoleId roleId => RoleInfo info) internal _roleInfo;

    /// @dev store role name info per role name
    mapping(Str roleName => RoleNameInfo) internal _roleForName;

    /// @dev store array with all created roles
    RoleId [] internal _roleIds;

    /// @dev store set of current role members for given role
    mapping(RoleId roleId => EnumerableSet.AddressSet roleMembers) internal _roleMembers;

    /// @dev temporary dynamic functions array
    bytes4[] private _functions;

    modifier onlyDeployer() {
        if (_deployer == address(0)) {
            _deployer = msg.sender;
        }

        if (msg.sender != _deployer) {
            revert ErrorNotDeployer();
        }
        _;
    }

    modifier onlyAdminRole(RoleId roleId) {
        if (!hasRole(msg.sender, _roleInfo[roleId].adminRoleId)) {
            revert ErrorNotAdminOfRole(_roleInfo[roleId].adminRoleId);
        }
        _;
    }

    modifier onlyRoleOwner(RoleId roleId) {
        if (!hasRole(msg.sender, roleId)) {
            revert ErrorNotRoleOwner();
        }
        _;
    }

    constructor() {
        _deployer = msg.sender;
        _authority = new AccessManager(address(this));

        _setAuthority(address(_authority));
        _createInitialRoleSetup();

        _disableInitializers();
    }


    function createRole(
        RoleId roleId, 
        RoleId adminRoleId, 
        string memory name
    )
        external
        restricted()
    {
        _createRole(roleId, adminRoleId, name);
    }

    function grantRole(
        address account, 
        RoleId roleId
    )
        external
        onlyAdminRole(roleId)
        restricted()
    {
        _grantRoleToAccount(roleId, account);
    }

    function revokeRole(
        address account, 
        RoleId roleId
    )
        external
        onlyAdminRole(roleId)
        restricted()
    {
        _revokeRoleFromAccount(roleId, account);
    }

    function renounceRole(
        RoleId roleId
    )
        external
        restricted()
    {
        _revokeRoleFromAccount(roleId, msg.sender);
    }


    //--- view functions ----------------------------------------------------//

    function roles() external view returns (uint256 numberOfRoles) {
        return _roleIds.length;
    }

    function getRoleId(uint256 idx) external view returns (RoleId roleId) {
        return _roleIds[idx];
    }

    function getAdminRole() public view returns (RoleId roleId) {
        return RoleId.wrap(_authority.ADMIN_ROLE());
    }

    function getPublicRole() public view returns (RoleId roleId) {
        return RoleId.wrap(_authority.PUBLIC_ROLE());
    }

    function getManagerRole() public view returns (RoleId roleId) {
        return _managerRoleId;
    }

    function roleExists(RoleId roleId) public view returns (bool exists) {
        return _roleInfo[roleId].createdAt.gtz();
    }

    function roleIsActive(RoleId roleId) public view returns (bool isActive) {
        return _roleInfo[roleId].disabledAt > TimestampLib.blockTimestamp();
    }

    function getRoleInfo(RoleId roleId) external view returns (RoleInfo memory) {
        return _roleInfo[roleId];
    }

    function getRoleForName(Str name) external view returns (RoleNameInfo memory) {
        return _roleForName[name];
    }

    function hasRole(address account, RoleId roleId) public view returns (bool) {
        (bool isMember, ) = _authority.hasRole(
            RoleId.unwrap(roleId), 
            account);
        return isMember;
    }

    function roleMembers(RoleId roleId) external view returns (uint256 numberOfMembers) {
        return _roleMembers[roleId].length();
    }

    function getRoleMember(RoleId roleId, uint256 idx) external view returns (address account) {
        return _roleMembers[roleId].at(idx);
    }

    function deployer() public view returns (address) {
        return _deployer;
    }

    //--- internal/private functions -------------------------------------------------//


    function _initializeAuthority(
        address authorityAddress
    )
        internal
        virtual
        onlyInitializing()
        onlyDeployer()
    {
        if (authority() != address(0)) {
            revert ErrorAuthorityAlreadySet();
        }

        _authority = AccessManager(authorityAddress);

        if(!hasRole(address(this), RoleId.wrap(_authority.ADMIN_ROLE()))) {
            revert ErrorAdminRoleMissing();
        }

        __AccessManaged_init(address(_authority));
    }


    function _initializeRoleSetup()
        internal
        virtual
        onlyInitializing()
    {
        _createInitialRoleSetup();
    }


    function _createInitialRoleSetup()
        private
    {
        RoleId adminRoleId = RoleIdLib.toRoleId(_authority.ADMIN_ROLE());

        // setup public role
        _createRoleUnchecked(
            adminRoleId,
            adminRoleId,
            StrLib.toStr(ADMIN_ROLE_NAME));

        // setup public role
        _createRoleUnchecked(
            RoleIdLib.toRoleId(_authority.PUBLIC_ROLE()),
            adminRoleId,
            StrLib.toStr(PUBLIC_ROLE_NAME));

        // setup manager role
        _managerRoleId = RoleIdLib.toRoleId(MANAGER_ROLE);
        _createRole(
            _managerRoleId, 
            adminRoleId,
            MANAGER_ROLE_NAME);

        // grant anybody access to grant and revoke, renounce
        // these functions do additional checks internally
        _functions = [
            IAccessAdmin.grantRole.selector,
            IAccessAdmin.revokeRole.selector,
            IAccessAdmin.renounceRole.selector
        ];

        _grantRoleAccessToFunctions(getPublicRole(), _functions);

        // grant manager role access to the specified functions 
        _functions = [
            IAccessAdmin.createRole.selector
        ];

        // setup initial function granting for manager role
        _grantRoleAccessToFunctions(_managerRoleId, _functions);

        // grant manger role to deployer
        _grantRoleToAccount(_managerRoleId, _deployer);

        // add this contract as admin role member
        _roleMembers[adminRoleId].add(address(this));
    }

    /// @dev grant the specified role access to all functions in the provided selector list
    function _grantRoleAccessToFunctions(RoleId roleId, bytes4[] memory functionSelectors)
        internal
    {
        _authority.setTargetFunctionRole(
            address(this), // target
            functionSelectors,
            RoleId.unwrap(roleId));
    }

    /// @dev grant the specified role to the provided account
    function _grantRoleToAccount(RoleId roleId, address account)
        internal
    {
        _checkForAdminAndPublicRole(roleId);
        _roleMembers[roleId].add(account);
        _authority.grantRole(
            RoleId.unwrap(roleId), 
            account, 
            0);
    }

    /// @dev revoke the specified role from the provided account
    function _revokeRoleFromAccount(RoleId roleId, address account)
        internal
    {
        _checkForAdminAndPublicRole(roleId);
        _roleMembers[roleId].remove(account);
        _authority.revokeRole(
            RoleId.unwrap(roleId), 
            account);
    }


    function _checkForAdminAndPublicRole(RoleId roleId)
        internal
    {
        uint64 roleIdInt = RoleId.unwrap(roleId);
        if (roleIdInt == _authority.ADMIN_ROLE()
            || roleIdInt == _authority.PUBLIC_ROLE())
        {
            revert ErrorRoleIsLocked(roleId);
        }
    }


    function _createRole(RoleId roleId, RoleId adminRoleId, string memory roleName)
        internal
    {
        // check role does not yet exist
        if(roleExists(roleId)) {
            revert ErrorRoleAlreadyCreated(
                roleId, 
                _roleInfo[roleId].name.toString());
        }

        // check admin role exists
        if(!roleExists(adminRoleId)) {
            revert ErrorRoleAdminNotExisting(adminRoleId);
        }

        // check role name is not empty
        Str name = StrLib.toStr(roleName);
        if(name.length() == 0) {
            revert ErrorRoleNameEmpty(roleId);
        }

        // check role name is not used for another role
        if(_roleForName[name].exists) {
            revert ErrorRoleNameAlreadyExists(
                roleId, 
                roleName,
                _roleForName[name].roleId);
        }

        _createRoleUnchecked(roleId, adminRoleId, name);
    }


    function _createRoleUnchecked(
        RoleId roleId, 
        RoleId adminRoleId, 
        Str name
    )
        private
    {
        // create role info
        _roleInfo[roleId] = RoleInfo({
            adminRoleId: adminRoleId,
            name: name,
            disabledAt: TimestampLib.max(),
            createdAt: TimestampLib.blockTimestamp()
        });

        // create role name info
        _roleForName[name] = RoleNameInfo({
            roleId: roleId,
            exists: true});

        // add role to list of roles
        _roleIds.push(roleId);

        emit LogRoleCreated(roleId, adminRoleId, name.toString());
    }
}