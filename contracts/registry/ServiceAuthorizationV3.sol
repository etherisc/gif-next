// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {
     ALL, ACCOUNTING, REGISTRY, RISK, ORACLE, POOL, INSTANCE, COMPONENT, DISTRIBUTION, APPLICATION, POLICY, CLAIM, BUNDLE, STAKING, PRICE
} from "../../contracts/type/ObjectType.sol";

import {IAccess} from "../authorization/IAccess.sol";
import {IAccountingService} from "../accounting/IAccountingService.sol";
import {IBundleService} from "../pool/IBundleService.sol";
import {IDistributionService} from "../distribution/IDistributionService.sol";
import {IPoolService} from "../pool/IPoolService.sol";
import {IStakingService} from "../staking/IStakingService.sol";
import {IRegistryService} from "./IRegistryService.sol";
import {ServiceAuthorization} from "../authorization/ServiceAuthorization.sol";


contract ServiceAuthorizationV3
     is ServiceAuthorization
{

     constructor(string memory commitHash)
          ServiceAuthorization(commitHash, 3)
     {}

     function _setupDomains()
          internal
          override
     {
          _authorizeDomain(REGISTRY(), address(1));
          _authorizeDomain(STAKING(), address(2));
          _authorizeDomain(INSTANCE(), address(3));
          _authorizeDomain(ACCOUNTING(), address(4));
          _authorizeDomain(COMPONENT(), address(5));
          _authorizeDomain(DISTRIBUTION(), address(6));
          _authorizeDomain(PRICE(), address(7));
          _authorizeDomain(BUNDLE(), address(8));
          _authorizeDomain(POOL(), address(9));
          _authorizeDomain(ORACLE(), address(10));
          _authorizeDomain(RISK(), address(11));
          _authorizeDomain(POLICY(), address(12));
          _authorizeDomain(CLAIM(), address(13));
          _authorizeDomain(APPLICATION(), address(14));
     }


     function _setupDomainAuthorizations()
          internal
          override
     {
          _setupIRegistryServiceAuthorization();
          _setupStakingServiceAuthorization();
          _setupInstanceServiceAuthorization();
          _setupAccountingServiceAuthorization();
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

          functions = _authorizeForService(REGISTRY(), BUNDLE());
          _authorize(functions, IRegistryService.registerBundle.selector, "registerBundle");

          functions = _authorizeForService(REGISTRY(), COMPONENT());
          _authorize(functions, IRegistryService.registerProduct.selector, "registerProduct");
          _authorize(functions, IRegistryService.registerProductLinkedComponent.selector, "registerProductLinkedComponent");

          functions = _authorizeForService(REGISTRY(), DISTRIBUTION());
          _authorize(functions, IRegistryService.registerDistributor.selector, "registerDistributor");

          functions = _authorizeForService(REGISTRY(), INSTANCE());
          _authorize(functions, IRegistryService.registerInstance.selector, "registerInstance");

          functions = _authorizeForService(REGISTRY(), STAKING());
          _authorize(functions, IRegistryService.registerStake.selector, "registerStake");
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
     }

     /// @dev Accounting service function authorization.
     function _setupAccountingServiceAuthorization()
          internal
     {
          IAccess.FunctionInfo[] storage functions;

          functions = _authorizeForService(ACCOUNTING(), BUNDLE());
          _authorize(functions, IAccountingService.increaseBundleBalance.selector, "increaseBundleBalance");
          _authorize(functions, IAccountingService.decreaseBundleBalance.selector, "decreaseBundleBalance");

          functions = _authorizeForService(ACCOUNTING(), COMPONENT());
          _authorize(functions, IAccountingService.decreaseComponentFees.selector, "decreaseComponentFees");

          functions = _authorizeForService(ACCOUNTING(), DISTRIBUTION());
          _authorize(functions, IAccountingService.increaseDistributionBalance.selector, "increaseDistributionBalance");
          _authorize(functions, IAccountingService.decreaseDistributionBalance.selector, "decreaseDistributionBalance");
          _authorize(functions, IAccountingService.increaseDistributorBalance.selector, "increaseDistributorBalance");
          _authorize(functions, IAccountingService.decreaseDistributorBalance.selector, "decreaseDistributorBalance");

          functions = _authorizeForService(ACCOUNTING(), POLICY());
          _authorize(functions, IAccountingService.increaseProductFees.selector, "increaseProductFees");
          
          functions = _authorizeForService(ACCOUNTING(), POOL());
          _authorize(functions, IAccountingService.increasePoolBalance.selector, "increasePoolBalance");
          _authorize(functions, IAccountingService.decreasePoolBalance.selector, "decreasePoolBalance");
          _authorize(functions, IAccountingService.increaseBundleBalanceForPool.selector, "increaseBundleBalanceForPool");
          _authorize(functions, IAccountingService.decreaseBundleBalanceForPool.selector, "decreaseBundleBalanceForPool");

     }


     /// @dev Component service function authorization.
     function _setupComponentServiceAuthorization()
          internal
     {
     }

     /// @dev Distribution service function authorization.
     function _setupDistributionServiceAuthorization()
          internal
     {
          IAccess.FunctionInfo[] storage functions;

          functions = _authorizeForService(DISTRIBUTION(), POLICY());
          _authorize(functions, IDistributionService.processSale.selector, "processSale");
          _authorize(functions, IDistributionService.processReferral.selector, "processReferral");
     }


     /// @dev Pool service function authorization.
     function _setupPoolServiceAuthorization()
          internal
     {
          IAccess.FunctionInfo[] storage functions;

          functions = _authorizeForService(POOL(), POLICY());
          _authorize(functions, IPoolService.lockCollateral.selector, "lockCollateral");
          _authorize(functions, IPoolService.releaseCollateral.selector, "releaseCollateral");
          _authorize(functions, IPoolService.processSale.selector, "processSale");

          functions = _authorizeForService(POOL(), CLAIM());
          _authorize(functions, IPoolService.processPayout.selector, "processPayout");
     }


     /// @dev Instance service function authorization.
     function _setupBundleServiceAuthorization()
          internal
     {
          IAccess.FunctionInfo[] storage functions;

          functions = _authorizeForService(BUNDLE(), POOL());
          _authorize(functions, IBundleService.stake.selector, "stake");
          _authorize(functions, IBundleService.unstake.selector, "unstake");
          _authorize(functions, IBundleService.close.selector, "close");
          _authorize(functions, IBundleService.lockCollateral.selector, "lockCollateral");
          _authorize(functions, IBundleService.releaseCollateral.selector, "releaseCollateral");

          functions = _authorizeForService(BUNDLE(), ALL());
          _authorize(functions, IBundleService.create.selector, "create");
          _authorize(functions, IBundleService.extend.selector, "extend");
          _authorize(functions, IBundleService.lock.selector, "lock");
          _authorize(functions, IBundleService.unlock.selector, "unlock");
          _authorize(functions, IBundleService.setFee.selector, "setFee");
          _authorize(functions, IBundleService.withdrawBundleFees.selector, "withdrawBundleFees");
     }
}

