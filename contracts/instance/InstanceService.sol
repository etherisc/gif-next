// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {IAuthorization} from "../authorization/IAuthorization.sol";
import {AccessManagerCloneable} from "../authorization/AccessManagerCloneable.sol";
import {Amount} from "../type/Amount.sol";
import {BundleSet} from "./BundleSet.sol";
import {RiskSet} from "./RiskSet.sol";
import {ChainNft} from "../registry/ChainNft.sol";
import {NftId} from "../type/NftId.sol";
import {RoleId} from "../type/RoleId.sol";
import {UFixed} from "../type/UFixed.sol";
import {ObjectType, INSTANCE, COMPONENT, INSTANCE, REGISTRY, STAKING} from "../type/ObjectType.sol";

import {Service} from "../shared/Service.sol";

import {IRegistry} from "../registry/IRegistry.sol";
import {IRegistryService} from "../registry/IRegistryService.sol";
import {IStakingService} from "../staking/IStakingService.sol";
import {TargetManagerLib} from "../staking/TargetManagerLib.sol";

import {IComponentService} from "../shared/IComponentService.sol";
import {Instance} from "./Instance.sol";
import {IInstance} from "./IInstance.sol";
import {InstanceAdmin} from "./InstanceAdmin.sol";
import {IInstanceService} from "./IInstanceService.sol";
import {InstanceReader} from "./InstanceReader.sol";
import {InstanceStore} from "./InstanceStore.sol";
import {Seconds} from "../type/Seconds.sol";
import {VersionPart} from "../type/Version.sol";


