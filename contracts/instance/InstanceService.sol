// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {AccessManagerSimple} from "./AccessManagerSimple.sol";
import {InstanceAccessManager} from "./InstanceAccessManager.sol";
import {Instance} from "./Instance.sol";
import {IInstanceService} from "./IInstanceService.sol";
import {InstanceReader} from "./InstanceReader.sol";
import {ServiceBase} from "../../contracts/instance/base/ServiceBase.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {Registry} from "../registry/Registry.sol";
import {RegistryService} from "../registry/RegistryService.sol";
import {IService} from "../../contracts/instance/base/IService.sol";
import {ContractDeployerLib} from "../shared/ContractDeployerLib.sol";
import {NftId, NftIdLib, zeroNftId} from "../../contracts/types/NftId.sol";
import {VersionLib} from "../types/Version.sol";

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
        Registry registry = Registry(_registryAddress);
        NftId registryNftId = registry.getNftId(_registryAddress);
        address registryServiceAddress = registry.getServiceAddress("RegistryService", VersionLib.toVersion(3, 0, 0).toMajorPart());
        RegistryService registryService = RegistryService(registryServiceAddress);

        clonedAccessManager = AccessManagerSimple(Clones.clone(_accessManagerMaster));
        clonedAccessManager.initialize(msg.sender);

        clonedInstance = Instance(Clones.clone(_instanceMaster));
        clonedInstance.initialize(address(clonedAccessManager), _registryAddress, registryNftId);
        ( IRegistry.ObjectInfo memory info, ) = registryService.registerInstance(clonedInstance);
        instanceNftId = info.nftId;
        
        clonedInstanceReader = InstanceReader(Clones.clone(address(_instanceReaderMaster)));
        clonedInstanceReader.initialize(_registryAddress, instanceNftId);
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

        // // TODO register instance in registry  
        IRegistry registry = IRegistry(_registryAddress);
        NftId registryNftId = registry.getNftId(_registryAddress);

        _initializeService(_registryAddress, initialOwner);
        
        _registerInterface(type(IService).interfaceId);
        _registerInterface(type(IInstanceService).interfaceId);
    }

    function getInstance() external view returns (Instance) {
        return Instance(address(this));
    }
}

