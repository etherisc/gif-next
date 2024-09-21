// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccess} from "../authorization/IAccess.sol";
import {IServiceAuthorization} from "./IServiceAuthorization.sol";

import {AccessAdminLib} from "./AccessAdminLib.sol";
import {BlocknumberLib} from "../type/Blocknumber.sol";
import {InitializableERC165} from "../shared/InitializableERC165.sol";
import {ObjectType, ObjectTypeLib, ALL} from "../type/ObjectType.sol";
import {RoleId, RoleIdLib, ADMIN_ROLE, PUBLIC_ROLE} from "../type/RoleId.sol";
import {SelectorLib} from "../type/Selector.sol";
import {Str, StrLib} from "../type/String.sol";
import {TimestampLib} from "../type/Timestamp.sol";
import {VersionPart, VersionPartLib} from "../type/Version.sol";


/// @dev Base contract for release specific service authorization contracts and for Authorization contracts.
contract ServiceAuthorization is 
     InitializableERC165,
     IServiceAuthorization
{

     string public constant COMMIT_HASH = "1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a";

     uint256 public constant COMMIT_HASH_LENGTH = 40;
     uint256 public constant GIF_INITIAL_VERSION = 3;

     string public constant SERVICE_NAME_SUFFIX = "Service";
     string public constant ROLE_NAME_SUFFIX = "_Role";

     ObjectType public immutable DOMAIN;
     uint256 internal immutable _release;
     string internal _commitHash;

     string internal _mainTargetName;
     Str internal _mainTarget;

     // services
     ObjectType[] internal _serviceDomains;
     mapping(ObjectType domain => address service) internal _serviceAddress;

     // roles
     RoleId[] internal _roles;
     mapping(RoleId role => RoleInfo info) internal _roleInfo;

     // targets
     Str[] internal _targets;
     mapping(Str target => bool exists) internal _targetExists;
     mapping(Str target => RoleId roleId) internal _targetRole;
     mapping(Str target => RoleId[] authorizedRoles) internal _authorizedRoles;
     mapping(Str target => mapping(RoleId authorizedRole => IAccess.FunctionInfo[] functions)) internal _authorizedFunctions;


     constructor(
          string memory mainTargetName, 
          ObjectType domain,
          uint8 release,
          string memory commitHash
     )
     {
          // checks
          if (bytes(mainTargetName).length == 0) {
               revert ErrorAuthorizationMainTargetNameEmpty();
          }

          if (domain == ObjectTypeLib.zero()) {
               revert ErrorAuthorizationTargetDomainZero();
          }

          if (release < VersionPartLib.releaseMin().toInt() || release >= VersionPartLib.releaseMax().toInt()) {
               revert ErrorAuthorizationReleaseInvalid(release);
          }

          if (bytes(commitHash).length != COMMIT_HASH_LENGTH) {
               revert ErrorAuthorizationCommitHashInvalid(commitHash);
          }

          // effects
          _initializeERC165();
          _registerInterfaceNotInitializing(type(IServiceAuthorization).interfaceId);

          _mainTargetName = mainTargetName;
          _mainTarget = StrLib.toStr(mainTargetName);

          DOMAIN = domain;
          _release = release;
          _commitHash = commitHash;

          // setup of roles defined in OpenZeppelin AccessManager
          _addRole(ADMIN_ROLE(), AccessAdminLib.adminRoleInfo());
          _addRole(PUBLIC_ROLE(), AccessAdminLib.publicRoleInfo());

          // defines service domains relevant for the authorization
          _setupDomains();
          _setupDomainAuthorizations();
     }

     /// @inheritdoc IServiceAuthorization
     function getDomain() public view returns(ObjectType targetDomain) {
          return DOMAIN;
     }

     /// @inheritdoc IServiceAuthorization
     function getRelease() public view returns(VersionPart release) {
          return VersionPartLib.toVersionPart(_release);
     }

     /// @inheritdoc IServiceAuthorization
     function getCommitHash() external view returns(string memory commitHash) {
          return _commitHash;
     }

     /// @inheritdoc IServiceAuthorization
     function getMainTargetName() public view returns (string memory name) {
          return _mainTargetName;
     }

     /// @inheritdoc IServiceAuthorization
     function getMainTarget() external view returns(Str target) {
          return _mainTarget;
     }

     /// @inheritdoc IServiceAuthorization
     function getServiceDomains() external view returns(ObjectType[] memory serviceDomains) {
          return _serviceDomains;
     }

     /// @inheritdoc IServiceAuthorization
     function getServiceDomain(uint256 idx) external view returns(ObjectType serviceDomain) {
          return _serviceDomains[idx];
     }

     /// @inheritdoc IServiceAuthorization
     function getServiceTarget(ObjectType serviceDomain) public view returns(Str target) {
          string memory serviceTargetName = ObjectTypeLib.toVersionedName(
               ObjectTypeLib.toName(serviceDomain), 
               "Service", 
               getRelease());

          return StrLib.toStr(serviceTargetName);
     }

     /// @inheritdoc IServiceAuthorization
     function getServiceRole(ObjectType serviceDomain) public view returns(RoleId serviceRoleId) {
          // special case domain ALL
          if (serviceDomain == ALL()) {
               return PUBLIC_ROLE();
          }

          Str target = getServiceTarget(serviceDomain);
          return getTargetRole(target);
     }

     /// @inheritdoc IServiceAuthorization
     function getServiceAddress(ObjectType serviceDomain) external view returns(address service) {
          return _serviceAddress[serviceDomain];
     }

     /// @inheritdoc IServiceAuthorization
     function getTargetRole(Str target) public view returns(RoleId roleId) {
          return _targetRole[target];
     }

     /// @inheritdoc IServiceAuthorization
     function roleExists(RoleId roleId) public view returns(bool exists) {
          return _roleInfo[roleId].roleType != RoleType.Undefined;
     }

     /// @inheritdoc IServiceAuthorization
     function getRoles() external view returns(RoleId[] memory roles) {
          return _roles;
     }

     /// @inheritdoc IServiceAuthorization
     function getRoleInfo(RoleId roleId) external view returns (RoleInfo memory info) {
          return _roleInfo[roleId];
     }

     /// @inheritdoc IServiceAuthorization
     function getRoleName(RoleId roleId) external view returns (string memory roleName) {
          return _roleInfo[roleId].name.toString();
     }

     /// @inheritdoc IServiceAuthorization
     function getAuthorizedRoles(Str target) external view returns(RoleId[] memory roleIds) {
          return _authorizedRoles[target];
     }

     /// @inheritdoc IServiceAuthorization
     function getAuthorizedFunctions(Str target, RoleId roleId) external view returns(FunctionInfo[] memory authorizatedFunctions) {
          return _authorizedFunctions[target][roleId];
     }

     /// @dev Defines service domains relevant for the authorization.
     /// When used for ReleaseAdmin the list defines the services to be registered for the release.
     /// IMPORTANT: Both the list of the service domains as well as the ordering of the domains is important.
     /// Trying to register services not in this list or register services in a different order will result in an error.
     // solhint-disable-next-line no-empty-blocks
     function _setupDomains() internal virtual {}

     /// @dev Overwrite this function for a specific realease.
     // solhint-disable-next-line no-empty-blocks
     function _setupDomainAuthorizations() internal virtual {}

     /// @dev Use this method to to add an authorized domain.
     /// The services will need to be registered in the order they are added using this function.
     function _authorizeServiceDomain(ObjectType serviceDomain, address serviceAddress) internal {
          _serviceDomains.push(serviceDomain);
          _serviceAddress[serviceDomain] = serviceAddress;

          string memory serviceName = ObjectTypeLib.toVersionedName(
               ObjectTypeLib.toName(serviceDomain), 
               SERVICE_NAME_SUFFIX, 
               getRelease());

          _addTargetWithRole(
               serviceName, 
               RoleIdLib.toServiceRoleId(serviceDomain, getRelease()), 
               string(abi.encodePacked(serviceName, ROLE_NAME_SUFFIX)));
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
                    _addRole(
                         roleId, 
                         AccessAdminLib.contractRoleInfo(
                              roleName));
               }

               // link target to role
               _targetRole[target] = roleId;
          }
     }


     /// @dev Use this method to to add an authorized role.
     function _addRole(RoleId roleId, RoleInfo memory info) internal {
          _roles.push(roleId);
          _roleInfo[roleId] = info;
     }


     /// @dev Use this method to authorize the specified domain to access the service domain.
     function _authorizeForService(
          ObjectType serviceDomain, 
          ObjectType authorizedDomain
     )
          internal
          returns (IAccess.FunctionInfo[] storage authorizatedFunctions)
     {
          Str serviceTarget = getServiceTarget(serviceDomain);
          RoleId authorizedRoleId = getServiceRole(authorizedDomain);

          return _authorizeForTarget(serviceTarget.toString(), authorizedRoleId);
     }


     /// @dev Use this method to authorize the specified role to access the target.
     function _authorizeForTarget(string memory target, RoleId authorizedRoleId)
          internal
          returns (IAccess.FunctionInfo[] storage authorizatedFunctions)
     {
          Str targetStr = StrLib.toStr(target);

          // add authorized role if not already added
          if (_authorizedFunctions[targetStr][authorizedRoleId].length == 0) {
               _authorizedRoles[targetStr].push(authorizedRoleId);
          }

          return _authorizedFunctions[targetStr][authorizedRoleId];
     }


     /// @dev Use this method to authorize a specific function authorization
     function _authorize(IAccess.FunctionInfo[] storage functions, bytes4 selector, string memory name) internal {
          functions.push(
               IAccess.FunctionInfo({
                    selector: SelectorLib.toSelector(selector),
                    name: StrLib.toStr(name),
                    createdAt: TimestampLib.current(),
                    lastUpdateIn: BlocknumberLib.current()}));
     }
}