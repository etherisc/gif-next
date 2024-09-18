// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccess} from "./IAccess.sol";
import {IAuthorization} from "./IAuthorization.sol";

import {AccessAdminLib} from "./AccessAdminLib.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {RoleId, RoleIdLib} from "../type/RoleId.sol";
import {ServiceAuthorization} from "../authorization/ServiceAuthorization.sol";
import {Str, StrLib} from "../type/String.sol";
import {VersionPart} from "../type/Version.sol";

contract Authorization is
    ServiceAuthorization,
    IAuthorization
{

    // MUST match with AccessAdminLib.COMPONENT_ROLE_MIN
    uint64 public constant COMPONENT_ROLE_MIN = 110000;
    uint64 public constant INSTANCE_ROLE_MIN = 100000;

    uint64 internal _nextGifContractRoleId;
    uint64 internal _nextInstanceContractRoleId;

    string internal _tokenHandlerName = "ComponentTh";
    Str internal _tokenHandlerTarget;


    constructor(
        string memory mainTargetName, 
        ObjectType domain,
        VersionPart release,
        string memory commitHash,
        IAccess.TargetType targetType,
        bool includeTokenHandler
    )
        ServiceAuthorization(mainTargetName, domain, release, commitHash)
    {
        // IMPORTANT must match with AccessAdminLib.CORE_ROLE_MIN
        _nextGifContractRoleId = 100;
        _nextInstanceContractRoleId = INSTANCE_ROLE_MIN;

        // setup main target
        // special case: core targets
        if (targetType == IAccess.TargetType.Core) {
            _addGifTarget(_mainTargetName);
        // special case instances
        } else if (targetType == IAccess.TargetType.Instance) {
            _addInstanceTarget(_mainTargetName);
        // all other target types
        } else {
            if (domain.eqz()) {
                revert ErrorAuthorizationTargetDomainZero();
            }

            RoleId mainRoleId = RoleIdLib.toRoleId(COMPONENT_ROLE_MIN);
            string memory mainRoleName = _toTargetRoleName(_mainTargetName);

            _addTargetWithRole(
                _mainTargetName, 
                mainRoleId,
                mainRoleName);
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


    /// @dev Add a contract role for the provided role id and name.
    function _addCustomRole(RoleId roleId, RoleId adminRoleId, uint32 maxMemberCount, string memory name) internal {
        _addRole(
            roleId,
            AccessAdminLib.roleInfo(
                adminRoleId,
                TargetType.Custom,
                maxMemberCount,
                name));
    }

    /// @dev Add a gif target with its corresponding contract role
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

    /// @dev Add an instance target with its corresponding contract role
    function _addInstanceTarget(string memory contractName) internal {
        RoleId contractRoleId = RoleIdLib.toRoleId(_nextInstanceContractRoleId++);
        string memory contractRoleName = _toTargetRoleName(contractName);

        _addTargetWithRole(
            contractName, 
            contractRoleId,
            contractRoleName);
    }

    /// @dev Use this method to to add an authorized target.
    function _addTarget(string memory name) internal {
        _addTargetWithRole(name, RoleIdLib.zero(), "");
    }


    /// @dev Role id for targets registry, staking and instance
    function _toTargetRoleId(ObjectType targetDomain) 
        internal
        pure
        returns (RoleId targetRoleId)
    {
        return RoleIdLib.toRoleId(100 * targetDomain.toInt());
    }


    /// @dev Returns the role name for the specified target name
    function _toTargetRoleName(string memory targetName) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                targetName,
                ROLE_NAME_SUFFIX));
    }
}

