// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ObjectType, REGISTRY, RELEASE, SERVICE} from "../../contracts/type/ObjectType.sol";
import {ServiceAuthorization} from "../../contracts/authorization/ServiceAuthorization.sol";
import {VersionPart} from "../../contracts/type/Version.sol";


contract ServiceAuthorizationMockWithRegistryService
     is ServiceAuthorization
{
     constructor(VersionPart release)
          ServiceAuthorization(
               "ReleaseAdmin",
               RELEASE(),
               release,
               COMMIT_HASH)
     {}

     function _setupDomains()
          internal
          override
     {
          _authorizeServiceDomain(REGISTRY(), address(1));
     }
}

contract ServiceAuthorizationMock is ServiceAuthorization
{

     ObjectType[] internal _domainsFromConstructor;

     constructor(
          VersionPart release, 
          ObjectType[] memory domains
     ) 
          ServiceAuthorization(
               "MockServiceAuthorization",
               SERVICE(),
               release,
               COMMIT_HASH
          )
     {
          _domainsFromConstructor = domains;
     }

     function _setupDomains()
          internal
          override
     {
          for (uint256 i = 0; i < _domainsFromConstructor.length; i++) {
               // address is 20 bytes which is uint160
               _authorizeServiceDomain(_domainsFromConstructor[i], address(uint160(1 + i)));
          }
     }
}