// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {ShortString, ShortStrings} from "@openzeppelin/contracts/utils/ShortStrings.sol";

import {Amount} from "../type/Amount.sol";
import {BundleManager} from "./BundleManager.sol";
import {ChainNft} from "../registry/ChainNft.sol";
import {NftId} from "../type/NftId.sol";
import {RoleId} from "../type/RoleId.sol";
import {SecondsLib} from "../type/Seconds.sol";
import {UFixed, UFixedLib} from "../type/UFixed.sol";
import {ADMIN_ROLE, INSTANCE_OWNER_ROLE, DISTRIBUTION_OWNER_ROLE, POOL_OWNER_ROLE, PRODUCT_OWNER_ROLE, INSTANCE_SERVICE_ROLE, DISTRIBUTION_SERVICE_ROLE, POOL_SERVICE_ROLE, PRODUCT_SERVICE_ROLE, APPLICATION_SERVICE_ROLE, POLICY_SERVICE_ROLE, CLAIM_SERVICE_ROLE, BUNDLE_SERVICE_ROLE, INSTANCE_ROLE} from "../type/RoleId.sol";
import {ObjectType, INSTANCE, BUNDLE, APPLICATION, CLAIM, DISTRIBUTION, INSTANCE, POLICY, POOL, PRODUCT, REGISTRY, STAKING} from "../type/ObjectType.sol";

import {Service} from "../shared/Service.sol";
import {IInstanceLinkedComponent} from "../shared/IInstanceLinkedComponent.sol";
import {IService} from "../shared/IService.sol";
import {AccessManagerExtendedInitializeable} from "../shared/AccessManagerExtendedInitializeable.sol";

import {IDistributionComponent} from "../distribution/IDistributionComponent.sol";
import {IPoolComponent} from "../pool/IPoolComponent.sol";
import {IProductComponent} from "../product/IProductComponent.sol";

import {IRegistry} from "../registry/IRegistry.sol";
import {IRegistryService} from "../registry/IRegistryService.sol";
import {IStakingService} from "../staking/IStakingService.sol";
import {TargetManagerLib} from "../staking/TargetManagerLib.sol";

import {Instance} from "./Instance.sol";
import {IInstance} from "./IInstance.sol";
import {InstanceAdmin} from "./InstanceAdmin.sol";
import {IInstanceService} from "./IInstanceService.sol";
import {InstanceReader} from "./InstanceReader.sol";
import {InstanceStore} from "./InstanceStore.sol";
import {InstanceAuthorizationsLib} from "./InstanceAuthorizationsLib.sol";
import {Seconds} from "../type/Seconds.sol";
import {VersionPart, VersionPartLib} from "../type/Version.sol";


