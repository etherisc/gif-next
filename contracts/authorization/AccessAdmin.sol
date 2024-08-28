// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {IAccessAdmin} from "./IAccessAdmin.sol";
import {IAuthorization} from "./IAuthorization.sol";
import {IRegistry} from "../registry/IRegistry.sol";

import {AccessAdminLib} from "./AccessAdminLib.sol";
import {AccessManagerCloneable} from "./AccessManagerCloneable.sol";
import {ContractLib} from "../shared/ContractLib.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {RoleId, RoleIdLib, ADMIN_ROLE, PUBLIC_ROLE} from "../type/RoleId.sol";
import {Selector, SelectorSetLib} from "../type/Selector.sol";
import {Str, StrLib} from "../type/String.sol";
import {TimestampLib} from "../type/Timestamp.sol";
import {VersionPart} from "../type/Version.sol";

interface IAccessManagedChecker {
    function authority() external view returns (address);
}

/**
 * @dev A generic access amin contract that implements role based access control based on OpenZeppelin's AccessManager contract.
 * The contract provides read functions to query all available roles, targets and access rights.
 * This contract works for both a constructor based deployment or a deployment based on cloning and initialization.
 */ 
contract AccessAdmin is
    AccessManagedUpgradeable,
    ReentrancyGuardUpgradeable,
    IAccessAdmin
{
    using EnumerableSet for EnumerableSet.AddressSet;

    string public constant ADMIN_ROLE_NAME = "AdminRole";
    string public constant PUBLIC_ROLE_NAME = "PublicRole";

    /// @dev admin name used for logging only
    string internal _adminName;

    /// @dev the access manager driving the access admin contract
    /// hold link to registry and release version
    AccessManagerCloneable internal _authority;

    /// @dev the authorization contract used for initial access control
    IAuthorization internal _authorization;

    /// @dev stores the deployer address and allows to create initializers
    /// that are restricted to the deployer address.
    address internal _deployer;

    /// @dev the linked NFT ID
    NftId internal _linkedNftId;

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
    mapping(address target => SelectorSetLib.Set selectors) internal _targetFunctions;

    /// @dev function infos array
    mapping(address target => mapping(Selector selector => FunctionInfo)) internal _functionInfo;

    /// @dev temporary dynamic functions array
    bytes4[] private _functions;


    modifier onlyDeployer() {
        // special case for cloned AccessAdmin contracts
        // IMPORTANT cloning and initialize authority needs to be done in a single transaction
        if (_deployer == address(0)) {
            _deployer = msg.sender;
        }

        if (msg.sender != _deployer) {
            revert ErrorAccessAdminNotDeployer();
        }
        _;
    }


    modifier onlyExistingRole(
        RoleId roleId, 
        bool onlyActiveRole,
        bool allowLockedRoles
    )
    {
        if (!allowLockedRoles) {
            _checkRoleExists(roleId, onlyActiveRole);
        }
        _;
    }


    modifier onlyExistingTarget(address target) {
        _checkTargetExists(target);
        _;
    }

    //-------------- initialization functions ------------------------------//

    // event LogAccessAdminDebug(string message);

    /// @dev Initializes this admin with the provided accessManager (and authorization specification).
    /// Internally initializes access manager with this admin and creates basic role setup.
    function initialize(
        address authority,
        string memory adminName 
    )
        public
        initializer()
    {
        __AccessAdmin_init(authority, adminName);
    }


    function __AccessAdmin_init(
        address authority, 
        string memory adminName 
    )
        internal
        onlyInitializing()
        onlyDeployer()
    {
        // checks
        // check authority is contract
        if (!ContractLib.isContract(authority)) {
            revert ErrorAccessAdminAuthorityNotContract(authority);
        }

        // check name not empty
        if (bytes(adminName).length == 0) {
            revert ErrorAccessAdminAccessManagerEmptyName();
        }

        _authority = AccessManagerCloneable(authority);
        _authority.initialize(address(this));

        // delayed additional check for authority after its initialization
        if (!ContractLib.isAuthority(authority)) {
            revert ErrorAccessAdminAccessManagerNotAccessManager(authority);
        }

        // effects
        // set and initialize this access manager contract as
        // the admin (ADMIN_ROLE) of the provided authority
        __AccessManaged_init(authority);

        // set name for logging
        _adminName = adminName;

        // set initial linked NFT ID to zero
        _linkedNftId = NftIdLib.zero();

        // create admin and public roles
        _initializeAdminAndPublicRoles();
    }


    function getRelease() public view virtual returns (VersionPart release) {
        return _authority.getRelease();
    }


    function getRegistry() public view returns (IRegistry registry) {
        return _authority.getRegistry();
    }


    function getLinkedNftId() external view returns (NftId linkedNftId) {
        return _linkedNftId;
    }


    function getLinkedOwner() external view returns (address linkedOwner) {
        return getRegistry().ownerOf(_linkedNftId);
    }


    function getAuthorization() public view returns (IAuthorization authorization) {
        return _authorization;
    }


    function isLocked() public view returns (bool locked) {
        return _authority.isLocked();
    }

    //--- view functions for roles ------------------------------------------//

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

    function roleExists(RoleId roleId) public view returns (bool exists) {
        return _roleInfo[roleId].createdAt.gtz();
    }

    function getRoleForName(string memory name) external view returns (RoleId roleId) {
        return _roleForName[StrLib.toStr(name)].roleId;
    }

    function getRoleInfo(RoleId roleId) public view returns (RoleInfo memory) {
        return _roleInfo[roleId];
    }

    function isRoleActive(RoleId roleId) external view returns (bool isActive) {
        return _roleInfo[roleId].pausedAt > TimestampLib.blockTimestamp();
    }

    function isRoleCustom(RoleId roleId) external view returns (bool isActive) {
        return _roleInfo[roleId].roleType == RoleType.Custom;
    }

    function roleMembers(RoleId roleId) external view returns (uint256 numberOfMembers) {
        return _roleMembers[roleId].length();
    }

    function getRoleMember(RoleId roleId, uint256 idx) external view returns (address account) {
        return _roleMembers[roleId].at(idx);
    }

    function isRoleMember(RoleId roleId, address account) public view returns (bool) {
        (bool isMember, ) = _authority.hasRole(
            RoleId.unwrap(roleId), 
            account);
        return isMember;
    }

    function isRoleAdmin(RoleId roleId, address account)
        public 
        virtual
        view 
        returns (bool)
    {
        return isRoleMember(_roleInfo[roleId].adminRoleId, account);
    }

    //--- view functions for targets ----------------------------------------//

    function targetExists(address target) public view returns (bool exists) {
        return _targetInfo[target].createdAt.gtz();
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

    function getTargetForName(Str name) public view returns (address target) {
        return _targetForName[name];
    }

    function isTargetLocked(address target) public view returns (bool locked) {
        return _authority.isTargetClosed(target);
    }

    function authorizedFunctions(address target) external view returns (uint256 numberOfFunctions) {
        return SelectorSetLib.size(_targetFunctions[target]);
    }

    function getAuthorizedFunction(
        address target, 
        uint256 idx
    )
        external 
        view 
        returns (
            FunctionInfo memory func, 
            RoleId roleId
        )
    {
        Selector selector = SelectorSetLib.at(_targetFunctions[target], idx);
        func = _functionInfo[target][selector];
        roleId = RoleIdLib.toRoleId(
            _authority.getTargetFunctionRole(
                target, 
                selector.toBytes4()));
    }

    function deployer() public view returns (address) {
        return _deployer;
    }

    //--- internal/private functions -------------------------------------------------//

    function _linkToNftOwnable(address registerable) internal {
        if (!getRegistry().isRegistered(registerable)) {
            revert ErrorAccessAdminNotRegistered(registerable);
        }

        _linkedNftId = getRegistry().getNftIdForAddress(registerable);
    }

    function _initializeAdminAndPublicRoles()
        internal
        virtual
        onlyInitializing()
    {
        RoleId adminRoleId = RoleIdLib.toRoleId(_authority.ADMIN_ROLE());

        // setup admin role
        _createRoleUnchecked(
            ADMIN_ROLE(),
            AccessAdminLib.toRole({
                adminRoleId: ADMIN_ROLE(),
                roleType: RoleType.Contract,
                maxMemberCount: 1,
                name: ADMIN_ROLE_NAME}));

        // add this contract as admin role member
        _roleMembers[adminRoleId].add(address(this));

        // setup public role
        _createRoleUnchecked(
            PUBLIC_ROLE(),
            AccessAdminLib.toRole({
                adminRoleId: ADMIN_ROLE(),
                roleType: RoleType.Gif,
                maxMemberCount: type(uint32).max,
                name: PUBLIC_ROLE_NAME}));
    }

    function _createTargetWithRole(
        address target,
        string memory targetName,
        RoleId targetRoleId
    )
        internal
    {
        _createTarget(target, targetName, true, false);
        _grantRoleToAccount(targetRoleId, target);
    }

    function _authorizeTargetFunctions(
        address target, 
        RoleId roleId, 
        FunctionInfo[] memory functions,
        bool addFunctions
    )
        internal
    {
        if (addFunctions && roleId == getAdminRole()) {
            revert ErrorAccessAdminAuthorizeForAdminRoleInvalid(target);
        }

        // apply authz via access manager
        _grantRoleAccessToFunctions(
            target, 
            roleId, 
            functions,
            addFunctions); // add functions
    }

    // function _unauthorizeTargetFunctions(
    //     address target, 
    //     FunctionInfo[] memory functions
    // )
    //     internal
    // {
    //     _grantRoleAccessToFunctions(
    //         target, 
    //         getAdminRole(), 
    //         functions,
    //         false);  // addFunctions
    // }

    // function _processFunctionSelectors(
    //     address target,
    //     FunctionInfo[] memory functions,
    //     bool addFunctions
    // )
    //     internal
    //     onlyExistingTarget(target)
    //     returns (
    //         bytes4[] memory functionSelectors,
    //         string[] memory functionNames
    //     )
    // {
    //     uint256 n = functions.length;
    //     functionSelectors = new bytes4[](n);
    //     functionNames = new string[](n);
    //     FunctionInfo memory func;
    //     Selector selector;

    //     for (uint256 i = 0; i < n; i++) {
    //         func = functions[i];
    //         selector = func.selector;

    //         // add function selector to target selector set if not in set
    //         if (addFunctions) { SelectorSetLib.add(_targetFunctions[target], selector); } 
    //         else { SelectorSetLib.remove(_targetFunctions[target], selector); }

    //         // set function name
    //         _functionInfo[target][selector] = func;

    //         // add bytes4 selector to function selector array
    //         functionSelectors[i] = selector.toBytes4();
    //         functionNames[i] = func.name.toString();
    //     }
    // }

    /// @dev grant the specified role access to all functions in the provided selector list
    function _grantRoleAccessToFunctions(
        address target,
        RoleId roleId, 
        FunctionInfo[] memory functions,
        bool addFunctions
    )
        internal
        onlyExistingTarget(target)
        onlyExistingRole(roleId, true, !addFunctions)
    {
        _authority.setTargetFunctionRole(
            target,
            AccessAdminLib.getSelectors(functions),
            RoleId.unwrap(roleId));

        // update function set and log function grantings
        for (uint256 i = 0; i < functions.length; i++) {
            _updateFunctionAccess(
                target, 
                roleId,
                functions[i], 
                addFunctions);
        }
    }


    function _updateFunctionAccess(
        address target, 
        RoleId roleId,
        FunctionInfo memory func, 
        bool addFunction
    )
        internal
    {
        // update functions info
        Selector selector = func.selector;
        _functionInfo[target][selector] = func;

        // update function sets
        if (addFunction) { SelectorSetLib.add(_targetFunctions[target], selector); } 
        else { SelectorSetLib.remove(_targetFunctions[target], selector); }

        // logging
        emit LogAccessAdminFunctionGranted(
            _adminName, 
            target, 
            string(abi.encodePacked(
                func.name.toString(), 
                "(): ",
                _getRoleName(roleId))));
    }


    /// @dev grant the specified role to the provided account
    function _grantRoleToAccount(RoleId roleId, address account)
        internal
        onlyExistingRole(roleId, true, false)
    {
        // check max role members will not be exceeded
        if (_roleMembers[roleId].length() >= _roleInfo[roleId].maxMemberCount) {
            revert ErrorAccessAdminRoleMembersLimitReached(roleId, _roleInfo[roleId].maxMemberCount);
        }

        // check account is contract for contract role
        if (
            _roleInfo[roleId].roleType == RoleType.Contract &&
            !ContractLib.isContract(account) // will fail in account's constructor
        ) {
            revert ErrorAccessAdminRoleMemberNotContract(roleId, account);
        }

        // effects
        _roleMembers[roleId].add(account);
        _authority.grantRole(
            RoleId.unwrap(roleId), 
            account, 
            0);
        
        emit LogAccessAdminRoleGranted(_adminName, account, _getRoleName(roleId));
    }

    /// @dev revoke the specified role from the provided account
    function _revokeRoleFromAccount(RoleId roleId, address account)
        internal
        onlyExistingRole(roleId, false, false)
    {

        // check role removal is permitted
        if (_roleInfo[roleId].roleType == RoleType.Contract) {
            revert ErrorAccessAdminRoleMemberRemovalDisabled(roleId, account);
        }

        // effects
        _roleMembers[roleId].remove(account);
        _authority.revokeRole(
            RoleId.unwrap(roleId), 
            account);

        emit LogAccessAdminRoleRevoked(_adminName, account, _roleInfo[roleId].name.toString());
    }


    /// @dev Creates a role based on the provided parameters.
    /// Checks that the provided role and role id and role name not already used.
    function _createRole(
        RoleId roleId, 
        RoleInfo memory info
    )
        internal
    {
        AccessAdminLib.checkRoleCreation(this, roleId, info);
        _createRoleUnchecked(roleId, info);
    }


    /// @dev Activates or deactivates role.
    /// The role activ property is indirectly controlled over the pausedAt timestamp.
    function _setRoleActive(RoleId roleId, bool active)
        internal
    {
        if (active) {
            _roleInfo[roleId].pausedAt = TimestampLib.max();
        } else {
            _roleInfo[roleId].pausedAt = TimestampLib.blockTimestamp();
        }
    }


    function _createTarget(
        address target, 
        string memory targetName, 
        bool checkAuthority,
        bool custom
    )
        internal
    {
        AccessAdminLib.checkTargetCreation(this, target, targetName, checkAuthority);
        _createTargetUnchecked(target, targetName, custom);
    }


    function _createRoleUnchecked(
        RoleId roleId, 
        RoleInfo memory info
    )
        private
    {
        // create role info
        info.createdAt = TimestampLib.blockTimestamp();
        info.pausedAt = TimestampLib.max();
        _roleInfo[roleId] = info;

        // create role name info
        _roleForName[info.name] = RoleNameInfo({
            roleId: roleId,
            exists: true});

        // add role to list of roles
        _roleIds.push(roleId);

        emit LogAccessAdminRoleCreated(_adminName, roleId, info.roleType, info.adminRoleId, info.name.toString());
    }


    function _createTargetUnchecked(
        address target, 
        string memory targetName, 
        bool custom
    )
        internal
    {
        // create target info
        Str name = StrLib.toStr(targetName);
        _targetInfo[target] = TargetInfo({
            name: name,
            isCustom: custom,
            createdAt: TimestampLib.blockTimestamp()
        });

        // create name to target mapping
        _targetForName[name] = target;

        // add role to list of roles
        _targets.push(target);

        emit LogAccessAdminTargetCreated(_adminName, target, targetName);
    }


    function _setTargetLocked(address target, bool locked)
        internal
        onlyExistingTarget(target)
    {
        _authority.setTargetClosed(target, locked);
    }


    function _getRoleName(RoleId roleId) internal view returns (string memory) {
        if (roleExists(roleId)) {
            return _roleInfo[roleId].name.toString();
        }
        return "<unknown-role>";
    }


    function _checkAuthorization( 
        address authorization,
        ObjectType expectedDomain, 
        VersionPart expectedRelease,
        bool checkAlreadyInitialized
    )
        internal
        view
    {
        AccessAdminLib.checkAuthorization(
            address(_authorization), 
            authorization, 
            expectedDomain, 
            expectedRelease, 
            checkAlreadyInitialized);
    }


    function _checkRoleExists( 
        RoleId roleId, 
        bool onlyActiveRole
    )
        internal
        view
    {
        if (!roleExists(roleId)) {
            revert ErrorAccessAdminRoleUnknown(roleId);
        }

        uint64 roleIdInt = RoleId.unwrap(roleId);
        if (roleIdInt == _authority.ADMIN_ROLE()) {
            revert ErrorAccessAdminRoleIsLocked(roleId);
        }

        // check if role is disabled
        if (onlyActiveRole && _roleInfo[roleId].pausedAt <= TimestampLib.blockTimestamp()) {
            revert ErrorAccessAdminRoleIsPaused(roleId);
        }
    }



    /// @dev check if target exists and reverts if it doesn't
    function _checkTargetExists(
        address target
    )
        internal
        view
    {
        // check not yet created
        if (!targetExists(target)) {
            revert ErrorAccessAdminTargetNotCreated(target);
        }
    }

    // TODO cleanup
    // function _checkIsRegistered( 
    //     address registry,
    //     address target,
    //     ObjectType expectedType
    // )
    //     internal
    //     view
    // {
    //     AccessAdminLib.checkIsRegistered(registry, target, expectedType);
    // }

    // function _checkRegistry(address registry) internal view {
    //     if (!ContractLib.isRegistry(registry)) {
    //         revert ErrorAccessAdminNotRegistry(registry);
    //     }
    // }
}