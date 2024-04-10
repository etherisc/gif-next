// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ADMIN_ROLE, INSTANCE_OWNER_ROLE, DISTRIBUTION_OWNER_ROLE, POOL_OWNER_ROLE, PRODUCT_OWNER_ROLE, INSTANCE_SERVICE_ROLE, DISTRIBUTION_SERVICE_ROLE, POOL_SERVICE_ROLE, PRODUCT_SERVICE_ROLE, APPLICATION_SERVICE_ROLE, POLICY_SERVICE_ROLE, CLAIM_SERVICE_ROLE, BUNDLE_SERVICE_ROLE, INSTANCE_ROLE} from "../types/RoleId.sol";
import {INSTANCE, BUNDLE, APPLICATION, POLICY, CLAIM, PRODUCT, DISTRIBUTION, REGISTRY, POOL} from "../types/ObjectType.sol";
import {VersionPart} from "../types/Version.sol";

import {IRegistry} from "../registry/IRegistry.sol";

import {Instance} from "./Instance.sol";
import {InstanceAccessManager} from "./InstanceAccessManager.sol";
import {InstanceReader} from "./InstanceReader.sol";
import {BundleManager} from "./BundleManager.sol";
import {AccessManagerUpgradeableInitializeable} from "../shared/AccessManagerUpgradeableInitializeable.sol";
import {InstanceStore} from "./InstanceStore.sol";


