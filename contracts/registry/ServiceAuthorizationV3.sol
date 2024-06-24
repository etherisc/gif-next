// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {
     ALL, REGISTRY, SERVICE, PRODUCT, ORACLE, POOL, INSTANCE, COMPONENT, DISTRIBUTION, DISTRIBUTOR, APPLICATION, POLICY, CLAIM, BUNDLE, STAKE, STAKING, PRICE
} from "../../contracts/type/ObjectType.sol";

import {ComponentService} from "../shared/ComponentService.sol";
import {IAccess} from "../authorization/IAccess.sol";
import {IBundleService} from "../pool/IBundleService.sol";
import {IDistributionService} from "../distribution/IDistributionService.sol";
import {InstanceService} from "../instance/InstanceService.sol";
import {IInstanceService} from "../instance/IInstanceService.sol";
import {IPoolService} from "../pool/IPoolService.sol";
import {IStakingService} from "../staking/IStakingService.sol";
import {IRegistryService} from "./IRegistryService.sol";
import {ServiceAuthorization} from "../authorization/ServiceAuthorization.sol";


contract ServiceAuthorizationV3
     is ServiceAuthorization
{

     constructor(string memory commitHash)
          ServiceAuthorization(commitHash)
     {}

     function _setupDomains()
          internal
          override
     {
          _authorizeDomain(REGISTRY(), address(1));
          _authorizeDomain(STAKING(), address(2));
          _authorizeDomain(INSTANCE(), address(3));
          _authorizeDomain(COMPONENT(), address(4));
          _authorizeDomain(DISTRIBUTION(), address(5));
          _authorizeDomain(PRICE(), address(6));
          _authorizeDomain(BUNDLE(), address(7));
          _authorizeDomain(POOL(), address(8));
          _authorizeDomain(ORACLE(), address(9));
          _authorizeDomain(PRODUCT(), address(10));
          _authorizeDomain(CLAIM(), address(11));
          _authorizeDomain(APPLICATION(), address(12));
          _authorizeDomain(POLICY(), address(13));
     }


     function _setupDomainAuthorizations()
          internal
          override
     {
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


     /// @dev staking service authorization.
     /// authorized functions MUST be implemented with a restricted modifier
     function _setupStakingServiceAuthorization()
          internal
     {
          IAccess.FunctionInfo[] storage functions;

          functions = _authorizeForService(STAKING(), INSTANCE());
          _authorize(functions, IStakingService.createInstanceTarget.selector, "createInstanceTarget");
          _authorize(functions, IStakingService.setInstanceLockingPeriod.selector, "setInstanceLockingPeriod");
          _authorize(functions, IStakingService.setInstanceRewardRate.selector, "setInstanceRewardRate");
          _authorize(functions, IStakingService.refillInstanceRewardReserves.selector, "refillInstanceRewardReserves");
          _authorize(functions, IStakingService.withdrawInstanceRewardReserves.selector, "withdrawInstanceRewardReserves");

          functions = _authorizeForService(STAKING(), ALL());
          _authorize(functions, IStakingService.create.selector, "create");
          _authorize(functions, IStakingService.stake.selector, "stake");
          _authorize(functions, IStakingService.restakeToNewTarget.selector, "restakeToNewTarget");
          _authorize(functions, IStakingService.updateRewards.selector, "updateRewards");
          _authorize(functions, IStakingService.claimRewards.selector, "claimRewards");
          _authorize(functions, IStakingService.unstake.selector, "unstake");
     }


     /// @dev Instance service function authorization.
     function _setupInstanceServiceAuthorization()
          internal
     {
          IAccess.FunctionInfo[] storage functions;

          functions = _authorizeForService(INSTANCE(), COMPONENT());
          _authorize(functions, IInstanceService.initializeAuthorization.selector, "initializeAuthorization");
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
          IAccess.FunctionInfo[] storage functions;

          functions = _authorizeForService(DISTRIBUTION(), POLICY());
          _authorize(functions, IDistributionService.processSale.selector, "processSale");
     }


     /// @dev Pool service function authorization.
     function _setupPoolServiceAuthorization()
          internal
     {
          IAccess.FunctionInfo[] storage functions;

          functions = _authorizeForService(POOL(), POLICY());
          _authorize(functions, IPoolService.lockCollateral.selector, "lockCollateral");
          _authorize(functions, IPoolService.releaseCollateral.selector, "releaseCollateral");
          _authorize(functions, IPoolService.reduceCollateral.selector, "reduceCollateral");
          _authorize(functions, IPoolService.processSale.selector, "processSale");

          functions = _authorizeForService(POOL(), CLAIM());
          _authorize(functions, IPoolService.reduceCollateral.selector, "reduceCollateral");
     }


     /// @dev Instance service function authorization.
     function _setupBundleServiceAuthorization()
          internal
     {
          IAccess.FunctionInfo[] storage functions;

          functions = _authorizeForService(BUNDLE(), POOL());
          _authorize(functions, IBundleService.create.selector, "create");
          _authorize(functions, IBundleService.close.selector, "close");
          _authorize(functions, IBundleService.lockCollateral.selector, "lockCollateral");
          _authorize(functions, IBundleService.releaseCollateral.selector, "releaseCollateral");
          _authorize(functions, IBundleService.unlinkPolicy.selector, "unlinkPolicy");
     }
}

