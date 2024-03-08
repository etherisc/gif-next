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
import {ADMIN_ROLE, DISTRIBUTION_OWNER_ROLE, POOL_OWNER_ROLE, PRODUCT_OWNER_ROLE, INSTANCE_SERVICE_ROLE, DISTRIBUTION_SERVICE_ROLE, POOL_SERVICE_ROLE, PRODUCT_SERVICE_ROLE, POLICY_SERVICE_ROLE, BUNDLE_SERVICE_ROLE} from "../types/RoleId.sol";
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
        IRegistry registry = getRegistry();
        ChainNft chainNft = ChainNft(registry.getChainNftAddress());
        
        if( msg.sender != chainNft.ownerOf(instanceNftId.toInt())) {
            revert ErrorInstanceServiceNotInstanceOwner(msg.sender, instanceNftId);
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

        // initially set the authority of the access managar to this (being the instance service). 
        // This will allow the instance service to bootstrap the authorizations of the instance
        // and then transfer the ownership of the access manager to the instance owner once everything is setup
        clonedAccessManager = InstanceAccessManager(Clones.clone(_masterInstanceAccessManager));
        clonedAccessManager.initialize(address(this));

        clonedInstance = Instance(Clones.clone(_masterInstance));
        clonedInstance.initialize(address(clonedAccessManager), registryAddress, registryNftId, msg.sender);
        
        clonedInstanceReader = InstanceReader(Clones.clone(address(_masterInstanceReader)));
        clonedInstanceReader.initialize(registryAddress, address(clonedInstance));
        clonedInstance.setInstanceReader(clonedInstanceReader);

        clonedBundleManager = BundleManager(Clones.clone(_masterInstanceBundleManager));
        clonedBundleManager.initialize(address(clonedAccessManager), registryAddress, address(clonedInstance));
        clonedInstance.setBundleManager(clonedBundleManager);

        // TODO amend setters with instance specific , policy manager ...

        _grantInitialAuthorizations(clonedAccessManager, clonedInstance, clonedBundleManager);

        // to complete setup switch instance ownership to the instance owner
        // TODO: use a role less powerful than admin, maybe INSTANCE_ADMIN (does not exist yet)
        clonedAccessManager.grantRole(ADMIN_ROLE(), instanceOwner);
        clonedAccessManager.revokeRole(ADMIN_ROLE(), address(this));

        IRegistry.ObjectInfo memory info = registryService.registerInstance(clonedInstance, instanceOwner);
        clonedInstanceNftId = info.nftId;
        // clonedInstance.linkToRegisteredNftId();

        emit LogInstanceCloned(address(clonedAccessManager), address(clonedInstance), address(clonedInstanceReader), clonedInstanceNftId);
    }

    function _grantInitialAuthorizations(InstanceAccessManager clonedAccessManager, Instance clonedInstance, BundleManager clonedBundleManager) internal {
        _createGifRoles(clonedAccessManager);
        _createGifTargets(clonedAccessManager, clonedInstance, clonedBundleManager);
        _grantDistributionServiceAuthorizations(clonedAccessManager, clonedInstance);
        _grantPoolServiceAuthorizations(clonedAccessManager, clonedInstance);
        _grantProductServiceAuthorizations(clonedAccessManager, clonedInstance);
        _grantPolicyServiceAuthorizations(clonedAccessManager, clonedInstance);    
        _grantBundleServiceAuthorizations(clonedAccessManager, clonedInstance, clonedBundleManager);
        _grantInstanceServiceAuthorizations(clonedAccessManager, clonedInstance);
    }

    function _createGifRoles(InstanceAccessManager clonedAccessManager) internal {
        clonedAccessManager.createGifRole(DISTRIBUTION_OWNER_ROLE(), "DistributionOwnerRole");
        clonedAccessManager.createGifRole(POOL_OWNER_ROLE(), "PoolOwnerRole");
        clonedAccessManager.createGifRole(PRODUCT_OWNER_ROLE(), "ProductOwnerRole");

        clonedAccessManager.createGifRole(DISTRIBUTION_SERVICE_ROLE(), "DistributionServiceRole");
        clonedAccessManager.createGifRole(POOL_SERVICE_ROLE(), "PoolServiceRole");
        clonedAccessManager.createGifRole(PRODUCT_SERVICE_ROLE(), "ProductServiceRole");
        clonedAccessManager.createGifRole(POLICY_SERVICE_ROLE(), "PolicyServiceRole");
        clonedAccessManager.createGifRole(BUNDLE_SERVICE_ROLE(), "BundleServiceRole");
        clonedAccessManager.createGifRole(INSTANCE_SERVICE_ROLE(), "InstanceServiceRole");
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
        clonedAccessManager.grantRole(DISTRIBUTION_SERVICE_ROLE(), distributionServiceAddress);
        bytes4[] memory instanceDistributionServiceSelectors = new bytes4[](8);
        instanceDistributionServiceSelectors[0] = clonedInstance.createDistributionSetup.selector;
        instanceDistributionServiceSelectors[1] = clonedInstance.updateDistributionSetup.selector;
        instanceDistributionServiceSelectors[2] = clonedInstance.createDistributorType.selector;
        instanceDistributionServiceSelectors[3] = clonedInstance.updateDistributorType.selector;
        instanceDistributionServiceSelectors[4] = clonedInstance.updateDistributorTypeState.selector;
        instanceDistributionServiceSelectors[5] = clonedInstance.createDistributor.selector;
        instanceDistributionServiceSelectors[6] = clonedInstance.updateDistributor.selector;
        instanceDistributionServiceSelectors[7] = clonedInstance.updateDistributorState.selector;
        clonedAccessManager.setTargetFunctionRole(
            "Instance",
            instanceDistributionServiceSelectors, 
            DISTRIBUTION_SERVICE_ROLE());        
    }

    function _grantPoolServiceAuthorizations(InstanceAccessManager clonedAccessManager, Instance clonedInstance) internal {
        // configure authorization for pool service on instance
        address poolServiceAddress = getRegistry().getServiceAddress(POOL(), getMajorVersion());
        clonedAccessManager.grantRole(POOL_SERVICE_ROLE(), address(poolServiceAddress));
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
        address productServiceAddress = getRegistry().getServiceAddress(PRODUCT(), getMajorVersion());
        clonedAccessManager.grantRole(PRODUCT_SERVICE_ROLE(), address(productServiceAddress));
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
        address policyServiceAddress = getRegistry().getServiceAddress(POLICY(), getMajorVersion());
        clonedAccessManager.grantRole(POLICY_SERVICE_ROLE(), address(policyServiceAddress));
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
        address bundleServiceAddress = getRegistry().getServiceAddress(BUNDLE(), getMajorVersion());
        clonedAccessManager.grantRole(BUNDLE_SERVICE_ROLE(), address(bundleServiceAddress));
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
        address instanceServiceAddress = getRegistry().getServiceAddress(INSTANCE(), getMajorVersion());
        clonedAccessManager.grantRole(INSTANCE_SERVICE_ROLE(), instanceServiceAddress);
        bytes4[] memory instanceInstanceServiceSelectors = new bytes4[](1);
        instanceInstanceServiceSelectors[0] = clonedInstance.setInstanceReader.selector;
        clonedAccessManager.setTargetFunctionRole(
            "Instance",
            instanceInstanceServiceSelectors, 
            INSTANCE_SERVICE_ROLE());

        bytes4[] memory instanceAccessManagerInstanceServiceSelectors = new bytes4[](1);
        instanceAccessManagerInstanceServiceSelectors[0] = clonedAccessManager.createGifTarget.selector;
        clonedAccessManager.setTargetFunctionRole(
            "InstanceAccessManager",
            instanceAccessManagerInstanceServiceSelectors, 
            INSTANCE_SERVICE_ROLE());
    }

    function setAndRegisterMasterInstance(address instanceAddress) 
            external 
            onlyOwner 
            returns(NftId masterInstanceNftId)
    {
        if(_masterInstance != address(0)) { revert ErrorInstanceServiceMasterInstanceAlreadySet(); }
        if(_masterInstanceAccessManager != address(0)) { revert ErrorInstanceServiceMasterInstanceAccessManagerAlreadySet(); }
        if(_masterInstanceBundleManager != address(0)) { revert ErrorInstanceServiceMasterBundleManagerAlreadySet(); }

        if(instanceAddress == address(0)) { revert ErrorInstanceServiceInstanceAddressZero(); }

        IInstance instance = IInstance(instanceAddress);
        InstanceAccessManager accessManager = InstanceAccessManager(instance.authority());
        address accessManagerAddress = address(accessManager);
        InstanceReader instanceReader = instance.getInstanceReader();
        address instanceReaderAddress = address(instanceReader);
        BundleManager bundleManager = instance.getBundleManager();
        address bundleManagerAddress = address(bundleManager);

        if(accessManagerAddress == address(0)) { revert ErrorInstanceServiceAccessManagerZero(); }
        if(instanceReaderAddress == address(0)) { revert ErrorInstanceServiceInstanceReaderZero(); }
        if(bundleManagerAddress == address(0)) { revert ErrorInstanceServiceBundleManagerZero(); }
        
        if(instance.authority() != accessManagerAddress) { revert ErrorInstanceServiceInstanceAuthorityMismatch(); }
        if(instanceReader.getInstance() != instance) { revert ErrorInstanceServiceInstanceReaderInstanceMismatch2(); }
        if(bundleManager.getInstance() != instance) { revert ErrorInstanceServiceBundleMangerInstanceMismatch(); }

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

    function setMasterInstanceReader(address instanceReaderAddress) external onlyOwner {
        if(_masterInstanceReader == address(0)) { revert ErrorInstanceServiceMasterInstanceReaderNotSet(); }
        if(instanceReaderAddress == address(0)) { revert ErrorInstanceServiceInstanceReaderAddressZero(); }
        if(instanceReaderAddress == _masterInstanceReader) { revert ErrorInstanceServiceInstanceReaderSameAsMasterInstanceReader(); }

        InstanceReader instanceReader = InstanceReader(instanceReaderAddress);
        if(instanceReader.getInstance() != IInstance(_masterInstance)) { revert ErrorInstanceServiceInstanceReaderInstanceMismatch(); }

        _masterInstanceReader = instanceReaderAddress;
    }

    // TODO access restriction
    function upgradeInstanceReader(NftId instanceNftId) external {
        IRegistry registry = getRegistry();
        IRegistry.ObjectInfo memory instanceInfo = registry.getObjectInfo(instanceNftId);
        Instance instance = Instance(instanceInfo.objectAddress);
        address owner = instance.getOwner();

        if (msg.sender != owner) {
            revert ErrorInstanceServiceRequestUnauhorized(msg.sender);
        }
        
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
        initializeService(registryAddress, owner);
        registerInterface(type(IInstanceService).interfaceId);
    }

    function hasRole(address account, RoleId role, address instanceAddress) public view returns (bool) {
        Instance instance = Instance(instanceAddress);
        InstanceAccessManager accessManager = InstanceAccessManager(instance.authority());
        return accessManager.hasRole(role, account);
    }

    function createGifTarget(NftId instanceNftId, address targetAddress, string memory targetName) external onlyRegisteredService {
        IRegistry registry = getRegistry();
        IRegistry.ObjectInfo memory instanceInfo = registry.getObjectInfo(instanceNftId);
        Instance instance = Instance(instanceInfo.objectAddress);
        InstanceAccessManager accessManager = InstanceAccessManager(instance.authority());
        accessManager.createGifTarget(targetAddress, targetName);
    }

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
        fctSelectors2[0] = IPoolComponent.verifyApplication.selector;
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

    function setTargetLocked(string memory targetName, bool locked) external {
        address componentAddress = msg.sender;
        IRegistry registry = getRegistry();
        IRegistry.ObjectInfo memory componentInfo = registry.getObjectInfo(componentAddress);
        if (componentInfo.nftId.eqz()) {
            revert ErrorInstanceServiceComponentNotRegistered(componentAddress);
        }

        // TODO validate component type


        address instanceAddress = registry.getObjectInfo(componentInfo.parentNftId).objectAddress;
        IInstance instance = IInstance(instanceAddress);

        InstanceAccessManager accessManager = InstanceAccessManager(instance.authority());
        accessManager.setTargetClosed(targetName, locked);
    }
    
}

