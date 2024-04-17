// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {ShortString, ShortStrings} from "@openzeppelin/contracts/utils/ShortStrings.sol";

import {NftId} from "../type/NftId.sol";
import {RoleId} from "../type/RoleId.sol";
import {ADMIN_ROLE, INSTANCE_OWNER_ROLE, DISTRIBUTION_OWNER_ROLE, POOL_OWNER_ROLE, PRODUCT_OWNER_ROLE, INSTANCE_SERVICE_ROLE, DISTRIBUTION_SERVICE_ROLE, POOL_SERVICE_ROLE, PRODUCT_SERVICE_ROLE, APPLICATION_SERVICE_ROLE, POLICY_SERVICE_ROLE, CLAIM_SERVICE_ROLE, BUNDLE_SERVICE_ROLE, INSTANCE_ROLE} from "../type/RoleId.sol";
import {ObjectType, INSTANCE, BUNDLE, APPLICATION, POLICY, CLAIM, PRODUCT, DISTRIBUTION, REGISTRY, POOL} from "../type/ObjectType.sol";

import {Service} from "../shared/Service.sol";
import {IService} from "../shared/IService.sol";
import {AccessManagerUpgradeableInitializeable} from "../shared/AccessManagerUpgradeableInitializeable.sol";

import {IDistributionComponent} from "../distribution/IDistributionComponent.sol";
import {IPoolComponent} from "../pool/IPoolComponent.sol";
import {IProductComponent} from "../product/IProductComponent.sol";

import {IRegistry} from "../registry/IRegistry.sol";
import {IRegistryService} from "../registry/IRegistryService.sol";
import {ChainNft} from "../registry/ChainNft.sol";

import {Instance} from "./Instance.sol";
import {IInstance} from "./IInstance.sol";
import {InstanceAccessManager} from "./InstanceAccessManager.sol";
import {IInstanceService} from "./IInstanceService.sol";
import {InstanceReader} from "./InstanceReader.sol";
import {BundleManager} from "./BundleManager.sol";
import {InstanceStore} from "./InstanceStore.sol";
import {InstanceAuthorizationsLib} from "./InstanceAuthorizationsLib.sol";

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

    // TODO check component - service - instance version match
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
        // initialize and set before instance reader
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

        // TODO library does external calls -> but it is registry and access manager -> find out is it best practice
        InstanceAuthorizationsLib.grantInitialAuthorizations(
            clonedInstanceAccessManager, 
            clonedInstance, 
            clonedBundleManager, 
            clonedInstanceStore, 
            instanceOwner,
            getRegistry(),
            getVersion().toMajorPart());

        clonedOzAccessManager.renounceRole(ADMIN_ROLE().toInt(), address(this));

        IRegistry.ObjectInfo memory info = _registryService.registerInstance(clonedInstance, instanceOwner);
        clonedInstanceNftId = info.nftId;

        emit LogInstanceCloned(
            address(clonedOzAccessManager), 
            address(clonedInstanceAccessManager), 
            address(clonedInstance),
            address(clonedInstanceStore),
            address(clonedBundleManager), 
            address(clonedInstanceReader), 
            clonedInstanceNftId);
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
        restricted
    {
        (
            IInstance instance, // or instanceInfo
            // or targetInfo
        ) = _validateInstanceAndComponent(instanceNftId, targetAddress);

        InstanceAccessManager accessManager = instance.getInstanceAccessManager();
        accessManager.createGifTarget(targetAddress, targetName);
        // set proposed target config
        // TODO restriction: gif targets are set only once and only here?
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

        instance.getInstanceAccessManager().setTargetLockedByService(
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