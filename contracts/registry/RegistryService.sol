// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin5/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IRegistry} from "../registry/IRegistry.sol";
import {IInstance} from "../instance/IInstance.sol";

import {ITreasury, ITreasuryModule} from "../../contracts/instance/module/treasury/ITreasury.sol";
import {TreasuryModule} from "../../contracts/instance/module/treasury/TreasuryModule.sol";
import {IComponent, IComponentModule} from "../../contracts/instance/module/component/IComponent.sol";
import {IPool} from "../../contracts/instance/module/pool/IPoolModule.sol";
import {IBaseComponent} from "../../contracts/components/IBaseComponent.sol";
import {IPoolComponent} from "../../contracts/components/IPoolComponent.sol";
import {IProductComponent} from "../../contracts/components/IProductComponent.sol";
import {IDistributionComponent} from "../../contracts/components/IDistributionComponent.sol";

import {IVersionable} from "../../contracts/shared/IVersionable.sol";
import {Versionable} from "../../contracts/shared/Versionable.sol";
import {IRegisterable} from "../../contracts/shared/IRegisterable.sol";

import {RoleId, PRODUCT_OWNER_ROLE, POOL_OWNER_ROLE, ORACLE_OWNER_ROLE} from "../../contracts/types/RoleId.sol";
import {ObjectType, REGISTRY, TOKEN, SERVICE, PRODUCT, ORACLE, POOL, TOKEN, INSTANCE, DISTRIBUTION, POLICY} from "../../contracts/types/ObjectType.sol";
import {StateId, ACTIVE, PAUSED} from "../../contracts/types/StateId.sol";
import {NftId, NftIdLib, zeroNftId} from "../../contracts/types/NftId.sol";
import {Fee, FeeLib} from "../../contracts/types/Fee.sol";
import {Version, VersionPart, VersionLib} from "../../contracts/types/Version.sol";
import {UFixed, UFixedMathLib} from "../../contracts/types/UFixed.sol";


import {ServiceBase} from "../../contracts/instance/base/ServiceBase.sol";
import {IService} from "../../contracts/instance/base/IService.sol";
import {IRegistryService} from "./IRegistryService.sol";
import {Registry} from "../registry/Registry.sol";

