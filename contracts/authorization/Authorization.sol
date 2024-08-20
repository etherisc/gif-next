// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccess} from "./IAccess.sol";
import {IAuthorization} from "./IAuthorization.sol";
import {ObjectType, ObjectTypeLib, PRODUCT, ORACLE, DISTRIBUTION, POOL} from "../type/ObjectType.sol";
import {RoleId, RoleIdLib, ADMIN_ROLE} from "../type/RoleId.sol";
import {SelectorLib} from "../type/Selector.sol";
import {Str, StrLib} from "../type/String.sol";
import {TimestampLib} from "../type/Timestamp.sol";
import {VersionPart, VersionPartLib} from "../type/Version.sol";

contract Authorization
    is IAuthorization
{
    uint256 public constant GIF_RELEASE = 3;

    string public constant ROLE_NAME_SUFFIX = "Role";
    string public constant SERVICE_ROLE_NAME_SUFFIX = "ServiceRole";

    ObjectType[] internal _serviceDomains;
    mapping(ObjectType domain => Str target) internal _serviceTarget;

    string internal _mainTargetName = "Component";
    string internal _tokenHandlerName = "ComponentTH";

    Str internal _mainTarget;
    Str internal _tokenHandlerTarget;
    Str[] internal _targets;

    mapping(Str target => RoleId roleid) internal _targetRole;
    mapping(Str target => bool exists) internal _targetExists;

    RoleId[] internal _roles;
    mapping(RoleId role => RoleInfo info) internal _roleInfo;

    mapping(Str target => RoleId[] authorizedRoles) internal _authorizedRoles;
    mapping(Str target => mapping(RoleId authorizedRole => IAccess.FunctionInfo[] functions)) internal _authorizedFunctions;


    constructor(
        string memory mainTargetName, 
        ObjectType targetDomain
    )
    {
        // checks
        if (bytes(mainTargetName).length == 0) {
            revert ErrorAuthorizationMainTargetNameEmpty();
        }

        if (targetDomain.eqz()) {
            revert ErrorAuthorizationTargetDomainZero();
        }

        // effects
        // setup main target, main role id and main role info
        _mainTargetName = mainTargetName;
        _tokenHandlerName = string(abi.encodePacked(mainTargetName, "TH"));

        RoleId mainRoleId = RoleIdLib.toComponentRoleId(targetDomain, 0);
        string memory mainRolName = _toTargetRoleName(mainTargetName);

        _addTargetWithRole(
            _mainTargetName, 
            mainRoleId,
            mainRolName);

        _mainTarget = StrLib.toStr(mainTargetName);
        _targetRole[_mainTarget] = mainRoleId;

        // add token handler target for components
        if (targetDomain == PRODUCT() 
            || targetDomain == DISTRIBUTION()
            || targetDomain == ORACLE()
            || targetDomain == POOL()
        ) {
            _addTarget(_tokenHandlerName);
        }

        // setup token handler target
        _tokenHandlerTarget = StrLib.toStr(_tokenHandlerName);

        // setup use case specific parts
        _setupServiceTargets();
        _setupRoles(); // not including main target role
        _setupTargets(); // not including main target (and token handler target)

        _setupTokenHandlerAuthorizations();
        _setupTargetAuthorizations(); // not including token handler target
    }

    function getServiceDomains() external view returns(ObjectType[] memory serviceDomains) {
        return _serviceDomains;
    }

    function getComponentRole(ObjectType componentDomain) public view returns(RoleId roleId) {
        return RoleIdLib.toComponentRoleId(componentDomain, 0);
    }

    function getServiceRole(ObjectType serviceDomain) public virtual pure returns (RoleId serviceRoleId) {
        return RoleIdLib.roleForTypeAndVersion(
            serviceDomain, 
            getRelease());
    }

    function getServiceTarget(ObjectType serviceDomain) external view returns(Str serviceTarget) {
        return _serviceTarget[serviceDomain];
    }

    function getRoles() external view returns(RoleId[] memory roles) {
        return _roles;
    }

    function roleExists(RoleId roleId) public view returns(bool exists) {
        return _roleInfo[roleId].roleType != RoleType.Undefined;
    }

    function getRoleInfo(RoleId roleId) external view returns (RoleInfo memory info) {
        return _roleInfo[roleId];
    }

    function getMainTargetName() public virtual view returns (string memory name) {
        return _mainTargetName;
    }

    function getMainTarget() public view returns(Str) {
        return _mainTarget;
    }

    function getTokenHandlerName() public view returns(string memory) {
        return _tokenHandlerName;
    }

    function getTokenHandlerTarget() public view returns(Str) {
        return _tokenHandlerTarget;
    }

    function getTarget(string memory targetName) public view returns(Str target) {
        return StrLib.toStr(targetName);
    }

    function getTargets() external view returns(Str[] memory targets) {
        return _targets;
    }

    function targetExists(Str target) external view returns(bool exists) {
        return target == _mainTarget || _targetExists[target];
    }

    function getTargetRole(Str target) external view returns(RoleId roleId) {
        return _targetRole[target];
    }

    function getAuthorizedRoles(Str target) external view returns(RoleId[] memory roleIds) {
        return _authorizedRoles[target];
    }

    function getAuthorizedFunctions(Str target, RoleId roleId) external view returns(IAccess.FunctionInfo[] memory authorizatedFunctions) {
        return _authorizedFunctions[target][roleId];
    }

    function getRelease() public virtual pure returns(VersionPart release) {
        return VersionPartLib.toVersionPart(GIF_RELEASE);
    }

    /// @dev Sets up the relevant service targets for the component.
    /// Overwrite this function for use case specific authorizations.
    function _setupServiceTargets() internal virtual { }

    /// @dev Sets up the relevant (non-service) targets for the component.
    /// Overwrite this function for use case specific authorizations.
    function _setupTargets() internal virtual { }

    /// @dev Sets up the relevant roles for the component.
    /// Overwrite this function for use case specific authorizations.
    function _setupRoles() internal virtual {}

    /// @dev Sets up the relevant component's token handler authorizations.
    /// Overwrite this function for use case specific authorizations.
    function _setupTokenHandlerAuthorizations() internal virtual {}

    /// @dev Sets up the relevant target authorizations for the component.
    /// Overwrite this function for use case specific authorizations.
    function _setupTargetAuthorizations() internal virtual {}

    /// @dev Add the service target role for the specified service domain
    function _addServiceTargetWithRole(ObjectType serviceDomain) internal {
        // add service domain
        _serviceDomains.push(serviceDomain);

        // get versioned target name
        string memory serviceTargetName = ObjectTypeLib.toVersionedName(
                ObjectTypeLib.toName(serviceDomain), 
                "Service", 
                getRelease().toInt());

        _serviceTarget[serviceDomain] = StrLib.toStr(serviceTargetName);

        RoleId serviceRoleId = getServiceRole(serviceDomain);
        string memory serviceRoleName = ObjectTypeLib.toVersionedName(
                ObjectTypeLib.toName(serviceDomain), 
                "ServiceRole", 
                getRelease().toInt());

        _addTargetWithRole(
            serviceTargetName,
            serviceRoleId,
            serviceRoleName);
    }


    /// @dev Use this method to to add an authorized role.
    function _addRole(RoleId roleId, RoleInfo memory info) internal {
        _roles.push(roleId);
        _roleInfo[roleId] = info;
    }


    /// @dev Add a contract role for the provided role id and name.
    function _addContractRole(RoleId roleId, string memory name) internal {
        _addRole(
            roleId,
            _toRoleInfo(
                ADMIN_ROLE(),
                RoleType.Contract,
                1,
                name));
    }


    /// @dev Add the versioned service role for the specified service domain
    function _addServiceRole(ObjectType serviceDomain) internal {
        _addContractRole(
            getServiceRole(serviceDomain),
            ObjectTypeLib.toVersionedName(
                ObjectTypeLib.toName(serviceDomain), 
                SERVICE_ROLE_NAME_SUFFIX, 
                getRelease().toInt()));
    }


    /// @dev Add a contract role for the provided role id and name.
    function _addCustomRole(RoleId roleId, RoleId adminRoleId, uint32 maxMemberCount, string memory name) internal {
        _addRole(
            roleId,
            _toRoleInfo(
                adminRoleId,
                RoleType.Custom,
                maxMemberCount,
                name));
    }


    /// @dev Use this method to to add an authorized target together with its target role.
    function _addTargetWithRole(
        string memory targetName, 
        RoleId roleId, 
        string memory roleName
    )
        internal
    {
        // add target
        Str target = StrLib.toStr(targetName);
        _targets.push(target);

        _targetExists[target] = true;

        // link role to target if defined
        if (roleId != RoleIdLib.zero()) {
            // add role if new
            if (!roleExists(roleId)) {
                _addContractRole(roleId, roleName);
            }

            // link target to role
            _targetRole[target] = roleId;
        }
    }


    /// @dev Use this method to to add an authorized target.
    function _addTarget(string memory name) internal {
        _addTargetWithRole(name, RoleIdLib.zero(), "");
    }


    /// @dev Use this method to authorize the specified role to access the target.
    function _authorizeForTarget(string memory target, RoleId authorizedRoleId)
        internal
        returns (IAccess.FunctionInfo[] storage authorizatedFunctions)
    {
        Str targetStr = StrLib.toStr(target);
        _authorizedRoles[targetStr].push(authorizedRoleId);
        return _authorizedFunctions[targetStr][authorizedRoleId];
    }


    /// @dev Use this method to authorize a specific function authorization
    function _authorize(IAccess.FunctionInfo[] storage functions, bytes4 selector, string memory name) internal {
        functions.push(
            IAccess.FunctionInfo({
                selector: SelectorLib.toSelector(selector),
                name: StrLib.toStr(name),
                createdAt: TimestampLib.blockTimestamp()}));
    }


    /// @dev role id for targets registry, staking and instance
    function _toTargetRoleId(ObjectType targetDomain) 
        internal
        pure
        returns (RoleId targetRoleId)
    {
        return RoleIdLib.roleForType(targetDomain);
    }


    function _toTargetRoleName(string memory targetName) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                targetName,
                ROLE_NAME_SUFFIX));
    }


    /// @dev creates a role info object from the provided parameters
    function _toRoleInfo(RoleId adminRoleId, RoleType roleType, uint32 maxMemberCount, string memory name) internal view returns (RoleInfo memory info) {
        return RoleInfo({
            name: StrLib.toStr(name),
            adminRoleId: adminRoleId,
            roleType: roleType,
            maxMemberCount: maxMemberCount,
            createdAt: TimestampLib.blockTimestamp(),
            pausedAt: TimestampLib.max()});
    }
}

