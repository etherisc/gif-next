// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {
     ALL, ACCOUNTING, REGISTRY, RISK, ORACLE, POOL, INSTANCE, COMPONENT, DISTRIBUTION, APPLICATION, POLICY, CLAIM, BUNDLE, STAKING, PRICE
} from "../../contracts/type/ObjectType.sol";

import {IAccess} from "../authorization/IAccess.sol";
import {IAccountingService} from "../accounting/IAccountingService.sol";
import {IApplicationService} from "../product/IApplicationService.sol";
import {IBundleService} from "../pool/IBundleService.sol";
import {IClaimService} from "../product/IClaimService.sol";
import {IComponentService} from "../shared/IComponentService.sol";
import {IDistributionService} from "../distribution/IDistributionService.sol";
import {IInstanceService} from "../instance/IInstanceService.sol";
import {IOracleService} from "../oracle/IOracleService.sol";
import {IPolicyService} from "../product/IPolicyService.sol";
import {IPoolService} from "../pool/IPoolService.sol";
import {IStakingService} from "../staking/IStakingService.sol";
import {IRegistryService} from "./IRegistryService.sol";
import {IRiskService} from "../product/IRiskService.sol";
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
          _setupInstanceServiceAuthorization();
          _setupAccountingServiceAuthorization();
          _setupComponentServiceAuthorization();
          _setupClaimServiceAuthorization();
          _setupRiskServiceAuthorization();
          _setupDistributionServiceAuthorization();
          _setupPoolServiceAuthorization();
          _setupBundleServiceAuthorization();
          _setupOracleServiceAuthorization();
          _setupApplicationServiceAuthorization();
          _setupPolicyServiceAuthorization();
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
          IAccess.FunctionInfo[] storage functions;
          functions = _authorizeForService(INSTANCE(), ALL());
          _authorize(functions, IInstanceService.createInstance.selector, "createInstance");
          _authorize(functions, IInstanceService.upgradeInstanceReader.selector, "upgradeInstanceReader");
          _authorize(functions, IInstanceService.upgradeMasterInstanceReader.selector, "upgradeMasterInstanceReader");

          _authorize(functions, IInstanceService.setStakingLockingPeriod.selector, "setStakingLockingPeriod");
          _authorize(functions, IInstanceService.setStakingRewardRate.selector, "setStakingRewardRate");
          _authorize(functions, IInstanceService.refillStakingRewardReserves.selector, "refillStakingRewardReserves");
          _authorize(functions, IInstanceService.withdrawStakingRewardReserves.selector, "withdrawStakingRewardReserves");
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
          IAccess.FunctionInfo[] storage functions;

          functions = _authorizeForService(COMPONENT(), ALL());
          _authorize(functions, IComponentService.registerComponent.selector, "registerComponent");
          _authorize(functions, IComponentService.approveTokenHandler.selector, "approveTokenHandler");
          _authorize(functions, IComponentService.approveStakingTokenHandler.selector, "approveStakingTokenHandler");
          _authorize(functions, IComponentService.setWallet.selector, "setWallet");
          _authorize(functions, IComponentService.setComponentLocked.selector, "setComponentLocked");
          _authorize(functions, IComponentService.withdrawFees.selector, "withdrawFees");
          _authorize(functions, IComponentService.registerProduct.selector, "registerProduct");
          _authorize(functions, IComponentService.setProductFees.selector, "setProductFees");
          _authorize(functions, IComponentService.setDistributionFees.selector, "setDistributionFees");
          _authorize(functions, IComponentService.setPoolFees.selector, "setPoolFees");

     }

     /// @dev Distribution service function authorization.
     function _setupRiskServiceAuthorization()
          internal
     {
          IAccess.FunctionInfo[] storage functions;
          functions = _authorizeForService(RISK(), ALL());
          _authorize(functions, IRiskService.createRisk.selector, "createRisk");
          _authorize(functions, IRiskService.updateRisk.selector, "updateRisk");
          _authorize(functions, IRiskService.updateRiskState.selector, "updateRiskState");
     }

     /// @dev Distribution service function authorization.
     function _setupClaimServiceAuthorization()
          internal
     {
          IAccess.FunctionInfo[] storage functions;
          functions = _authorizeForService(CLAIM(), ALL());
          _authorize(functions, IClaimService.submit.selector, "submit");
          _authorize(functions, IClaimService.confirm.selector, "confirm");
          _authorize(functions, IClaimService.decline.selector, "decline");
          _authorize(functions, IClaimService.revoke.selector, "revoke");
          _authorize(functions, IClaimService.close.selector, "close");
          _authorize(functions, IClaimService.createPayoutForBeneficiary.selector, "createPayoutForBeneficiary");
          _authorize(functions, IClaimService.createPayout.selector, "createPayout");
          _authorize(functions, IClaimService.processPayout.selector, "processPayout");
          _authorize(functions, IClaimService.cancelPayout.selector, "cancelPayout");
     }

     /// @dev Distribution service function authorization.
     function _setupDistributionServiceAuthorization()
          internal
     {
          IAccess.FunctionInfo[] storage functions;
          functions = _authorizeForService(DISTRIBUTION(), POLICY());
          _authorize(functions, IDistributionService.processSale.selector, "processSale");
          _authorize(functions, IDistributionService.processReferral.selector, "processReferral");

          functions = _authorizeForService(DISTRIBUTION(), ALL());
          _authorize(functions, IDistributionService.createDistributorType.selector, "createDistributorType");
          _authorize(functions, IDistributionService.createDistributor.selector, "createDistributor");
          _authorize(functions, IDistributionService.changeDistributorType.selector, "changeDistributorType");
          _authorize(functions, IDistributionService.createReferral.selector, "createReferral");
          _authorize(functions, IDistributionService.withdrawCommission.selector, "withdrawCommission");
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

          functions = _authorizeForService(POOL(), ALL());
          _authorize(functions, IPoolService.setMaxBalanceAmount.selector, "setMaxBalanceAmount");
          _authorize(functions, IPoolService.closeBundle.selector, "closeBundle");
          _authorize(functions, IPoolService.processFundedClaim.selector, "processFundedClaim");
          _authorize(functions, IPoolService.stake.selector, "stake");
          _authorize(functions, IPoolService.unstake.selector, "unstake");
          _authorize(functions, IPoolService.fundPoolWallet.selector, "fundPoolWallet");
          _authorize(functions, IPoolService.defundPoolWallet.selector, "defundPoolWallet");
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

     function _setupOracleServiceAuthorization()
          internal
     {
          IAccess.FunctionInfo[] storage functions;

          functions = _authorizeForService(ORACLE(), ALL());
          _authorize(functions, IOracleService.request.selector, "request");
          _authorize(functions, IOracleService.respond.selector, "respond");
          _authorize(functions, IOracleService.resend.selector, "resend");
          _authorize(functions, IOracleService.cancel.selector, "cancel");
     }

     function _setupApplicationServiceAuthorization()
          internal
     {
          IAccess.FunctionInfo[] storage functions;

          functions = _authorizeForService(APPLICATION(), ALL());
          _authorize(functions, IApplicationService.create.selector, "create");
          _authorize(functions, IApplicationService.renew.selector, "renew");
          _authorize(functions, IApplicationService.adjust.selector, "adjust");
          _authorize(functions, IApplicationService.revoke.selector, "revoke");
     }

     function _setupPolicyServiceAuthorization()
          internal
     {
          IAccess.FunctionInfo[] storage functions;

          functions = _authorizeForService(POLICY(), ALL());
          _authorize(functions, IPolicyService.decline.selector, "decline");
          _authorize(functions, IPolicyService.createPolicy.selector, "createPolicy");
          _authorize(functions, IPolicyService.collectPremium.selector, "collectPremium");
          _authorize(functions, IPolicyService.activate.selector, "activate");
          _authorize(functions, IPolicyService.expire.selector, "expire");
          _authorize(functions, IPolicyService.expirePolicy.selector, "expirePolicy");
          _authorize(functions, IPolicyService.close.selector, "close");

     }
}

