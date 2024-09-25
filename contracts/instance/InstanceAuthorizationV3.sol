// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccess} from "../authorization/IAccess.sol";
import {IInstance} from "../instance/Instance.sol";

import {AccessAdminLib} from "../authorization/AccessAdminLib.sol";
import {Authorization} from "../authorization/Authorization.sol";
import {ACCOUNTING, ORACLE, POOL, INSTANCE, COMPONENT, DISTRIBUTION, APPLICATION, POLICY, CLAIM, BUNDLE, RISK} from "../../contracts/type/ObjectType.sol";
import {BundleSet} from "../instance/BundleSet.sol";
import {InstanceAdmin} from "../instance/InstanceAdmin.sol";
import {InstanceStore} from "../instance/InstanceStore.sol";
import {INSTANCE_TARGET_NAME, INSTANCE_ADMIN_TARGET_NAME, INSTANCE_STORE_TARGET_NAME, PRODUCT_STORE_TARGET_NAME, BUNDLE_SET_TARGET_NAME, RISK_SET_TARGET_NAME} from "./TargetNames.sol";
import {ProductStore} from "../instance/ProductStore.sol";
import {ADMIN_ROLE, INSTANCE_OWNER_ROLE, PUBLIC_ROLE} from "../type/RoleId.sol";
import {RiskSet} from "../instance/RiskSet.sol"; 


