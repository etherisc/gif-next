// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {AccessManagerSimple} from "./AccessManagerSimple.sol";
import {InstanceAccessManager} from "./InstanceAccessManager.sol";
import {Instance} from "./Instance.sol";
import {IInstanceService} from "./IInstanceService.sol";
import {Service} from "../shared/Service.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IService} from "../shared/IService.sol";
import {ContractDeployerLib} from "../shared/ContractDeployerLib.sol";
import {NftId, NftIdLib, zeroNftId} from "../types/NftId.sol";

contract InstanceService is Service, IInstanceService {

    address internal _registryAddress;
    address internal _accessManagerMaster;
    address internal _instanceAccessManagerMaster;
    address internal _instanceMaster;

    // TODO update to real hash when instance is stable
    bytes32 public constant INSTANCE_CREATION_CODE_HASH = bytes32(0);
    string public constant NAME = "InstanceService";

    function createInstanceClone()
        external 
        returns (
            AccessManagerSimple am, 
            InstanceAccessManager im, 
            Instance i
        )
    {
        am = AccessManagerSimple(Clones.clone(_accessManagerMaster));
        im = InstanceAccessManager(Clones.clone(_instanceAccessManagerMaster));
        i = Instance(Clones.clone(_instanceMaster));
    }

    function setAccessManagerMaster(address accessManager) external {
        _accessManagerMaster = accessManager;
    }

    function setInstanceAccessManagerMaster(address instanceAccessManager) external {
        _instanceAccessManagerMaster = instanceAccessManager;
    }

    function setInstanceMaster(address instance) external {
        _instanceMaster = instance;
    }

    function getAccessManagerMaster() external view returns (address) { return address(_accessManagerMaster); }
    function getInstanceAccessManagerMaster() external view returns (address) { return address(_instanceAccessManagerMaster); }
    function getInstanceMaster() external view returns (address) { return address(_instanceMaster); }

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

