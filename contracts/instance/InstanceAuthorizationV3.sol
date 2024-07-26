// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {
     PRODUCT, ORACLE, POOL, INSTANCE, COMPONENT, DISTRIBUTION, APPLICATION, POLICY, CLAIM, BUNDLE
} from "../../contracts/type/ObjectType.sol";

import {BundleSet} from "../instance/BundleSet.sol"; 
import {IAccess} from "../authorization/IAccess.sol";
import {Instance} from "../instance/Instance.sol";
import {InstanceAdmin} from "../instance/InstanceAdmin.sol";
import {InstanceStore} from "../instance/InstanceStore.sol";
import {ModuleAuthorization} from "../authorization/ModuleAuthorization.sol";


contract InstanceAuthorizationV3
     is ModuleAuthorization
{

     string public constant INSTANCE_ROLE_NAME = "InstanceRole";

     string public constant INSTANCE_TARGET_NAME = "Instance";
     string public constant INSTANCE_STORE_TARGET_NAME = "InstanceStore";
     string public constant INSTANCE_ADMIN_TARGET_NAME = "InstanceAdmin";
     string public constant BUNDLE_SET_TARGET_NAME = "BundleSet";

     constructor() ModuleAuthorization(INSTANCE_TARGET_NAME) {}


     function _setupRoles()
          internal
          override
     {
          // empty implementation
     }


     function _setupTargets()
          internal
          override
     {
          // instance target
          _addTargetWithRole(
               INSTANCE_TARGET_NAME, 
               _getTargetRoleId(INSTANCE()),
               INSTANCE_ROLE_NAME);

          // instance supporting targets
          _addTarget(INSTANCE_STORE_TARGET_NAME);
          _addTarget(INSTANCE_ADMIN_TARGET_NAME);
          _addTarget(BUNDLE_SET_TARGET_NAME);

          // service targets relevant to instance
          _addServiceTargetWithRole(INSTANCE());
          _addServiceTargetWithRole(COMPONENT());
          _addServiceTargetWithRole(DISTRIBUTION());
          _addServiceTargetWithRole(ORACLE());
          _addServiceTargetWithRole(POOL());
          _addServiceTargetWithRole(BUNDLE());
          _addServiceTargetWithRole(PRODUCT());
          _addServiceTargetWithRole(APPLICATION());
          _addServiceTargetWithRole(POLICY());
          _addServiceTargetWithRole(CLAIM());
     }


     function _setupTargetAuthorizations()
          internal
          override
     {
          _setupInstanceAuthorization();
          _setupInstanceAdminAuthorization();
          _setupInstanceStoreAuthorization();
          _setupBundleSetAuthorization();
     }


     function _setupBundleSetAuthorization()
          internal
     {
          IAccess.FunctionInfo[] storage functions;

          // authorize bundle service role
          functions = _authorizeForTarget(BUNDLE_SET_TARGET_NAME, getServiceRole(BUNDLE()));
          _authorize(functions, BundleSet.linkPolicy.selector, "linkPolicy");
          _authorize(functions, BundleSet.unlinkPolicy.selector, "unlinkPolicy");
          _authorize(functions, BundleSet.add.selector, "add");
          _authorize(functions, BundleSet.lock.selector, "lock");
          _authorize(functions, BundleSet.unlock.selector, "unlock");
     }


     function _setupInstanceAuthorization()
          internal
     {
          IAccess.FunctionInfo[] storage functions;

          // authorize instance service role
          functions = _authorizeForTarget(INSTANCE_TARGET_NAME, getServiceRole(INSTANCE()));
          _authorize(functions, Instance.setInstanceReader.selector, "setInstanceReader");
     }


     function _setupInstanceAdminAuthorization()
          internal
     {
          IAccess.FunctionInfo[] storage functions;

          // authorize instance role
          functions = _authorizeForTarget(INSTANCE_ADMIN_TARGET_NAME, _getTargetRoleId(INSTANCE()));
          _authorize(functions, InstanceAdmin.grantRole.selector, "grantRole");

          // authorize instance service role
          // functions = _authorizeForTarget(INSTANCE_ADMIN_TARGET_NAME, getServiceRole(INSTANCE()));
     }


     function _setupInstanceStoreAuthorization()
          internal
     {
          IAccess.FunctionInfo[] storage functions;

          // authorize component service role
          functions = _authorizeForTarget(INSTANCE_STORE_TARGET_NAME, getServiceRole(COMPONENT()));
          _authorize(functions, InstanceStore.createComponent.selector, "createComponent");
          _authorize(functions, InstanceStore.updateComponent.selector, "updateComponent");
          _authorize(functions, InstanceStore.createPool.selector, "createPool");
          _authorize(functions, InstanceStore.createProduct.selector, "createProduct");
          _authorize(functions, InstanceStore.updateProduct.selector, "updateProduct");
          _authorize(functions, InstanceStore.increaseBalance.selector, "increaseBalance");
          _authorize(functions, InstanceStore.decreaseBalance.selector, "decreaseBalance");
          _authorize(functions, InstanceStore.increaseFees.selector, "increaseFees");
          _authorize(functions, InstanceStore.decreaseFees.selector, "decreaseFees");

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

          // authorize product service role
          functions = _authorizeForTarget(INSTANCE_STORE_TARGET_NAME, getServiceRole(PRODUCT()));
          _authorize(functions, InstanceStore.createRisk.selector, "createRisk");
          _authorize(functions, InstanceStore.updateRisk.selector, "updateRisk");
          _authorize(functions, InstanceStore.updateRiskState.selector, "updateRiskState");

          // authorize application service role
          functions = _authorizeForTarget(INSTANCE_STORE_TARGET_NAME, getServiceRole(APPLICATION()));
          _authorize(functions, InstanceStore.createApplication.selector, "createApplication");
          _authorize(functions, InstanceStore.updateApplication.selector, "updateApplication");
          _authorize(functions, InstanceStore.updateApplicationState.selector, "updateApplicationState");

          // authorize policy service role
          functions = _authorizeForTarget(INSTANCE_STORE_TARGET_NAME, getServiceRole(POLICY()));
          _authorize(functions, InstanceStore.updatePolicy.selector, "updatePolicy");
          _authorize(functions, InstanceStore.updatePolicyState.selector, "updatePolicyState");
          _authorize(functions, InstanceStore.createPremium.selector, "createPremium");
          _authorize(functions, InstanceStore.updatePremiumState.selector, "updatePremiumState");

          // authorize claim service role
          functions = _authorizeForTarget(INSTANCE_STORE_TARGET_NAME, getServiceRole(CLAIM()));
          _authorize(functions, InstanceStore.updatePolicyClaims.selector, "updatePolicyClaims");
          _authorize(functions, InstanceStore.createClaim.selector, "createClaim");
          _authorize(functions, InstanceStore.updateClaim.selector, "updateClaim");
          _authorize(functions, InstanceStore.createPayout.selector, "createPayout");
          _authorize(functions, InstanceStore.updatePayout.selector, "updatePayout");
     }
}

