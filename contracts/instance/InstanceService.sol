// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {AccessManagerUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";

import {AccessManagerUpgradeableInitializeable} from "./AccessManagerUpgradeableInitializeable.sol";
import {Instance} from "./Instance.sol";
import {IInstanceService} from "./IInstanceService.sol";
import {InstanceReader} from "./InstanceReader.sol";
import {BundleManager} from "./BundleManager.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {RegistryService} from "../registry/RegistryService.sol";
import {Service} from "../../contracts/shared/Service.sol";
import {IService} from "../shared/IService.sol";
import {NftId} from "../../contracts/types/NftId.sol";
import {RoleId} from "../types/RoleId.sol";
import {ADMIN_ROLE, INSTANCE_SERVICE_ROLE, DISTRIBUTION_SERVICE_ROLE, POOL_SERVICE_ROLE, PRODUCT_SERVICE_ROLE, POLICY_SERVICE_ROLE, BUNDLE_SERVICE_ROLE} from "../types/RoleId.sol";
import {ObjectType, REGISTRY, INSTANCE, PRODUCT, POOL, DISTRIBUTION, POLICY, BUNDLE} from "../types/ObjectType.sol";

contract InstanceService is Service, IInstanceService {

    address internal _masterInstanceAccessManager;
    address internal _masterInstance;
    address internal _masterInstanceReader;
    address internal _masterInstanceBundleManager;

    // TODO update to real hash when instance is stable
    bytes32 public constant INSTANCE_CREATION_CODE_HASH = bytes32(0);

    function createInstanceClone()
        external 
        returns (
            AccessManagerUpgradeableInitializeable clonedAccessManager, 
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
        RegistryService registryService = RegistryService(registryServiceAddress);

        // initially set the authority of the access managar to this (being the instance service). 
        // This will allow the instance service to bootstrap the authorizations of the instance
        // and then transfer the ownership of the access manager to the instance owner once everything is setup
        clonedAccessManager = AccessManagerUpgradeableInitializeable(Clones.clone(_masterInstanceAccessManager));
        clonedAccessManager.__AccessManagerUpgradeableInitializeable_init(address(this));

        clonedInstance = Instance(Clones.clone(_masterInstance));
        clonedInstance.initialize(address(clonedAccessManager), registryAddress, registryNftId, msg.sender);
        ( IRegistry.ObjectInfo memory info, ) = registryService.registerInstance(clonedInstance);
        clonedInstanceNftId = info.nftId;
        
        clonedInstanceReader = InstanceReader(Clones.clone(address(_masterInstanceReader)));
        clonedInstanceReader.initialize(registryAddress, clonedInstanceNftId);
        clonedInstance.setInstanceReader(clonedInstanceReader);

        clonedBundleManager = BundleManager(Clones.clone(_masterInstanceBundleManager));
        clonedBundleManager.initialize(address(clonedAccessManager), registryAddress, clonedInstanceNftId);
        clonedInstance.setBundleManager(clonedBundleManager);

        // TODO amend setters with instance specific , policy manager ...

        _grantInitialAuthorizations(clonedAccessManager, clonedInstance, clonedBundleManager);

        // to complete setup switch instance ownership to the instance owner
        // TODO: use a role less powerful than admin, maybe INSTANCE_ADMIN (does not exist yet)
        clonedAccessManager.grantRole(ADMIN_ROLE().toInt(), instanceOwner, 0);
        clonedAccessManager.revokeRole(ADMIN_ROLE().toInt(), address(this));

        emit LogInstanceCloned(address(clonedAccessManager), address(clonedInstance), address(clonedInstanceReader), clonedInstanceNftId);
    }

    function _grantInitialAuthorizations(AccessManagerUpgradeable clonedAccessManager, Instance clonedInstance, BundleManager clonedBundleManager) internal {
        _grantRegistryServiceAuthorizations(clonedAccessManager, clonedInstance);
        _grantPoolServiceAuthorizations(clonedAccessManager, clonedInstance);
        _grantProductServiceAuthorizations(clonedAccessManager, clonedInstance);
        _grantPolicyServiceAuthorizations(clonedAccessManager, clonedInstance);    
        _grantBundleServiceAuthorizations(clonedAccessManager, clonedInstance, clonedBundleManager);
        _grantInstanceServiceAuthorizations(clonedAccessManager, clonedInstance);
    }

    function _grantRegistryServiceAuthorizations(AccessManagerUpgradeable clonedAccessManager, Instance clonedInstance) internal {
        // configure authorization for distribution service on instance
        IRegistry registry = getRegistry();
        address distributionServiceAddress = registry.getServiceAddress(DISTRIBUTION(), getMajorVersion());
        clonedAccessManager.grantRole(DISTRIBUTION_SERVICE_ROLE().toInt(), distributionServiceAddress, 0);
        bytes4[] memory instanceDistributionServiceSelectors = new bytes4[](2);
        instanceDistributionServiceSelectors[0] = clonedInstance.createDistributionSetup.selector;
        instanceDistributionServiceSelectors[1] = clonedInstance.updateDistributionSetup.selector;
        clonedAccessManager.setTargetFunctionRole(
            address(clonedInstance),
            instanceDistributionServiceSelectors, 
            DISTRIBUTION_SERVICE_ROLE().toInt());
    }

    function _grantPoolServiceAuthorizations(AccessManagerUpgradeable clonedAccessManager, Instance clonedInstance) internal {
        // configure authorization for pool service on instance
        address poolServiceAddress = _registry.getServiceAddress(POOL(), getMajorVersion());
        clonedAccessManager.grantRole(POOL_SERVICE_ROLE().toInt(), address(poolServiceAddress), 0);
        bytes4[] memory instancePoolServiceSelectors = new bytes4[](4);
        instancePoolServiceSelectors[0] = clonedInstance.createPoolSetup.selector;
        instancePoolServiceSelectors[1] = clonedInstance.updatePoolSetup.selector;
        clonedAccessManager.setTargetFunctionRole(
            address(clonedInstance),
            instancePoolServiceSelectors, 
            POOL_SERVICE_ROLE().toInt());
    }

    function _grantProductServiceAuthorizations(AccessManagerUpgradeable clonedAccessManager, Instance clonedInstance) internal {
        // configure authorization for product service on instance
        address productServiceAddress = _registry.getServiceAddress(PRODUCT(), getMajorVersion());
        clonedAccessManager.grantRole(PRODUCT_SERVICE_ROLE().toInt(), address(productServiceAddress), 0);
        bytes4[] memory instanceProductServiceSelectors = new bytes4[](5);
        instanceProductServiceSelectors[0] = clonedInstance.createProductSetup.selector;
        instanceProductServiceSelectors[1] = clonedInstance.updateProductSetup.selector;
        instanceProductServiceSelectors[2] = clonedInstance.createRisk.selector;
        instanceProductServiceSelectors[3] = clonedInstance.updateRisk.selector;
        instanceProductServiceSelectors[4] = clonedInstance.updateRiskState.selector;
        clonedAccessManager.setTargetFunctionRole(
            address(clonedInstance),
            instanceProductServiceSelectors, 
            PRODUCT_SERVICE_ROLE().toInt());
    }

    function _grantPolicyServiceAuthorizations(AccessManagerUpgradeable clonedAccessManager, Instance clonedInstance) internal {
        // configure authorization for policy service on instance
        address policyServiceAddress = _registry.getServiceAddress(POLICY(), getMajorVersion());
        clonedAccessManager.grantRole(POLICY_SERVICE_ROLE().toInt(), address(policyServiceAddress), 0);
        bytes4[] memory instancePolicyServiceSelectors = new bytes4[](3);
        instancePolicyServiceSelectors[0] = clonedInstance.createPolicy.selector;
        instancePolicyServiceSelectors[1] = clonedInstance.updatePolicy.selector;
        instancePolicyServiceSelectors[2] = clonedInstance.updatePolicyState.selector;
        clonedAccessManager.setTargetFunctionRole(
            address(clonedInstance),
            instancePolicyServiceSelectors, 
            POLICY_SERVICE_ROLE().toInt());
    }

    function _grantBundleServiceAuthorizations(AccessManagerUpgradeable clonedAccessManager, Instance clonedInstance, BundleManager clonedBundleManager) internal {
        // configure authorization for bundle service on instance
        address bundleServiceAddress = _registry.getServiceAddress(BUNDLE(), getMajorVersion());
        clonedAccessManager.grantRole(BUNDLE_SERVICE_ROLE().toInt(), address(bundleServiceAddress), 0);
        bytes4[] memory instanceBundleServiceSelectors = new bytes4[](2);
        instanceBundleServiceSelectors[0] = clonedInstance.createBundle.selector;
        instanceBundleServiceSelectors[1] = clonedInstance.updateBundle.selector;
        clonedAccessManager.setTargetFunctionRole(
            address(clonedInstance),
            instanceBundleServiceSelectors, 
            BUNDLE_SERVICE_ROLE().toInt());

        // configure authorization for bundle service on bundle manager
        bytes4[] memory bundleManagerBundleServiceSelectors = new bytes4[](5);
        bundleManagerBundleServiceSelectors[0] = clonedBundleManager.linkPolicy.selector;
        bundleManagerBundleServiceSelectors[1] = clonedBundleManager.unlinkPolicy.selector;
        bundleManagerBundleServiceSelectors[2] = clonedBundleManager.add.selector;
        bundleManagerBundleServiceSelectors[3] = clonedBundleManager.lock.selector;
        bundleManagerBundleServiceSelectors[4] = clonedBundleManager.unlock.selector;
        clonedAccessManager.setTargetFunctionRole(
            address(clonedBundleManager),
            bundleManagerBundleServiceSelectors, 
            BUNDLE_SERVICE_ROLE().toInt());
    }

    function _grantInstanceServiceAuthorizations(AccessManagerUpgradeable clonedAccessManager, Instance clonedInstance) internal {
// configure authorization for instance service on instance
        address instanceServiceAddress = _registry.getServiceAddress(INSTANCE(), getMajorVersion());
        clonedAccessManager.grantRole(INSTANCE_SERVICE_ROLE().toInt(), instanceServiceAddress, 0);
        bytes4[] memory instanceInstanceServiceSelectors = new bytes4[](1);
        instanceInstanceServiceSelectors[0] = clonedInstance.setInstanceReader.selector;
        clonedAccessManager.setTargetFunctionRole(
            address(clonedInstance),
            instanceInstanceServiceSelectors, 
            INSTANCE_SERVICE_ROLE().toInt());
    }

    function setMasterInstance(address accessManagerAddress, address instanceAddress, address instanceReaderAddress, address bundleManagerAddress) external onlyOwner {
        require(_masterInstanceAccessManager == address(0), "ERROR:CRD-001:ACCESS_MANAGER_MASTER_ALREADY_SET");
        require(_masterInstance == address(0), "ERROR:CRD-002:INSTANCE_MASTER_ALREADY_SET");
        require(_masterInstanceBundleManager == address(0), "ERROR:CRD-004:BUNDLE_MANAGER_MASTER_ALREADY_SET");

        require (accessManagerAddress != address(0), "ERROR:CRD-005:ACCESS_MANAGER_ZERO");
        require (instanceAddress != address(0), "ERROR:CRD-006:INSTANCE_ZERO");
        require (instanceReaderAddress != address(0), "ERROR:CRD-007:INSTANCE_READER_ZERO");
        require (bundleManagerAddress != address(0), "ERROR:CRD-008:BUNDLE_MANAGER_ZERO");

        Instance instance = Instance(instanceAddress);
        InstanceReader instanceReader = InstanceReader(instanceReaderAddress);
        BundleManager bundleManager = BundleManager(bundleManagerAddress);

        require(instance.authority() == accessManagerAddress, "ERROR:CRD-009:INSTANCE_AUTHORITY_MISMATCH");
        require(instanceReader.getInstanceNftId() == instance.getNftId(), "ERROR:CRD-010:INSTANCE_READER_INSTANCE_MISMATCH");
        require(bundleManager.getInstanceNftId() == instance.getNftId(), "ERROR:CRD-011:BUNDLE_MANAGER_INSTANCE_MISMATCH");

        _masterInstanceAccessManager = accessManagerAddress;
        _masterInstance = instanceAddress;
        _masterInstanceReader = instanceReaderAddress;
        _masterInstanceBundleManager = bundleManagerAddress;
    }

    function setMasterInstanceReader(address instanceReaderAddress) external onlyOwner {
        require(_masterInstanceReader != address(0), "ERROR:CRD-003:INSTANCE_READER_MASTER_NOT_SET");
        require (instanceReaderAddress != address(0), "ERROR:CRD-012:INSTANCE_READER_ZERO");
        require(instanceReaderAddress != _masterInstanceReader, "ERROR:CRD-014:INSTANCE_READER_MASTER_SAME_AS_NEW");

        InstanceReader instanceReader = InstanceReader(instanceReaderAddress);
        require(instanceReader.getInstanceNftId() == Instance(_masterInstance).getNftId(), "ERROR:CRD-015:INSTANCE_READER_INSTANCE_MISMATCH");

        _masterInstanceReader = instanceReaderAddress;
    }

    function upgradeInstanceReader(NftId instanceNftId) external {
        IRegistry registry = getRegistry();
        IRegistry.ObjectInfo memory instanceInfo = registry.getObjectInfo(instanceNftId);
        Instance instance = Instance(instanceInfo.objectAddress);
        address owner = instance.getOwner();

        if (msg.sender != owner) {
            revert ErrorInstanceServiceRequestUnauhorized(msg.sender);
        }
        
        InstanceReader upgradedInstanceReaderClone = InstanceReader(Clones.clone(address(_masterInstanceReader)));
        upgradedInstanceReaderClone.initialize(address(registry), instanceNftId);
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
    // 1) registry is non upgradeable -> don't need a proxy and uses constructor !
    // 2) deploy registry service first -> from its initialization func it is easier to deploy registry then vice versa
    // 3) deploy registry -> pass registry service address as constructor argument
    // registry is getting instantiated and locked to registry service address forever
    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        initializer
        virtual override
    {
        address initialOwner = address(0);
        address registryAddress = address(0);
        (registryAddress, initialOwner) = abi.decode(data, (address, address));
        // TODO while InstanceService is not deployed in InstanceServiceManager constructor
        //      owner is InstanceServiceManager deployer
        _initializeService(registryAddress, owner);
        
        _registerInterface(type(IService).interfaceId);
        _registerInterface(type(IInstanceService).interfaceId);
    }
    // TODO use instanceAddress instead of nft
    /*function hasRole(address account, RoleId role, NftId instanceNftId) external view returns (bool) {
        IRegistry.ObjectInfo memory instanceObjectInfo = getRegistry().getObjectInfo(instanceNftId);
        address instanceAddress = instanceObjectInfo.objectAddress;
        Instance instance = Instance(instanceAddress);
        AccessManagerUpgradeable accessManager = AccessManagerUpgradeable(instance.authority());
        (bool isMember, uint32 executionDelay) = accessManager.hasRole(role.toInt(), account);
        if (executionDelay > 0) {
            return false;
        } 
        return isMember;
    }*/
    function hasRole(address account, RoleId role, address instanceAddress) external view returns (bool) {
        Instance instance = Instance(instanceAddress);
        AccessManagerUpgradeable accessManager = AccessManagerUpgradeable(instance.authority());
        (bool isMember, uint32 executionDelay) = accessManager.hasRole(role.toInt(), account);
        if (executionDelay > 0) {
            return false;
        } 
        return isMember;
    }
}

