// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {AccessManagerSimple} from "./AccessManagerSimple.sol";
import {InstanceAccessManager} from "./InstanceAccessManager.sol";
import {Instance} from "./Instance.sol";
import {IInstanceService} from "./IInstanceService.sol";
import {InstanceReader} from "./InstanceReader.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {Registry} from "../registry/Registry.sol";
import {RegistryService} from "../registry/RegistryService.sol";
import {Service} from "../../contracts/shared/Service.sol";
import {IService} from "../shared/IService.sol";
import {ContractDeployerLib} from "../shared/ContractDeployerLib.sol";
import {NftId, NftIdLib, zeroNftId} from "../../contracts/types/NftId.sol";
import {RoleId} from "../types/RoleId.sol";
import {VersionLib} from "../types/Version.sol";
import {ADMIN_ROLE, INSTANCE_SERVICE_ROLE, DISTRIBUTION_SERVICE_ROLE, POOL_SERVICE_ROLE} from "../types/RoleId.sol";

contract InstanceService is Service, IInstanceService {

    address internal _registryAddress;
    address internal _accessManagerMaster;
    address internal _instanceMaster;
    address internal _instanceReaderMaster;

    // TODO update to real hash when instance is stable
    bytes32 public constant INSTANCE_CREATION_CODE_HASH = bytes32(0);
    string public constant NAME = "InstanceService";

    function createInstanceClone()
        external 
        returns (
            AccessManagerSimple clonedAccessManager, 
            Instance clonedInstance,
            NftId instanceNftId,
            InstanceReader clonedInstanceReader
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
        clonedAccessManager = AccessManagerSimple(Clones.clone(_accessManagerMaster));
        clonedAccessManager.initialize(address(this));

        clonedInstance = Instance(Clones.clone(_instanceMaster));
        clonedInstance.initialize(address(clonedAccessManager), _registryAddress, registryNftId, msg.sender);
        ( IRegistry.ObjectInfo memory info, ) = registryService.registerInstance(clonedInstance);
        instanceNftId = info.nftId;
        
        clonedInstanceReader = InstanceReader(Clones.clone(address(_instanceReaderMaster)));
        clonedInstanceReader.initialize(_registryAddress, instanceNftId);

        _grantInitialAuthorizations(clonedAccessManager, clonedInstance);

        clonedInstance.setInstanceReader(clonedInstanceReader);
        
        // to complete setup switch instance ownership to the instance owner
        // TODO: use a role less powerful than admin, maybe INSTANCE_ADMIN (does not exist yet)
        clonedAccessManager.grantRole(ADMIN_ROLE().toInt(), instanceOwner, 0);
        clonedAccessManager.revokeRole(ADMIN_ROLE().toInt(), address(this));

        emit LogInstanceCloned(address(clonedAccessManager), address(clonedInstance), address(clonedInstanceReader), instanceNftId);
    }

    function _grantInitialAuthorizations(AccessManagerSimple clonedAccessManager, Instance clonedInstance) internal {
        address distributionServiceAddress = _registry.getServiceAddress("DistributionService", VersionLib.toVersion(3, 0, 0).toMajorPart());
        clonedAccessManager.grantRole(DISTRIBUTION_SERVICE_ROLE().toInt(), distributionServiceAddress, 0);
        bytes4[] memory instanceDistributionServiceSelectors = new bytes4[](2);
        instanceDistributionServiceSelectors[0] = clonedInstance.createDistributionSetup.selector;
        instanceDistributionServiceSelectors[1] = clonedInstance.updateDistributionSetup.selector;
        clonedAccessManager.setTargetFunctionRole(
            address(clonedInstance),
            instanceDistributionServiceSelectors, 
            DISTRIBUTION_SERVICE_ROLE().toInt());

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

    }

    function setAccessManagerMaster(address accessManagerMaster) external {
        require(
            _accessManagerMaster == address(0),
            "ERROR:CRD-001:ACCESS_MANAGER_MASTER_ALREADY_SET");
        _accessManagerMaster = accessManagerMaster;
    }

    function setInstanceMaster(address instanceMaster) external {
        require(
            _instanceMaster == address(0),
            "ERROR:CRD-002:INSTANCE_MASTER_ALREADY_SET");
        _instanceMaster = instanceMaster;
    }

    function setInstanceReaderMaster(address instanceReaderMaster) external {
        require(
            _instanceReaderMaster == address(0),
            "ERROR:CRD-003:INSTANCE_READER_MASTER_ALREADY_SET");
        _instanceReaderMaster = instanceReaderMaster;
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

        _initializeService(_registryAddress, initialOwner);
        
        _registerInterface(type(IService).interfaceId);
        _registerInterface(type(IInstanceService).interfaceId);
    }

    function hasRole(address account, RoleId role, NftId instanceNftId) external view returns (bool) {
        IRegistry.ObjectInfo memory instanceObjectInfo = getRegistry().getObjectInfo(instanceNftId);
        address instanceAddress = instanceObjectInfo.objectAddress;
        Instance instance = Instance(instanceAddress);
        AccessManagerSimple accessManager = AccessManagerSimple(instance.authority());
        (bool isMember, uint32 executionDelay) = accessManager.hasRole(role.toInt(), account);
        if (executionDelay > 0) {
            return false;
        } 
        return isMember;
    }
}

