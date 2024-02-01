// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {AccessManagerUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";

import {AccessManagerUpgradeableInitializeable} from "./AccessManagerUpgradeableInitializeable.sol";
import {InstanceAccessManager} from "./InstanceAccessManager.sol";
import {Instance} from "./Instance.sol";
import {IInstanceService} from "./IInstanceService.sol";
import {InstanceReader} from "./InstanceReader.sol";
import {BundleManager} from "./BundleManager.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {Registry} from "../registry/Registry.sol";
import {RegistryService} from "../registry/RegistryService.sol";
import {Service} from "../../contracts/shared/Service.sol";
import {IService} from "../shared/IService.sol";
import {ContractDeployerLib} from "../shared/ContractDeployerLib.sol";
import {NftId, NftIdLib, zeroNftId} from "../../contracts/types/NftId.sol";
import {RoleId} from "../types/RoleId.sol";
import {VersionLib} from "../types/Version.sol";
import {ADMIN_ROLE, INSTANCE_SERVICE_ROLE, DISTRIBUTION_SERVICE_ROLE, POOL_SERVICE_ROLE, PRODUCT_SERVICE_ROLE} from "../types/RoleId.sol";

contract InstanceService is Service, IInstanceService {

    address internal _registryAddress;
    address internal _accessManagerMaster;
    address internal _instanceMaster;
    address internal _instanceReaderMaster;
    address internal _instanceBundleManagerMaster;

    // TODO update to real hash when instance is stable
    bytes32 public constant INSTANCE_CREATION_CODE_HASH = bytes32(0);
    string public constant NAME = "InstanceService";

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
        Registry registry = Registry(_registryAddress);
        NftId registryNftId = registry.getNftId(_registryAddress);
        address registryServiceAddress = registry.getServiceAddress("RegistryService", VersionLib.toVersion(3, 0, 0).toMajorPart());
        RegistryService registryService = RegistryService(registryServiceAddress);

        // initially set the authority of the access managar to this (being the instance service). 
        // This will allow the instance service to bootstrap the authorizations of the instance
        // and then transfer the ownership of the access manager to the instance owner once everything is setup
        clonedAccessManager = AccessManagerUpgradeableInitializeable(Clones.clone(_accessManagerMaster));
        clonedAccessManager.__AccessManagerUpgradeableInitializeable_init(address(this));

        clonedInstance = Instance(Clones.clone(_instanceMaster));
        clonedInstance.initialize(address(clonedAccessManager), _registryAddress, registryNftId, msg.sender);
        ( IRegistry.ObjectInfo memory info, ) = registryService.registerInstance(clonedInstance);
        clonedInstanceNftId = info.nftId;
        
        clonedInstanceReader = InstanceReader(Clones.clone(address(_instanceReaderMaster)));
        clonedInstanceReader.initialize(_registryAddress, clonedInstanceNftId);
        clonedInstance.setInstanceReader(clonedInstanceReader);

        clonedBundleManager = BundleManager(Clones.clone(_instanceBundleManagerMaster));
        clonedBundleManager.initialize(address(clonedAccessManager), _registryAddress, clonedInstanceNftId);
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
        // configure authorization for distribution service on instance
        address distributionServiceAddress = _registry.getServiceAddress("DistributionService", VersionLib.toVersion(3, 0, 0).toMajorPart());
        clonedAccessManager.grantRole(DISTRIBUTION_SERVICE_ROLE().toInt(), distributionServiceAddress, 0);
        bytes4[] memory instanceDistributionServiceSelectors = new bytes4[](2);
        instanceDistributionServiceSelectors[0] = clonedInstance.createDistributionSetup.selector;
        instanceDistributionServiceSelectors[1] = clonedInstance.updateDistributionSetup.selector;
        clonedAccessManager.setTargetFunctionRole(
            address(clonedInstance),
            instanceDistributionServiceSelectors, 
            DISTRIBUTION_SERVICE_ROLE().toInt());

        // configure authorization for pool service on instance
        address poolServiceAddress = _registry.getServiceAddress("PoolService", VersionLib.toVersion(3, 0, 0).toMajorPart());
        clonedAccessManager.grantRole(POOL_SERVICE_ROLE().toInt(), address(poolServiceAddress), 0);
        bytes4[] memory instancePoolServiceSelectors = new bytes4[](4);
        instancePoolServiceSelectors[0] = clonedInstance.createPoolSetup.selector;
        instancePoolServiceSelectors[1] = clonedInstance.updatePoolSetup.selector;
        instancePoolServiceSelectors[2] = clonedInstance.createBundle.selector;
        instancePoolServiceSelectors[3] = clonedInstance.updateBundle.selector;
        clonedAccessManager.setTargetFunctionRole(
            address(clonedInstance),
            instancePoolServiceSelectors, 
            POOL_SERVICE_ROLE().toInt());
        
        // configure authorization for pool service on bundle manager
        bytes4[] memory bundleManagerPoolServiceSelectors = new bytes4[](5);
        bundleManagerPoolServiceSelectors[0] = clonedBundleManager.linkPolicy.selector;
        bundleManagerPoolServiceSelectors[1] = clonedBundleManager.unlinkPolicy.selector;
        bundleManagerPoolServiceSelectors[2] = clonedBundleManager.add.selector;
        bundleManagerPoolServiceSelectors[3] = clonedBundleManager.lock.selector;
        bundleManagerPoolServiceSelectors[4] = clonedBundleManager.unlock.selector;
        clonedAccessManager.setTargetFunctionRole(
            address(clonedBundleManager),
            bundleManagerPoolServiceSelectors, 
            POOL_SERVICE_ROLE().toInt());

        // configure authorization for product service on instance
        address productServiceAddress = _registry.getServiceAddress("ProductService", VersionLib.toVersion(3, 0, 0).toMajorPart());
        clonedAccessManager.grantRole(PRODUCT_SERVICE_ROLE().toInt(), address(productServiceAddress), 0);
        bytes4[] memory instanceProductServiceSelectors = new bytes4[](9);
        instanceProductServiceSelectors[0] = clonedInstance.createProductSetup.selector;
        instanceProductServiceSelectors[1] = clonedInstance.updateProductSetup.selector;
        instanceProductServiceSelectors[2] = clonedInstance.createRisk.selector;
        instanceProductServiceSelectors[3] = clonedInstance.updateRisk.selector;
        instanceProductServiceSelectors[4] = clonedInstance.updateRiskState.selector;
        instanceProductServiceSelectors[5] = clonedInstance.createPolicy.selector;
        instanceProductServiceSelectors[6] = clonedInstance.updatePolicy.selector;
        instanceProductServiceSelectors[7] = clonedInstance.updatePolicyState.selector;
        clonedAccessManager.setTargetFunctionRole(
            address(clonedInstance),
            instanceProductServiceSelectors, 
            PRODUCT_SERVICE_ROLE().toInt());
    }

    function setAccessManagerMaster(address accessManagerMaster) external {
        require(
            _accessManagerMaster == address(0),
            "ERROR:CRD-001:ACCESS_MANAGER_MASTER_ALREADY_SET");
        _accessManagerMaster = accessManagerMaster;
    }

    function setInstanceMaster(address instanceMaster) external {
        // TODO: ensure instance has correct access manager
        require(
            _instanceMaster == address(0),
            "ERROR:CRD-002:INSTANCE_MASTER_ALREADY_SET");
        _instanceMaster = instanceMaster;
    }

    function setInstanceReaderMaster(address instanceReaderMaster) external onlyOwner {
        // TODO: ensure instance reader points to master instance
        // TODO: add a test for this
        _instanceReaderMaster = instanceReaderMaster;
    }

    function upgradeInstanceReader(NftId instanceNftId) external {
        // TODO: ensure this is done by instance owner
        // TODO: upgrade instance reader of this instance to latest (set above here)
    }

    function setBundleManagerMaster(address bundleManagerMaster) external {
        // TODO: ensure bundle manager points to master instance
        require(
            _instanceBundleManagerMaster == address(0),
            "ERROR:CRD-004:BUNDLE_MANAGER_MASTER_ALREADY_SET");
        _instanceBundleManagerMaster = bundleManagerMaster;
    }

    function getInstanceReaderMaster() external view returns (address) {
        return _instanceReaderMaster;
    }

    function getInstanceMaster() external view returns (address) {
        return _instanceMaster;
    }

    function getAccessManagerMaster() external view returns (address) {
        return _accessManagerMaster;
    }

    function getBundleManagerMaster() external view returns (address) {
        return _instanceBundleManagerMaster;
    }

    // From IService
    function getName() public pure override(IService, Service) returns(string memory) {
        return NAME;
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
        // bytes memory encodedConstructorArguments = abi.encode(
        //     _registryAddress);

        // bytes memory instanceCreationCode = ContractDeployerLib.getCreationCode(
        //     instanceByteCodeWithInitCode,
        //     encodedConstructorArguments);

        // address instanceAddress = ContractDeployerLib.deploy(
        //     instanceCreationCode,
        //     INSTANCE_CREATION_CODE_HASH);

        address initialOwner = address(0);
        (_registryAddress, initialOwner) = abi.decode(data, (address, address));
        // TODO while InstanceService is not deployed in InstanceServiceManager constructor
        //      owner is InstanceServiceManager deployer
        _initializeService(_registryAddress, owner);
        
        _registerInterface(type(IService).interfaceId);
        _registerInterface(type(IInstanceService).interfaceId);
    }

    function hasRole(address account, RoleId role, NftId instanceNftId) external view returns (bool) {
        IRegistry.ObjectInfo memory instanceObjectInfo = getRegistry().getObjectInfo(instanceNftId);
        address instanceAddress = instanceObjectInfo.objectAddress;
        Instance instance = Instance(instanceAddress);
        AccessManagerUpgradeable accessManager = AccessManagerUpgradeable(instance.authority());
        (bool isMember, uint32 executionDelay) = accessManager.hasRole(role.toInt(), account);
        if (executionDelay > 0) {
            return false;
        } 
        return isMember;
    }
}

