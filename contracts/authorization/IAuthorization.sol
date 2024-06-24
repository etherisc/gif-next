// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccess} from "../authorization/IAccess.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {RoleId} from "../type/RoleId.sol";
import {Str} from "../type/String.sol";
import {VersionPart} from "../type/Version.sol";

interface IAuthorization is 
     IAccess 
{

     /// @dev Returns the release (VersionPart) for which the authorizations are defined by this contract.
     /// Matches with the release returned by the linked service authorization.
     function getRelease() external view returns(VersionPart release);

     /// @dev Returns the list of involved roles.
     function getRoles() external view returns(RoleId[] memory roles);

     /// @dev Returns the service role for the specified service domain.
     function getServiceRole(ObjectType serviceDomain) external pure returns (RoleId serviceRoleId);

     /// @dev Returns the name for the provided role id.
     function getRoleInfo(RoleId roleId) external view returns (RoleInfo memory roleInfo);

     /// @dev Returns true iff the specified role id exists.
     function roleExists(RoleId roleId) external view returns(bool exists);

     /// @dev Returns the main target id name as string.
     /// This name is used to derive the target id and a corresponding target role name
     /// Overwrite this function to change the basic pool target name.
     function getTargetName() external view returns (string memory name);

     /// @dev Returns the main target.
     function getTarget() external view returns(Str target);

     /// @dev Returns the complete list of targets.
     function getTargets() external view returns(Str[] memory targets);

     /// @dev Returns true iff the specified target exists.
     function targetExists(Str target) external view returns(bool exists);

     /// @dev Returns the role id associated with the target.
     /// If no role is associated with the target the zero role id is returned.
     function getTargetRole(Str target) external view returns(RoleId roleId);

     /// @dev For the given target the list of authorized role ids is returned
     function getAuthorizedRoles(Str target) external view returns(RoleId[] memory roleIds);

     /// @dev For the given target and role id the list of authorized functions is returned
     function getAuthorizedFunctions(Str target, RoleId roleId) external view returns(FunctionInfo[] memory authorizatedFunctions);
}
