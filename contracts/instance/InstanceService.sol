// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {ShortString, ShortStrings} from "@openzeppelin/contracts/utils/ShortStrings.sol";

import {Instance} from "./Instance.sol";
import {IInstance} from "./IInstance.sol";
import {InstanceAccessManager} from "./InstanceAccessManager.sol";
import {IInstanceService} from "./IInstanceService.sol";
import {InstanceReader} from "./InstanceReader.sol";
import {BundleManager} from "./BundleManager.sol";
import {InstanceStore} from "./InstanceStore.sol";
import {AccessManagerUpgradeableInitializeable} from "./AccessManagerUpgradeableInitializeable.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IRegistryService} from "../registry/IRegistryService.sol";
import {Service} from "../../contracts/shared/Service.sol";
import {NftId} from "../../contracts/types/NftId.sol";
import {RoleId} from "../types/RoleId.sol";
import {ADMIN_ROLE, INSTANCE_OWNER_ROLE, DISTRIBUTION_OWNER_ROLE, POOL_OWNER_ROLE, PRODUCT_OWNER_ROLE, INSTANCE_SERVICE_ROLE, DISTRIBUTION_SERVICE_ROLE, POOL_SERVICE_ROLE, PRODUCT_SERVICE_ROLE, APPLICATION_SERVICE_ROLE, POLICY_SERVICE_ROLE, CLAIM_SERVICE_ROLE, BUNDLE_SERVICE_ROLE, INSTANCE_ROLE} from "../types/RoleId.sol";
import {ObjectType, INSTANCE, BUNDLE, APPLICATION, POLICY, CLAIM, PRODUCT, DISTRIBUTION, REGISTRY, POOL} from "../types/ObjectType.sol";

