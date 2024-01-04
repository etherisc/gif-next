// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin5/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ERC165Checker} from "@openzeppelin5/contracts/utils/introspection/ERC165Checker.sol";
import {IERC721Receiver} from "@openzeppelin5/contracts/token/ERC721/IERC721Receiver.sol";
import {AccessManagedUpgradeable} from "@openzeppelin5/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {IRegistry} from "./IRegistry.sol";
import {IInstance} from "../instance/IInstance.sol";

import {ContractDeployerLib} from "../shared/ContractDeployerLib.sol";
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
import {ObjectType, REGISTRY, TOKEN, SERVICE, PRODUCT, ORACLE, POOL, TOKEN, INSTANCE, DISTRIBUTION, POLICY, BUNDLE} from "../../contracts/types/ObjectType.sol";
import {StateId, ACTIVE, PAUSED} from "../../contracts/types/StateId.sol";
import {NftId, NftIdLib, zeroNftId} from "../../contracts/types/NftId.sol";
import {Fee, FeeLib} from "../../contracts/types/Fee.sol";
import {Version, VersionPart, VersionLib} from "../../contracts/types/Version.sol";

import {ServiceBase} from "../../contracts/instance/base/ServiceBase.sol";
import {IService} from "../../contracts/instance/base/IService.sol";
import {IRegistryService} from "./IRegistryService.sol";
import {Registry} from "./Registry.sol";
import {ChainNft} from "./ChainNft.sol";

