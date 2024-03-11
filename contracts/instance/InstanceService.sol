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
import {AccessManagerUpgradeableInitializeable} from "./AccessManagerUpgradeableInitializeable.sol";
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

contract InstanceService is Service, IInstanceService 
{
    address internal _masterOzAccessManager;
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
            AccessManagerUpgradeableInitializeable clonedOzAccessManager,
            InstanceAccessManager clonedInstanceAccessManager, 
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

        clonedOzAccessManager = AccessManagerUpgradeableInitializeable(
            Clones.clone(_masterOzAccessManager));

        // initially grants ADMIN_ROLE to this (being the instance service). 
        // This will allow the instance service to bootstrap the authorizations of the instance.
        // Instance service will not use oz access manager directlly but through instance access manager instead
        // Instance service will renounce ADMIN_ROLE when bootstraping is finished
        clonedOzAccessManager.initialize(address(this));

        clonedInstanceAccessManager = InstanceAccessManager(Clones.clone(_masterInstanceAccessManager));
        clonedOzAccessManager.grantRole(ADMIN_ROLE().toInt(), address(clonedInstanceAccessManager), 0);
        clonedInstanceAccessManager.initialize(address(clonedOzAccessManager), registryAddress);

        clonedInstance = Instance(Clones.clone(_masterInstance));
        clonedInstance.initialize(address(clonedInstanceAccessManager), registryAddress, registryNftId, instanceOwner);
        
        clonedInstanceReader = InstanceReader(Clones.clone(address(_masterInstanceReader)));
        clonedInstanceReader.initialize(registryAddress, address(clonedInstance));
        clonedInstance.setInstanceReader(clonedInstanceReader);

        clonedBundleManager = BundleManager(Clones.clone(_masterInstanceBundleManager));
        clonedBundleManager.initialize(clonedInstanceAccessManager.authority(), registryAddress, address(clonedInstance));
        clonedInstance.setBundleManager(clonedBundleManager);

        // TODO amend setters with instance specific , policy manager ...

        _grantInitialAuthorizations(clonedInstanceAccessManager, clonedInstance, clonedBundleManager, instanceOwner);

        clonedOzAccessManager.renounceRole(ADMIN_ROLE().toInt(), address(this));

        IRegistry.ObjectInfo memory info = registryService.registerInstance(clonedInstance, instanceOwner);
        clonedInstanceNftId = info.nftId;
        // clonedInstance.linkToRegisteredNftId();

        emit LogInstanceCloned(address(clonedOzAccessManager), address(clonedInstanceAccessManager), address(clonedInstance), address(clonedInstanceReader), clonedInstanceNftId);
    }

    function _grantInitialAuthorizations(
        InstanceAccessManager clonedAccessManager, 
        Instance clonedInstance, 
        BundleManager clonedBundleManager,
        address instanceOwner) 
            internal 
    {
        _createCoreAndGifRoles(clonedAccessManager);
        _createCoreTargets(clonedAccessManager, clonedInstance, clonedBundleManager);
        _grantDistributionServiceAuthorizations(clonedAccessManager, clonedInstance);
        _grantPoolServiceAuthorizations(clonedAccessManager, clonedInstance);
        _grantProductServiceAuthorizations(clonedAccessManager, clonedInstance);
        _grantPolicyServiceAuthorizations(clonedAccessManager, clonedInstance);    
        _grantBundleServiceAuthorizations(clonedAccessManager, clonedInstance, clonedBundleManager);
        _grantInstanceServiceAuthorizations(clonedAccessManager, clonedInstance);
        _grantInstanceOwnerAuthorizations(clonedAccessManager, instanceOwner);
    }

    function _createCoreAndGifRoles(InstanceAccessManager clonedAccessManager) internal {
        // default roles controlled by INSTANCE_OWNER_ROLE -> gif roles
        clonedAccessManager.createGifRole(INSTANCE_OWNER_ROLE(), "InstanceOwnerRole", ADMIN_ROLE());
        clonedAccessManager.createGifRole(DISTRIBUTION_OWNER_ROLE(), "DistributionOwnerRole", INSTANCE_OWNER_ROLE());
        clonedAccessManager.createGifRole(POOL_OWNER_ROLE(), "PoolOwnerRole", INSTANCE_OWNER_ROLE());
        clonedAccessManager.createGifRole(PRODUCT_OWNER_ROLE(), "ProductOwnerRole", INSTANCE_OWNER_ROLE());
        // default roles controlled by INSTANCE_SERVICE_ROLE -> core roles, all set/granted only once during cloning
        clonedAccessManager.createCoreRole(INSTANCE_SERVICE_ROLE(), "InstanceServiceRole");
        clonedAccessManager.createCoreRole(DISTRIBUTION_SERVICE_ROLE(), "DistributionServiceRole");
        clonedAccessManager.createCoreRole(POOL_SERVICE_ROLE(), "PoolServiceRole");
        clonedAccessManager.createCoreRole(PRODUCT_SERVICE_ROLE(), "ProductServiceRole");
        clonedAccessManager.createCoreRole(POLICY_SERVICE_ROLE(), "PolicyServiceRole");
        clonedAccessManager.createCoreRole(BUNDLE_SERVICE_ROLE(), "BundleServiceRole");
    }

    function _createCoreTargets(InstanceAccessManager clonedAccessManager, Instance clonedInstance, BundleManager clonedBundleManager) internal {
        clonedAccessManager.createCoreTarget(address(clonedAccessManager), "InstanceAccessManager");
        clonedAccessManager.createCoreTarget(address(clonedInstance), "Instance");
        clonedAccessManager.createCoreTarget(address(clonedBundleManager), "BundleManager");
    }   

    function _grantDistributionServiceAuthorizations(InstanceAccessManager clonedAccessManager, Instance clonedInstance) internal {
        // configure authorization for distribution service on instance
        IRegistry registry = getRegistry();
        address distributionServiceAddress = registry.getServiceAddress(DISTRIBUTION(), getMajorVersion());
        clonedAccessManager.grantRole(DISTRIBUTION_SERVICE_ROLE(), distributionServiceAddress);
        bytes4[] memory instanceDistributionServiceSelectors = new bytes4[](11);
        instanceDistributionServiceSelectors[0] = clonedInstance.createDistributionSetup.selector;
        instanceDistributionServiceSelectors[1] = clonedInstance.updateDistributionSetup.selector;
        instanceDistributionServiceSelectors[2] = clonedInstance.createDistributorType.selector;
        instanceDistributionServiceSelectors[3] = clonedInstance.updateDistributorType.selector;
        instanceDistributionServiceSelectors[4] = clonedInstance.updateDistributorTypeState.selector;
        instanceDistributionServiceSelectors[5] = clonedInstance.createDistributor.selector;
        instanceDistributionServiceSelectors[6] = clonedInstance.updateDistributor.selector;
        instanceDistributionServiceSelectors[7] = clonedInstance.updateDistributorState.selector;
        instanceDistributionServiceSelectors[8] = clonedInstance.createReferral.selector;
        instanceDistributionServiceSelectors[9] = clonedInstance.updateReferral.selector;
        instanceDistributionServiceSelectors[10] = clonedInstance.updateReferralState.selector;
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

        // configure authorizations for instance service on instance access manager
        bytes4[] memory accessManagerInstanceServiceSelectors = new bytes4[](4);
        accessManagerInstanceServiceSelectors[0] = clonedAccessManager.createCoreTarget.selector;
        accessManagerInstanceServiceSelectors[1] = clonedAccessManager.createGifTarget.selector;
        accessManagerInstanceServiceSelectors[2] = clonedAccessManager.setTargetLocked.selector;
        accessManagerInstanceServiceSelectors[3] = clonedAccessManager.setTargetFunctionRole.selector;
        clonedAccessManager.setTargetFunctionRole(
            "InstanceAccessManager",
            accessManagerInstanceServiceSelectors, 
            INSTANCE_SERVICE_ROLE());
    }

    function _grantInstanceOwnerAuthorizations(InstanceAccessManager clonedAccessManager, address instanceOwner) internal {
        // configure authorization for instance owner on instance access manager
        clonedAccessManager.grantRole(INSTANCE_OWNER_ROLE(), instanceOwner);
        // INSTANCE_OWNER_ROLE administrates itself
        clonedAccessManager.setRoleAdmin(INSTANCE_OWNER_ROLE(), INSTANCE_OWNER_ROLE());
        bytes4[] memory accessManagerInstanceOwnerSelectors = new bytes4[](3);
        accessManagerInstanceOwnerSelectors[0] = clonedAccessManager.createCustomRole.selector;
        accessManagerInstanceOwnerSelectors[1] = clonedAccessManager.createCustomTarget.selector;
        accessManagerInstanceOwnerSelectors[2] = clonedAccessManager.setTargetFunctionCustomRole.selector;
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
        if(_masterInstance != address(0)) { revert ErrorInstanceServiceMasterInstanceAlreadySet(); }
        if(_masterInstanceAccessManager != address(0)) { revert ErrorInstanceServiceMasterInstanceAccessManagerAlreadySet(); }
        if(_masterInstanceBundleManager != address(0)) { revert ErrorInstanceServiceMasterBundleManagerAlreadySet(); }

        if(instanceAddress == address(0)) { revert ErrorInstanceServiceInstanceAddressZero(); }

        IInstance instance = IInstance(instanceAddress);
        AccessManagerUpgradeableInitializeable ozAccessManager = AccessManagerUpgradeableInitializeable(instance.authority());
        address ozAccessManagerAddress = address(ozAccessManager);
        InstanceAccessManager instanceAccessManager = instance.getInstanceAccessManager();
        address instanceAccessManagerAddress = address(instanceAccessManager);
        InstanceReader instanceReader = instance.getInstanceReader();
        address instanceReaderAddress = address(instanceReader);
        BundleManager bundleManager = instance.getBundleManager();
        address bundleManagerAddress = address(bundleManager);

        require (ozAccessManagerAddress != address(0), "ERROR:CRD-005:ACCESS_MANAGER_ZERO");
        require (instanceAccessManagerAddress != address(0), "ERROR:CRD-005:INSTANCE_ACCESS_MANAGER_ZERO");
        require (instanceReaderAddress != address(0), "ERROR:CRD-007:INSTANCE_READER_ZERO");
        require (bundleManagerAddress != address(0), "ERROR:CRD-008:BUNDLE_MANAGER_ZERO");

        require(instance.authority() == instanceAccessManager.authority(), "ERROR:CRD-009:INSTANCE_AUTHORITY_MISMATCH");
        require(instanceReader.getInstance() == instance, "ERROR:CRD-010:INSTANCE_READER_INSTANCE_MISMATCH");
        require(bundleManager.getInstance() == instance, "ERROR:CRD-011:BUNDLE_MANAGER_INSTANCE_MISMATCH");

        _masterOzAccessManager = ozAccessManagerAddress;
        _masterInstanceAccessManager = instanceAccessManagerAddress;
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
        initializeService(registryAddress, owner);
        registerInterface(type(IInstanceService).interfaceId);
    }

    // TODO call instance access manager directlly and delete this function?
    function hasRole(address account, RoleId role, address instanceAddress) public view returns (bool) {
        Instance instance = Instance(instanceAddress);
        InstanceAccessManager accessManager = InstanceAccessManager(instance.authority());
        return accessManager.hasRole(role, account);
    }
    // creates gif targets only -> they have INSTANCE as parent
    function createGifTarget(NftId instanceNftId, address targetAddress, string memory targetName, bytes4[][] memory selectors, RoleId[] memory roles) 
        external 
        onlyRegisteredService 
    {
        IRegistry registry = getRegistry();
        IRegistry.ObjectInfo memory instanceInfo = registry.getObjectInfo(instanceNftId);
        if(instanceInfo.objectType != INSTANCE()) {
            revert ErrorInstanceServiceNotInstance(instanceNftId);
        }

        Instance instance = Instance(instanceInfo.objectAddress);
        InstanceAccessManager accessManager = instance.getInstanceAccessManager();
        accessManager.createGifTarget(targetAddress, targetName);
        for(uint roleIdx = 0; roleIdx < roles.length; roleIdx++)
        {
            accessManager.setTargetFunctionRole(targetName, selectors[roleIdx], roles[roleIdx]);
        }
        
    }

    // TODO called by component, but target can be component helper...so needs target name
    // TODO check that targetName associated with component...how???
    //function setTargetLocked(string memory targetName, bool locked) onlyComponent external {
    function setComponentLocked(bool locked) onlyComponent external {
        address componentAddress = msg.sender;
        IRegistry registry = getRegistry();
        NftId instanceNftId = registry.getObjectInfo(componentAddress).parentNftId;
        address instanceAddress = registry.getObjectInfo(instanceNftId).objectAddress;
        IInstance instance = IInstance(instanceAddress);

        InstanceAccessManager accessManager = instance.getInstanceAccessManager();
        // TODO setLocked by target address?
        string memory componentName = ShortStrings.toString(accessManager.getTargetInfo(componentAddress).name);
        accessManager.setTargetLocked(componentName, locked);
    }
}