library InstanceAuthorizationsLib
{
    function grantInitialAuthorizations(
        InstanceAccessManager clonedAccessManager,
        Instance clonedInstance,
        BundleManager clonedBundleManager,
        InstanceStore clonedInstanceStore,
        address instanceOwner,
        IRegistry registry,
        VersionPart majorVersion)
            external
    {
        _createCoreAndGifRoles(clonedAccessManager);
        _createCoreTargets(clonedAccessManager, clonedInstance, clonedBundleManager, clonedInstanceStore);
        _grantDistributionServiceAuthorizations(clonedAccessManager, clonedInstanceStore, registry, majorVersion);
        _grantPoolServiceAuthorizations(clonedAccessManager, clonedInstanceStore, registry, majorVersion);
        _grantProductServiceAuthorizations(clonedAccessManager, clonedInstanceStore, registry, majorVersion);
        _grantApplicationServiceAuthorizations(clonedAccessManager, clonedInstanceStore, registry, majorVersion);
        _grantPolicyServiceAuthorizations(clonedAccessManager, clonedInstanceStore, registry, majorVersion);
        _grantClaimServiceAuthorizations(clonedAccessManager, clonedInstanceStore, registry, majorVersion);
        _grantBundleServiceAuthorizations(clonedAccessManager, clonedInstanceStore, clonedBundleManager, registry, majorVersion);
        _grantInstanceServiceAuthorizations(clonedAccessManager, clonedInstance, registry, majorVersion);
        _grantInstanceAuthorizations(clonedAccessManager, registry, majorVersion);
        _grantInstanceOwnerAuthorizations(clonedAccessManager, clonedInstance, registry, majorVersion);
    }

    function _createCoreAndGifRoles(InstanceAccessManager clonedAccessManager) private {
        // default roles controlled by ADMIN_ROLE -> core roles
        // all set/granted only once during cloning (the only exception is INSTANCE_OWNER_ROLE, hooked to instance nft)
        clonedAccessManager.createCoreRole(INSTANCE_SERVICE_ROLE(), "InstanceServiceRole");
        clonedAccessManager.createCoreRole(DISTRIBUTION_SERVICE_ROLE(), "DistributionServiceRole");
        clonedAccessManager.createCoreRole(POOL_SERVICE_ROLE(), "PoolServiceRole");
        clonedAccessManager.createCoreRole(APPLICATION_SERVICE_ROLE(), "ApplicationServiceRole");
        clonedAccessManager.createCoreRole(PRODUCT_SERVICE_ROLE(), "ProductServiceRole");
        clonedAccessManager.createCoreRole(CLAIM_SERVICE_ROLE(), "ClaimServiceRole");
        clonedAccessManager.createCoreRole(POLICY_SERVICE_ROLE(), "PolicyServiceRole");
        clonedAccessManager.createCoreRole(BUNDLE_SERVICE_ROLE(), "BundleServiceRole");
        // default roles controlled by INSTANCE_OWNER_ROLE -> gif roles
        clonedAccessManager.createGifRole(DISTRIBUTION_OWNER_ROLE(), "DistributionOwnerRole", INSTANCE_OWNER_ROLE());
        clonedAccessManager.createGifRole(POOL_OWNER_ROLE(), "PoolOwnerRole", INSTANCE_OWNER_ROLE());
        clonedAccessManager.createGifRole(PRODUCT_OWNER_ROLE(), "ProductOwnerRole", INSTANCE_OWNER_ROLE());
    }

    function _createCoreTargets(
        InstanceAccessManager clonedAccessManager,
        Instance clonedInstance,
        BundleManager clonedBundleManager,
        InstanceStore clonedInstanceStore)
        private
    {
        clonedAccessManager.createCoreTarget(address(clonedAccessManager), "InstanceAccessManager");// TODO create in instance access manager initializer?
        clonedAccessManager.createCoreTarget(address(clonedInstance), "Instance");// TODO create in instance access manager initializer?
        clonedAccessManager.createCoreTarget(address(clonedBundleManager), "BundleManager");
        clonedAccessManager.createCoreTarget(address(clonedInstanceStore), "InstanceStore");
    }

    function _grantDistributionServiceAuthorizations(
        InstanceAccessManager clonedAccessManager,
        InstanceStore clonedInstanceStore,
        IRegistry registry,
        VersionPart majorVersion)
        private
    {
        // configure authorization for distribution service on instance
        address distributionServiceAddress = registry.getServiceAddress(DISTRIBUTION(), majorVersion);
        clonedAccessManager.grantRole(DISTRIBUTION_SERVICE_ROLE(), distributionServiceAddress);
        bytes4[] memory instanceDistributionServiceSelectors = new bytes4[](11);
        instanceDistributionServiceSelectors[0] = clonedInstanceStore.createDistributionSetup.selector;
        instanceDistributionServiceSelectors[1] = clonedInstanceStore.updateDistributionSetup.selector;
        instanceDistributionServiceSelectors[2] = clonedInstanceStore.createDistributorType.selector;
        instanceDistributionServiceSelectors[3] = clonedInstanceStore.updateDistributorType.selector;
        instanceDistributionServiceSelectors[4] = clonedInstanceStore.updateDistributorTypeState.selector;
        instanceDistributionServiceSelectors[5] = clonedInstanceStore.createDistributor.selector;
        instanceDistributionServiceSelectors[6] = clonedInstanceStore.updateDistributor.selector;
        instanceDistributionServiceSelectors[7] = clonedInstanceStore.updateDistributorState.selector;
        instanceDistributionServiceSelectors[8] = clonedInstanceStore.createReferral.selector;
        instanceDistributionServiceSelectors[9] = clonedInstanceStore.updateReferral.selector;
        instanceDistributionServiceSelectors[10] = clonedInstanceStore.updateReferralState.selector;
        clonedAccessManager.setCoreTargetFunctionRole(
            "InstanceStore",
            instanceDistributionServiceSelectors,
            DISTRIBUTION_SERVICE_ROLE());
    }

    function _grantPoolServiceAuthorizations(
        InstanceAccessManager clonedAccessManager,
        InstanceStore clonedInstanceStore,
        IRegistry registry,
        VersionPart majorVersion)
        private
    {
        // configure authorization for pool service on instance
        address poolServiceAddress = registry.getServiceAddress(POOL(), majorVersion);
        clonedAccessManager.grantRole(POOL_SERVICE_ROLE(), address(poolServiceAddress));
        bytes4[] memory instancePoolServiceSelectors = new bytes4[](4);
        instancePoolServiceSelectors[0] = clonedInstanceStore.createPoolSetup.selector;
        instancePoolServiceSelectors[1] = clonedInstanceStore.updatePoolSetup.selector;
        clonedAccessManager.setCoreTargetFunctionRole(
            "InstanceStore",
            instancePoolServiceSelectors,
            POOL_SERVICE_ROLE());
    }

    function _grantProductServiceAuthorizations(
        InstanceAccessManager clonedAccessManager,
        InstanceStore clonedInstanceStore,
        IRegistry registry,
        VersionPart majorVersion)
        private
    {
        // configure authorization for product service on instance
        address productServiceAddress = registry.getServiceAddress(PRODUCT(), majorVersion);
        clonedAccessManager.grantRole(PRODUCT_SERVICE_ROLE(), address(productServiceAddress));
        bytes4[] memory instanceProductServiceSelectors = new bytes4[](5);
        instanceProductServiceSelectors[0] = clonedInstanceStore.createProductSetup.selector;
        instanceProductServiceSelectors[1] = clonedInstanceStore.updateProductSetup.selector;
        instanceProductServiceSelectors[2] = clonedInstanceStore.createRisk.selector;
        instanceProductServiceSelectors[3] = clonedInstanceStore.updateRisk.selector;
        instanceProductServiceSelectors[4] = clonedInstanceStore.updateRiskState.selector;
        clonedAccessManager.setCoreTargetFunctionRole(
            "InstanceStore",
            instanceProductServiceSelectors,
            PRODUCT_SERVICE_ROLE());
    }

    function _grantApplicationServiceAuthorizations(
        InstanceAccessManager clonedAccessManager,
        InstanceStore clonedInstanceStore,
        IRegistry registry,
        VersionPart majorVersion)
        private
    {
        // configure authorization for application services on instance
        address applicationServiceAddress = registry.getServiceAddress(APPLICATION(), majorVersion);
        clonedAccessManager.grantRole(APPLICATION_SERVICE_ROLE(), applicationServiceAddress);
        bytes4[] memory instanceApplicationServiceSelectors = new bytes4[](3);
        instanceApplicationServiceSelectors[0] = clonedInstanceStore.createApplication.selector;
        instanceApplicationServiceSelectors[1] = clonedInstanceStore.updateApplication.selector;
        instanceApplicationServiceSelectors[2] = clonedInstanceStore.updateApplicationState.selector;
        clonedAccessManager.setCoreTargetFunctionRole(
            "InstanceStore",
            instanceApplicationServiceSelectors,
            APPLICATION_SERVICE_ROLE());
    }

    function _grantPolicyServiceAuthorizations(
        InstanceAccessManager clonedAccessManager,
        InstanceStore clonedInstanceStore,
        IRegistry registry,
        VersionPart majorVersion)
        private
    {
        // configure authorization for policy services on instance
        address policyServiceAddress = registry.getServiceAddress(POLICY(), majorVersion);
        clonedAccessManager.grantRole(POLICY_SERVICE_ROLE(), policyServiceAddress);
        bytes4[] memory instancePolicyServiceSelectors = new bytes4[](2);
        instancePolicyServiceSelectors[0] = clonedInstanceStore.updatePolicy.selector;
        instancePolicyServiceSelectors[1] = clonedInstanceStore.updatePolicyState.selector;
        clonedAccessManager.setCoreTargetFunctionRole(
            "InstanceStore",
            instancePolicyServiceSelectors,
            POLICY_SERVICE_ROLE());
    }

    function _grantClaimServiceAuthorizations(
        InstanceAccessManager clonedAccessManager,
        InstanceStore clonedInstanceStore,
        IRegistry registry,
        VersionPart majorVersion)
        private
    {
        // configure authorization for claim/payout services on instance
        address claimServiceAddress = registry.getServiceAddress(CLAIM(), majorVersion);
        clonedAccessManager.grantRole(CLAIM_SERVICE_ROLE(), claimServiceAddress);

        bytes4[] memory instancePolicyServiceSelectors = new bytes4[](1);
        instancePolicyServiceSelectors[0] = clonedInstanceStore.updatePolicyClaims.selector;
        clonedAccessManager.setCoreTargetFunctionRole(
            "InstanceStore",
            instancePolicyServiceSelectors, 
            CLAIM_SERVICE_ROLE());

        bytes4[] memory instanceClaimServiceSelectors = new bytes4[](4);
        instanceClaimServiceSelectors[0] = clonedInstanceStore.createClaim.selector;
        instanceClaimServiceSelectors[1] = clonedInstanceStore.updateClaim.selector;
        instanceClaimServiceSelectors[2] = clonedInstanceStore.createPayout.selector;
        instanceClaimServiceSelectors[3] = clonedInstanceStore.updatePayout.selector;
        clonedAccessManager.setCoreTargetFunctionRole(
            "InstanceStore",
            instanceClaimServiceSelectors, 
            CLAIM_SERVICE_ROLE());
    }

    function _grantBundleServiceAuthorizations(
        InstanceAccessManager clonedAccessManager,
        InstanceStore clonedInstanceStore,
        BundleManager clonedBundleManager,
        IRegistry registry,
        VersionPart majorVersion)
        private
    {
        // configure authorization for bundle service on instance
        address bundleServiceAddress = registry.getServiceAddress(BUNDLE(), majorVersion);
        clonedAccessManager.grantRole(BUNDLE_SERVICE_ROLE(), address(bundleServiceAddress));
        bytes4[] memory instanceBundleServiceSelectors = new bytes4[](3);
        instanceBundleServiceSelectors[0] = clonedInstanceStore.createBundle.selector;
        instanceBundleServiceSelectors[1] = clonedInstanceStore.updateBundle.selector;
        instanceBundleServiceSelectors[2] = clonedInstanceStore.updateBundleState.selector;
        clonedAccessManager.setCoreTargetFunctionRole(
            "InstanceStore",
            instanceBundleServiceSelectors,
            BUNDLE_SERVICE_ROLE());

        // configure authorization for bundle service on bundle manager
        bytes4[] memory bundleManagerBundleServiceSelectors = new bytes4[](5);
        bundleManagerBundleServiceSelectors[0] = clonedBundleManager.linkPolicy.selector;
        bundleManagerBundleServiceSelectors[1] = clonedBundleManager.unlinkPolicy.selector;
        bundleManagerBundleServiceSelectors[2] = clonedBundleManager.add.selector;
        bundleManagerBundleServiceSelectors[3] = clonedBundleManager.lock.selector;
        bundleManagerBundleServiceSelectors[4] = clonedBundleManager.unlock.selector;
        clonedAccessManager.setCoreTargetFunctionRole(
            "BundleManager",
            bundleManagerBundleServiceSelectors,
            BUNDLE_SERVICE_ROLE());
    }

    function _grantInstanceServiceAuthorizations(
        InstanceAccessManager clonedAccessManager,
        Instance clonedInstance,
        IRegistry registry,
        VersionPart majorVersion)
        private
    {
        // configure authorization for instance service on instance
        address instanceServiceAddress = registry.getServiceAddress(INSTANCE(), majorVersion);
        clonedAccessManager.grantRole(INSTANCE_SERVICE_ROLE(), instanceServiceAddress);
        bytes4[] memory instanceInstanceServiceSelectors = new bytes4[](1);
        instanceInstanceServiceSelectors[0] = clonedInstance.setInstanceReader.selector;
        clonedAccessManager.setCoreTargetFunctionRole(
            "Instance",
            instanceInstanceServiceSelectors,
            INSTANCE_SERVICE_ROLE());

        // configure authorizations for instance service on instance access manager
        bytes4[] memory accessManagerInstanceServiceSelectors = new bytes4[](3);
        accessManagerInstanceServiceSelectors[0] = clonedAccessManager.createGifTarget.selector;
        accessManagerInstanceServiceSelectors[1] = clonedAccessManager.setTargetLockedByService.selector;
        accessManagerInstanceServiceSelectors[2] = clonedAccessManager.setCoreTargetFunctionRole.selector;
        clonedAccessManager.setCoreTargetFunctionRole(
            "InstanceAccessManager",
            accessManagerInstanceServiceSelectors,
            INSTANCE_SERVICE_ROLE());
    }

    function _grantInstanceAuthorizations(
        InstanceAccessManager clonedAccessManager,
        IRegistry registry,
        VersionPart majorVersion)
        private
    {
        bytes4[] memory accessManagerInstanceSelectors = new bytes4[](4);
        accessManagerInstanceSelectors[0] = clonedAccessManager.createRole.selector;
        accessManagerInstanceSelectors[1] = clonedAccessManager.createTarget.selector;
        accessManagerInstanceSelectors[2] = clonedAccessManager.setTargetFunctionRole.selector;
        accessManagerInstanceSelectors[3] = clonedAccessManager.setTargetLockedByInstance.selector;
        clonedAccessManager.setCoreTargetFunctionRole(
            "InstanceAccessManager",
            accessManagerInstanceSelectors,
            INSTANCE_ROLE());
    }

    function _grantInstanceOwnerAuthorizations(
        InstanceAccessManager clonedAccessManager,
        Instance clonedInstance,
        IRegistry registry,
        VersionPart majorVersion) 
        private 
    {
        // configure authorization for instance owner on instance access manager
        // instance owner role is granted/revoked ONLY by INSTANCE_ROLE
        bytes4[] memory instanceInstanceOwnerSelectors = new bytes4[](4);
        instanceInstanceOwnerSelectors[0] = clonedInstance.createRole.selector;
        instanceInstanceOwnerSelectors[1] = clonedInstance.createTarget.selector;
        instanceInstanceOwnerSelectors[2] = clonedInstance.setTargetFunctionRole.selector;
        instanceInstanceOwnerSelectors[3] = clonedInstance.setTargetLocked.selector;
        clonedAccessManager.setCoreTargetFunctionRole(
            "Instance",
            instanceInstanceOwnerSelectors,
            INSTANCE_OWNER_ROLE());
    }
}