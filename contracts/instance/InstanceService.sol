// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {Instance} from "./Instance.sol";
import {IInstance} from "./IInstance.sol";
import {InstanceAccessManager} from "./InstanceAccessManager.sol";
import {IInstanceService} from "./IInstanceService.sol";
import {InstanceReader} from "./InstanceReader.sol";
import {BundleManager} from "./BundleManager.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IRegistryService} from "../registry/IRegistryService.sol";
import {ChainNft} from "../registry/ChainNft.sol";
import {Service} from "../../contracts/shared/Service.sol";
import {IService} from "../shared/IService.sol";
import {NftId} from "../../contracts/types/NftId.sol";
import {RoleId} from "../types/RoleId.sol";
import {
    ADMIN_ROLE,
    INSTANCE_OWNER_ROLE,
    DISTRIBUTION_OWNER_ROLE, 
    POOL_OWNER_ROLE, 
    PRODUCT_OWNER_ROLE, 
    INSTANCE_SERVICE_ROLE, 
    DISTRIBUTION_SERVICE_ROLE, 
    POOL_SERVICE_ROLE, 
    PRODUCT_SERVICE_ROLE, 
    POLICY_SERVICE_ROLE, 
    BUNDLE_SERVICE_ROLE} from "../types/RoleId.sol";
import {ObjectType, INSTANCE, BUNDLE, POLICY, PRODUCT, DISTRIBUTION, REGISTRY, POOL} from "../types/ObjectType.sol";
import {IDistributionComponent} from "../components/IDistributionComponent.sol";
import {IPoolComponent} from "../components/IPoolComponent.sol";
import {IProductComponent} from "../components/IProductComponent.sol";

