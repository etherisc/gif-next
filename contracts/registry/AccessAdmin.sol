// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IAccessAdmin} from "./IAccessAdmin.sol";
import {RoleId, RoleIdLib} from "../type/RoleId.sol";
import {Selector, SelectorLib, SelectorSet} from "../type/Selector.sol";
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
    mapping(Str roleName => RoleNameInfo nameInfo) internal _roleForName;

    /// @dev store array with all created roles
    RoleId [] internal _roleIds;

    /// @dev store set of current role members for given role
    mapping(RoleId roleId => EnumerableSet.AddressSet roleMembers) internal _roleMembers;

    /// @dev store target info per target address
    mapping(address target => TargetInfo info) internal _targetInfo;

    /// @dev store role name info per role name
    mapping(Str targetName => address target) internal _targetForName;

    /// @dev store array with all created targets
    address [] internal _targets;

    /// @dev store all managed functions per target
    mapping(address target => SelectorSet.Set selectors) internal _targetFunctions;

    /// @dev temporary dynamic function infos array
    mapping(address target => mapping(Selector selector => Str functionName)) internal _functionName;

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

    //--- role management functions -----------------------------------------//

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

    //--- target management functions ---------------------------------------//

    function createTarget(
        address target, 
        string memory name
    )
        external
        restricted()
    {
        _createTarget(target, name);
    }

    function setTargetLocked(
        address target, 
        bool locked
    )
        external
        restricted()
    {
        _authority.setTargetClosed(target, locked);
    }

    function authorizeFunctions(
        address target, 
        RoleId roleId, 
        Function[] memory functions
    )
        external
        restricted()
    {
        _authorizeTargetFunctions(target, roleId, functions);
    }

    function authorizedFunctions(address target) external view returns (uint256 numberOfFunctions) {
        return SelectorSet.size(_targetFunctions[target]);
    }

    function getAuthorizedFunction(
        address target, 
        uint256 idx
    )
        external 
        view 
        returns (
            Function memory func, 
            RoleId roleId
        )
    {
        Selector selector = SelectorSet.at(_targetFunctions[target], idx);

        func = Function({
            selector: selector, 
            name: _functionName[target][selector]});

        roleId = RoleIdLib.toRoleId(
            _authority.getTargetFunctionRole(
                target, 
                selector.toBytes4()));
    }

    function canCall(address caller, address target, Selector selector) external view returns (bool can) {
        (can, ) = _authority.canCall(caller, target, selector.toBytes4());
    }

    function _authorizeTargetFunctions(
        address target, 
        RoleId roleId, 
        Function[] memory functions
    )
        internal
    {
        // _processFunctions(target, roleId, functions);
        uint256 n = functions.length;
        bytes4[] memory functionSelectors = new bytes4[](n);
        for (uint256 i = 0; i < n; i++) {
            Function memory func = functions[i];
            Selector selector = func.selector;

            // add function selector to target selector set if not in set
            if (!SelectorSet.contains(_targetFunctions[target], selector)) {
                SelectorSet.add(_targetFunctions[target], selector);
            }

            // set function name
            _functionName[target][selector] = func.name;

            // add bytes4 selector to function selector array
            functionSelectors[i] = selector.toBytes4();
        }

        // apply authz via access manager
        _grantRoleAccessToFunctions(target, roleId, functionSelectors);
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

    function isAccessManaged(address target) public view returns (bool) {
        if (!_isContract(target)) {
            return false;
        }

        (bool success, ) = target.staticcall(
            abi.encodeWithSelector(
                AccessManagedUpgradeable.authority.selector));

        return success;
    }

    function targetExists(address target) public view returns (bool exists) {
        return _targetInfo[target].createdAt.gtz();
    }

    function isTargetLocked(address target) public view returns (bool locked) {
        return _authority.isTargetClosed(target);
    }

    function targets() external view returns (uint256 numberOfTargets) {
        return _targets.length;
    }

    function getTargetAddress(uint256 idx) external view returns (address target) {
        return _targets[idx];
    }

    function getTargetInfo(address target) external view returns (TargetInfo memory targetInfo) {
        return _targetInfo[target];
    }

    function getTargetForName(Str name) external view returns (address target) {
        return _targetForName[name];
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
        Function[] memory functions;

        // setup admin role
        _createRoleUnchecked(
            adminRoleId,
            adminRoleId,
            StrLib.toStr(ADMIN_ROLE_NAME));

        // add this contract as admin role member
        _roleMembers[adminRoleId].add(address(this));

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

        // grant public role access to grant and revoke, renounce
        functions = new Function[](3);
        functions[0] = toFunction(IAccessAdmin.grantRole.selector, "grantRole");
        functions[1] = toFunction(IAccessAdmin.revokeRole.selector, "revokeRole");
        functions[2] = toFunction(IAccessAdmin.renounceRole.selector, "renounceRole");
        _authorizeTargetFunctions(address(this), getPublicRole(), functions);

        // grant manager role access to the specified functions 
        functions = new Function[](4);
        functions[0] = toFunction(IAccessAdmin.createRole.selector, "createRole");
        functions[1] = toFunction(IAccessAdmin.createTarget.selector, "createTarget");
        functions[2] = toFunction(IAccessAdmin.setTargetLocked.selector, "setTargetLocked");
        functions[3] = toFunction(IAccessAdmin.authorizeFunctions.selector, "authorizeFunctions");
        _authorizeTargetFunctions(address(this), _managerRoleId, functions);

        // grant manger role to deployer
        _grantRoleToAccount(_managerRoleId, _deployer);
    }

    function toFunction(bytes4 selector, string memory name) internal pure returns (Function memory) {
            return Function({
                selector: SelectorLib.toSelector(selector),
                name: StrLib.toStr(name)});
    }

    /// @dev grant the specified role access to all functions in the provided selector list
    function _grantRoleAccessToFunctions(
        address target,
        RoleId roleId, 
        bytes4[] memory functionSelectors
    )
        internal
    {
        _authority.setTargetFunctionRole(
            target,
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
        
        emit LogRoleGranted(roleId, account);
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
        
        if (msg.sender == account) {
            emit LogRoleRenounced(roleId, account);
        } else {
            emit LogRoleRevoked(roleId, account);
        }
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


    function _createTarget(address target, string memory targetName)
        internal
    {
        // check target does not yet exist
        if(targetExists(target)) {
            revert ErrorTargetAlreadyCreated(
                target, 
                _targetInfo[target].name.toString());
        }

        // check target name is not empty
        Str name = StrLib.toStr(targetName);
        if(name.length() == 0) {
            revert ErrorTargetNameEmpty(target);
        }

        // check target name is not used for another role
        if( _targetForName[name] != address(0)) {
            revert ErrorTargetNameAlreadyExists(
                target, 
                targetName,
                _targetForName[name]);
        }

        // check target is an access managed contract
        if (!isAccessManaged(target)) {
            revert ErrorTargetNotAccessManaged(target);
        }

        // check target shares authority with this contract
        address targetAuthority = AccessManagedUpgradeable(target).authority();
        if (targetAuthority != authority()) {
            revert ErrorTargetAuthorityMismatch(authority(), targetAuthority);
        }

        // create target info
        _targetInfo[target] = TargetInfo({
            name: name,
            createdAt: TimestampLib.blockTimestamp()
        });

        // create name to target mapping
        _targetForName[name] = target;

        // add role to list of roles
        _targets.push(target);

        emit LogTargetCreated(target, targetName);
    }

    function _isContract(address target)
        internal
        view 
        returns (bool)
    {
        uint256 size;
        assembly {
            size := extcodesize(target)
        }
        return size > 0;
    }
    
}