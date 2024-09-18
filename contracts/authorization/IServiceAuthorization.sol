// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IAccess} from "../authorization/IAccess.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {RoleId} from "../type/RoleId.sol";
import {Str} from "../type/String.sol";
import {VersionPart} from "../type/Version.sol";

interface IServiceAuthorization is 
     IERC165, 
     IAccess
{

     error ErrorAuthorizationMainTargetNameEmpty();
     error ErrorAuthorizationTargetDomainZero();
     error ErrorAuthorizationReleaseInvalid(VersionPart release);
     error ErrorAuthorizationCommitHashInvalid(string commitHash);

     /// @dev Returns the main domain of the authorization.
     function getDomain() external view returns(ObjectType targetDomain);

     /// @dev Returns the release (VersionPart) for which the authorizations are defined by this contract.
     /// Matches with the release returned by the linked service authorization.
     function getRelease() external view returns(VersionPart release);

     /// @dev Returns the commit hash for the related GIF release.
     function getCommitHash() external view returns(string memory commitHash);

     /// @dev Returns the main target id name as string.
     /// This name is used to derive the target id and a corresponding target role name
     /// Overwrite this function to change the basic pool target name.
     function getMainTargetName() external view returns (string memory name);

     /// @dev Returns the main target.
     function getMainTarget() external view returns(Str target);

     /// @dev Returns the full list of service domains for this release.
     /// Services need to be registered for the release in revers order of this list.
     function getServiceDomains() external view returns(ObjectType[] memory serviceDomains);

     /// @dev Returns the service domain for the provided index.
     function getServiceDomain(uint256 idx) external view returns(ObjectType serviceDomain);

     /// @dev Returns the service target for the specified domain.
     function getServiceTarget(ObjectType serviceDomain) external view returns(Str serviceTarget);

     /// @dev Returns the service target for the specified domain.
     function getServiceRole(ObjectType serviceDomain) external view returns(RoleId serviceRoleId);

     /// @dev Returns the expected service address for the provided domain.
     function getServiceAddress(ObjectType serviceDomain) external view returns(address service);

     /// @dev Returns the role id associated with the target.
     /// If no role is associated with the target the zero role id is returned.
     function getTargetRole(Str target) external view returns(RoleId roleId);

     /// @dev Returns true iff the role exists.
     function roleExists(RoleId roleId) external view returns(bool exists);

     /// @dev Returns the list of involved roles.
     function getRoles() external view returns(RoleId[] memory roles);

     /// @dev Returns the role info for the provided role id.
     function getRoleInfo(RoleId roleId) external view returns (RoleInfo memory roleInfo);

     /// @dev Returns the name for the provided role id.
     function getRoleName(RoleId roleId) external view returns (string memory roleName);

     /// @dev For the given target the list of authorized role ids is returned
     function getAuthorizedRoles(Str target) external view returns(RoleId[] memory roleIds);

     /// @dev For the given target and role id the list of authorized functions is returned
     function getAuthorizedFunctions(Str target, RoleId roleId) external view returns(FunctionInfo[] memory authorizatedFunctions);
}