contract InstanceService is Service, IInstanceService {

    address internal _masterInstanceAccessManager;
    address internal _masterInstance;
    address internal _masterInstanceReader;
    address internal _masterInstanceBundleManager;

    // TODO update to real hash when instance is stable
    bytes32 public constant INSTANCE_CREATION_CODE_HASH = bytes32(0);

    modifier onlyInstanceOwner(NftId instanceNftId) {        
        if(msg.sender != getRegistry().ownerOf(instanceNftId)) {
            revert ErrorInstanceServiceRequestUnauhorized(msg.sender);
        }
        _;
    }

    modifier onlyRegisteredService() {
        address caller = msg.sender;
        if (! getRegistry().isRegisteredService(caller)) {
            revert ErrorInstanceServiceRequestUnauhorized(caller);
        }
        _;
    }

    function createInstanceClone()
        external 
        returns (
            InstanceAccessManager clonedAccessManager, 
            Instance clonedInstance,
            NftId clonedInstanceNftId,
            InstanceReader clonedInstanceReader,
            BundleManager clonedBundleManager
        )
    {
        address instanceOwner = msg.sender;
        IRegistry registry = getRegistry();
        address registryAddress = address(registry);
        NftId registryNftId = registry.getNftId(registryAddress);
        address registryServiceAddress = registry.getServiceAddress(REGISTRY(), getMajorVersion());
        IRegistryService registryService = IRegistryService(registryServiceAddress);

        // initially grants ADMIN_ROLE to this (being the instance service). 
        // This will allow the instance service to bootstrap the authorizations of the instance.
        // Instance service will renounce ADMIN_ROLE when bootstraping is finished
        clonedAccessManager = InstanceAccessManager(Clones.clone(_masterInstanceAccessManager));
        clonedAccessManager.initialize(address(this));

        clonedInstance = Instance(Clones.clone(_masterInstance));
        clonedInstance.initialize(address(clonedAccessManager), registryAddress, registryNftId, instanceOwner);
        
        clonedInstanceReader = InstanceReader(Clones.clone(address(_masterInstanceReader)));
        clonedInstanceReader.initialize(registryAddress, address(clonedInstance));
        clonedInstance.setInstanceReader(clonedInstanceReader);

        clonedBundleManager = BundleManager(Clones.clone(_masterInstanceBundleManager));
        clonedBundleManager.initialize(address(clonedAccessManager), registryAddress, address(clonedInstance));
        clonedInstance.setBundleManager(clonedBundleManager);

        // TODO amend setters with instance specific , policy manager ...

        _grantInitialAuthorizations(clonedAccessManager, clonedInstance, clonedBundleManager, instanceOwner);

        assert(clonedAccessManager.renounceRole(ADMIN_ROLE()));

        IRegistry.ObjectInfo memory info = registryService.registerInstance(clonedInstance, instanceOwner);
        clonedInstanceNftId = info.nftId;
        // clonedInstance.linkToRegisteredNftId();

        emit LogInstanceCloned(address(clonedAccessManager), address(clonedInstance), address(clonedInstanceReader), clonedInstanceNftId);
    }

    function _grantInitialAuthorizations(
        InstanceAccessManager clonedAccessManager, 
        Instance clonedInstance, 
        BundleManager clonedBundleManager,
        address instanceOwner) 
            internal 
    {
        _createRoles(clonedAccessManager);
        _createGifTargets(clonedAccessManager, clonedInstance, clonedBundleManager);
        _grantDistributionServiceAuthorizations(clonedAccessManager, clonedInstance);
        _grantPoolServiceAuthorizations(clonedAccessManager, clonedInstance);
        _grantProductServiceAuthorizations(clonedAccessManager, clonedInstance);
        _grantPolicyServiceAuthorizations(clonedAccessManager, clonedInstance);    
        _grantBundleServiceAuthorizations(clonedAccessManager, clonedInstance, clonedBundleManager);
        _grantInstanceServiceAuthorizations(clonedAccessManager, clonedInstance);
        _grantInstanceOwnerAuthorizations(clonedAccessManager, instanceOwner);
    }

    function _createRoles(InstanceAccessManager clonedAccessManager) internal {
        // default roles controlled by INSTANCE_OWNER_ROLE -> custom roles
        clonedAccessManager.createRole(INSTANCE_OWNER_ROLE(), "InstanceOwnerRole");
        clonedAccessManager.createRole(DISTRIBUTION_OWNER_ROLE(), "DistributionOwnerRole");
        clonedAccessManager.createRole(POOL_OWNER_ROLE(), "PoolOwnerRole");
        clonedAccessManager.createRole(PRODUCT_OWNER_ROLE(), "ProductOwnerRole");
        // default roles controlled by INSTANCE_SERVICE_ROLE -> GIF roles, all set/granted only once during cloning
        clonedAccessManager.createGifRole(INSTANCE_SERVICE_ROLE(), "InstanceServiceRole");
        clonedAccessManager.createGifRole(DISTRIBUTION_SERVICE_ROLE(), "DistributionServiceRole");
        clonedAccessManager.createGifRole(POOL_SERVICE_ROLE(), "PoolServiceRole");
        clonedAccessManager.createGifRole(PRODUCT_SERVICE_ROLE(), "ProductServiceRole");
        clonedAccessManager.createGifRole(POLICY_SERVICE_ROLE(), "PolicyServiceRole");
        clonedAccessManager.createGifRole(BUNDLE_SERVICE_ROLE(), "BundleServiceRole");
    }

    function _createGifTargets(InstanceAccessManager clonedAccessManager, Instance clonedInstance, BundleManager clonedBundleManager) internal {
        clonedAccessManager.createGifTarget(address(clonedAccessManager), "InstanceAccessManager");
        clonedAccessManager.createGifTarget(address(clonedInstance), "Instance");
        clonedAccessManager.createGifTarget(address(clonedBundleManager), "BundleManager");
    }   

    function _grantDistributionServiceAuthorizations(InstanceAccessManager clonedAccessManager, Instance clonedInstance) internal {
        // configure authorization for distribution service on instance
        IRegistry registry = getRegistry();
        address distributionServiceAddress = registry.getServiceAddress(DISTRIBUTION(), getMajorVersion());
        clonedAccessManager.grantGifRole(DISTRIBUTION_SERVICE_ROLE(), distributionServiceAddress);
        bytes4[] memory instanceDistributionServiceSelectors = new bytes4[](2);
        instanceDistributionServiceSelectors[0] = clonedInstance.createDistributionSetup.selector;
        instanceDistributionServiceSelectors[1] = clonedInstance.updateDistributionSetup.selector;
        clonedAccessManager.setTargetFunctionRole(
            "Instance",
            instanceDistributionServiceSelectors, 
            DISTRIBUTION_SERVICE_ROLE());        
    }

    function _grantPoolServiceAuthorizations(InstanceAccessManager clonedAccessManager, Instance clonedInstance) internal {
        // configure authorization for pool service on instance
        address poolServiceAddress = _registry.getServiceAddress(POOL(), getMajorVersion());
        clonedAccessManager.grantGifRole(POOL_SERVICE_ROLE(), address(poolServiceAddress));
        bytes4[] memory instancePoolServiceSelectors = new bytes4[](4);
        instancePoolServiceSelectors[0] = clonedInstance.createPoolSetup.selector;
        instancePoolServiceSelectors[1] = clonedInstance.updatePoolSetup.selector;
        clonedAccessManager.setTargetFunctionRole(
            "Instance",
            instancePoolServiceSelectors, 
            POOL_SERVICE_ROLE());
    }

    function _grantProductServiceAuthorizations(InstanceAccessManager clonedAccessManager, Instance clonedInstance) internal {
        // configure authorization for product service on instance
        address productServiceAddress = _registry.getServiceAddress(PRODUCT(), getMajorVersion());
        clonedAccessManager.grantGifRole(PRODUCT_SERVICE_ROLE(), address(productServiceAddress));
        bytes4[] memory instanceProductServiceSelectors = new bytes4[](5);
        instanceProductServiceSelectors[0] = clonedInstance.createProductSetup.selector;
        instanceProductServiceSelectors[1] = clonedInstance.updateProductSetup.selector;
        instanceProductServiceSelectors[2] = clonedInstance.createRisk.selector;
        instanceProductServiceSelectors[3] = clonedInstance.updateRisk.selector;
        instanceProductServiceSelectors[4] = clonedInstance.updateRiskState.selector;
        clonedAccessManager.setTargetFunctionRole(
            "Instance",
            instanceProductServiceSelectors, 
            PRODUCT_SERVICE_ROLE());
    }

    function _grantPolicyServiceAuthorizations(InstanceAccessManager clonedAccessManager, Instance clonedInstance) internal {
        // configure authorization for policy service on instance
        address policyServiceAddress = _registry.getServiceAddress(POLICY(), getMajorVersion());
        clonedAccessManager.grantGifRole(POLICY_SERVICE_ROLE(), address(policyServiceAddress));
        bytes4[] memory instancePolicyServiceSelectors = new bytes4[](3);
        instancePolicyServiceSelectors[0] = clonedInstance.createPolicy.selector;
        instancePolicyServiceSelectors[1] = clonedInstance.updatePolicy.selector;
        instancePolicyServiceSelectors[2] = clonedInstance.updatePolicyState.selector;
        clonedAccessManager.setTargetFunctionRole(
            "Instance",
            instancePolicyServiceSelectors, 
            POLICY_SERVICE_ROLE());
    }

    function _grantBundleServiceAuthorizations(InstanceAccessManager clonedAccessManager, Instance clonedInstance, BundleManager clonedBundleManager) internal {
        // configure authorization for bundle service on instance
        address bundleServiceAddress = _registry.getServiceAddress(BUNDLE(), getMajorVersion());
        clonedAccessManager.grantGifRole(BUNDLE_SERVICE_ROLE(), address(bundleServiceAddress));
        bytes4[] memory instanceBundleServiceSelectors = new bytes4[](2);
        instanceBundleServiceSelectors[0] = clonedInstance.createBundle.selector;
        instanceBundleServiceSelectors[1] = clonedInstance.updateBundle.selector;
        clonedAccessManager.setTargetFunctionRole(
            "Instance",
            instanceBundleServiceSelectors, 
            BUNDLE_SERVICE_ROLE());

        // configure authorization for bundle service on bundle manager
        bytes4[] memory bundleManagerBundleServiceSelectors = new bytes4[](5);
        bundleManagerBundleServiceSelectors[0] = clonedBundleManager.linkPolicy.selector;
        bundleManagerBundleServiceSelectors[1] = clonedBundleManager.unlinkPolicy.selector;
        bundleManagerBundleServiceSelectors[2] = clonedBundleManager.add.selector;
        bundleManagerBundleServiceSelectors[3] = clonedBundleManager.lock.selector;
        bundleManagerBundleServiceSelectors[4] = clonedBundleManager.unlock.selector;
        clonedAccessManager.setTargetFunctionRole(
            "BundleManager",
            bundleManagerBundleServiceSelectors, 
            BUNDLE_SERVICE_ROLE());
    }

    function _grantInstanceServiceAuthorizations(InstanceAccessManager clonedAccessManager, Instance clonedInstance) internal {
        // configure authorization for instance service on instance
        address instanceServiceAddress = _registry.getServiceAddress(INSTANCE(), getMajorVersion());
        clonedAccessManager.grantGifRole(INSTANCE_SERVICE_ROLE(), instanceServiceAddress);
        bytes4[] memory instanceInstanceServiceSelectors = new bytes4[](1);
        instanceInstanceServiceSelectors[0] = clonedInstance.setInstanceReader.selector;
        clonedAccessManager.setTargetFunctionRole(
            "Instance",
            instanceInstanceServiceSelectors, 
            INSTANCE_SERVICE_ROLE());

        // configure authorizations for instance service on instance access manager
        bytes4[] memory accessManagerInstanceServiceSelectors = new bytes4[](3);
        accessManagerInstanceServiceSelectors[0] = clonedAccessManager.createGifTarget.selector;
        accessManagerInstanceServiceSelectors[1] = clonedAccessManager.setTargetLocked.selector;
        accessManagerInstanceServiceSelectors[2] = clonedAccessManager.setTargetFunctionRole.selector;
        // not used 
        //accessManagerInstanceServiceSelectors[3] = clonedAccessManager.createTarget.selector;
        // used only during cloning when instance service has ADMIN_ROLE, otherwise uncomment
        //accessManagerInstanceServiceSelectors[4] = clonedAccessManager.createGifRole.selector;
        //accessManagerInstanceServiceSelectors[5] = clonedAccessManager.grantGifRole.selector;
        clonedAccessManager.setTargetFunctionRole(
            "InstanceAccessManager",
            accessManagerInstanceServiceSelectors, 
            INSTANCE_SERVICE_ROLE());
    }

    function _grantInstanceOwnerAuthorizations(InstanceAccessManager clonedAccessManager, address instanceOwner) internal {
        // configure authorization for instance owner on instance access manager
        clonedAccessManager.grantRole(INSTANCE_OWNER_ROLE(), instanceOwner);
        bytes4[] memory accessManagerInstanceOwnerSelectors = new bytes4[](4);
        accessManagerInstanceOwnerSelectors[0] = clonedAccessManager.createRole.selector;
        accessManagerInstanceOwnerSelectors[1] = clonedAccessManager.grantRole.selector;
        accessManagerInstanceOwnerSelectors[2] = clonedAccessManager.revokeRole.selector;
        accessManagerInstanceOwnerSelectors[3] = clonedAccessManager.setRoleLocked.selector;
        clonedAccessManager.setTargetFunctionRole(
            "InstanceAccessManager",
            accessManagerInstanceOwnerSelectors, 
            INSTANCE_OWNER_ROLE());
    }

    function setAndRegisterMasterInstance(address instanceAddress) 
            external 
            onlyOwner 
            returns(NftId masterInstanceNftId)
    {
        require(_masterInstance == address(0), "ERROR:CRD-002:INSTANCE_MASTER_ALREADY_SET");
        require(_masterInstanceAccessManager == address(0), "ERROR:CRD-001:ACCESS_MANAGER_MASTER_ALREADY_SET");
        require(_masterInstanceBundleManager == address(0), "ERROR:CRD-004:BUNDLE_MANAGER_MASTER_ALREADY_SET");

        require (instanceAddress != address(0), "ERROR:CRD-006:INSTANCE_ZERO");

        IInstance instance = IInstance(instanceAddress);
        InstanceAccessManager accessManager = InstanceAccessManager(instance.authority());
        address accessManagerAddress = address(accessManager);
        InstanceReader instanceReader = instance.getInstanceReader();
        address instanceReaderAddress = address(instanceReader);
        BundleManager bundleManager = instance.getBundleManager();
        address bundleManagerAddress = address(bundleManager);

        require (accessManagerAddress != address(0), "ERROR:CRD-005:ACCESS_MANAGER_ZERO");
        require (instanceReaderAddress != address(0), "ERROR:CRD-007:INSTANCE_READER_ZERO");
        require (bundleManagerAddress != address(0), "ERROR:CRD-008:BUNDLE_MANAGER_ZERO");

        require(instance.authority() == accessManagerAddress, "ERROR:CRD-009:INSTANCE_AUTHORITY_MISMATCH");
        require(instanceReader.getInstance() == instance, "ERROR:CRD-010:INSTANCE_READER_INSTANCE_MISMATCH");
        require(bundleManager.getInstance() == instance, "ERROR:CRD-011:BUNDLE_MANAGER_INSTANCE_MISMATCH");

        _masterInstanceAccessManager = accessManagerAddress;
        _masterInstance = instanceAddress;
        _masterInstanceReader = instanceReaderAddress;
        _masterInstanceBundleManager = bundleManagerAddress;
        
        IRegistryService registryService = IRegistryService(getRegistry().getServiceAddress(REGISTRY(), getMajorVersion()));
        IInstance masterInstance = IInstance(_masterInstance);
        IRegistry.ObjectInfo memory info = registryService.registerInstance(masterInstance, getOwner());
        masterInstanceNftId = info.nftId;

        // masterInstance.linkToRegisteredNftId();
    }

    function setMasterInstanceReader(address instanceReaderAddress) 
        external 
        onlyOwner 
    {
        require(_masterInstanceReader != address(0), "ERROR:CRD-003:INSTANCE_READER_MASTER_NOT_SET");
        require (instanceReaderAddress != address(0), "ERROR:CRD-012:INSTANCE_READER_ZERO");
        require(instanceReaderAddress != _masterInstanceReader, "ERROR:CRD-014:INSTANCE_READER_MASTER_SAME_AS_NEW");

        InstanceReader instanceReader = InstanceReader(instanceReaderAddress);
        require(instanceReader.getInstance() == IInstance(_masterInstance), "ERROR:CRD-015:INSTANCE_READER_INSTANCE_MISMATCH");

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
        upgradedInstanceReaderClone.initialize(address(registry), address(instance));
        instance.setInstanceReader(upgradedInstanceReaderClone);
    }

    function getMasterInstanceReader() external view returns (address) {
        return _masterInstanceReader;
    }

    function getMasterInstance() external view returns (address) {
        return _masterInstance;
    }

    function getMasterInstanceAccessManager() external view returns (address) {
        return _masterInstanceAccessManager;
    }

    function getMasterInstanceBundleManager() external view returns (address) {
        return _masterInstanceBundleManager;
    }

    // From IService
    function getDomain() public pure override(Service, IService) returns(ObjectType) {
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
        address initialOwner;
        address registryAddress;
        (registryAddress, initialOwner) = abi.decode(data, (address, address));
        // TODO while InstanceService is not deployed in InstanceServiceManager constructor
        //      owner is InstanceServiceManager deployer
        _initializeService(registryAddress, owner);
        
        _registerInterface(type(IInstanceService).interfaceId);
    }

    // TODO call instance access manager directlly and delete this function?
    function hasRole(address account, RoleId role, address instanceAddress) public view returns (bool) {
        Instance instance = Instance(instanceAddress);
        InstanceAccessManager accessManager = InstanceAccessManager(instance.authority());
        return accessManager.hasRole(role, account);
    }
    // TODO used to create component targets which are not Gif tergets?
    function createGifTarget(NftId instanceNftId, address targetAddress, string memory targetName) external onlyRegisteredService {
        IRegistry registry = getRegistry();
        IRegistry.ObjectInfo memory instanceInfo = registry.getObjectInfo(instanceNftId);
        Instance instance = Instance(instanceInfo.objectAddress);
        InstanceAccessManager accessManager = InstanceAccessManager(instance.authority());
        accessManager.createGifTarget(targetAddress, targetName);
    }
    // TODO why is instance access manager responsible for component access management?
    //      1). potentially, instance and component are controlled by 2 different entities
    //      2). hard to predict what access management mechanism will be used by some future component
    //      3). instance access manager already used by 2 "admins": insatance service and instance owner
    function grantDistributionDefaultPermissions(NftId instanceNftId, address distributionAddress, string memory distributionName) external onlyRegisteredService {
        IRegistry registry = getRegistry();
        IRegistry.ObjectInfo memory distributionInfo = registry.getObjectInfo(distributionAddress);

        if (distributionInfo.objectType != DISTRIBUTION()) {
            revert ErrorInstanceServiceInvalidComponentType(distributionAddress, DISTRIBUTION(), distributionInfo.objectType);
        }

        IRegistry.ObjectInfo memory instanceInfo = registry.getObjectInfo(instanceNftId);
        Instance instance = Instance(instanceInfo.objectAddress);
        InstanceAccessManager instanceAccessManager = InstanceAccessManager(instance.authority());

        bytes4[] memory fctSelectors = new bytes4[](1);
        fctSelectors[0] = IDistributionComponent.setFees.selector;
        instanceAccessManager.setTargetFunctionRole(distributionName, fctSelectors, DISTRIBUTION_OWNER_ROLE());

        bytes4[] memory fctSelectors2 = new bytes4[](2);
        fctSelectors2[0] = IDistributionComponent.processSale.selector;
        fctSelectors2[1] = IDistributionComponent.processRenewal.selector;
        instanceAccessManager.setTargetFunctionRole(distributionName, fctSelectors2, PRODUCT_SERVICE_ROLE());
    }

    function grantPoolDefaultPermissions(NftId instanceNftId, address poolAddress, string memory poolName) external onlyRegisteredService {
        IRegistry registry = getRegistry();
        IRegistry.ObjectInfo memory poolInfo = registry.getObjectInfo(poolAddress);

        if (poolInfo.objectType != POOL()) {
            revert ErrorInstanceServiceInvalidComponentType(poolAddress, POOL(), poolInfo.objectType);
        }

        IRegistry.ObjectInfo memory instanceInfo = registry.getObjectInfo(instanceNftId);
        Instance instance = Instance(instanceInfo.objectAddress);
        InstanceAccessManager instanceAccessManager = InstanceAccessManager(instance.authority());

        bytes4[] memory fctSelectors = new bytes4[](1);
        fctSelectors[0] = IPoolComponent.setFees.selector;
        instanceAccessManager.setTargetFunctionRole(poolName, fctSelectors, POOL_OWNER_ROLE());

        bytes4[] memory fctSelectors2 = new bytes4[](1);
        fctSelectors2[0] = IPoolComponent.underwrite.selector;
        instanceAccessManager.setTargetFunctionRole(poolName, fctSelectors2, POLICY_SERVICE_ROLE());
    }

    function grantProductDefaultPermissions(NftId instanceNftId, address productAddress, string memory productName) external onlyRegisteredService {
        IRegistry registry = getRegistry();
        IRegistry.ObjectInfo memory productInfo = registry.getObjectInfo(productAddress);

        if (productInfo.objectType != PRODUCT()) {
            revert ErrorInstanceServiceInvalidComponentType(productAddress, PRODUCT(), productInfo.objectType);
        }

        IRegistry.ObjectInfo memory instanceInfo = registry.getObjectInfo(instanceNftId);
        Instance instance = Instance(instanceInfo.objectAddress);
        InstanceAccessManager instanceAccessManager = InstanceAccessManager(instance.authority());

        bytes4[] memory fctSelectors = new bytes4[](1);
        fctSelectors[0] = IProductComponent.setFees.selector;
        instanceAccessManager.setTargetFunctionRole(productName, fctSelectors, PRODUCT_OWNER_ROLE());
    }

    // assume component can lock only itself
    function setComponentLocked(string memory componentName, bool locked) external {
        address componentAddress = msg.sender;
        IRegistry registry = getRegistry();
        IRegistry.ObjectInfo memory componentInfo = registry.getObjectInfo(componentAddress);
        if (componentInfo.nftId.eqz()) {
            revert ErrorInstanceServiceComponentNotRegistered(componentAddress);
        }

        // TODO validate component type
        // TODO validate component name
        // TODO component can provide name of other component or GIF contract...use component address as id

        address instanceAddress = registry.getObjectInfo(componentInfo.parentNftId).objectAddress;
        IInstance instance = IInstance(instanceAddress);

        InstanceAccessManager accessManager = InstanceAccessManager(instance.authority());
        accessManager.setTargetLocked(componentName, locked);
    }
}

