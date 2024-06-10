// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {
     ObjectType, 
     REGISTRY, SERVICE, PRODUCT, ORACLE, POOL, INSTANCE, COMPONENT, DISTRIBUTION, DISTRIBUTOR, APPLICATION, POLICY, CLAIM, BUNDLE, STAKE, STAKING, PRICE
} from "../../contracts/type/ObjectType.sol";

import {ComponentService} from "../shared/ComponentService.sol";
import {IAccessAdmin} from "../shared/IAccessAdmin.sol";
import {IBundleService} from "../pool/IBundleService.sol";
import {IDistributionService} from "../distribution/IDistributionService.sol";
import {InstanceService} from "../instance/InstanceService.sol";
import {IInstanceService} from "../instance/IInstanceService.sol";
import {IPoolService} from "../pool/IPoolService.sol";
import {IServiceAuthorization} from "./IServiceAuthorization.sol";
import {IStakingService} from "../staking/IStakingService.sol";
import {IRegistryService} from "./IRegistryService.sol";
import {SelectorLib} from "../../contracts/type/Selector.sol";
import {StrLib} from "../../contracts/type/String.sol";
import {VersionPart, VersionPartLib} from "../../contracts/type/Version.sol";


contract ServiceAuthorizationV3
     is IServiceAuthorization
{
     uint256 public constant GIF_VERSION = 3;

     ObjectType[] private _serviceDomains;
     mapping(ObjectType domain => ObjectType[] authorizedDomains) private _authorizedDomains;
     mapping(ObjectType domain => mapping(ObjectType authorizedDomain => IAccessAdmin.Function[] functions)) private _authorizedFunctions;

     constructor() {
          _setupDomains();
          _setupDomainAuthorizations();
     }

     function getRelease() external pure returns(VersionPart release) {
          return VersionPartLib.toVersionPart(GIF_VERSION);
     }

     function getServiceDomains() external view returns(ObjectType[] memory serviceDomains) {
          return _serviceDomains;
     }

     function getAuthorizedDomains(ObjectType serviceDomain) external view returns(ObjectType[] memory authorizatedDomains) {
          return _authorizedDomains[serviceDomain];
     }

     function getAuthorizedFunctions(ObjectType serviceDomain, ObjectType authorizedDomain) external view returns(IAccessAdmin.Function[] memory authorizatedFunctions) {
          return _authorizedFunctions[serviceDomain][authorizedDomain];
     }

     function _setupDomains()
          internal
     {
          _serviceDomains = new ObjectType[](13);
          _serviceDomains[0] = POLICY();
          _serviceDomains[1] = APPLICATION();
          _serviceDomains[2] = CLAIM();
          _serviceDomains[3] = PRODUCT();
          _serviceDomains[4] = ORACLE();
          _serviceDomains[5] = POOL();
          _serviceDomains[6] = BUNDLE();
          _serviceDomains[7] = PRICE();
          _serviceDomains[8] = DISTRIBUTION();
          _serviceDomains[9] = COMPONENT();
          _serviceDomains[10] = INSTANCE();
          _serviceDomains[11] = STAKING();
          _serviceDomains[12] = REGISTRY();
     }

     function _setupDomainAuthorizations() internal {
          _setupIRegistryServiceAuthorization();
          _setupStakingServiceAuthorization();
          _setupInstanceServiceAuthorization();
          _setupComponentServiceAuthorization();
          _setupDistributionServiceAuthorization();
          _setupPoolServiceAuthorization();
          _setupBundleServiceAuthorization();
     }


     /// @dev registry service authorization.
     /// authorized functions MUST be implemented with a restricted modifier
     function _setupIRegistryServiceAuthorization()
          internal
     {
          IAccessAdmin.Function[] storage functions;

          _authorizedDomains[REGISTRY()].push(APPLICATION());
          functions = _authorizedFunctions[REGISTRY()][APPLICATION()];
          _authorize(functions, IRegistryService.registerPolicy.selector, "registerPolicy");

          _authorizedDomains[REGISTRY()].push(POOL());
          functions = _authorizedFunctions[REGISTRY()][POOL()];
          _authorize(functions, IRegistryService.registerPool.selector, "registerPool");

          _authorizedDomains[REGISTRY()].push(BUNDLE());
          functions = _authorizedFunctions[REGISTRY()][BUNDLE()];
          _authorize(functions, IRegistryService.registerBundle.selector, "registerBundle");

          _authorizedDomains[REGISTRY()].push(DISTRIBUTION());
          functions = _authorizedFunctions[REGISTRY()][DISTRIBUTION()];
          _authorize(functions, IRegistryService.registerDistribution.selector, "registerDistribution");
          _authorize(functions, IRegistryService.registerDistributor.selector, "registerDistributor");

          _authorizedDomains[REGISTRY()].push(COMPONENT());
          functions = _authorizedFunctions[REGISTRY()][COMPONENT()];
          _authorize(functions, IRegistryService.registerComponent.selector, "registerComponent");

          _authorizedDomains[REGISTRY()].push(INSTANCE());
          functions = _authorizedFunctions[REGISTRY()][INSTANCE()];
          _authorize(functions, IRegistryService.registerInstance.selector, "registerInstance");

          _authorizedDomains[REGISTRY()].push(STAKING());
          functions = _authorizedFunctions[REGISTRY()][STAKING()];
          _authorize(functions, IRegistryService.registerStake.selector, "registerStake");

          _authorizedDomains[REGISTRY()].push(PRODUCT());
          functions = _authorizedFunctions[REGISTRY()][PRODUCT()];
          _authorize(functions, IRegistryService.registerProduct.selector, "registerProduct");
     }


     /// @dev staking service authorization.
     /// authorized functions MUST be implemented with a restricted modifier
     function _setupStakingServiceAuthorization()
          internal
     {
          IAccessAdmin.Function[] storage functions;

          _authorizedDomains[STAKING()].push(INSTANCE());
          functions = _authorizedFunctions[STAKING()][INSTANCE()];
          _authorize(functions, IStakingService.createInstanceTarget.selector, "createInstanceTarget");
          _authorize(functions, IStakingService.setInstanceLockingPeriod.selector, "setInstanceLockingPeriod");
          _authorize(functions, IStakingService.setInstanceRewardRate.selector, "setInstanceRewardRate");
          _authorize(functions, IStakingService.refillInstanceRewardReserves.selector, "refillInstanceRewardReserves");
     }


     /// @dev Instance service function authorization.
     function _setupInstanceServiceAuthorization()
          internal
     {
          IAccessAdmin.Function[] storage functions;

          _authorizedDomains[INSTANCE()].push(COMPONENT());
          functions = _authorizedFunctions[INSTANCE()][COMPONENT()];
          _authorize(functions, IInstanceService.createComponentTarget.selector, "createComponentTarget");
     }


     /// @dev Component service function authorization.
     function _setupComponentServiceAuthorization()
          internal
     {
          // authz.authorizations = new DomainAuthorization[](4);

          // authz.authorizations[0].domain = POLICY();
          // _functions = new IAccessAdmin.Function[](1);
          // __authorize(ComponentService.increaseProductFees.selector, "increaseProductFees"));
          // authz.authorizations[0].functions = _functions;

          // authz.authorizations[1].domain = DISTRIBUTION();
          // _functions = new IAccessAdmin.Function[](1);
          // __authorize(ComponentService.increaseDistributionBalance.selector, "increaseDistributionBalance"));
          // authz.authorizations[1].functions = _functions;

          // authz.authorizations[2].domain = POOL();
          // _functions = new IAccessAdmin.Function[](1);
          // __authorize(ComponentService.increasePoolBalance.selector, "increasePoolBalance"));
          // authz.authorizations[2].functions = _functions;

          // authz.authorizations[3].domain = BUNDLE();
          // _functions = new IAccessAdmin.Function[](1);
          // __authorize(ComponentService.increaseBundleBalance.selector, "increaseBundleBalance"));
          // authz.authorizations[3].functions = _functions;
     }

     /// @dev Distribution service function authorization.
     function _setupDistributionServiceAuthorization()
          internal
     {
          IAccessAdmin.Function[] storage functions;

          _authorizedDomains[DISTRIBUTION()].push(POLICY());
          functions = _authorizedFunctions[DISTRIBUTION()][POLICY()];
          _authorize(functions, IDistributionService.processSale.selector, "processSale");
     }


     /// @dev Pool service function authorization.
     function _setupPoolServiceAuthorization()
          internal
     {
          IAccessAdmin.Function[] storage functions;

          _authorizedDomains[POOL()].push(POLICY());
          functions = _authorizedFunctions[POOL()][POLICY()];
          _authorize(functions, IPoolService.lockCollateral.selector, "lockCollateral");
          _authorize(functions, IPoolService.releaseCollateral.selector, "releaseCollateral");
          _authorize(functions, IPoolService.reduceCollateral.selector, "reduceCollateral");
          _authorize(functions, IPoolService.processSale.selector, "processSale");

          _authorizedDomains[POOL()].push(CLAIM());
          functions = _authorizedFunctions[POOL()][CLAIM()];
          _authorize(functions, IPoolService.reduceCollateral.selector, "reduceCollateral");
     }


     /// @dev Instance service function authorization.
     function _setupBundleServiceAuthorization()
          internal
     {
          IAccessAdmin.Function[] storage functions;

          _authorizedDomains[BUNDLE()].push(POOL());
          functions = _authorizedFunctions[BUNDLE()][POOL()];
          _authorize(functions, IBundleService.create.selector, "create");
          _authorize(functions, IBundleService.close.selector, "close");
          _authorize(functions, IBundleService.lockCollateral.selector, "lockCollateral");
          _authorize(functions, IBundleService.releaseCollateral.selector, "releaseCollateral");
          _authorize(functions, IBundleService.unlinkPolicy.selector, "unlinkPolicy");
     }


     function _authorize(IAccessAdmin.Function[] storage functions, bytes4 selector, string memory name) internal {
          functions.push(
               IAccessAdmin.Function({
                    selector: SelectorLib.toSelector(selector),
                    name: StrLib.toStr(name)}));
     }
}