contract RegistryService is
    ServiceBase,
    IRegistryService
{
    using NftIdLib for NftId;

    error NotRegistryOwner();
    error MissingAllowance();

    error NotToken();
    error NotService();
    error NotComponent();
    error NotInstance();

    error InvalidAddress(address registerableAddress);
    error InvalidInitialOwner(address initialOwner);
    error SelfRegistration();
    error InvalidType(ObjectType objectType);

    string public constant NAME = "RegistryService";

    bytes32 public constant REGISTRY_CREATIONCODE_HASH = 0x7e569c7200a12c63728b648d78f84be7e32ef6804f9ee723e15363ce34d01251;

    address constant public NFT_LOCK_ADDRESS = address(0x1);

    /// @dev 
    //  msg.sender - ONLY registry owner
    //      CAN register ANY non IRegisterable address
    //      CAN register ONLY valid object-parent types combinations for TOKEN
    //      CAN NOT register IRegisterable address
    //      CAN NOT register itself
    // IMPORTANT: MUST NOT call untrusted contract inbetween calls to registry/instance (trusted contracts)
    // motivation: registry/instance state may change during external call
    function registerToken(address tokenAddress)
        external 
        returns(NftId nftId) 
    {
        IRegisterable registerable = IRegisterable(tokenAddress);
        bool isRegisterable;

        // registryOwner can not register IRegisterable as TOKEN
        try registerable.supportsInterface(type(IRegisterable).interfaceId) returns(bool result) {
            isRegisterable = result;
        } catch {// TODO specify expected error type
            isRegisterable = false;
        }

        if(isRegisterable) {
            revert NotToken();
        } 

        IRegistry registry = getRegistry();

        if(msg.sender != registry.ownerOf(address(registry))) {
            revert NotRegistryOwner();
        }

        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            zeroNftId(), // any value
            registry.getNftId(address(registry)),
            TOKEN(),
            tokenAddress,
            NFT_LOCK_ADDRESS,//registry.getLockAddress(),//msg.sender,
            "" // any value
        );

        nftId = registry.register(info);
    }

    /// @dev 
    //  msg.sender - ONLY registry owner
    //      CAN register ONLY valid object-parent types combinations for SERVICE
    //      CAN register ONLY IRegisterable address he owns
    //      CAN NOT register itself
    // IMPORTANT: MUST NOT check owner before calling external contract
    function registerService(IService service)
        external
        returns(
            IRegistry.ObjectInfo memory info,
            bytes memory data
        ) 
    {
        if(service.supportsInterface(type(IService).interfaceId) == false) {
            revert NotService();
        } 

        // TODO read also a version?
        (
            info, 
            data
        ) = _getAndVerifyContractInfo(service, SERVICE(), msg.sender);

        IRegistry registry = getRegistry();

        if(msg.sender != registry.ownerOf(address(registry))) {
            revert NotRegistryOwner();
        }

        info.initialOwner = NFT_LOCK_ADDRESS;//registry.getLockAddress();
        info.nftId = registry.register(info);

        return (
            info,
            data
        );
    }

    // TODO: when called by approved service: add owner arg (service must pass it's msg.sender as owner) & check service allowance
    // anybody can register component if instance gives a corresponding role
    //function registerComponent(IBaseComponent component, ObjectType componentType, address owner)
    function registerComponent(IBaseComponent component, ObjectType componentType)
        external
        returns(
            IRegistry.ObjectInfo memory info,
            bytes memory data
        ) 
    {
        if(component.supportsInterface(type(IBaseComponent).interfaceId) == false) {
            revert NotComponent();
        }

        (
            info, 
            data
        ) = _getAndVerifyContractInfo(component, componentType, msg.sender);

        IRegistry registry = getRegistry();

        //if(registry.allowance(registry.getNftId(msg.sender), componentType) == false) {
        //    revert MissingAllowance();
        //}      

        info.nftId = registry.register(info);

        return (
            info,
            data
        );  
    }

    // TODO: when called by approved service: add owner arg (service must pass it's msg.sender as owner) & check service allowance
    //function registerInstance(IRegisterable instance, address owner)
    function registerInstance(IRegisterable instance)
        external 
        returns(
            IRegistry.ObjectInfo memory info,
            bytes memory data
        ) 
    {
        if(instance.supportsInterface(type(IInstance).interfaceId) == false) {
            revert NotInstance();
        }

        (
            info, 
            data
        ) = _getAndVerifyContractInfo(instance, INSTANCE(), msg.sender);// owner);

        IRegistry registry = getRegistry();

        //if(registry.allowance(registry.getNftId(msg.sender), INSTANCE()) == false) {
        //    revert MissingAllowance();
        //}

        info.nftId = registry.register(info);     
        
        return (
            info,
            data            
        );
    }

    /// @dev trust approved service that initial owner is valid
    function registerPolicy(IRegistry.ObjectInfo memory info)
        external 
        returns(NftId nftId) 
    {
        IRegistry registry = getRegistry();

        if(registry.allowance(registry.getNftId(msg.sender), POLICY()) == false) {
            revert MissingAllowance();
        }

        _verifyObjectInfo(info, POLICY());

        nftId = registry.register(info);
    }

    // From IService
    function getName() public pure override(IService, ServiceBase) returns(string memory) {
        return NAME;
    }


    // from Versionable

    /// @dev top level initializer
    // 1) registry is non upgradeable -> don't need a proxy and uses constructor !
    // 2) deploy registry service first -> from its initialization func it is easier to deploy registry then vice versa
    // 3) deploy registry -> pass registry service address as constructor argument
    // registry is getting instantiated and locked to registry service address forever
    // owner of registry is the same as of registry service
    function _initialize(address protocolOwner, bytes memory registryCreationCode)
        internal
        initializer
        virtual override
    {
        // TODO check when stable
        //require(keccak256(registryCreationCode) == REGISTRY_CREATIONCODE_HASH, "INVALID_REGISTRY_CREATIONCODE");

        bytes memory bytecode = abi.encodePacked(
            registryCreationCode, 
            abi.encode(
                protocolOwner, 
                address(this), 
                NAME, 
                getMajorVersion()
            )
        );
        address registryAddress;

        assembly {
            registryAddress := create(0, add(bytecode, 0x20), mload(bytecode))  

            if iszero(extcodesize(registryAddress)) {
                revert(0, 0)
            }
        }

        IRegistry registry = IRegistry(registryAddress);
        NftId registryNftId = registry.getNftId(registryAddress);

        _initializeServiceBase(registryAddress, registryNftId, protocolOwner);

        _registerInterface(type(IRegistryService).interfaceId);
    }

    // parent check done in registry because of approve()
    function _getAndVerifyContractInfo(
        IRegisterable registerable,
        ObjectType objectType,
        address owner
    )
        internal
        returns(
            IRegistry.ObjectInfo memory info, 
            bytes memory data
        )
    {
        (
            info, 
            data
        ) = registerable.getInitialInfo();

        if(info.objectAddress != address(registerable)) {
            revert InvalidAddress(info.objectAddress);
        }

        if(
            getRegistry().isRegistered(owner) ||
            info.initialOwner != owner) { // contract owner protection
            revert InvalidInitialOwner(info.initialOwner);
        }

        if(msg.sender == address(registerable)) {
            revert SelfRegistration();
        }
        
        if(info.objectType != objectType) {
            revert InvalidType(info.objectType);
        }

        /*NftId parentNftId = info.parentNftId;
        IRegistry.ObjectInfo memory parentInfo = getRegistry().getObjectInfo(parentNftId);

        if(parentInfo.objectType != parentType) { // parent registration + type
            revert InvalidParent(parentNftId);
        }*/

        return(
            info,
            data
        );
    }

    // parent checks done in registry because of approve()
    function _verifyObjectInfo(
        IRegistry.ObjectInfo memory info,
        ObjectType objectType
    )
        internal
        view
    {
        if(info.objectAddress > address(0)) {
            revert InvalidAddress(info.objectAddress);
        }

        if(
            getRegistry().isRegistered(info.initialOwner) ||
            info.initialOwner == address(0)) {
            // TODO non registered address can register object(e.g. POLICY()) and then transfer associated nft to registered contract
            // what are motivations to do so?
            // at least registered contract can not register objects by itself, SERVICE, 
            revert InvalidInitialOwner(info.initialOwner); 
        }

        // can catch all 3 if check that initialOwner is not registered
        /*if(info.initialOwner == msg.sender) {
            revert InitialOwnerIsParent();
        }

        if(info.initialOwner == address(this)) {
            revert InitialOwnerIsService();
        }

        if(info.initialOwner == address(getRegistry())) {
            revert InitialOwnerIsRegistry();
        }*/

        
        if(info.objectType != objectType) {
            revert InvalidType(info.objectType);
        }

        /*NftId parentNftId = info.parentNftId;
        IRegistry.ObjectInfo memory parentInfo = getRegistry().getObjectInfo(parentNftId);

        if(parentInfo.objectType != parentType) { // parent registration + type
            revert InvalidParent(parentNftId);
        }*/        
    }
}