contract InstanceAuthorizationV3
     is Authorization
{

     string public constant INSTANCE_ROLE_NAME = "InstanceRole";
     string public constant INSTANCE_OWNER_ROLE_NAME = "InstanceOwnerRole";

     constructor()
          Authorization(
               INSTANCE_TARGET_NAME, 
               INSTANCE(), 
               3, 
               COMMIT_HASH,
               TargetType.Instance, 
               false)
     { }

     function _setupServiceTargets() internal virtual override {
          // service targets relevant to instance
          _authorizeServiceDomain(INSTANCE(), address(10));
          _authorizeServiceDomain(ACCOUNTING(), address(11));
          _authorizeServiceDomain(COMPONENT(), address(12));
          _authorizeServiceDomain(DISTRIBUTION(), address(13));
          _authorizeServiceDomain(ORACLE(), address(14));
          _authorizeServiceDomain(POOL(), address(15));
          _authorizeServiceDomain(BUNDLE(), address(16));
          _authorizeServiceDomain(RISK(), address(17));
          _authorizeServiceDomain(APPLICATION(), address(18));
          _authorizeServiceDomain(POLICY(), address(19));
          _authorizeServiceDomain(CLAIM(), address(20));
     }

     function _setupRoles()
          internal
          override
     {
          _addRole(
               INSTANCE_OWNER_ROLE(),
               AccessAdminLib.roleInfo(
                    ADMIN_ROLE(),
                    TargetType.Custom,
                    0, // max member count special case: instance nft owner is sole role owner
                    INSTANCE_OWNER_ROLE_NAME));
     }

     function _setupTargets()
          internal
          override
     {
          // instance supporting targets
          _addInstanceTarget(INSTANCE_ADMIN_TARGET_NAME);
          _addInstanceTarget(INSTANCE_STORE_TARGET_NAME);
          _addInstanceTarget(PRODUCT_STORE_TARGET_NAME);
          _addInstanceTarget(BUNDLE_SET_TARGET_NAME);
          _addInstanceTarget(RISK_SET_TARGET_NAME);
     }


     function _setupTargetAuthorizations()
          internal
          override
     {
          _setupInstanceAuthorization();
          _setupInstanceAdminAuthorization();
          _setupInstanceStoreAuthorization();
          _setupProductStoreAuthorization();
          _setupBundleSetAuthorization();
          _setUpRiskSetAuthorization();
     }


     function _setupBundleSetAuthorization()
          internal
     {
          IAccess.FunctionInfo[] storage functions;

          // authorize bundle service role
          functions = _authorizeForTarget(BUNDLE_SET_TARGET_NAME, getServiceRole(BUNDLE()));
          _authorize(functions, BundleSet.add.selector, "add");
          _authorize(functions, BundleSet.lock.selector, "lock");
          _authorize(functions, BundleSet.unlock.selector, "unlock");

          // authorize bundle service role
          functions = _authorizeForTarget(BUNDLE_SET_TARGET_NAME, getServiceRole(POLICY()));
          _authorize(functions, BundleSet.linkPolicy.selector, "linkPolicy");
          _authorize(functions, BundleSet.unlinkPolicy.selector, "unlinkPolicy");
     }

     function _setUpRiskSetAuthorization()
          internal
     {
          IAccess.FunctionInfo[] storage functions;

          // authorize risk service role
          functions = _authorizeForTarget(RISK_SET_TARGET_NAME, getServiceRole(RISK()));
          _authorize(functions, RiskSet.add.selector, "add");
          _authorize(functions, RiskSet.deactivate.selector, "deactivate");
          _authorize(functions, RiskSet.activate.selector, "activate");

          // authorize policy service role
          functions = _authorizeForTarget(RISK_SET_TARGET_NAME, getServiceRole(POLICY()));
          _authorize(functions, RiskSet.linkPolicy.selector, "linkPolicy");
          _authorize(functions, RiskSet.unlinkPolicy.selector, "unlinkPolicy");
     }


     function _setupInstanceAuthorization()
          internal
     {
          IAccess.FunctionInfo[] storage functions;

          // authorize instance service role
          functions = _authorizeForTarget(INSTANCE_TARGET_NAME, PUBLIC_ROLE());
          _authorize(functions, IInstance.registerProduct.selector, "registerProduct");
          _authorize(functions, IInstance.upgradeInstanceReader.selector, "upgradeInstanceReader");

          // staking
          _authorize(functions, IInstance.setStakingLockingPeriod.selector, "setStakingLockingPeriod");
          _authorize(functions, IInstance.setStakingRewardRate.selector, "setStakingRewardRate");
          _authorize(functions, IInstance.setStakingMaxAmount.selector, "setStakingMaxAmount");
          _authorize(functions, IInstance.refillStakingRewardReserves.selector, "refillStakingRewardReserves");
          _authorize(functions, IInstance.withdrawStakingRewardReserves.selector, "withdrawStakingRewardReserves");

          // custom authz
          _authorize(functions, IInstance.createRole.selector, "createRole");
          _authorize(functions, IInstance.setRoleActive.selector, "setRoleActive");
          _authorize(functions, IInstance.grantRole.selector, "grantRole");
          _authorize(functions, IInstance.revokeRole.selector, "revokeRole");
          _authorize(functions, IInstance.createTarget.selector, "createTarget");
          _authorize(functions, IInstance.authorizeFunctions.selector, "authorizeFunctions");
          _authorize(functions, IInstance.unauthorizeFunctions.selector, "unauthorizeFunctions");

          // authorize instance service role
          functions = _authorizeForTarget(INSTANCE_TARGET_NAME, getServiceRole(INSTANCE()));
          _authorize(functions, IInstance.setInstanceReader.selector, "setInstanceReader");
     }


     function _setupInstanceAdminAuthorization()
          internal
     {
          IAccess.FunctionInfo[] storage functions;

          // authorize component service role
          functions = _authorizeForTarget(INSTANCE_ADMIN_TARGET_NAME, getServiceRole(INSTANCE()));
          _authorize(functions, InstanceAdmin.createRole.selector, "createRole");
          _authorize(functions, InstanceAdmin.setRoleActive.selector, "setRoleActive");
          _authorize(functions, InstanceAdmin.grantRole.selector, "grantRole");
          _authorize(functions, InstanceAdmin.revokeRole.selector, "revokeRole");

          _authorize(functions, InstanceAdmin.createTarget.selector, "createTarget");
          _authorize(functions, InstanceAdmin.authorizeFunctions.selector, "authorizeFunctions");
          _authorize(functions, InstanceAdmin.unauthorizeFunctions.selector, "unauthorizeFunctions");
          _authorize(functions, InstanceAdmin.setTargetLocked.selector, "setTargetLocked");
          _authorize(functions, InstanceAdmin.setInstanceLocked.selector, "setInstanceLocked");

          // authorize component service role
          functions = _authorizeForTarget(INSTANCE_ADMIN_TARGET_NAME, getServiceRole(COMPONENT()));
          _authorize(functions, InstanceAdmin.initializeComponentAuthorization.selector, "initializeComponentAuthoriz");
          _authorize(functions, InstanceAdmin.setContractLocked.selector, "setContractLocked");
     }


     function _setupInstanceStoreAuthorization()
          internal
     {
          IAccess.FunctionInfo[] storage functions;

          // authorize accounting service role
          functions = _authorizeForTarget(INSTANCE_STORE_TARGET_NAME, getServiceRole(ACCOUNTING()));
          _authorize(functions, InstanceStore.increaseBalance.selector, "increaseBalance");
          _authorize(functions, InstanceStore.decreaseBalance.selector, "decreaseBalance");
          _authorize(functions, InstanceStore.increaseFees.selector, "increaseFees");
          _authorize(functions, InstanceStore.decreaseFees.selector, "decreaseFees");

          // authorize component service role
          functions = _authorizeForTarget(INSTANCE_STORE_TARGET_NAME, getServiceRole(COMPONENT()));
          _authorize(functions, InstanceStore.createComponent.selector, "createComponent");
          _authorize(functions, InstanceStore.updateComponent.selector, "updateComponent");
          _authorize(functions, InstanceStore.createPool.selector, "createPool");
          
          // authorize distribution service role
          functions = _authorizeForTarget(INSTANCE_STORE_TARGET_NAME, getServiceRole(DISTRIBUTION()));
          _authorize(functions, InstanceStore.createDistributorType.selector, "createDistributorType");
          _authorize(functions, InstanceStore.updateDistributorType.selector, "updateDistributorType");
          _authorize(functions, InstanceStore.updateDistributorTypeState.selector, "updateDistributorTypeState");
          _authorize(functions, InstanceStore.createDistributor.selector, "createDistributor");
          _authorize(functions, InstanceStore.updateDistributor.selector, "updateDistributor");
          _authorize(functions, InstanceStore.updateDistributorState.selector, "updateDistributorState");
          _authorize(functions, InstanceStore.createReferral.selector, "createReferral");
          _authorize(functions, InstanceStore.updateReferral.selector, "updateReferral");
          _authorize(functions, InstanceStore.updateReferralState.selector, "updateReferralState");

          // authorize oracle service role
          functions = _authorizeForTarget(INSTANCE_STORE_TARGET_NAME, getServiceRole(ORACLE()));
          _authorize(functions, InstanceStore.createRequest.selector, "createRequest");
          _authorize(functions, InstanceStore.updateRequest.selector, "updateRequest");
          _authorize(functions, InstanceStore.updateRequestState.selector, "updateRequestState");

          // authorize pool service role
          functions = _authorizeForTarget(INSTANCE_STORE_TARGET_NAME, getServiceRole(POOL()));
          _authorize(functions, InstanceStore.updatePool.selector, "updatePool");

          // authorize bundle service role
          functions = _authorizeForTarget(INSTANCE_STORE_TARGET_NAME, getServiceRole(BUNDLE()));
          _authorize(functions, InstanceStore.createBundle.selector, "createBundle");
          _authorize(functions, InstanceStore.updateBundle.selector, "updateBundle");
          _authorize(functions, InstanceStore.updateBundleState.selector, "updateBundleState");
          _authorize(functions, InstanceStore.increaseLocked.selector, "increaseLocked");
          _authorize(functions, InstanceStore.decreaseLocked.selector, "decreaseLocked");

     }

     function _setupProductStoreAuthorization()
          internal
     {
          IAccess.FunctionInfo[] storage functions;

          functions = _authorizeForTarget(PRODUCT_STORE_TARGET_NAME, getServiceRole(COMPONENT()));
          _authorize(functions, ProductStore.createProduct.selector, "createProduct");
          _authorize(functions, ProductStore.updateProduct.selector, "updateProduct");
          _authorize(functions, ProductStore.createFee.selector, "createFee");
          _authorize(functions, ProductStore.updateFee.selector, "updateFee");

          // authorize application service role
          functions = _authorizeForTarget(PRODUCT_STORE_TARGET_NAME, getServiceRole(APPLICATION()));
          _authorize(functions, ProductStore.createApplication.selector, "createApplication");
          _authorize(functions, ProductStore.updateApplication.selector, "updateApplication");
          _authorize(functions, ProductStore.updateApplicationState.selector, "updateApplicationState");

          // authorize policy service role
          functions = _authorizeForTarget(PRODUCT_STORE_TARGET_NAME, getServiceRole(POLICY()));
          _authorize(functions, ProductStore.updatePolicy.selector, "updatePolicy");
          _authorize(functions, ProductStore.updatePolicyState.selector, "updatePolicyState");

          // authorize policy service role
          functions = _authorizeForTarget(PRODUCT_STORE_TARGET_NAME, getServiceRole(POLICY()));
          _authorize(functions, ProductStore.createPremium.selector, "createPremium");
          _authorize(functions, ProductStore.updatePremiumState.selector, "updatePremiumState");

          // authorize risk service role
          functions = _authorizeForTarget(PRODUCT_STORE_TARGET_NAME, getServiceRole(RISK()));
          _authorize(functions, ProductStore.createRisk.selector, "createRisk");
          _authorize(functions, ProductStore.updateRisk.selector, "updateRisk");
          _authorize(functions, ProductStore.updateRiskState.selector, "updateRiskState");

          // authorize claim service role
          functions = _authorizeForTarget(PRODUCT_STORE_TARGET_NAME, getServiceRole(CLAIM()));
          _authorize(functions, ProductStore.updatePolicyClaims.selector, "updatePolicyClaims");
          _authorize(functions, ProductStore.createClaim.selector, "createClaim");
          _authorize(functions, ProductStore.updateClaim.selector, "updateClaim");
          _authorize(functions, ProductStore.createPayout.selector, "createPayout");
          _authorize(functions, ProductStore.updatePayout.selector, "updatePayout");
          _authorize(functions, ProductStore.updatePayoutState.selector, "updatePayoutState");
     }
}

