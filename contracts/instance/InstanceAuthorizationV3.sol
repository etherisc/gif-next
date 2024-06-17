// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {
     ALL, REGISTRY, SERVICE, PRODUCT, ORACLE, POOL, INSTANCE, COMPONENT, DISTRIBUTION, DISTRIBUTOR, APPLICATION, POLICY, CLAIM, BUNDLE, STAKE, STAKING, PRICE
} from "../../contracts/type/ObjectType.sol";

import {IAccess} from "../authorization/IAccess.sol";
import {Instance} from "../instance/Instance.sol";
import {InstanceAdmin} from "../instance/InstanceAdmin.sol";
import {InstanceStore} from "../instance/InstanceStore.sol";
import {ModuleAuthorization} from "../authorization/ModuleAuthorization.sol";
import {VersionPart, VersionPartLib} from "../type/Version.sol";


contract InstanceAuthorizationV3
     is ModuleAuthorization
{
     uint256 public constant GIF_VERSION = 3;

     string public constant INSTANCE_TARGET_NAME = "Instance";
     string public constant INSTANCE_STORE_TARGET_NAME = "InstanceStore";
     string public constant INSTANCE_ADMIN_TARGET_NAME = "InstanceAdmin";
     string public constant BUNDLE_MANAGER_TARGET_NAME = "BundleManager";

     string public constant INSTANCE_ROLE_NAME = "InstanceRole";

     function getRelease() public override view returns(VersionPart release) {
          return VersionPartLib.toVersionPart(GIF_VERSION);
     }

     function _setupTargets()
          internal
          override
     {
          _addTarget(INSTANCE_TARGET_NAME);
          _addTarget(INSTANCE_STORE_TARGET_NAME);
          _addTarget(INSTANCE_ADMIN_TARGET_NAME);
          _addTarget(BUNDLE_MANAGER_TARGET_NAME);
     }

     function _setupRoles()
          internal
          override
     {
          _addRole(_getTargetRoleId(INSTANCE()), INSTANCE_ROLE_NAME);

          _addServiceRole(INSTANCE());
          _addServiceRole(COMPONENT());
          _addServiceRole(DISTRIBUTION());
          _addServiceRole(ORACLE());
          _addServiceRole(POOL());
          _addServiceRole(BUNDLE());
          _addServiceRole(PRODUCT());
          _addServiceRole(APPLICATION());
          _addServiceRole(POLICY());
          _addServiceRole(CLAIM());
     }


     function _setupTargetAuthorizations()
          internal
          override
     {
          _setupInstanceAuthorization();
          _setupInstanceAdminAuthorization();
          _setupInstanceStoreAuthorization();
     }


     function _setupInstanceAuthorization()
          internal
     {
          IAccess.FunctionInfo[] storage functions;

          // authorize instance service role
          functions = _authorizeForTarget( INSTANCE_TARGET_NAME, _getServiceRoleId(INSTANCE()));
          _authorize(functions, Instance.setInstanceAdmin.selector, "setInstanceAdmin");
          _authorize(functions, Instance.setInstanceStore.selector, "setInstanceStore");
          _authorize(functions, Instance.setBundleManager.selector, "setBundleManager");
          _authorize(functions, Instance.setInstanceReader.selector, "setInstanceReader");
     }


     function _setupInstanceAdminAuthorization()
          internal
     {
          IAccess.FunctionInfo[] storage functions;

          // authorize instance role
          functions = _authorizeForTarget(INSTANCE_ADMIN_TARGET_NAME, _getTargetRoleId(INSTANCE()));
          _authorize(functions, InstanceAdmin.createRole.selector, "createRole");
          _authorize(functions, InstanceAdmin.createTarget.selector, "createTarget");
          _authorize(functions, InstanceAdmin.setTargetFunctionRoleByInstance.selector, "setTargetFunctionRoleByInstance");
          _authorize(functions, InstanceAdmin.setTargetLockedByInstance.selector, "setTargetLockedByInstance");

          // authorize instance service role
          functions = _authorizeForTarget(INSTANCE_ADMIN_TARGET_NAME, _getServiceRoleId(INSTANCE()));
          _authorize(functions, InstanceAdmin.createGifTarget.selector, "createGifTarget");
          _authorize(functions, InstanceAdmin.setTargetLockedByService.selector, "setTargetLockedByService");
          _authorize(functions, InstanceAdmin.setTargetFunctionRoleByService.selector, "setTargetFunctionRoleByService");
     }


     function _setupInstanceStoreAuthorization()
          internal
     {
          IAccess.FunctionInfo[] storage functions;

          // authorize component service role
          functions = _authorizeForTarget(INSTANCE_STORE_TARGET_NAME, _getServiceRoleId(COMPONENT()));
          _authorize(functions, InstanceStore.createComponent.selector, "createComponent");
          _authorize(functions, InstanceStore.updateComponent.selector, "updateComponent");
          _authorize(functions, InstanceStore.createPool.selector, "createPool");
          _authorize(functions, InstanceStore.createProduct.selector, "createProduct");
          _authorize(functions, InstanceStore.updateProduct.selector, "updateProduct");
          _authorize(functions, InstanceStore.increaseBalance.selector, "increaseBalance");
          _authorize(functions, InstanceStore.increaseFees.selector, "increaseFees");

          // authorize distribution service role
          functions = _authorizeForTarget(INSTANCE_STORE_TARGET_NAME, _getServiceRoleId(DISTRIBUTION()));
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
          functions = _authorizeForTarget(INSTANCE_STORE_TARGET_NAME, _getServiceRoleId(ORACLE()));
          _authorize(functions, InstanceStore.createRequest.selector, "createRequest");
          _authorize(functions, InstanceStore.updateRequest.selector, "updateRequest");
          _authorize(functions, InstanceStore.updateRequestState.selector, "updateRequestState");

          // authorize pool service role
          functions = _authorizeForTarget(INSTANCE_STORE_TARGET_NAME, _getServiceRoleId(POOL()));
          _authorize(functions, InstanceStore.updatePool.selector, "updatePool");

          // authorize bundle service role
          functions = _authorizeForTarget(INSTANCE_STORE_TARGET_NAME, _getServiceRoleId(BUNDLE()));
          _authorize(functions, InstanceStore.createBundle.selector, "createBundle");
          _authorize(functions, InstanceStore.updateBundle.selector, "updateBundle");
          _authorize(functions, InstanceStore.updateBundleState.selector, "updateBundleState");
          _authorize(functions, InstanceStore.increaseLocked.selector, "increaseLocked");
          _authorize(functions, InstanceStore.decreaseLocked.selector, "decreaseLocked");

          // authorize product service role
          functions = _authorizeForTarget(INSTANCE_STORE_TARGET_NAME, _getServiceRoleId(PRODUCT()));
          _authorize(functions, InstanceStore.createRisk.selector, "createRisk");
          _authorize(functions, InstanceStore.updateRisk.selector, "updateRisk");
          _authorize(functions, InstanceStore.updateRiskState.selector, "updateRiskState");

          // authorize application service role
          functions = _authorizeForTarget(INSTANCE_STORE_TARGET_NAME, _getServiceRoleId(APPLICATION()));
          _authorize(functions, InstanceStore.createApplication.selector, "createApplication");
          _authorize(functions, InstanceStore.updateApplication.selector, "updateApplication");
          _authorize(functions, InstanceStore.updateApplicationState.selector, "updateApplicationState");

          // authorize policy service role
          functions = _authorizeForTarget(INSTANCE_STORE_TARGET_NAME, _getServiceRoleId(POLICY()));
          _authorize(functions, InstanceStore.updatePolicy.selector, "updatePolicy");
          _authorize(functions, InstanceStore.updatePolicyState.selector, "updatePolicyState");

          // authorize claim service role
          functions = _authorizeForTarget(INSTANCE_STORE_TARGET_NAME, _getServiceRoleId(CLAIM()));
          _authorize(functions, InstanceStore.updatePolicyClaims.selector, "updatePolicyClaims");
          _authorize(functions, InstanceStore.createClaim.selector, "createClaim");
          _authorize(functions, InstanceStore.updateClaim.selector, "updateClaim");
          _authorize(functions, InstanceStore.createPayout.selector, "createPayout");
          _authorize(functions, InstanceStore.updatePayout.selector, "updatePayout");
     }
}

