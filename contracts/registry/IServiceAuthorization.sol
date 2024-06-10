// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccessAdmin} from "../shared/IAccessAdmin.sol";
import {ObjectType} from "../../contracts/type/ObjectType.sol";
import {VersionPart} from "../../contracts/type/Version.sol";

interface IServiceAuthorization {

     /// @dev Returns the release (VersionPart) for which the service authorizations are defined by this contract.
     function getRelease()
          external
          view
          returns(VersionPart release);

     /// @dev Returns the full list of service domains for this release.
     /// Services need to be registered for the release in revers order of this list.
     function getServiceDomains() external view returns(ObjectType[] memory serviceDomains);


     /// @dev Given the service domain this function returns the list of other service domains that are authorized to access this service.
     function getAuthorizedDomains(ObjectType serviceDomain) external view returns(ObjectType[] memory authorizatedDomains);


     /// @dev For the given service domain and authorized domain the function returns the list of authorized functions
     function getAuthorizedFunctions(ObjectType serviceDomain, ObjectType authorizedDomain) external view returns(IAccessAdmin.Function[] memory authorizatedFunctions);
}

