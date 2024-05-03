// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ADMIN_ROLE, INSTANCE_OWNER_ROLE, DISTRIBUTION_OWNER_ROLE, POOL_OWNER_ROLE, PRODUCT_OWNER_ROLE, INSTANCE_SERVICE_ROLE, DISTRIBUTION_SERVICE_ROLE, POOL_SERVICE_ROLE, PRODUCT_SERVICE_ROLE, APPLICATION_SERVICE_ROLE, POLICY_SERVICE_ROLE, CLAIM_SERVICE_ROLE, BUNDLE_SERVICE_ROLE, INSTANCE_ROLE} from "../type/RoleId.sol";
import {INSTANCE, BUNDLE, APPLICATION, POLICY, CLAIM, PRODUCT, DISTRIBUTION, REGISTRY, POOL} from "../type/ObjectType.sol";
import {VersionPart} from "../type/Version.sol";

import {IRegistry} from "../registry/IRegistry.sol";

import {Instance} from "./Instance.sol";
import {InstanceAdmin} from "./InstanceAdmin.sol";
import {InstanceReader} from "./InstanceReader.sol";
import {BundleManager} from "./BundleManager.sol";
import {AccessManagerExtendedInitializeable} from "../shared/AccessManagerExtendedInitializeable.sol";
import {InstanceStore} from "./InstanceStore.sol";