contract InstanceService is
    Service,
    IInstanceService
{

    // TODO update to real hash when instance is stable
    bytes32 public constant INSTANCE_CREATION_CODE_HASH = bytes32(0);

    IRegistryService internal _registryService;
    IStakingService internal _stakingService;
    IComponentService internal _componentService;

    address internal _masterAccessManager;
    address internal _masterInstanceAdmin;
    address internal _masterInstance;
    address internal _masterInstanceReader;
    address internal _masterInstanceBundleSet;
    address internal _masterInstanceRiskSet;
    address internal _masterInstanceStore;


    modifier onlyInstance() {        
        address instanceAddress = msg.sender;
        NftId instanceNftId = getRegistry().getNftIdForAddress(msg.sender);
        if (instanceNftId.eqz()) {
            revert ErrorInstanceServiceNotRegistered(instanceAddress);
        }

        ObjectType objectType = getRegistry().getObjectInfo(instanceNftId).objectType;
        if (objectType != INSTANCE()) {
            revert ErrorInstanceServiceNotInstance(instanceAddress, objectType);
        }

        VersionPart instanceVersion = IInstance(instanceAddress).getRelease();
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

    function createInstance()
        external 
        restricted()
        returns (
            IInstance instance,
            NftId instanceNftId
        )
    {
        // tx sender will become instance owner
        address instanceOwner = msg.sender;

        // create instance admin and instance
        InstanceAdmin instanceAdmin = _createInstanceAdmin();
        instance = _createInstance(instanceAdmin, instanceOwner);

        // register cloned instance with registry
        instanceNftId = _registryService.registerInstance(
            instance, instanceOwner).nftId;

        // register cloned instance as staking target
        _stakingService.createInstanceTarget(
            instanceNftId,
            TargetManagerLib.getDefaultLockingPeriod(),
            TargetManagerLib.getDefaultRewardRate());

        // MUST be set after instance is set up and registered
        IAuthorization instanceAuthorization = InstanceAdmin(_masterInstanceAdmin).getInstanceAuthorization();
        VersionPart release = AccessManagerCloneable(authority()).getRelease();
        instanceAdmin.completeSetup(
            address(instance),
            address(instanceAuthorization));

        emit LogInstanceCloned(
            instanceNftId,
            address(instance));
    }


    function setStakingLockingPeriod(Seconds stakeLockingPeriod)
        external
        virtual
        restricted()
        onlyInstance()
    {
        NftId instanceNftId = getRegistry().getNftIdForAddress(msg.sender);
        _stakingService.setInstanceLockingPeriod(
            instanceNftId,
            stakeLockingPeriod);
    }


    function setStakingRewardRate(UFixed rewardRate)
        external
        virtual
        restricted()
        onlyInstance()
    {
        NftId instanceNftId = getRegistry().getNftIdForAddress(msg.sender);
        _stakingService.setInstanceRewardRate(
            instanceNftId,
            rewardRate);
    }


    function refillStakingRewardReserves(address rewardProvider, Amount dipAmount)
        external
        virtual
        restricted()
        onlyInstance()
    {
        NftId instanceNftId = getRegistry().getNftIdForAddress(msg.sender);
        _stakingService.refillInstanceRewardReserves(
            instanceNftId,
            rewardProvider,
            dipAmount);
    }


    function withdrawStakingRewardReserves(Amount dipAmount)
        external
        virtual
        restricted()
        onlyInstance()
        returns (Amount newBalance)
    {
        NftId instanceNftId = getRegistry().getNftIdForAddress(msg.sender);
        _stakingService.withdrawInstanceRewardReserves(
            instanceNftId,
            dipAmount);
    }

    function upgradeInstanceReader(NftId instanceNftId) 
        external 
        nonReentrant()
        restricted()
        onlyInstanceOwner(instanceNftId) 
        onlyNftOfType(instanceNftId, INSTANCE())
    {
        IRegistry registry = getRegistry();
        IRegistry.ObjectInfo memory instanceInfo = registry.getObjectInfo(instanceNftId);
        Instance instance = Instance(instanceInfo.objectAddress);
        
        InstanceReader upgradedInstanceReaderClone = InstanceReader(Clones.clone(address(_masterInstanceReader)));
        upgradedInstanceReaderClone.initializeWithInstance(address(instance));
        instance.setInstanceReader(upgradedInstanceReaderClone);
    }

    function setAndRegisterMasterInstance(address instanceAddress)
        external 
        onlyOwner()
        returns(NftId masterInstanceNftId)
    {
        if(_masterInstance != address(0)) { revert ErrorInstanceServiceMasterInstanceAlreadySet(); }
        if(_masterInstanceAdmin != address(0)) { revert ErrorInstanceServiceMasterInstanceAdminAlreadySet(); }
        if(_masterInstanceBundleSet != address(0)) { revert ErrorInstanceServiceMasterBundleSetAlreadySet(); }
        if(_masterInstanceRiskSet != address(0)) { revert ErrorInstanceServiceMasterRiskSetAlreadySet(); }
        if(instanceAddress == address(0)) { revert ErrorInstanceServiceInstanceAddressZero(); }

        IInstance instance = IInstance(instanceAddress);
        address accessManagerAddress = instance.authority();
        InstanceAdmin instanceAdmin = instance.getInstanceAdmin();
        address instanceAdminAddress = address(instanceAdmin);
        InstanceReader instanceReader = instance.getInstanceReader();
        address instanceReaderAddress = address(instanceReader);
        BundleSet bundleSet = instance.getBundleSet();
        address bundleSetAddress = address(bundleSet);
        RiskSet riskSet = instance.getRiskSet();
        address riskSetAddress = address(riskSet);
        InstanceStore instanceStore = instance.getInstanceStore();
        address instanceStoreAddress = address(instanceStore);

        if(accessManagerAddress == address(0)) { revert ErrorInstanceServiceAccessManagerZero(); }
        if(instanceAdminAddress == address(0)) { revert ErrorInstanceServiceInstanceAdminZero(); }
        if(instanceReaderAddress == address(0)) { revert ErrorInstanceServiceInstanceReaderZero(); }
        if(bundleSetAddress == address(0)) { revert ErrorInstanceServiceBundleSetZero(); }
        if(riskSetAddress == address(0)) { revert ErrorInstanceServiceRiskSetZero(); }
        if(instanceStoreAddress == address(0)) { revert ErrorInstanceServiceInstanceStoreZero(); }
        
        if(instance.authority() != instanceAdmin.authority()) { revert ErrorInstanceServiceInstanceAuthorityMismatch(); }
        if(bundleSet.authority() != instanceAdmin.authority()) { revert ErrorInstanceServiceBundleSetAuthorityMismatch(); }
        if(riskSet.authority() != instanceAdmin.authority()) { revert ErrorInstanceServiceRiskSetAuthorityMismatch(); }
        if(instanceStore.authority() != instanceAdmin.authority()) { revert ErrorInstanceServiceInstanceStoreAuthorityMismatch(); }
        if(bundleSet.getInstance() != instance) { revert ErrorInstanceServiceBundleSetInstanceMismatch(); }
        if(riskSet.getInstance() != instance) { revert ErrorInstanceServiceRiskSetInstanceMismatch(); }
        if(instanceReader.getInstance() != instance) { revert ErrorInstanceServiceInstanceReaderInstanceMismatch2(); }

        _masterAccessManager = accessManagerAddress;
        _masterInstanceAdmin = instanceAdminAddress;
        _masterInstance = instanceAddress;
        _masterInstanceReader = instanceReaderAddress;
        _masterInstanceBundleSet = bundleSetAddress;
        _masterInstanceRiskSet = riskSetAddress;
        _masterInstanceStore = instanceStoreAddress;
        
        IInstance masterInstance = IInstance(_masterInstance);
        IRegistry.ObjectInfo memory info = _registryService.registerInstance(masterInstance, getOwner());
        masterInstanceNftId = info.nftId;
    }

    function upgradeMasterInstanceReader(address instanceReaderAddress)
        external
        onlyOwner
    {
        if(_masterInstanceReader == address(0)) { revert ErrorInstanceServiceMasterInstanceReaderNotSet(); }
        if(instanceReaderAddress == address(0)) { revert ErrorInstanceServiceInstanceReaderAddressZero(); }
        if(instanceReaderAddress == _masterInstanceReader) { revert ErrorInstanceServiceInstanceReaderSameAsMasterInstanceReader(); }

        InstanceReader instanceReader = InstanceReader(instanceReaderAddress);
        if(instanceReader.getInstance() != IInstance(_masterInstance)) { revert ErrorInstanceServiceInstanceReaderInstanceMismatch(); }

        _masterInstanceReader = instanceReaderAddress;
    }

    function getMasterInstanceReader() external view returns (address) {
        return _masterInstanceReader;
    }

    /// @dev create new cloned instance admin
    /// function used to setup a new instance
    function _createInstanceAdmin()
        internal
        virtual
        returns (InstanceAdmin clonedInstanceAdmin)
    {
        // start with setting up a new OZ access manager
        // TODO consider _masterInstanceAdmin.authority() instead of _masterAccessManager
        AccessManagerCloneable clonedAccessManager = AccessManagerCloneable(
            Clones.clone(_masterAccessManager));
        
        // set up the instance admin
        clonedInstanceAdmin = InstanceAdmin(Clones.clone(_masterInstanceAdmin));
        clonedInstanceAdmin.initialize(
            clonedAccessManager,
            getRegistry(),
            getRelease());
    }


    /// @dev create new cloned instance
    /// function used to setup a new instance
    function _createInstance(
        InstanceAdmin instanceAdmin,
        address instanceOwner
    )
        internal
        virtual
        returns (IInstance)
    {
        InstanceStore clonedInstanceStore = InstanceStore(Clones.clone(address(_masterInstanceStore)));
        BundleSet clonedBundleSet = BundleSet(Clones.clone(_masterInstanceBundleSet));
        RiskSet clonedRiskSet = RiskSet(Clones.clone(_masterInstanceRiskSet));
        InstanceReader clonedInstanceReader = InstanceReader(Clones.clone(address(_masterInstanceReader)));

        // clone instance
        Instance clonedInstance = Instance(Clones.clone(_masterInstance));
        clonedInstance.initialize(
            instanceAdmin,
            clonedInstanceStore,
            clonedBundleSet,
            clonedRiskSet,
            clonedInstanceReader,
            getRegistry(),
            instanceOwner);
        return clonedInstance;
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
        virtual override
        initializer()
    {
        (
            address authority,
            address registry
        ) = abi.decode(data, (address, address));

        __Service_init(authority, registry, owner);

        _registryService = IRegistryService(_getServiceAddress(REGISTRY()));
        _stakingService = IStakingService(_getServiceAddress(STAKING()));
        _componentService = IComponentService(_getServiceAddress(COMPONENT()));

        _registerInterface(type(IInstanceService).interfaceId);
    }

    // TODO use function from ComponentVerifyingService instead?
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

        if(registry.getNftIdForAddress(componentAddress).eqz()) {
            revert ErrorInstanceServiceComponentNotRegistered(componentAddress);
        }
        
        IRegistry.ObjectInfo memory componentInfo = registry.getObjectInfo(componentAddress);
        if(componentInfo.parentNftId != instanceNftId) {
            revert ErrorInstanceServiceInstanceComponentMismatch(instanceNftId, componentInfo.nftId);
        }

        componentNftId = componentInfo.nftId;
        instance = Instance(instanceInfo.objectAddress);
    }

    // From IService
    function _getDomain() internal pure override returns(ObjectType) {
        return INSTANCE();
    }
}