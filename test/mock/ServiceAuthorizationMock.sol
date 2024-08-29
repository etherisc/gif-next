// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {
     ObjectType, ALL, RELEASE, REGISTRY, SERVICE, PRODUCT, ORACLE, POOL, INSTANCE, COMPONENT, DISTRIBUTION, DISTRIBUTOR, APPLICATION, POLICY, CLAIM, BUNDLE, STAKE, STAKING, PRICE
} from "../../contracts/type/ObjectType.sol";
import {VersionPart} from "../../contracts/type/Version.sol";


import {IAccess} from "../../contracts/authorization/IAccess.sol";
import {IRegistryService} from "../../contracts/registry/IRegistryService.sol";
import {IServiceAuthorization} from "../../contracts/authorization/IServiceAuthorization.sol";
import {ServiceAuthorization} from "../../contracts/authorization/ServiceAuthorization.sol";


contract ServiceAuthorizationMockWithRegistryService
     is ServiceAuthorization
{
     constructor(VersionPart release)
          ServiceAuthorization(
               "ReleaseAdmin",
               RELEASE(),
               uint8(release.toInt()),
               COMMIT_HASH)
     {}

     function _setupDomains()
          internal
          override
     {
          _authorizeServiceDomain(REGISTRY(), address(1));
          _authorizeServiceDomain(APPLICATION(), address(2));
          _authorizeServiceDomain(BUNDLE(), address(3));
          _authorizeServiceDomain(DISTRIBUTION(), address(4));
          _authorizeServiceDomain(COMPONENT(), address(5));
          _authorizeServiceDomain(INSTANCE(), address(6));
          _authorizeServiceDomain(STAKING(), address(7));
     }

     function _setupDomainAuthorizations()
          internal
          override
     {
          _setupIRegistryServiceAuthorization();
     }


     function _setupIRegistryServiceAuthorization()
          internal
     {
          IAccess.FunctionInfo[] storage functions;

          functions = _authorizeForService(REGISTRY(), APPLICATION());
          _authorize(functions, IRegistryService.registerPolicy.selector, "registerPolicy");

          // functions = _authorizeForService(REGISTRY(), POOL());
          // _authorize(functions, IRegistryService.registerPool.selector, "registerPool");

          functions = _authorizeForService(REGISTRY(), BUNDLE());
          _authorize(functions, IRegistryService.registerBundle.selector, "registerBundle");

          functions = _authorizeForService(REGISTRY(), DISTRIBUTION());
          // _authorize(functions, IRegistryService.registerDistribution.selector, "registerDistribution");
          _authorize(functions, IRegistryService.registerDistributor.selector, "registerDistributor");

          functions = _authorizeForService(REGISTRY(), COMPONENT());
          _authorize(functions, IRegistryService.registerProduct.selector, "registerProduct");

          functions = _authorizeForService(REGISTRY(), COMPONENT());
          _authorize(functions, IRegistryService.registerProductLinkedComponent.selector, "registerProductLinkedComponent");

          functions = _authorizeForService(REGISTRY(), INSTANCE());
          _authorize(functions, IRegistryService.registerInstance.selector, "registerInstance");

          functions = _authorizeForService(REGISTRY(), STAKING());
          _authorize(functions, IRegistryService.registerStake.selector, "registerStake");

          // functions = _authorizeForService(REGISTRY(), PRODUCT());
          // _authorize(functions, IRegistryService.registerProduct.selector, "registerProduct");
     }
}

contract ServiceAuthorizationMock is ServiceAuthorization
{

     constructor(
          VersionPart release, 
          ObjectType[] memory domains
     ) 
          ServiceAuthorization(
               "MockServiceAuthorization",
               SERVICE(),
               uint8(release.toInt()),
               COMMIT_HASH
          )
     {
          _serviceDomains = domains;
     }
}