contract RegistryService is
    AccessManagedUpgradeable,
    ServiceBase,
    IRegistryService
{
    using NftIdLib for NftId;

    error SelfRegistration();
    error NotRegistryOwner();

    error NotToken();
    error NotService();
    error NotInstance();
    error NotProduct();
    error NotPool();
    error NotDistribution();

    error UnexpectedRegisterableType(ObjectType expected, ObjectType found);
    error UnexpectedRegisterableAddress(address expected, address found);
    error NotRegisterableOwner(address expectedOwner);
    error RegisterableOwnerIsZero();   
    error RegisterableOwnerIsRegistered();
    error InvalidInitialOwner(address initialOwner);
    error InvalidAddress(address registerableAddress);


    // Initial value for constant variable has to be compile-time constant
    // TODO define types as constants?
    //ObjectType public constant SERVICE_TYPE = REGISTRY(); 
    string public constant NAME = "RegistryService";

    // TODO update to real hash when registry is stable
    bytes32 public constant REGISTRY_CREATION_CODE_HASH = bytes32(0);

    address public constant NFT_LOCK_ADDRESS = address(0x1);

    /// @dev 
    //  msg.sender - ONLY registry owner
    //      CAN NOT register itself
    //      CAN NOT register IRegisterable address
    //      CAN register ONLY valid object-parent types combinations for TOKEN
    // IMPORTANT: MUST NOT call untrusted contract inbetween calls to registry/instance (trusted contracts)
    // motivation: registry/instance state may change during external call
    // TODO it may be usefull to have transferable token nft in order to delist token, make it invalid for new beginings
    // TODO: MUST prohibit registration of precompiles addresses
    function registerToken(address tokenAddress)
        external 
        returns(NftId nftId) 
    {
        if(msg.sender == tokenAddress) {
            revert SelfRegistration();
        }    

        // MUST not revert if no ERC165 support
        if(tokenAddress.code.length == 0 ||
            ERC165Checker.supportsInterface(tokenAddress, type(IRegisterable).interfaceId)) {
            revert NotToken();
        }

        NftId registryNftId = _registry.getNftId(address(_registry));

        if(msg.sender != _registry.ownerOf(registryNftId)) {
            revert NotRegistryOwner();
        }

        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            zeroNftId(), // any value
            registryNftId, // parent nft id
            TOKEN(),
            false, // isInterceptor
            tokenAddress,
            NFT_LOCK_ADDRESS,
            "" // any value
        );

        nftId = _registry.register(info);
    }

    /// @dev 
    //  msg.sender - ONLY registry owner
    //      CAN NOT register itself
    //      CAN register ONLY valid object-parent types combinations for SERVICE
    //      CAN register ONLY IRegisterable address he owns
    // IMPORTANT: MUST NOT check owner before calling external contract
    function registerService(IService service)
        external
        returns(
            IRegistry.ObjectInfo memory info,
            bytes memory data
        ) 
    {
        if(msg.sender == address(service)) {
            revert SelfRegistration();
        }

        // CAN revert if no ERC165 support -> will revert with empty message 
        if(!service.supportsInterface(type(IService).interfaceId)) {
            revert NotService();
        }

        (
            info, 
            data
        ) = _getAndVerifyContractInfo(service, SERVICE(), msg.sender);

        if(msg.sender != _registry.getOwner()) {
            revert NotRegistryOwner();
        }

        info.nftId = _registry.register(info);
        service.linkToRegisteredNftId();
        return (
            info,
            data
        );
    }

    // If msg.sender is approved service: 
    // 1) add owner arg (service MUST pass it's msg.sender as owner)
    // 2) check service allowance 
    // 3) comment self registrstion check
    //function registerInstance(IRegisterable instance, address owner)
    function registerInstance(IRegisterable instance)
        external
        returns(
            IRegistry.ObjectInfo memory info,
            bytes memory data
        ) 
    {
        if(msg.sender == address(instance)) {
            revert SelfRegistration();
        }

        if(!instance.supportsInterface(type(IInstance).interfaceId)) {
            revert NotInstance();
        }

        (
            info, 
            data
        ) = _getAndVerifyContractInfo(instance, INSTANCE(), msg.sender);

        info.nftId = _registry.register(info);
        instance.linkToRegisteredNftId(); // asume safe
        
        return (
            info,
            data            
        );
    }

    function registerProduct(IBaseComponent product, address owner)
        external
        restricted
        returns(
            IRegistry.ObjectInfo memory info,
            bytes memory data
        ) 
    {
        // CAN revert if no ERC165 support -> will revert with empty message 
        if(!product.supportsInterface(type(IProductComponent).interfaceId)) {
            revert NotProduct();
        }

        (
            info, 
            data
        ) = _getAndVerifyContractInfo(product, PRODUCT(), owner);

        NftId serviceNftId = _registry.getNftId(msg.sender);

        info.nftId = _registry.register(info);
        // TODO unsafe, let component or its owner derive nftId latter, when state assumptions and modifications of GIF contracts are finished  
        product.linkToRegisteredNftId();

        return (
            info,
            data
        );  
    }

    function registerPool(IBaseComponent pool, address owner)
        external
        restricted
        returns(
            IRegistry.ObjectInfo memory info,
            bytes memory data
        ) 
    {
        if(!pool.supportsInterface(type(IPoolComponent).interfaceId)) {
            revert NotPool();
        }

        (
            info, 
            data
        ) = _getAndVerifyContractInfo(pool, POOL(), owner);

        NftId serviceNftId = _registry.getNftId(msg.sender);

        info.nftId = _registry.register(info);
        pool.linkToRegisteredNftId();

        return (
            info,
            data
        );  
    }

   function registerDistribution(IBaseComponent distribution, address owner)
        external
        restricted
        returns(
            IRegistry.ObjectInfo memory info,
            bytes memory data
        ) 
    {
        if(!distribution.supportsInterface(type(IDistributionComponent).interfaceId)) {
            revert NotDistribution();
        }

        (
            info, 
            data
        ) = _getAndVerifyContractInfo(distribution, DISTRIBUTION(), owner);

        NftId serviceNftId = _registry.getNftId(msg.sender);

        info.nftId = _registry.register(info); 
        distribution.linkToRegisteredNftId();

        return (
            info,
            data
        );  
    }

    function registerPolicy(IRegistry.ObjectInfo memory info)
        external
        restricted 
        returns(NftId nftId) 
    {
        NftId senderNftId = _registry.getNftId(msg.sender);

        _verifyObjectInfo(info, POLICY());

        nftId = _registry.register(info);
    }

    function registerBundle(IRegistry.ObjectInfo memory info)
        external
        restricted 
        returns(NftId nftId) 
    {

        NftId senderNftId = _registry.getNftId(msg.sender);

        _verifyObjectInfo(info, BUNDLE());

        nftId = _registry.register(info);
    }


    // From IService
    function getName() public pure override(IService, ServiceBase) returns(string memory) {
        return NAME;
    }
    //function getType() public pure override(IService, ServiceBase) returns(ObjectType serviceType) {
    //    return SERVICE_TYPE;
    //}


    // from Versionable

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
        (
            address initialAuthority,
            bytes memory registryByteCodeWithInitCode
        ) = abi.decode(data, (address, bytes));

        __AccessManaged_init(initialAuthority);

        bytes memory encodedConstructorArguments = abi.encode(
            owner,
            getMajorVersion());

        bytes memory registryCreationCode = ContractDeployerLib.getCreationCode(
            registryByteCodeWithInitCode,
            encodedConstructorArguments);

        IRegistry registry = IRegistry(ContractDeployerLib.deploy(
            registryCreationCode,
            REGISTRY_CREATION_CODE_HASH));

        NftId registryNftId = registry.getNftId(address(registry));

        _initializeServiceBase(address(registry), registryNftId, owner);

        // TODO why do registry service proxy need to keep its nftId??? -> no registryServiceNftId checks in implementation
        // if they are -> use registry address to obtain owner of registry service nft (works the same with any registerable and(or) implementation)
        linkToRegisteredNftId(); 
        _registerInterface(type(IRegistryService).interfaceId);
    }

    // parent check done in registry because of approve()
    function _getAndVerifyContractInfo(
        IRegisterable registerable,
        ObjectType expectedType, // assume can be valid only
        address expectedOwner // assume can be 0
    )
        internal
        view
        returns(
            IRegistry.ObjectInfo memory info, 
            bytes memory data
        )
    {
        (
            info, 
            data
        ) = registerable.getInitialInfo();

        if(info.objectType != expectedType) {// type is checked in registry anyway...but service logic may depend on expected value
            revert UnexpectedRegisterableType(expectedType, info.objectType);
        }

        if(info.objectAddress != address(registerable)) {
            revert UnexpectedRegisterableAddress(address(registerable), info.objectAddress);
        }

        address owner = info.initialOwner;

        if(owner != expectedOwner) { // registerable owner protection
            revert NotRegisterableOwner(expectedOwner);
        }

        if(owner == address(0)) {
            revert RegisterableOwnerIsZero();
        }
        
        if(getRegistry().isRegistered(owner)) { 
            revert RegisterableOwnerIsRegistered();
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

        /*NftId parentNftId = info.parentNftId;
        IRegistry.ObjectInfo memory parentInfo = getRegistry().getObjectInfo(parentNftId);

        if(parentInfo.objectType != parentType) { // parent registration + type
            revert InvalidParent(parentNftId);
        }*/        
    }
}
