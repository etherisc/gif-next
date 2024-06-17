// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccess} from "../authorization/IAccess.sol";
import {RoleId} from "../type/RoleId.sol";
import {Str} from "../type/String.sol";
import {VersionPart} from "../type/Version.sol";

interface IModuleAuthorization {

     /// @dev Returns the release (VersionPart) for which the instance authorizations are defined by this contract.
     /// Matches with the release returned by the linked service authorization.
     function getRelease() external view returns(VersionPart release);

     /// @dev Returns the list of module targets.
     function getTargets() external view returns(Str[] memory targets);

     /// @dev Returns the list of involved roles.
     function getRoles() external view returns(RoleId[] memory roles);

     /// @dev For the given target the list of authorized role ids is returned
     function getAuthorizedRoles(Str target) external view returns(RoleId[] memory roleIds);

     /// @dev For the given target and role id the list of authorized functions is returned
     function getAuthorizedFunctions(Str target, RoleId roleId) external view returns(IAccess.FunctionInfo[] memory authorizatedFunctions);
}

