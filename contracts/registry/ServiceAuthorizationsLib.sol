// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {
     RoleId, 
     PRODUCT_OWNER_ROLE, POOL_OWNER_ROLE, ORACLE_OWNER_ROLE,
     APPLICATION_SERVICE_ROLE, BUNDLE_SERVICE_ROLE, COMPONENT_SERVICE_ROLE, DISTRIBUTION_SERVICE_ROLE, INSTANCE_SERVICE_ROLE, POLICY_SERVICE_ROLE, POOL_SERVICE_ROLE, PRODUCT_SERVICE_ROLE, STAKING_SERVICE_ROLE
} from "../../contracts/type/RoleId.sol";

import {
     ObjectType, 
     REGISTRY, SERVICE, PRODUCT, ORACLE, POOL, INSTANCE, COMPONENT, DISTRIBUTION, DISTRIBUTOR, APPLICATION, POLICY, CLAIM, BUNDLE, STAKE, STAKING, PRICE
} from "../../contracts/type/ObjectType.sol";

import {ComponentService} from "../shared/ComponentService.sol";
import {InstanceService} from "../instance/InstanceService.sol";
import {RegistryService} from "./RegistryService.sol";

library ServiceAuthorizationsLib {

     struct ServiceAuthorization {
          RoleId[] authorizedRole;
          bytes4[][] authorizedSelectors;
     }

     /// @dev returns the full list of gif service domains for this release.
     /// services need to be registered for the release in revers order of this list.
     function getDomains()
          external
          pure
          returns(
               ObjectType[] memory domain
          )
     {
          domain = new ObjectType[](11);
          domain[0] = POLICY();
          domain[1] = APPLICATION();
          domain[2] = CLAIM();
          domain[3] = PRODUCT();
          domain[4] = POOL();
          domain[5] = BUNDLE();
          domain[6] = PRICE();
          domain[7] = DISTRIBUTION();
          domain[8] = COMPONENT();
          domain[9] = INSTANCE();
          domain[10] = STAKING();
     }


     /// @dev given the target domain this function returns the list of authorized function signatures per authorized domain.
     function getAuthorizations(ObjectType domain)
          external
          pure
          returns(
               ServiceAuthorization memory authorizations
          )
     {
          if(domain == REGISTRY()) { return _getRegistryServiceAuthorization(); }
          if(domain == INSTANCE()) { return _getInstanceServiceAuthorization(); }
          if(domain == COMPONENT()) { return _getComponentServiceAuthorization(); }

          // disallows access to all functions with a restricted modifier
          return _getDefaultAuthorizations();
     }


     /// @dev registry service authorization.
     /// returns all authorized function signatures per authorized domain.
     /// all listed functions MUST be implemented with a restricted modifier
     function _getRegistryServiceAuthorization()
          internal
          pure
          returns (ServiceAuthorization memory authz)
     {
          uint8 authorizedRoles = 8;
          authz.authorizedRole = new RoleId[](authorizedRoles);
          authz.authorizedSelectors = new bytes4[][](authorizedRoles);

          // TODO role ids need to have a stable setup, this is not the case currently
          authz.authorizedRole[0] = APPLICATION_SERVICE_ROLE();
          authz.authorizedSelectors[0] = new bytes4[](1);
          authz.authorizedSelectors[0][0] = RegistryService.registerPolicy.selector;

          authz.authorizedRole[1] = POOL_SERVICE_ROLE();
          authz.authorizedSelectors[1] = new bytes4[](1);
          authz.authorizedSelectors[1][0] = RegistryService.registerPool.selector;

          authz.authorizedRole[2] = BUNDLE_SERVICE_ROLE();
          authz.authorizedSelectors[2] = new bytes4[](1);
          authz.authorizedSelectors[2][0] = RegistryService.registerBundle.selector;

          authz.authorizedRole[3] = DISTRIBUTION_SERVICE_ROLE();
          authz.authorizedSelectors[3] = new bytes4[](2);
          authz.authorizedSelectors[3][0] = RegistryService.registerDistribution.selector;
          authz.authorizedSelectors[3][1] = RegistryService.registerDistributor.selector;

          authz.authorizedRole[4] = COMPONENT_SERVICE_ROLE();
          authz.authorizedSelectors[4] = new bytes4[](1);
          authz.authorizedSelectors[4][0] = RegistryService.registerComponent.selector;

          authz.authorizedRole[5] = INSTANCE_SERVICE_ROLE();
          authz.authorizedSelectors[5] = new bytes4[](1);
          authz.authorizedSelectors[5][0] = RegistryService.registerInstance.selector;

          authz.authorizedRole[6] = STAKING_SERVICE_ROLE();
          authz.authorizedSelectors[6] = new bytes4[](1);
          authz.authorizedSelectors[6][0] = RegistryService.registerStaking.selector;

          authz.authorizedRole[7] = PRODUCT_SERVICE_ROLE();
          authz.authorizedSelectors[7] = new bytes4[](1);
          authz.authorizedSelectors[7][0] = RegistryService.registerProduct.selector;
     }


     /// @dev instance service authorization.
     /// returns all authorized function signatures per authorized domain.
     /// all listed functions MUST be implemented with a restricted modifier
     function _getInstanceServiceAuthorization()
          internal
          pure
          returns (ServiceAuthorization memory authz)
     {
          uint8 authorizedRoles = 1;
          authz.authorizedRole = new RoleId[](authorizedRoles);
          authz.authorizedSelectors = new bytes4[][](authorizedRoles);

          authz.authorizedRole[0] = COMPONENT_SERVICE_ROLE();
          authz.authorizedSelectors[0] = new bytes4[](1);
          authz.authorizedSelectors[0][0] = InstanceService.createComponentTarget.selector;
     }


     /// @dev component service authorization.
     /// returns all authorized function signatures per authorized domain.
     /// all listed functions MUST be implemented with a restricted modifier
     function _getComponentServiceAuthorization()
          internal
          pure
          returns (ServiceAuthorization memory authz)
     {
          uint8 authorizedRoles = 4;
          authz.authorizedRole = new RoleId[](authorizedRoles);
          authz.authorizedSelectors = new bytes4[][](authorizedRoles);

          authz.authorizedRole[0] = POLICY_SERVICE_ROLE();
          authz.authorizedSelectors[0] = new bytes4[](1);
          authz.authorizedSelectors[0][0] = ComponentService.increaseProductFees.selector;

          authz.authorizedRole[1] = DISTRIBUTION_SERVICE_ROLE();
          authz.authorizedSelectors[1] = new bytes4[](1);
          authz.authorizedSelectors[1][0] = ComponentService.increaseDistributionBalance.selector;

          authz.authorizedRole[2] = POOL_SERVICE_ROLE();
          authz.authorizedSelectors[2] = new bytes4[](1);
          authz.authorizedSelectors[2][0] = ComponentService.increasePoolBalance.selector;

          authz.authorizedRole[3] = BUNDLE_SERVICE_ROLE();
          authz.authorizedSelectors[3] = new bytes4[](1);
          authz.authorizedSelectors[3][0] = ComponentService.increaseBundleBalance.selector;
     }


     function _getDefaultAuthorizations()
          internal
          pure
          returns (ServiceAuthorization memory authz)
     {
          uint8 authorizedRoles = 0;
          authz.authorizedRole = new RoleId[](authorizedRoles);
          authz.authorizedSelectors = new bytes4[][](authorizedRoles);
     }
}

