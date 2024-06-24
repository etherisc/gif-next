// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccess} from "../authorization/IAccess.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {IServiceAuthorization} from "./IServiceAuthorization.sol";
import {SelectorLib} from "../type/Selector.sol";
import {StrLib} from "../type/String.sol";
import {TimestampLib} from "../type/Timestamp.sol";
import {VersionPart, VersionPartLib} from "../type/Version.sol";

/// @dev Base contract for release specific service authorization contracts.
contract ServiceAuthorization
     is IServiceAuthorization
{
     uint256 public constant GIF_VERSION_3 = 3;

     string private _commitHash;

     ObjectType[] internal _serviceDomains;
     mapping(ObjectType domain => address service) internal _serviceAddress;
     mapping(ObjectType domain => ObjectType[] authorizedDomains) internal _authorizedDomains;
     mapping(ObjectType domain => mapping(ObjectType authorizedDomain => IAccess.FunctionInfo[] functions)) internal _authorizedFunctions;

     constructor(string memory commitHash) {
          _commitHash = commitHash;
          _setupDomains();
          _setupDomainAuthorizations();
     }

     function getCommitHash() external view returns(string memory commitHash) {
          return _commitHash;
     }

     function getRelease() external view returns(VersionPart release) {
          return VersionPartLib.toVersionPart(GIF_VERSION_3);
     }

     function getServiceDomains() external view returns(ObjectType[] memory serviceDomains) {
          return _serviceDomains;
     }

     function getServiceDomain(uint idx) external view returns(ObjectType serviceDomain) {
          return _serviceDomains[idx];
     }

     function getServiceAddress(ObjectType serviceDomain) external view returns(address service) {
          return _serviceAddress[serviceDomain];
     }

     function getAuthorizedDomains(ObjectType serviceDomain) external view returns(ObjectType[] memory authorizatedDomains) {
          return _authorizedDomains[serviceDomain];
     }

     function getAuthorizedFunctions(ObjectType serviceDomain, ObjectType authorizedDomain) external view returns(IAccess.FunctionInfo[] memory authorizatedFunctions) {
          return _authorizedFunctions[serviceDomain][authorizedDomain];
     }

     /// @dev Overwrite this function for a specific realease.
     function _setupDomains() internal virtual {}

     /// @dev Overwrite this function for a specific realease.
     function _setupDomainAuthorizations() internal virtual {}

     /// @dev Use this method to to add an authorized domain.
     /// The services will need to be registered in the order they are added using this function.
     function _authorizeDomain(ObjectType serviceDomain, address serviceAddress) internal {
          _serviceDomains.push(serviceDomain);
          _serviceAddress[serviceDomain] = serviceAddress;
     }

     /// @dev Use this method to authorize the specified domain to access the service domain.
     function _authorizeForService(ObjectType serviceDomain, ObjectType authorizedDomain)
          internal
          returns (IAccess.FunctionInfo[] storage authorizatedFunctions)
     {
          _authorizedDomains[serviceDomain].push(authorizedDomain);
          return _authorizedFunctions[serviceDomain][authorizedDomain];
     }

     /// @dev Use this method to authorize a specific function authorization
     function _authorize(IAccess.FunctionInfo[] storage functions, bytes4 selector, string memory name) internal {
          functions.push(
               IAccess.FunctionInfo({
                    selector: SelectorLib.toSelector(selector),
                    name: StrLib.toStr(name),
                    createdAt: TimestampLib.blockTimestamp()}));
     }
}