contract InstanceService is
    Service,
    IInstanceService
{

    // TODO update to real hash when instance is stable
    bytes32 public constant INSTANCE_CREATION_CODE_HASH = bytes32(0);

    IRegistryService internal _registryService;
    address internal _masterOzAccessManager;
    address internal _masterInstanceAccessManager;
    address internal _masterInstance;
    address internal _masterInstanceReader;
    address internal _masterInstanceBundleManager;
    address internal _masterInstanceStore;

    modifier onlyInstanceOwner(NftId instanceNftId) {        
        if(msg.sender != getRegistry().ownerOf(instanceNftId)) {
            revert ErrorInstanceServiceRequestUnauhorized(msg.sender);
        }
        _;
    }
    // TODO check service domain?
    // TODO check release version?
    modifier onlyRegisteredService() {
        if (! getRegistry().isRegisteredService(msg.sender)) {
            revert ErrorInstanceServiceRequestUnauhorized(msg.sender);
        }
        _;
    }
    // TODO check release version?
    modifier onlyComponent() {
        if (! getRegistry().isRegisteredComponent(msg.sender)) {
            revert ErrorInstanceServiceRequestUnauhorized(msg.sender);
        }
        _;
    }

    function createInstanceClone()
        external 
        returns (
            Instance clonedInstance,
            NftId clonedInstanceNftId
        )
    {
        address instanceOwner = msg.sender;
        AccessManagerUpgradeableInitializeable clonedOzAccessManager = AccessManagerUpgradeableInitializeable(
            Clones.clone(_masterOzAccessManager));

        // initially grants ADMIN_ROLE to this (being the instance service). 
        // This will allow the instance service to bootstrap the authorizations of the instance.
        // Instance service will not use oz access manager directlly but through instance access manager instead
        // Instance service will renounce ADMIN_ROLE when bootstraping is finished
        clonedOzAccessManager.initialize(address(this));

        clonedInstance = Instance(Clones.clone(_masterInstance));
        clonedInstance.initialize(
            address(clonedOzAccessManager),
            address(getRegistry()), 
            instanceOwner);

        InstanceStore clonedInstanceStore = InstanceStore(Clones.clone(address(_masterInstanceStore)));
        clonedInstanceStore.initialize(address(clonedInstance));
        clonedInstance.setInstanceStore(clonedInstanceStore);
        
        InstanceReader clonedInstanceReader = InstanceReader(Clones.clone(address(_masterInstanceReader)));
        clonedInstanceReader.initialize(address(clonedInstance));
        clonedInstance.setInstanceReader(clonedInstanceReader);

        BundleManager clonedBundleManager = BundleManager(Clones.clone(_masterInstanceBundleManager));
        clonedBundleManager.initialize(address(clonedInstance));
        clonedInstance.setBundleManager(clonedBundleManager);

        InstanceAccessManager clonedInstanceAccessManager = InstanceAccessManager(Clones.clone(_masterInstanceAccessManager));
        clonedOzAccessManager.grantRole(ADMIN_ROLE().toInt(), address(clonedInstanceAccessManager), 0);
        clonedInstanceAccessManager.initialize(address(clonedInstance));
        clonedInstance.setInstanceAccessManager(clonedInstanceAccessManager);

        // TODO amend setters with instance specific , policy manager ...

        _grantInitialAuthorizations(
            clonedInstanceAccessManager, 
            clonedInstance, 
            clonedBundleManager, 
            clonedInstanceStore, 
            instanceOwner
        );

        clonedOzAccessManager.renounceRole(ADMIN_ROLE().toInt(), address(this));

        IRegistry.ObjectInfo memory info = _registryService.registerInstance(clonedInstance, instanceOwner);
        clonedInstanceNftId = info.nftId;

        emit LogInstanceCloned(
            address(clonedOzAccessManager), 
            address(clonedInstanceAccessManager), 
            address(clonedInstance), 
            address(clonedBundleManager), 
            address(clonedInstanceReader), 
            clonedInstanceNftId);
    }

    function _grantInitialAuthorizations(
        InstanceAccessManager clonedAccessManager, 
        Instance clonedInstance, 
        BundleManager clonedBundleManager,
        InstanceStore clonedInstanceStore,
        address instanceOwner) 
            internal 
    {
        _createCoreAndGifRoles(clonedAccessManager);
        _createCoreTargets(clonedAccessManager, clonedInstance, clonedBundleManager, clonedInstanceStore);
        _grantDistributionServiceAuthorizations(clonedAccessManager, clonedInstanceStore);
        _grantPoolServiceAuthorizations(clonedAccessManager, clonedInstanceStore);
        _grantProductServiceAuthorizations(clonedAccessManager, clonedInstanceStore);
        _grantApplicationServiceAuthorizations(clonedAccessManager, clonedInstanceStore);    
        _grantPolicyServiceAuthorizations(clonedAccessManager, clonedInstanceStore);    
        _grantClaimServiceAuthorizations(clonedAccessManager, clonedInstanceStore);    
        _grantBundleServiceAuthorizations(clonedAccessManager, clonedInstanceStore, clonedBundleManager);
        _grantInstanceServiceAuthorizations(clonedAccessManager, clonedInstance);
        _grantInstanceOwnerAuthorizations(clonedAccessManager, instanceOwner);
    }

    function _createCoreAndGifRoles(InstanceAccessManager clonedAccessManager) internal {
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
        InstanceStore clonedInstanceStore
    ) 
        internal 
    {
        clonedAccessManager.createCoreTarget(address(clonedAccessManager), "InstanceAccessManager");
        clonedAccessManager.createCoreTarget(address(clonedInstance), "Instance");
        clonedAccessManager.createCoreTarget(address(clonedBundleManager), "BundleManager");
        clonedAccessManager.createCoreTarget(address(clonedInstanceStore), "InstanceStore");
    }   

    function _grantDistributionServiceAuthorizations(InstanceAccessManager clonedAccessManager, InstanceStore clonedInstanceStore) internal {
        // configure authorization for distribution service on instance store
        address distributionServiceAddress = getRegistry().getServiceAddress(DISTRIBUTION(), getVersion().toMajorPart());
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

    function _grantPoolServiceAuthorizations(InstanceAccessManager clonedAccessManager, InstanceStore clonedInstanceStore) internal {
        // configure authorization for pool service on instance store
        address poolServiceAddress = getRegistry().getServiceAddress(POOL(), getVersion().toMajorPart());
        clonedAccessManager.grantRole(POOL_SERVICE_ROLE(), address(poolServiceAddress));
        bytes4[] memory instancePoolServiceSelectors = new bytes4[](4);
        instancePoolServiceSelectors[0] = clonedInstanceStore.createPoolSetup.selector;
        instancePoolServiceSelectors[1] = clonedInstanceStore.updatePoolSetup.selector;
        clonedAccessManager.setCoreTargetFunctionRole(
            "InstanceStore",
            instancePoolServiceSelectors, 
            POOL_SERVICE_ROLE());
    }

    function _grantProductServiceAuthorizations(InstanceAccessManager clonedAccessManager, InstanceStore clonedInstanceStore) internal {
        // configure authorization for product service on instance store
        address productServiceAddress = getRegistry().getServiceAddress(PRODUCT(), getVersion().toMajorPart());
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

    function _grantApplicationServiceAuthorizations(InstanceAccessManager clonedAccessManager, InstanceStore clonedInstanceStore) internal {
        // configure authorization for application services on instance
        address applicationServiceAddress = getRegistry().getServiceAddress(APPLICATION(), getVersion().toMajorPart());
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

    function _grantPolicyServiceAuthorizations(InstanceAccessManager clonedAccessManager, InstanceStore clonedInstanceStore) internal {
        // configure authorization for policy services on instance store
        address policyServiceAddress = getRegistry().getServiceAddress(POLICY(), getVersion().toMajorPart());
        clonedAccessManager.grantRole(POLICY_SERVICE_ROLE(), policyServiceAddress);
        bytes4[] memory instancePolicyServiceSelectors = new bytes4[](2);
        instancePolicyServiceSelectors[0] = clonedInstanceStore.updatePolicy.selector;
        instancePolicyServiceSelectors[1] = clonedInstanceStore.updatePolicyState.selector;
        clonedAccessManager.setCoreTargetFunctionRole(
            "InstanceStore",
            instancePolicyServiceSelectors, 
            POLICY_SERVICE_ROLE());
    }

    function _grantClaimServiceAuthorizations(InstanceAccessManager clonedAccessManager, InstanceStore clonedInstanceStore) internal {
        // configure authorization for claim/payout services on instance
        address claimServiceAddress = getRegistry().getServiceAddress(CLAIM(), getVersion().toMajorPart());
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

    function _grantBundleServiceAuthorizations(InstanceAccessManager clonedAccessManager, InstanceStore clonedInstanceStore, BundleManager clonedBundleManager) internal {
        // configure authorization for bundle service on instance store
        address bundleServiceAddress = getRegistry().getServiceAddress(BUNDLE(), getVersion().toMajorPart());
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

    function _grantInstanceServiceAuthorizations(InstanceAccessManager clonedAccessManager, Instance clonedInstance) internal {
        // configure authorization for instance service on instance
        address instanceServiceAddress = getRegistry().getServiceAddress(INSTANCE(), getVersion().toMajorPart());
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
        accessManagerInstanceServiceSelectors[1] = clonedAccessManager.setTargetLocked.selector;
        accessManagerInstanceServiceSelectors[2] = clonedAccessManager.setCoreTargetFunctionRole.selector;
        clonedAccessManager.setCoreTargetFunctionRole(
            "InstanceAccessManager",
            accessManagerInstanceServiceSelectors, 
            INSTANCE_SERVICE_ROLE());
    }

    function _grantInstanceOwnerAuthorizations(InstanceAccessManager clonedAccessManager, address instanceOwner) internal {
        // configure authorization for instance owner on instance access manager
        // instance owner role is granted/revoked ONLY by INSTANCE_ROLE
        bytes4[] memory accessManagerInstanceOwnerSelectors = new bytes4[](3);
        accessManagerInstanceOwnerSelectors[0] = clonedAccessManager.createRole.selector;
        accessManagerInstanceOwnerSelectors[1] = clonedAccessManager.createTarget.selector;
        accessManagerInstanceOwnerSelectors[2] = clonedAccessManager.setTargetFunctionRole.selector;
        clonedAccessManager.setCoreTargetFunctionRole(
            "InstanceAccessManager",
            accessManagerInstanceOwnerSelectors, 
            INSTANCE_OWNER_ROLE());
    }


    function setAndRegisterMasterInstance(address instanceAddress) 
            external 
            onlyOwner 
            returns(NftId masterInstanceNftId)
    {
        if(_masterInstance != address(0)) { revert ErrorInstanceServiceMasterInstanceAlreadySet(); }
        if(_masterOzAccessManager != address(0)) { revert ErrorInstanceServiceMasterOzAccessManagerAlreadySet(); }
        if(_masterInstanceAccessManager != address(0)) { revert ErrorInstanceServiceMasterInstanceAccessManagerAlreadySet(); }
        if(_masterInstanceBundleManager != address(0)) { revert ErrorInstanceServiceMasterBundleManagerAlreadySet(); }

        if(instanceAddress == address(0)) { revert ErrorInstanceServiceInstanceAddressZero(); }

        IInstance instance = IInstance(instanceAddress);
        InstanceAccessManager instanceAccessManager = instance.getInstanceAccessManager();
        address instanceAccessManagerAddress = address(instanceAccessManager);
        InstanceReader instanceReader = instance.getInstanceReader();
        address instanceReaderAddress = address(instanceReader);
        BundleManager bundleManager = instance.getBundleManager();
        address bundleManagerAddress = address(bundleManager);
        InstanceStore instanceStore = instance.getInstanceStore();
        address instanceStoreAddress = address(instanceStore);

        if(instanceAccessManagerAddress == address(0)) { revert ErrorInstanceServiceInstanceAccessManagerZero(); }
        if(instanceReaderAddress == address(0)) { revert ErrorInstanceServiceInstanceReaderZero(); }
        if(bundleManagerAddress == address(0)) { revert ErrorInstanceServiceBundleManagerZero(); }
        if(instanceStoreAddress == address(0)) { revert ErrorInstanceServiceInstanceStoreZero(); }
        
        if(instance.authority() != instanceAccessManager.authority()) { revert ErrorInstanceServiceInstanceAuthorityMismatch(); }
        if(bundleManager.authority() != instanceAccessManager.authority()) { revert ErrorInstanceServiceBundleManagerAuthorityMismatch(); }
        if(instanceStore.authority() != instanceAccessManager.authority()) { revert ErrorInstanceServiceInstanceStoreAuthorityMismatch(); }
        if(bundleManager.getInstance() != instance) { revert ErrorInstanceServiceBundleMangerInstanceMismatch(); }
        if(instanceReader.getInstance() != instance) { revert ErrorInstanceServiceInstanceReaderInstanceMismatch2(); }

        _masterOzAccessManager = instance.authority();
        _masterInstanceAccessManager = instanceAccessManagerAddress;
        _masterInstance = instanceAddress;
        _masterInstanceReader = instanceReaderAddress;
        _masterInstanceBundleManager = bundleManagerAddress;
        _masterInstanceStore = instanceStoreAddress;
        
        IInstance masterInstance = IInstance(_masterInstance);
        IRegistry.ObjectInfo memory info = _registryService.registerInstance(masterInstance, getOwner());
        masterInstanceNftId = info.nftId;
    }

    function setMasterInstanceReader(address instanceReaderAddress) external onlyOwner {
        if(_masterInstanceReader == address(0)) { revert ErrorInstanceServiceMasterInstanceReaderNotSet(); }
        if(instanceReaderAddress == address(0)) { revert ErrorInstanceServiceInstanceReaderAddressZero(); }
        if(instanceReaderAddress == _masterInstanceReader) { revert ErrorInstanceServiceInstanceReaderSameAsMasterInstanceReader(); }

        InstanceReader instanceReader = InstanceReader(instanceReaderAddress);
        if(instanceReader.getInstance() != IInstance(_masterInstance)) { revert ErrorInstanceServiceInstanceReaderInstanceMismatch(); }

        _masterInstanceReader = instanceReaderAddress;
    }

    function upgradeInstanceReader(NftId instanceNftId) 
        external 
        onlyInstanceOwner(instanceNftId) 
    {
        IRegistry registry = getRegistry();
        IRegistry.ObjectInfo memory instanceInfo = registry.getObjectInfo(instanceNftId);
        Instance instance = Instance(instanceInfo.objectAddress);
        
        InstanceReader upgradedInstanceReaderClone = InstanceReader(Clones.clone(address(_masterInstanceReader)));
        upgradedInstanceReaderClone.initialize(address(instance));
        instance.setInstanceReader(upgradedInstanceReaderClone);
    }


    // all gif targets MUST be childs of instanceNftId
    function createGifTarget(
        NftId instanceNftId,
        address targetAddress,
        string memory targetName,
        bytes4[][] memory selectors,
        RoleId[] memory roles
    )
        external
        onlyRegisteredService
    {
        (
            IInstance instance, // or instanceInfo
            // or targetInfo
        ) = _validateInstanceAndComponent(instanceNftId, targetAddress);

        InstanceAccessManager accessManager = instance.getInstanceAccessManager();
        accessManager.createGifTarget(targetAddress, targetName);
        // set proposed target config
        // TODO restriction: for gif targets can set only once and only here?
        //      assume config is a mix of gif and custom roles and no further configuration by INSTANCE_OWNER_ROLE is ever needed?
        for(uint roleIdx = 0; roleIdx < roles.length; roleIdx++)
        {
            accessManager.setCoreTargetFunctionRole(targetName, selectors[roleIdx], roles[roleIdx]);
        }
    }


    // TODO called by component, but target can be component helper...so needs target name
    // TODO check that targetName associated with component...how???
    function setComponentLocked(bool locked) onlyComponent external {

        address componentAddress = msg.sender;
        IRegistry registry = getRegistry();
        NftId instanceNftId = registry.getObjectInfo(componentAddress).parentNftId;

        IInstance instance = IInstance(
            registry.getObjectInfo(
                instanceNftId).objectAddress);

        instance.getInstanceAccessManager().setTargetLocked(
            componentAddress, 
            locked);
    }


    function getMasterInstanceReader() external view returns (address) {
        return _masterInstanceReader;
    }

    // From IService
    function getDomain() public pure override returns(ObjectType) {
        return INSTANCE();
    }
    
    /// @dev top level initializer
    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        initializer
        virtual override
    {
        (
            address registryAddress,
            address initialOwner
        ) = abi.decode(data, (address, address));

        _registryService = IRegistryService(
            IRegistry(registryAddress).getServiceAddress(
                REGISTRY(), 
                getVersion().toMajorPart()));

        // TODO while InstanceService is not deployed in InstanceServiceManager constructor
        //      owner is InstanceServiceManager deployer
        initializeService(registryAddress, address(0), owner);
        registerInterface(type(IInstanceService).interfaceId);
    }


    function _validateInstanceAndComponent(NftId instanceNftId, address componentAddress) 
        internal
        view
        returns (IInstance instance, NftId componentNftId)
    {
        IRegistry registry = getRegistry();
        IRegistry.ObjectInfo memory instanceInfo = registry.getObjectInfo(instanceNftId);
        if(instanceInfo.objectType != INSTANCE()) {
            revert ErrorInstanceServiceNotInstance(instanceNftId);
        }

        IRegistry.ObjectInfo memory componentInfo = registry.getObjectInfo(componentAddress);
        if(componentInfo.parentNftId != instanceNftId) {
            revert ErrorInstanceServiceInstanceComponentMismatch(instanceNftId, componentInfo.nftId);
        }

        instance = Instance(instanceInfo.objectAddress);
        componentNftId = componentInfo.nftId;
    }
}