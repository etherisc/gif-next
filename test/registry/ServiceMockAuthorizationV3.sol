// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {
     ALL, REGISTRY, SERVICE, PRODUCT, ORACLE, POOL, INSTANCE, COMPONENT, DISTRIBUTION, DISTRIBUTOR, APPLICATION, POLICY, CLAIM, BUNDLE, STAKE, STAKING, PRICE
} from "../../contracts/type/ObjectType.sol";

import {IAccess} from "../../contracts/authorization/IAccess.sol";
import {IRegistryService} from "../../contracts/registry/IRegistryService.sol";
import {ServiceAuthorization} from "../../contracts/authorization/ServiceAuthorization.sol";


contract ServiceMockAuthorizationV3
     is ServiceAuthorization
{

     constructor()
          ServiceAuthorization("1db548e7d69f8974042d01be522cbd5d097a0dd2")
     {}

     function _setupDomains()
          internal
          override
     {
          _authorizeDomain(REGISTRY(), address(1));
     }


     function _setupDomainAuthorizations()
          internal
          override
     {
          _setupIRegistryServiceAuthorization();
     }


     /// @dev registry service authorization.
     /// authorized functions MUST be implemented with a restricted modifier
     function _setupIRegistryServiceAuthorization()
          internal
     {
          IAccess.FunctionInfo[] storage functions;

          functions = _authorizeForService(REGISTRY(), APPLICATION());
          _authorize(functions, IRegistryService.registerPolicy.selector, "registerPolicy");

          functions = _authorizeForService(REGISTRY(), POOL());
          _authorize(functions, IRegistryService.registerPool.selector, "registerPool");

          functions = _authorizeForService(REGISTRY(), BUNDLE());
          _authorize(functions, IRegistryService.registerBundle.selector, "registerBundle");

          functions = _authorizeForService(REGISTRY(), DISTRIBUTION());
          _authorize(functions, IRegistryService.registerDistribution.selector, "registerDistribution");
          _authorize(functions, IRegistryService.registerDistributor.selector, "registerDistributor");

          functions = _authorizeForService(REGISTRY(), COMPONENT());
          _authorize(functions, IRegistryService.registerComponent.selector, "registerComponent");

          functions = _authorizeForService(REGISTRY(), INSTANCE());
          _authorize(functions, IRegistryService.registerInstance.selector, "registerInstance");

          functions = _authorizeForService(REGISTRY(), STAKING());
          _authorize(functions, IRegistryService.registerStake.selector, "registerStake");

          functions = _authorizeForService(REGISTRY(), PRODUCT());
          _authorize(functions, IRegistryService.registerProduct.selector, "registerProduct");
     }
}

