// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccess} from "./IAccess.sol";
import {IAuthorization} from "./IAuthorization.sol";

import {ADMIN_ROLE_NAME, PUBLIC_ROLE_NAME} from "./AccessAdmin.sol";
import {ObjectType, ObjectTypeLib} from "../type/ObjectType.sol";
import {RoleId, RoleIdLib, ADMIN_ROLE, PUBLIC_ROLE} from "../type/RoleId.sol";
import {SelectorLib} from "../type/Selector.sol";
import {ServiceAuthorization} from "../authorization/ServiceAuthorization.sol";
import {Str, StrLib} from "../type/String.sol";
import {TimestampLib} from "../type/Timestamp.sol";
import {VersionPart, VersionPartLib} from "../type/Version.sol";


contract Authorization is
    ServiceAuthorization,
    IAuthorization
{

    // MUST match with AccessAdminLib.COMPONENT_ROLE_MIN
    uint64 public constant COMPONENT_ROLE_MIN = 110000;

    uint64 internal _nextGifContractRoleId;
    // mapping(ObjectType domain => Str target) internal _serviceTarget;

    string internal _tokenHandlerName = "ComponentTh";

    Str internal _tokenHandlerTarget;


    constructor(
        string memory mainTargetName, 
        ObjectType domain,
        uint8 release,
        string memory commitHash,
        bool isComponent,
        bool includeTokenHandler
    )
        ServiceAuthorization(mainTargetName, domain, release, commitHash)
    {
        _nextGifContractRoleId = 10;

        // setup main target
        if (isComponent) {
            if (domain.eqz()) {
                revert ErrorAuthorizationTargetDomainZero();
            }

            RoleId mainRoleId = RoleIdLib.toRoleId(COMPONENT_ROLE_MIN);
            string memory mainRolName = _toTargetRoleName(_mainTargetName);

            _addTargetWithRole(
                _mainTargetName, 
                mainRoleId,
                mainRolName);
        } else {
            _addGifTarget(_mainTargetName);
        }

        // setup use case specific parts
        _setupServiceTargets();
        _setupRoles(); // not including main target role
        _setupTargets(); // not including main target (and token handler target)
        _setupTargetAuthorizations(); // not including token handler target

        // setup component token handler 
        if (includeTokenHandler) {
            _tokenHandlerName = string(abi.encodePacked(mainTargetName, "Th"));
            _tokenHandlerTarget = StrLib.toStr(_tokenHandlerName);
            _addTarget(_tokenHandlerName);
            _setupTokenHandlerAuthorizations();
        }

        _registerInterfaceNotInitializing(type(IAuthorization).interfaceId);
    }


    // TODO cleanup
    // function roleExists(RoleId roleId) public view returns(bool exists) {
    //     return _roleInfo[roleId].roleType != RoleType.Undefined;
    // }


    function getTokenHandlerName() public view returns(string memory) {
        return _tokenHandlerName;
    }

    function getTokenHandlerTarget() public view returns(Str) {
        return _tokenHandlerTarget;
    }

    function getTarget(string memory targetName) public pure returns(Str target) {
        return StrLib.toStr(targetName);
    }

    function getTargets() external view returns(Str[] memory targets) {
        return _targets;
    }

    function targetExists(Str target) external view returns(bool exists) {
        return target == _mainTarget || _targetExists[target];
    }

    // TODO cleanup
    // function getTargetRole(Str target) public view returns(RoleId roleId) {
    //     return _targetRole[target];
    // }

    // function getAuthorizedRoles(Str target) external view returns(RoleId[] memory roleIds) {
    //     return _authorizedRoles[target];
    // }

    // function getAuthorizedFunctions(Str target, RoleId roleId) external view returns(IAccess.FunctionInfo[] memory authorizatedFunctions) {
    //     return _authorizedFunctions[target][roleId];
    // }

    /// @dev Sets up the relevant service targets for the component.
    /// Overwrite this function for use case specific authorizations.
    // solhint-disable-next-line no-empty-blocks
    function _setupServiceTargets() internal virtual { }

    /// @dev Sets up the relevant (non-service) targets for the component.
    /// Overwrite this function for use case specific authorizations.
    // solhint-disable-next-line no-empty-blocks
    function _setupTargets() internal virtual { }

    /// @dev Sets up the relevant roles for the component.
    /// Overwrite this function for use case specific authorizations.
    // solhint-disable-next-line no-empty-blocks
    function _setupRoles() internal virtual {}

    /// @dev Sets up the relevant component's token handler authorizations.
    /// Overwrite this function for use case specific authorizations.
    // solhint-disable-next-line no-empty-blocks
    function _setupTokenHandlerAuthorizations() internal virtual {}

    /// @dev Sets up the relevant target authorizations for the component.
    /// Overwrite this function for use case specific authorizations.
    // solhint-disable-next-line no-empty-blocks
    function _setupTargetAuthorizations() internal virtual {}

    function _addGifTarget(string memory contractName) internal {

        RoleId contractRoleId = RoleIdLib.toRoleId(_nextGifContractRoleId++);
        string memory contractRoleName = string(
            abi.encodePacked(
                contractName,
                ROLE_NAME_SUFFIX));

        _addTargetWithRole(
            contractName,
            contractRoleId,
            contractRoleName);
    }

    // TODO cleanup
    // /// @dev Add the service target role for the specified service domain
    // function _addServiceTargetWithRole(ObjectType serviceDomain) internal {
    //     // add service domain
    //     _serviceDomains.push(serviceDomain);

    //     // get versioned target name
    //     string memory serviceTargetName = ObjectTypeLib.toVersionedName(
    //             ObjectTypeLib.toName(serviceDomain), 
    //             "Service", 
    //             getRelease());

    //     // _serviceTarget[serviceDomain] = StrLib.toStr(serviceTargetName);

    //     RoleId serviceRoleId = getServiceRole(serviceDomain);
    //     string memory serviceRoleName = ObjectTypeLib.toVersionedName(
    //             ObjectTypeLib.toName(serviceDomain), 
    //             "ServiceRole", 
    //             getRelease());

    //     _addTargetWithRole(
    //         serviceTargetName,
    //         serviceRoleId,
    //         serviceRoleName);
    // }


    // /// @dev Use this method to to add an authorized role.
    // function _addRole(RoleId roleId, RoleInfo memory info) internal {
    //     _roles.push(roleId);
    //     _roleInfo[roleId] = info;
    // }


    // /// @dev Add a contract role for the provided role id and name.
    // function _addContractRole(RoleId roleId, string memory name) internal {
    //     _addRole(
    //         roleId,
    //         _toRoleInfo(
    //             ADMIN_ROLE(),
    //             RoleType.Contract,
    //             1,
    //             name));
    // }


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


    /// @dev Use this method to to add an authorized target.
    function _addTarget(string memory name) internal {
        _addTargetWithRole(name, RoleIdLib.zero(), "");
    }

    // TODO cleanup
    // /// @dev Use this method to authorize a specific function authorization
    // function _authorize(IAccess.FunctionInfo[] storage functions, bytes4 selector, string memory name) internal {
    //     functions.push(
    //         IAccess.FunctionInfo({
    //             selector: SelectorLib.toSelector(selector),
    //             name: StrLib.toStr(name),
    //             createdAt: TimestampLib.blockTimestamp()}));
    // }


    /// @dev role id for targets registry, staking and instance
    function _toTargetRoleId(ObjectType targetDomain) 
        internal
        pure
        returns (RoleId targetRoleId)
    {
        return RoleIdLib.toRoleId(100 * targetDomain.toInt());
    }


    function _toTargetRoleName(string memory targetName) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                targetName,
                ROLE_NAME_SUFFIX));
    }

    // TODO cleanup
    // /// @dev creates a role info object from the provided parameters
    // function _toRoleInfo(RoleId adminRoleId, RoleType roleType, uint32 maxMemberCount, string memory name) internal view returns (RoleInfo memory info) {
    //     return RoleInfo({
    //         name: StrLib.toStr(name),
    //         adminRoleId: adminRoleId,
    //         roleType: roleType,
    //         maxMemberCount: maxMemberCount,
    //         createdAt: TimestampLib.blockTimestamp(),
    //         pausedAt: TimestampLib.max()});
    // }
}