library InstanceAuthorizationsLib
{
    function grantInitialAuthorizations(
        AccessManagerExtendedInitializeable accessManager,
        InstanceAdmin instanceAdmin,
        Instance instance,
        BundleManager bundleManager,
        InstanceStore instanceStore,
        address instanceOwner,
        IRegistry registry,
        VersionPart majorVersion)
            external
    {
        _createRoles(instanceAdmin);
        _createTargets(instanceAdmin, instance, bundleManager, instanceStore);
        _grantDistributionServiceAuthorizations(accessManager, instanceAdmin, instanceStore, registry, majorVersion);
        _grantPoolServiceAuthorizations(accessManager, instanceAdmin, instanceStore, registry, majorVersion);
        _grantProductServiceAuthorizations(accessManager, instanceAdmin, instanceStore, registry, majorVersion);
        _grantApplicationServiceAuthorizations(accessManager, instanceAdmin, instanceStore, registry, majorVersion);
        _grantPolicyServiceAuthorizations(accessManager, instanceAdmin, instanceStore, registry, majorVersion);
        _grantClaimServiceAuthorizations(accessManager, instanceAdmin, instanceStore, registry, majorVersion);
        _grantBundleServiceAuthorizations(accessManager, instanceAdmin, instanceStore, bundleManager, registry, majorVersion);
        _grantInstanceServiceAuthorizations(accessManager, instanceAdmin, instance, registry, majorVersion);
        _grantInstanceAuthorizations(accessManager, instanceAdmin, instance, registry, majorVersion);
        _grantInstanceOwnerAuthorizations(instanceAdmin, instance, registry, majorVersion);
    }

    function _createRoles(InstanceAdmin instanceAdmin) private {
        // default roles controlled by ADMIN_ROLE -> core roles
        // all set/granted only once during cloning (the only exception is INSTANCE_OWNER_ROLE, hooked to instance nft)
        instanceAdmin.createCoreRole(INSTANCE_SERVICE_ROLE(), "InstanceServiceRole");
        instanceAdmin.createCoreRole(DISTRIBUTION_SERVICE_ROLE(), "DistributionServiceRole");
        instanceAdmin.createCoreRole(POOL_SERVICE_ROLE(), "PoolServiceRole");
        instanceAdmin.createCoreRole(APPLICATION_SERVICE_ROLE(), "ApplicationServiceRole");
        instanceAdmin.createCoreRole(PRODUCT_SERVICE_ROLE(), "ProductServiceRole");
        instanceAdmin.createCoreRole(CLAIM_SERVICE_ROLE(), "ClaimServiceRole");
        instanceAdmin.createCoreRole(POLICY_SERVICE_ROLE(), "PolicyServiceRole");
        instanceAdmin.createCoreRole(BUNDLE_SERVICE_ROLE(), "BundleServiceRole");
        // default roles controlled by INSTANCE_OWNER_ROLE -> gif roles
        instanceAdmin.createGifRole(DISTRIBUTION_OWNER_ROLE(), "DistributionOwnerRole", INSTANCE_OWNER_ROLE());
        instanceAdmin.createGifRole(POOL_OWNER_ROLE(), "PoolOwnerRole", INSTANCE_OWNER_ROLE());
        instanceAdmin.createGifRole(PRODUCT_OWNER_ROLE(), "ProductOwnerRole", INSTANCE_OWNER_ROLE());
    }

    function _createTargets(
        InstanceAdmin instanceAdmin,
        Instance instance,
        BundleManager bundleManager,
        InstanceStore instanceStore)
        private
    {
        instanceAdmin.createCoreTarget(address(instance), "Instance");
        //instanceAdmin.createCoreTarget(address(instanceAdmin), "InstanceAdmin");
        instanceAdmin.createCoreTarget(address(bundleManager), "BundleManager");
        instanceAdmin.createCoreTarget(address(instanceStore), "InstanceStore");
    }

    function _grantDistributionServiceAuthorizations(
        AccessManagerExtendedInitializeable accessManager,
        InstanceAdmin instanceAdmin,
        InstanceStore instanceStore,
        IRegistry registry,
        VersionPart majorVersion)
        private
    {
        // configure authorization for distribution service on instance
        address distributionServiceAddress = registry.getServiceAddress(DISTRIBUTION(), majorVersion);
        accessManager.grantRole(DISTRIBUTION_SERVICE_ROLE().toInt(), distributionServiceAddress, 0);
        bytes4[] memory instanceDistributionServiceSelectors = new bytes4[](11);
        instanceDistributionServiceSelectors[0] = instanceStore.createDistributionSetup.selector;
        instanceDistributionServiceSelectors[1] = instanceStore.updateDistributionSetup.selector;
        instanceDistributionServiceSelectors[2] = instanceStore.createDistributorType.selector;
        instanceDistributionServiceSelectors[3] = instanceStore.updateDistributorType.selector;
        instanceDistributionServiceSelectors[4] = instanceStore.updateDistributorTypeState.selector;
        instanceDistributionServiceSelectors[5] = instanceStore.createDistributor.selector;
        instanceDistributionServiceSelectors[6] = instanceStore.updateDistributor.selector;
        instanceDistributionServiceSelectors[7] = instanceStore.updateDistributorState.selector;
        instanceDistributionServiceSelectors[8] = instanceStore.createReferral.selector;
        instanceDistributionServiceSelectors[9] = instanceStore.updateReferral.selector;
        instanceDistributionServiceSelectors[10] = instanceStore.updateReferralState.selector;
        instanceAdmin.setCoreTargetFunctionRole(
            "InstanceStore",
            instanceDistributionServiceSelectors,
            DISTRIBUTION_SERVICE_ROLE());
    }

    function _grantPoolServiceAuthorizations(
        AccessManagerExtendedInitializeable accessManager,
        InstanceAdmin instanceAdmin,
        InstanceStore instanceStore,
        IRegistry registry,
        VersionPart majorVersion)
        private
    {
        // configure authorization for pool service on instance
        address poolServiceAddress = registry.getServiceAddress(POOL(), majorVersion);
        accessManager.grantRole(POOL_SERVICE_ROLE().toInt(), address(poolServiceAddress), 0);
        bytes4[] memory instancePoolServiceSelectors = new bytes4[](4);
        instancePoolServiceSelectors[0] = instanceStore.createPoolSetup.selector;
        instancePoolServiceSelectors[1] = instanceStore.updatePoolSetup.selector;
        instanceAdmin.setCoreTargetFunctionRole(
            "InstanceStore",
            instancePoolServiceSelectors,
            POOL_SERVICE_ROLE());
    }

    function _grantProductServiceAuthorizations(
        AccessManagerExtendedInitializeable accessManager,
        InstanceAdmin instanceAdmin,
        InstanceStore instanceStore,
        IRegistry registry,
        VersionPart majorVersion)
        private
    {
        // configure authorization for product service on instance
        address productServiceAddress = registry.getServiceAddress(PRODUCT(), majorVersion);
        accessManager.grantRole(PRODUCT_SERVICE_ROLE().toInt(), address(productServiceAddress), 0);
        bytes4[] memory instanceProductServiceSelectors = new bytes4[](5);
        instanceProductServiceSelectors[0] = instanceStore.createProductSetup.selector;
        instanceProductServiceSelectors[1] = instanceStore.updateProductSetup.selector;
        instanceProductServiceSelectors[2] = instanceStore.createRisk.selector;
        instanceProductServiceSelectors[3] = instanceStore.updateRisk.selector;
        instanceProductServiceSelectors[4] = instanceStore.updateRiskState.selector;
        instanceAdmin.setCoreTargetFunctionRole(
            "InstanceStore",
            instanceProductServiceSelectors,
            PRODUCT_SERVICE_ROLE());
    }

    function _grantApplicationServiceAuthorizations(
        AccessManagerExtendedInitializeable accessManager,
        InstanceAdmin instanceAdmin,
        InstanceStore instanceStore,
        IRegistry registry,
        VersionPart majorVersion)
        private
    {
        // configure authorization for application services on instance
        address applicationServiceAddress = registry.getServiceAddress(APPLICATION(), majorVersion);
        accessManager.grantRole(APPLICATION_SERVICE_ROLE().toInt(), applicationServiceAddress, 0);
        bytes4[] memory instanceApplicationServiceSelectors = new bytes4[](3);
        instanceApplicationServiceSelectors[0] = instanceStore.createApplication.selector;
        instanceApplicationServiceSelectors[1] = instanceStore.updateApplication.selector;
        instanceApplicationServiceSelectors[2] = instanceStore.updateApplicationState.selector;
        instanceAdmin.setCoreTargetFunctionRole(
            "InstanceStore",
            instanceApplicationServiceSelectors,
            APPLICATION_SERVICE_ROLE());
    }

    function _grantPolicyServiceAuthorizations(
        AccessManagerExtendedInitializeable accessManager,
        InstanceAdmin instanceAdmin,
        InstanceStore instanceStore,
        IRegistry registry,
        VersionPart majorVersion)
        private
    {
        // configure authorization for policy services on instance
        address policyServiceAddress = registry.getServiceAddress(POLICY(), majorVersion);
        accessManager.grantRole(POLICY_SERVICE_ROLE().toInt(), policyServiceAddress, 0);
        bytes4[] memory instancePolicyServiceSelectors = new bytes4[](2);
        instancePolicyServiceSelectors[0] = instanceStore.updatePolicy.selector;
        instancePolicyServiceSelectors[1] = instanceStore.updatePolicyState.selector;
        instanceAdmin.setCoreTargetFunctionRole(
            "InstanceStore",
            instancePolicyServiceSelectors,
            POLICY_SERVICE_ROLE());
    }

    function _grantClaimServiceAuthorizations(
        AccessManagerExtendedInitializeable accessManager,
        InstanceAdmin instanceAdmin,
        InstanceStore instanceStore,
        IRegistry registry,
        VersionPart majorVersion)
        private
    {
        // configure authorization for claim/payout services on instance
        address claimServiceAddress = registry.getServiceAddress(CLAIM(), majorVersion);
        accessManager.grantRole(CLAIM_SERVICE_ROLE().toInt(), claimServiceAddress, 0);

        bytes4[] memory instancePolicyServiceSelectors = new bytes4[](1);
        instancePolicyServiceSelectors[0] = instanceStore.updatePolicyClaims.selector;
        instanceAdmin.setCoreTargetFunctionRole(
            "InstanceStore",
            instancePolicyServiceSelectors, 
            CLAIM_SERVICE_ROLE());

        bytes4[] memory instanceClaimServiceSelectors = new bytes4[](4);
        instanceClaimServiceSelectors[0] = instanceStore.createClaim.selector;
        instanceClaimServiceSelectors[1] = instanceStore.updateClaim.selector;
        instanceClaimServiceSelectors[2] = instanceStore.createPayout.selector;
        instanceClaimServiceSelectors[3] = instanceStore.updatePayout.selector;
        instanceAdmin.setCoreTargetFunctionRole(
            "InstanceStore",
            instanceClaimServiceSelectors, 
            CLAIM_SERVICE_ROLE());
    }

    function _grantBundleServiceAuthorizations(
        AccessManagerExtendedInitializeable accessManager,
        InstanceAdmin instanceAdmin,
        InstanceStore instanceStore,
        BundleManager bundleManager,
        IRegistry registry,
        VersionPart majorVersion)
        private
    {
        // configure authorization for bundle service on instance
        address bundleServiceAddress = registry.getServiceAddress(BUNDLE(), majorVersion);
        accessManager.grantRole(BUNDLE_SERVICE_ROLE().toInt(), address(bundleServiceAddress), 0);
        bytes4[] memory instanceBundleServiceSelectors = new bytes4[](3);
        instanceBundleServiceSelectors[0] = instanceStore.createBundle.selector;
        instanceBundleServiceSelectors[1] = instanceStore.updateBundle.selector;
        instanceBundleServiceSelectors[2] = instanceStore.updateBundleState.selector;
        instanceAdmin.setCoreTargetFunctionRole(
            "InstanceStore",
            instanceBundleServiceSelectors,
            BUNDLE_SERVICE_ROLE());

        // configure authorization for bundle service on bundle manager
        bytes4[] memory bundleManagerBundleServiceSelectors = new bytes4[](5);
        bundleManagerBundleServiceSelectors[0] = bundleManager.linkPolicy.selector;
        bundleManagerBundleServiceSelectors[1] = bundleManager.unlinkPolicy.selector;
        bundleManagerBundleServiceSelectors[2] = bundleManager.add.selector;
        bundleManagerBundleServiceSelectors[3] = bundleManager.lock.selector;
        bundleManagerBundleServiceSelectors[4] = bundleManager.unlock.selector;
        instanceAdmin.setCoreTargetFunctionRole(
            "BundleManager",
            bundleManagerBundleServiceSelectors,
            BUNDLE_SERVICE_ROLE());
    }

    function _grantInstanceServiceAuthorizations(
        AccessManagerExtendedInitializeable accessManager,
        InstanceAdmin instanceAdmin,
        Instance instance,
        IRegistry registry,
        VersionPart majorVersion)
        private
    {
        // configure authorization for instance service on instance
        address instanceServiceAddress = registry.getServiceAddress(INSTANCE(), majorVersion);
        accessManager.grantRole(INSTANCE_SERVICE_ROLE().toInt(), instanceServiceAddress, 0);
        bytes4[] memory instanceInstanceServiceSelectors = new bytes4[](1);
        instanceInstanceServiceSelectors[0] = instance.setInstanceReader.selector;
        instanceAdmin.setCoreTargetFunctionRole(
            "Instance",
            instanceInstanceServiceSelectors,
            INSTANCE_SERVICE_ROLE());

        // configure authorizations for instance service on instance access manager
        bytes4[] memory instanceAdminInstanceServiceSelectors = new bytes4[](3);
        instanceAdminInstanceServiceSelectors[0] = instanceAdmin.createGifTarget.selector;
        instanceAdminInstanceServiceSelectors[1] = instanceAdmin.setTargetLockedByService.selector;
        instanceAdminInstanceServiceSelectors[2] = instanceAdmin.setCoreTargetFunctionRole.selector;
        instanceAdmin.setCoreTargetFunctionRole(
            "InstanceAdmin",
            instanceAdminInstanceServiceSelectors,
            INSTANCE_SERVICE_ROLE());
    }

    function _grantInstanceAuthorizations(
        AccessManagerExtendedInitializeable accessManager,
        InstanceAdmin instanceAdmin,
        Instance instance,
        IRegistry registry,
        VersionPart majorVersion)
        private
    {
        // configure authorizations for instance on instance admin
        bytes4[] memory instanceAdminInstanceSelectors = new bytes4[](4);
        instanceAdminInstanceSelectors[0] = instanceAdmin.createRole.selector;
        instanceAdminInstanceSelectors[1] = instanceAdmin.createTarget.selector;
        instanceAdminInstanceSelectors[2] = instanceAdmin.setTargetFunctionRole.selector;
        instanceAdminInstanceSelectors[3] = instanceAdmin.setTargetLockedByInstance.selector;
        instanceAdmin.setCoreTargetFunctionRole(
            "InstanceAdmin",
            instanceAdminInstanceSelectors,
            INSTANCE_ROLE());
    }

    function _grantInstanceOwnerAuthorizations(
        InstanceAdmin instanceAdmin,
        Instance instance,
        IRegistry registry,
        VersionPart majorVersion) 
        private 
    {
        // configure authorization for instance owner on instance access manager
        // instance owner role is granted/revoked ONLY by INSTANCE_ROLE
        bytes4[] memory instanceInstanceOwnerSelectors = new bytes4[](4);
        instanceInstanceOwnerSelectors[0] = instance.createRole.selector;
        instanceInstanceOwnerSelectors[1] = instance.createTarget.selector;
        instanceInstanceOwnerSelectors[2] = instance.setTargetFunctionRole.selector;
        instanceInstanceOwnerSelectors[3] = instance.setTargetLocked.selector;
        instanceAdmin.setCoreTargetFunctionRole(
            "Instance",
            instanceInstanceOwnerSelectors,
            INSTANCE_OWNER_ROLE());
    }
}