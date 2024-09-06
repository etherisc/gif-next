// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {IAccess} from "../authorization/IAccess.sol";
import {IAuthorization} from "../authorization/IAuthorization.sol";
import {IComponentService} from "../shared/IComponentService.sol";
import {IInstance} from "./IInstance.sol";
import {IInstanceService} from "./IInstanceService.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IRegistryService} from "../registry/IRegistryService.sol";
import {IStakingService} from "../staking/IStakingService.sol";

import {AccessManagerCloneable} from "../authorization/AccessManagerCloneable.sol";
import {Amount} from "../type/Amount.sol";
import {BundleSet} from "./BundleSet.sol";
import {Instance} from "./Instance.sol";
import {InstanceAdmin} from "./InstanceAdmin.sol";
import {InstanceReader} from "./InstanceReader.sol";
import {InstanceStore} from "./InstanceStore.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, INSTANCE, COMPONENT, INSTANCE, REGISTRY, STAKING} from "../type/ObjectType.sol";
import {RiskSet} from "./RiskSet.sol";
import {RoleId} from "../type/RoleId.sol";
import {Seconds} from "../type/Seconds.sol";
import {Service} from "../shared/Service.sol";
import {TargetManagerLib} from "../staking/TargetManagerLib.sol";
import {UFixed} from "../type/UFixed.sol";
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
        _checkInstance(msg.sender, getRelease());
        _;
    }


    /// @inheritdoc IInstanceService
    function createRole(
        string memory roleName, 
        RoleId adminRoleId,
        uint32 maxMemberCount
    )
        external
        restricted()
        onlyInstance()
        returns (RoleId roleId)
    {
        IInstance instance = IInstance(msg.sender);
        roleId = instance.getInstanceAdmin().createRole(
            roleName, 
            adminRoleId, 
            maxMemberCount);
    }


    /// @inheritdoc IInstanceService
    function setRoleActive(RoleId roleId, bool active)
        external
        restricted()
        onlyInstance()
    {
        IInstance instance = IInstance(msg.sender);
        instance.getInstanceAdmin().setRoleActive(roleId, active);
    }


    /// @inheritdoc IInstanceService
    function grantRole(RoleId roleId, address account)
        external
        restricted()
        onlyInstance()
    {
        IInstance instance = IInstance(msg.sender);
        instance.getInstanceAdmin().grantRole(roleId, account);
    }


    /// @inheritdoc IInstanceService
    function revokeRole(RoleId roleId, address account) 
        external 
        restricted()
        onlyInstance()
    {
        IInstance instance = IInstance(msg.sender);
        instance.getInstanceAdmin().revokeRole(roleId, account);
    }


    /// @inheritdoc IInstanceService
    function createTarget(address target, string memory name)
        external
        restricted()
        onlyInstance()
        returns (RoleId contractRoleId)
    {
        IInstance instance = IInstance(msg.sender);
        return instance.getInstanceAdmin().createTarget(target, name);
    }


    /// @inheritdoc IInstanceService
    function authorizeFunctions(
        address target, 
        RoleId roleId, 
        IAccess.FunctionInfo[] memory functions
    )
        external 
        restricted()
        onlyInstance()
    {
        IInstance instance = IInstance(msg.sender);
        return instance.getInstanceAdmin().authorizeFunctions(target, roleId, functions);
    }


    /// @inheritdoc IInstanceService
    function unauthorizeFunctions(
        address target, 
        IAccess.FunctionInfo[] memory functions
    )
        external
        restricted()
        onlyInstance()
    {
        IInstance instance = IInstance(msg.sender);
        return instance.getInstanceAdmin().unauthorizeFunctions(target, functions);
    }


    /// @inheritdoc IInstanceService
    function setTargetLocked(address target, bool locked)
        external
        virtual
        restricted()
        onlyInstance()
    {
        address instanceAddress = msg.sender;
        IInstance(instanceAddress).getInstanceAdmin().setTargetLocked(target, locked);
    }


    /// @inheritdoc IInstanceService
    function setInstanceLocked(bool locked)
        external
        virtual
        restricted()
        onlyInstance()
    {
        address instanceAddress = msg.sender;
        IInstance(instanceAddress).getInstanceAdmin().setInstanceLocked(locked);

        emit LogInstanceServiceInstanceLocked(
            getRegistry().getNftIdForAddress(instanceAddress),
            locked);
    }


    /// @inheritdoc IInstanceService
    function createInstance(bool allowAnyToken)
        external 
        virtual
        restricted()
        returns (
            IInstance instance,
            NftId instanceNftId
        )
    {
        // tx sender will become instance owner
        address instanceOwner = msg.sender;

        // create instance admin and instance
        InstanceAdmin instanceAdmin = _cloneNewInstanceAdmin();
        instance = _createInstance(instanceAdmin, instanceOwner, allowAnyToken);

        // register cloned instance with registry
        instanceNftId = _registryService.registerInstance(
            instance, instanceOwner).nftId;

        // MUST be set after instance is set up and registered
        IAuthorization instanceAuthorization = InstanceAdmin(_masterInstanceAdmin).getInstanceAuthorization();
        instanceAdmin.completeSetup(
            address(getRegistry()),
            address(instanceAuthorization),
            getRelease(),
            address(instance));

        // hard checks for newly cloned instance
        assert(address(instance.getRegistry()) == address(getRegistry()));
        assert(instance.getRelease() == getRelease());

        // register cloned instance as staking target
        _stakingService.createInstanceTarget(
            instanceNftId,
            TargetManagerLib.getDefaultLockingPeriod(),
            TargetManagerLib.getDefaultRewardRate());

        emit LogInstanceServiceInstanceCreated(
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

    function setStakingMaxAmount(Amount maxStakedAmount)
        external
        virtual
        restricted()
        onlyInstance()
    {
        NftId instanceNftId = getRegistry().getNftIdForAddress(msg.sender);
        _stakingService.setInstanceMaxStakedAmount(
            instanceNftId,
            maxStakedAmount);
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
        newBalance = _stakingService.withdrawInstanceRewardReserves(
            instanceNftId,
            dipAmount);
    }


    function upgradeInstanceReader() 
        external 
        virtual
        restricted()
        onlyInstance()
    {
        address instanceAddress = msg.sender;
        IInstance instance = IInstance(msg.sender);
        
        InstanceReader upgradedInstanceReaderClone = InstanceReader(
            Clones.clone(address(_masterInstanceReader)));

        upgradedInstanceReaderClone.initializeWithInstance(instanceAddress);
        instance.setInstanceReader(upgradedInstanceReaderClone);

        emit LogInstanceServiceInstanceReaderUpgraded(
            getRegistry().getNftIdForAddress(instanceAddress),
            address(upgradedInstanceReaderClone));
    }


    function setAndRegisterMasterInstance(address instanceAddress)
        external 
        virtual
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
        if(bundleSet.getInstanceAddress() != address(instance)) { revert ErrorInstanceServiceBundleSetInstanceMismatch(); }
        if(riskSet.getInstanceAddress() != address(instance)) { revert ErrorInstanceServiceRiskSetInstanceMismatch(); }
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
        virtual
        onlyOwner
    {
        if(_masterInstanceReader == address(0)) { revert ErrorInstanceServiceMasterInstanceReaderNotSet(); }
        if(instanceReaderAddress == address(0)) { revert ErrorInstanceServiceInstanceReaderAddressZero(); }
        if(instanceReaderAddress == _masterInstanceReader) { revert ErrorInstanceServiceInstanceReaderSameAsMasterInstanceReader(); }

        InstanceReader instanceReader = InstanceReader(instanceReaderAddress);
        if(instanceReader.getInstance() != IInstance(_masterInstance)) { revert ErrorInstanceServiceInstanceReaderInstanceMismatch(); }

        _masterInstanceReader = instanceReaderAddress;

        emit LogInstanceServiceMasterInstanceReaderUpgraded(
            getRegistry().getNftIdForAddress(_masterInstance),
            instanceReaderAddress);
    }

    function getMasterInstanceReader() external virtual view returns (address) {
        return _masterInstanceReader;
    }

    //--- internal functions --------------------------------------------------------//

    /// @dev create new cloned instance admin
    /// function used to setup a new instance
    function _cloneNewInstanceAdmin()
        internal
        virtual
        returns (InstanceAdmin clonedAdmin)
    {
        // clone instance specific access manager
        AccessManagerCloneable clonedAccessManager = AccessManagerCloneable(
            Clones.clone(
                InstanceAdmin(_masterInstanceAdmin).authority()));
        
        // set up the instance admin
        clonedAdmin = InstanceAdmin(
            Clones.clone(_masterInstanceAdmin));

        clonedAdmin.initialize(
            address(clonedAccessManager),
            "InstanceAdmin");
    }


    /// @dev create new cloned instance
    /// function used to setup a new instance
    function _createInstance(
        InstanceAdmin instanceAdmin,
        address instanceOwner,
        bool allowAnyToken
    )
        internal
        virtual
        returns (IInstance)
    {
        // clone instance
        Instance clonedInstance = Instance(Clones.clone(_masterInstance));
        clonedInstance.initialize(
            instanceAdmin,
            InstanceStore(Clones.clone(address(_masterInstanceStore))),
            BundleSet(Clones.clone(_masterInstanceBundleSet)),
            RiskSet(Clones.clone(_masterInstanceRiskSet)),
            InstanceReader(Clones.clone(address(_masterInstanceReader))),
            getRegistry(),
            getRelease(),
            instanceOwner,
            allowAnyToken);

        return clonedInstance;
    }


    /// @dev top level initializer (upgradable contract)
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


    function _checkInstance(
        address instanceAddress,
        VersionPart expectedRelease
    )
        internal
        virtual
        view
    {
        IRegistry registry = getRegistry();

        NftId instanceNftId = registry.getNftIdForAddress(instanceAddress);
        if (instanceNftId.eqz()) {
            revert ErrorInstanceServiceNotRegistered(instanceAddress);
        }

        ObjectType objectType = registry.getObjectInfo(instanceNftId).objectType;
        if (objectType != INSTANCE()) {
            revert ErrorInstanceServiceNotInstance(instanceAddress, objectType);
        }

        if (expectedRelease.gtz()) {
            VersionPart instanceRelease = IInstance(instanceAddress).getRelease();
            if (instanceRelease != expectedRelease) {
                revert ErrorInstanceServiceInstanceVersionMismatch(instanceNftId, expectedRelease, instanceRelease);
            }
        }
    }


    // From IService
    function _getDomain() internal pure override returns(ObjectType) {
        return INSTANCE();
    }
}