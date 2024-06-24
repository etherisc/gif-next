// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {ShortString, ShortStrings} from "@openzeppelin/contracts/utils/ShortStrings.sol";

import {AccessManagerCloneable} from "../authorization/AccessManagerCloneable.sol";
import {Amount} from "../type/Amount.sol";
import {BundleManager} from "./BundleManager.sol";
import {ChainNft} from "../registry/ChainNft.sol";
import {NftId} from "../type/NftId.sol";
import {RoleId} from "../type/RoleId.sol";
import {SecondsLib} from "../type/Seconds.sol";
import {UFixed, UFixedLib} from "../type/UFixed.sol";
import {ADMIN_ROLE, DISTRIBUTION_OWNER_ROLE, ORACLE_OWNER_ROLE, POOL_OWNER_ROLE, PRODUCT_OWNER_ROLE} from "../type/RoleId.sol";
import {ObjectType, INSTANCE, BUNDLE, APPLICATION, CLAIM, DISTRIBUTION, INSTANCE, POLICY, POOL, PRODUCT, REGISTRY, STAKING} from "../type/ObjectType.sol";

import {Service} from "../shared/Service.sol";
import {IInstanceLinkedComponent} from "../shared/IInstanceLinkedComponent.sol";
import {IService} from "../shared/IService.sol";

import {IDistributionComponent} from "../distribution/IDistributionComponent.sol";
import {IPoolComponent} from "../pool/IPoolComponent.sol";
import {IProductComponent} from "../product/IProductComponent.sol";

import {IRegistry} from "../registry/IRegistry.sol";
import {IRegistryService} from "../registry/IRegistryService.sol";
import {IStakingService} from "../staking/IStakingService.sol";
import {TargetManagerLib} from "../staking/TargetManagerLib.sol";

import {Instance} from "./Instance.sol";
import {IModuleAuthorization} from "../authorization/IModuleAuthorization.sol";
import {IInstance} from "./IInstance.sol";
import {InstanceAdmin} from "./InstanceAdmin.sol";
import {IInstanceService} from "./IInstanceService.sol";
import {InstanceReader} from "./InstanceReader.sol";
import {InstanceStore} from "./InstanceStore.sol";
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
        // tx sender will become instance owner
        address instanceOwner = msg.sender;

        // start with setting up a new OZ access manager
        AccessManagerCloneable clonedAccessManager = AccessManagerCloneable(
            Clones.clone(_masterAccessManager));
        
        // set up the instance admin
        InstanceAdmin clonedInstanceAdmin = InstanceAdmin(Clones.clone(_masterInstanceAdmin));
        clonedAccessManager.initialize(
            address(clonedInstanceAdmin)); // grant ADMIN_ROLE to instance admin

        clonedInstanceAdmin.initialize(
            clonedAccessManager,
            InstanceAdmin(_masterInstanceAdmin).getInstanceAuthorization());

        InstanceStore clonedInstanceStore = InstanceStore(Clones.clone(address(_masterInstanceStore)));
        BundleManager clonedBundleManager = BundleManager(Clones.clone(_masterInstanceBundleManager));
        InstanceReader clonedInstanceReader = InstanceReader(Clones.clone(address(_masterInstanceReader)));

        // clone instance
        clonedInstance = Instance(Clones.clone(_masterInstance));
        clonedInstance.initialize(
            clonedInstanceAdmin,
            clonedInstanceStore,
            clonedBundleManager,
            clonedInstanceReader,
            getRegistry(),
            instanceOwner);

        // register cloned instance with registry
        clonedInstanceNftId = _registryService.registerInstance(
            clonedInstance, instanceOwner).nftId;

        // register cloned instance as staking target
        _stakingService.createInstanceTarget(
            clonedInstanceNftId,
            TargetManagerLib.getDefaultLockingPeriod(),
            TargetManagerLib.getDefaultRewardRate());

        // MUST be set after instance is set up and registered
        clonedInstanceAdmin.initializeInstanceAuthorization(address(clonedInstance));

        emit LogInstanceCloned(
            clonedInstanceNftId,
            address(clonedInstance));
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
        // TODO refactor/implement
        // instance.getInstanceAdmin().setTargetLockedByService(
        //     componentAddress, 
        //     locked);
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
        if(_masterInstanceAdmin != address(0)) { revert ErrorInstanceServiceMasterInstanceAdminAlreadySet(); }
        if(_masterInstanceBundleManager != address(0)) { revert ErrorInstanceServiceMasterBundleManagerAlreadySet(); }

        if(instanceAddress == address(0)) { revert ErrorInstanceServiceInstanceAddressZero(); }

        IInstance instance = IInstance(instanceAddress);
        address accessManagerAddress = instance.authority();
        InstanceAdmin instanceAdmin = instance.getInstanceAdmin();
        address instanceAdminAddress = address(instanceAdmin);
        InstanceReader instanceReader = instance.getInstanceReader();
        address instanceReaderAddress = address(instanceReader);
        BundleManager bundleManager = instance.getBundleManager();
        address bundleManagerAddress = address(bundleManager);
        InstanceStore instanceStore = instance.getInstanceStore();
        address instanceStoreAddress = address(instanceStore);

        if(accessManagerAddress == address(0)) { revert ErrorInstanceServiceAccessManagerZero(); }
        if(instanceAdminAddress == address(0)) { revert ErrorInstanceServiceInstanceAdminZero(); }
        if(instanceReaderAddress == address(0)) { revert ErrorInstanceServiceInstanceReaderZero(); }
        if(bundleManagerAddress == address(0)) { revert ErrorInstanceServiceBundleManagerZero(); }
        if(instanceStoreAddress == address(0)) { revert ErrorInstanceServiceInstanceStoreZero(); }
        
        if(instance.authority() != instanceAdmin.authority()) { revert ErrorInstanceServiceInstanceAuthorityMismatch(); }
        if(bundleManager.authority() != instanceAdmin.authority()) { revert ErrorInstanceServiceBundleManagerAuthorityMismatch(); }
        if(instanceStore.authority() != instanceAdmin.authority()) { revert ErrorInstanceServiceInstanceStoreAuthorityMismatch(); }
        if(bundleManager.getInstance() != instance) { revert ErrorInstanceServiceBundleMangerInstanceMismatch(); }
        if(instanceReader.getInstance() != instance) { revert ErrorInstanceServiceInstanceReaderInstanceMismatch2(); }

        _masterAccessManager = accessManagerAddress;
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
        upgradedInstanceReaderClone.initializeWithInstance(address(instance));
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


    function initializeAuthorization(
        NftId instanceNftId, 
        IInstanceLinkedComponent component
    )
        external
        virtual
        restricted()
    {
        (IInstance instance, ) = _validateInstanceAndComponent(
            instanceNftId, 
            address(component));

        InstanceAdmin instanceAdmin = instance.getInstanceAdmin();
        instanceAdmin.initializeComponentAuthorization(
            address(component),
            component.getAuthorization());
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

        // TODO refactor/implement
        // instanceAdmin.createGifTarget(targetAddress, targetName);

        // set proposed target config
        for(uint roleIdx = 0; roleIdx < roles.length; roleIdx++) {
            // TODO refactor/implement
            // instanceAdmin.setTargetFunctionRoleByService(targetName, selectors[roleIdx], roles[roleIdx]);
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