contract InstanceService is
    Service,
    IInstanceService
{

    // TODO update to real hash when instance is stable
    bytes32 public constant INSTANCE_CREATION_CODE_HASH = bytes32(0);

    IRegistryService internal _registryService;
    IStakingService internal _stakingService;

    address internal _masterAccessManager;
    address internal _masterInstanceAdmin;
    address internal _masterInstance;
    address internal _masterInstanceReader;
    address internal _masterInstanceBundleManager;
    address internal _masterInstanceStore;


    modifier onlyInstance() {        
        address instanceAddress = msg.sender;
        NftId instanceNftId = getRegistry().getNftId(msg.sender);
        if (instanceNftId.eqz()) {
            revert ErrorInstanceServiceNotRegistered(instanceAddress);
        }

        ObjectType objectType = getRegistry().getObjectInfo(instanceNftId).objectType;
        if (objectType != INSTANCE()) {
            revert ErrorInstanceServiceNotInstance(instanceAddress, objectType);
        }

        VersionPart instanceVersion = IInstance(instanceAddress).getMajorVersion();
        if (instanceVersion != getVersion().toMajorPart()) {
            revert ErrorInstanceServiceInstanceVersionMismatch(instanceAddress, instanceVersion);
        }

        _;
    }


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
        AccessManagerExtendedInitializeable clonedAccessManager = AccessManagerExtendedInitializeable(
            Clones.clone(_masterAccessManager));

        // initially grants ADMIN_ROLE to this (being the instance service). 
        // This will allow the instance service to bootstrap the authorizations of the instance.
        // Instance service will renounce ADMIN_ROLE when bootstraping is finished
        clonedAccessManager.initialize(address(this));

        clonedInstance = Instance(Clones.clone(_masterInstance));
        clonedInstance.initialize(
            address(clonedAccessManager),
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

        InstanceAdmin clonedInstanceAdmin = InstanceAdmin(Clones.clone(_masterInstanceAdmin));
        clonedAccessManager.grantRole(ADMIN_ROLE().toInt(), address(clonedInstanceAdmin), 0);
        clonedInstanceAdmin.initialize(address(clonedInstance));
        clonedInstance.setInstanceAdmin(clonedInstanceAdmin);

        // TODO amend setters with instance specific , policy manager ...

        // TODO library does external calls -> but it is registry and access manager -> find out is it best practice
        InstanceAuthorizationsLib.grantInitialAuthorizations(
            clonedAccessManager, 
            clonedInstanceAdmin, 
            clonedInstance, 
            clonedBundleManager, 
            clonedInstanceStore, 
            instanceOwner,
            getRegistry(),
            getVersion().toMajorPart());

        clonedAccessManager.renounceRole(ADMIN_ROLE().toInt(), address(this));

        // register new instance with registry
        IRegistry.ObjectInfo memory info = _registryService.registerInstance(clonedInstance, instanceOwner);
        clonedInstanceNftId = info.nftId;

        // create corresponding staking target
        _stakingService.createInstanceTarget(
            clonedInstanceNftId,
            TargetManagerLib.getDefaultLockingPeriod(),
            TargetManagerLib.getDefaultRewardRate());

        emit LogInstanceCloned(
            address(clonedAccessManager), 
            address(clonedInstanceAdmin), 
            address(clonedInstance),
            address(clonedInstanceStore),
            address(clonedBundleManager), 
            address(clonedInstanceReader), 
            clonedInstanceNftId);
    }


    function setStakingLockingPeriod(Seconds stakeLockingPeriod)
        external
        virtual
        onlyInstance()
    {
        NftId instanceNftId = getRegistry().getNftId(msg.sender);
        _stakingService.setInstanceLockingPeriod(
            instanceNftId,
            stakeLockingPeriod);
    }


    function setStakingRewardRate(UFixed rewardRate)
        external
        virtual
        onlyInstance()
    {
        NftId instanceNftId = getRegistry().getNftId(msg.sender);
        _stakingService.setInstanceRewardRate(
            instanceNftId,
            rewardRate);
    }


    function refillStakingRewardReserves(address rewardProvider, Amount dipAmount)
        external
        virtual
        onlyInstance()
    {
        NftId instanceNftId = getRegistry().getNftId(msg.sender);
        _stakingService.refillInstanceRewardReserves(
            instanceNftId,
            rewardProvider,
            dipAmount);
    }


    function withdrawStakingRewardReserves(Amount dipAmount)
        external
        virtual
        onlyInstance()
        returns (Amount newBalance)
    {
        NftId instanceNftId = getRegistry().getNftId(msg.sender);
        _stakingService.withdrawInstanceRewardReserves(
            instanceNftId,
            dipAmount);
    }


    function setComponentLocked(bool locked)
        external
        virtual
        onlyComponent()
    {
        // checks
        address componentAddress = msg.sender;

        if (!IInstanceLinkedComponent(componentAddress).supportsInterface(type(IInstanceLinkedComponent).interfaceId)) {
            revert ErrorInstanceServiceComponentNotInstanceLinked(componentAddress);
        }

        IRegistry registry = getRegistry();
        NftId instanceNftId = registry.getObjectInfo(componentAddress).parentNftId;

        IInstance instance = IInstance(
            registry.getObjectInfo(
                instanceNftId).objectAddress);

        // no revert in case already locked
        instance.getInstanceAdmin().setTargetLockedByService(
            componentAddress, 
            locked);
    }


    function getMasterInstanceReader() external view returns (address) {
        return _masterInstanceReader;
    }

    function setAndRegisterMasterInstance(address instanceAddress)
            external 
            onlyOwner 
            returns(NftId masterInstanceNftId)
    {
        if(_masterInstance != address(0)) { revert ErrorInstanceServiceMasterInstanceAlreadySet(); }
        if(_masterAccessManager != address(0)) { revert ErrorInstanceServiceMasterInstanceAccessManagerAlreadySet(); }
        if(_masterInstanceAdmin != address(0)) { revert ErrorInstanceServiceMasterInstanceAdminAlreadySet(); }
        if(_masterInstanceBundleManager != address(0)) { revert ErrorInstanceServiceMasterBundleManagerAlreadySet(); }

        if(instanceAddress == address(0)) { revert ErrorInstanceServiceInstanceAddressZero(); }

        IInstance instance = IInstance(instanceAddress);
        InstanceAdmin instanceAdmin = instance.getInstanceAdmin();
        address instanceAdminAddress = address(instanceAdmin);
        InstanceReader instanceReader = instance.getInstanceReader();
        address instanceReaderAddress = address(instanceReader);
        BundleManager bundleManager = instance.getBundleManager();
        address bundleManagerAddress = address(bundleManager);
        InstanceStore instanceStore = instance.getInstanceStore();
        address instanceStoreAddress = address(instanceStore);

        if(instanceAdminAddress == address(0)) { revert ErrorInstanceServiceInstanceAdminZero(); }
        if(instanceReaderAddress == address(0)) { revert ErrorInstanceServiceInstanceReaderZero(); }
        if(bundleManagerAddress == address(0)) { revert ErrorInstanceServiceBundleManagerZero(); }
        if(instanceStoreAddress == address(0)) { revert ErrorInstanceServiceInstanceStoreZero(); }
        
        if(instance.authority() != instanceAdmin.authority()) { revert ErrorInstanceServiceInstanceAuthorityMismatch(); }
        if(bundleManager.authority() != instanceAdmin.authority()) { revert ErrorInstanceServiceBundleManagerAuthorityMismatch(); }
        if(instanceStore.authority() != instanceAdmin.authority()) { revert ErrorInstanceServiceInstanceStoreAuthorityMismatch(); }
        if(bundleManager.getInstance() != instance) { revert ErrorInstanceServiceBundleMangerInstanceMismatch(); }
        if(instanceReader.getInstance() != instance) { revert ErrorInstanceServiceInstanceReaderInstanceMismatch2(); }

        _masterAccessManager = instance.authority();
        _masterInstanceAdmin = instanceAdminAddress;
        _masterInstance = instanceAddress;
        _masterInstanceReader = instanceReaderAddress;
        _masterInstanceBundleManager = bundleManagerAddress;
        _masterInstanceStore = instanceStoreAddress;
        
        IInstance masterInstance = IInstance(_masterInstance);
        IRegistry.ObjectInfo memory info = _registryService.registerInstance(masterInstance, getOwner());
        masterInstanceNftId = info.nftId;
    }

    function upgradeMasterInstanceReader(address instanceReaderAddress) external onlyOwner {
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


    function createGifTarget(
        NftId instanceNftId,
        address targetAddress,
        string memory targetName,
        bytes4[][] memory selectors,
        RoleId[] memory roles
    )
        external
        virtual
        restricted()
    {
        _createGifTarget(
            instanceNftId,
            targetAddress,
            targetName,
            roles,
            selectors
        );
    }


    function createComponentTarget(
        NftId instanceNftId,
        address targetAddress,
        string memory targetName,
        bytes4[][] memory selectors,
        RoleId[] memory roles
    )
        external
        virtual
        restricted()
    {
        _createGifTarget(
            instanceNftId,
            targetAddress,
            targetName,
            roles,
            selectors
        );
    }


    /// all gif targets MUST be children of instanceNftId
    function _createGifTarget(
        NftId instanceNftId,
        address targetAddress,
        string memory targetName,
        RoleId[] memory roles,
        bytes4[][] memory selectors
    )
        internal
        virtual
    {
        // TODO instanceAdmin will check target instance match anyway
        (
            IInstance instance, // or instanceInfo
            // or targetInfo
        ) = _validateInstanceAndComponent(instanceNftId, targetAddress);

        InstanceAdmin instanceAdmin = instance.getInstanceAdmin();
        instanceAdmin.createGifTarget(targetAddress, targetName);
        // set proposed target config
        // TODO restriction: gif targets are set only once and only here?
        //      assume config is a mix of gif and custom roles and no further configuration by INSTANCE_OWNER_ROLE is ever needed?
        for(uint roleIdx = 0; roleIdx < roles.length; roleIdx++) {
            instanceAdmin.setTargetFunctionRoleByService(targetName, selectors[roleIdx], roles[roleIdx]);
        }
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
            address registryAddress,, 
            //address managerAddress
            address authority
        ) = abi.decode(data, (address, address, address));

        initializeService(registryAddress, authority, owner);

        _registryService = IRegistryService(_getServiceAddress(REGISTRY()));
        _stakingService = IStakingService(_getServiceAddress(STAKING()));

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
            revert ErrorInstanceServiceNotInstanceNftId(instanceNftId);
        }

        IRegistry.ObjectInfo memory componentInfo = registry.getObjectInfo(componentAddress);
        if(componentInfo.parentNftId != instanceNftId) {
            revert ErrorInstanceServiceInstanceComponentMismatch(instanceNftId, componentInfo.nftId);
        }

        instance = Instance(instanceInfo.objectAddress);
        componentNftId = componentInfo.nftId;
    }

    // From IService
    function _getDomain() internal pure override returns(ObjectType) {
        return INSTANCE();
    }
}