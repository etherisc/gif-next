// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IRegisterable} from "../shared/IRegisterable.sol";
import {IService} from "../instance/base/IService.sol";

import {IChainNft} from "./IChainNft.sol";
import {ChainNft} from "./ChainNft.sol";
import {IRegistry} from "./IRegistry.sol";
import {NftId, toNftId, zeroNftId, NftIdLib} from "../types/NftId.sol";
import {Version, VersionPart, VersionLib} from "../types/Version.sol";
import {ObjectType, PROTOCOL, REGISTRY, TOKEN, SERVICE, INSTANCE, STAKE, PRODUCT, DISTRIBUTION, ORACLE, POOL, POLICY, BUNDLE} from "../types/ObjectType.sol";

import {Versionable} from "../shared/Versionable.sol";
import {ERC165} from "../shared/ERC165.sol";


// IMPORTANT
// Each NFT minted by registry is accosiated with:
// 1) NFT owner ( used in register() )
// 2) registred contract OR object stored in registered (parent) contract ( used in registerFrom() )

contract Registry is
    ERC165,
    Versionable,
    IRegisterable,
    IRegistry
{
    // register
    error NotOwner();
    error InvalidTypesCombination(ObjectType objectType, ObjectType parentType);
    error ServiceInterfaceNotSupported(IService service);
    error ServiceAlreadyRegistered(IService service);
            
    // registerFrom        
    error FromIsRegistrar();
    error FromIsZero();
    error NoAllowance(NftId registrarNftId, ObjectType objectType);

    // approve
    // NotOwner
    error NotRegisteredContract(NftId registrarNftId);
    error NotService(NftId registrarNftId);
    // InvalidTypesCombination

    // _verifyContract
    error NotContractType(ObjectType objectType);
    error ContractAddressZero();
    error SelfRegistration();
    error ContractAlreadyRegistered(address objectAddress);
    error ContractOwnerIsRegistered(address owner);

    // _verifyObject
    error NotObjectType(ObjectType objectType);
    error ObjectAddressNotZero();
    error InitialOwnerIsZero();
    error InitialOwnerIsParent();
    error InitialOwnerIsRegistrar();
    error ParentNotRegistered(address parent);
    error ParentMismatch(NftId parentNftId);

    string public constant EMPTY_URI = "";

    // TODO do not use gif-next in namespace id
    // keccak256(abi.encode(uint256(keccak256("gif-next.contracts.registry.Registry.sol")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant REGISTRY_LOCATION_V1 = 0x6548007c3f4340f82f348c576c0ff69f4f529cadd5ad41f96aae61abceeaa300;

    // IMPORTANT Every new version must implement its own storage struct
    // copy paste previous version and append changes to the end 
    // @custom:storage-location erc7201:gif-next.contracts.registry.Registry.sol
    struct RegistryStorageV1 {

        mapping(NftId nftId => ObjectInfo info) _info;
        mapping(address object => NftId nftId) _nftIdByAddress;

        mapping(NftId registrator => mapping(
                ObjectType objectType => bool)) _isApproved;

        mapping(ObjectType objectType => mapping(
                ObjectType parentType => bool)) _isValidCombination;

        mapping(ObjectType objectType => bool) _isContract;

        mapping(NftId nftId => string stringValue) _string;
        mapping(bytes32 serviceNameHash => mapping(
                VersionPart majorVersion => address service)) _service;

        NftId _nftId;
        IChainNft _chainNft;
        ChainNft _chainNftInternal;

        /// @dev will own protocol nft and registry nft(s) minted during initialize
        address _protocolOwner;
    }

    modifier onlyOwner() {
        if(msg.sender != getOwner()) {
            revert NotOwner();
        }
        _;
    }

    /// @dev 
    //  msg.sender - ONLY registry owner
    //      registers ONLY valid type combinations 
    //      CAN register contracts ONLY
    //      CAN NOT register itself
    function register(ObjectInfo memory info)
        external
        onlyOwner
        returns(NftId nftId)
    {
        RegistryStorageV1 storage $ = _getStorage();
        ObjectType objectType = info.objectType;
        ObjectType parentType = $._info[info.parentNftId].objectType;

        if($._isValidCombination[objectType][parentType] == false) {
            revert InvalidTypesCombination(objectType, parentType);
        }

        info.initialOwner = msg.sender; // enforce owner instead of check

        _verifyContract(info);

        nftId = _registerInfo(info, true); 

        // special case -> TODO unsafe to call service here -> add function register(info, serviceInfo) or what???
        if(info.objectType == SERVICE()) {
            IService service = IService(info.objectAddress);
            if(service.supportsInterface(type(IService).interfaceId) == false) {
                revert ServiceInterfaceNotSupported(service); 
            }

            string memory serviceName = service.getName();
            VersionPart majorVersion = service.getMajorVersion();
            bytes32 serviceNameHash = keccak256(abi.encode(serviceName));

            // service specific state
            $._string[nftId] = serviceName;

            if($._service[serviceNameHash][majorVersion] != address(0)) {
                revert ServiceAlreadyRegistered(service);
            }

            $._service[serviceNameHash][majorVersion] = info.objectAddress;

            emit LogServiceRegistered(address(service), serviceName, majorVersion); 
        }
    }
    /// @dev 
    // msg.sender - registrar
    //      MUST BE a registered contract
    //      MUST BE approved by registry owner
    //      registers ONLY valid type combinations
    //      registers ONLY within it's approval
    //      CAN register contracts AND objects
    //      CAN NOT register itself
    // from - registrar's msg.sender 
    //      either contract owner or registered parent contract (assumption)
    //      MUST NOT equal 0
    //      MUST NOT equal registrar
    function registerFrom(
        address from,
        ObjectInfo memory info
    )
        external
        returns(NftId nftId)
    {
        address registrar = msg.sender;

        if(from == address(0)) {
            revert FromIsZero();
        }

        if(from == registrar) {
            revert FromIsRegistrar(); 
        }

        RegistryStorageV1 storage $ = _getStorage();
        NftId registrarNftId = $._nftIdByAddress[registrar];
        ObjectType objectType = info.objectType;
        ObjectType parentType = $._info[info.parentNftId].objectType;

        if(allowance(registrarNftId, objectType) == false) {
            revert NoAllowance(registrarNftId, objectType);
        }

        if($._isValidCombination[objectType][parentType] == false) {
            revert InvalidTypesCombination(objectType, parentType);
        }

        // TODO if any of parameters is "zero" -> usually expected behavior is revert
        if(info.objectAddress > address(0)) 
        {
            info.initialOwner = from; // enforce instead of check

            _verifyContract(info);

            nftId = _registerInfo(info, true);//isContract
        }
        else
        {
            _verifyObject(registrar, from, info);

            nftId = _registerInfo(info, false);
        }
    }
    

    /// @dev 
    // msg.sender - registry owner 
    //     CAN approve only registered service contract
    //     CAN approve any combination specified in _isValidCombination
    //     CAN NOT approve itself
    function approve(
        NftId registrarNftId,
        ObjectType objectType,
        ObjectType parentType
    ) 
        public
        onlyOwner()
    {
        RegistryStorageV1 storage $ = _getStorage();
        address registrarAddress = $._info[registrarNftId].objectAddress;
            
        if($._nftIdByAddress[registrarAddress].eqz()) {
            revert NotRegisteredContract(registrarNftId);
        }

        if($._info[registrarNftId].objectType != SERVICE()) {
            revert NotService(registrarNftId);
        }

        if($._isValidCombination[objectType][parentType] == false) {
            revert InvalidTypesCombination(objectType, parentType);
        }

        $._isApproved[registrarNftId][objectType] = true;

        emit LogApproval(registrarNftId, objectType);
    }

    /// @dev returns false for registry owner nft
    function allowance(
        NftId nftId, 
        ObjectType object
    ) 
        public
        view 
        returns (bool)
    {
        return _getStorage()._isApproved[nftId][object];
    }

    // from IRegistry
    function getObjectCount() external view override returns (uint256) {
        RegistryStorageV1 storage $ = _getStorage();
        return $._chainNft.totalSupply();
    }

    function getNftId(address object) external view override returns (NftId id) {
        return _getStorage()._nftIdByAddress[object];
    }

    function getName(NftId nftId) external view returns (string memory name) {
        return _getStorage()._string[nftId];
    }

    function ownerOf(NftId nftId) public view override returns (address) {
        return _getStorage()._chainNft.ownerOf(nftId.toInt());
    }

    function ownerOf(address contractAddress) public view returns (address) {
        RegistryStorageV1 storage $ = _getStorage();
        return $._chainNft.ownerOf($._nftIdByAddress[contractAddress].toInt());
    }

    function getObjectInfo(NftId nftId) external view override returns (ObjectInfo memory) {
        return _getStorage()._info[nftId];
    }

    function getObjectInfo(address object) external view override returns (ObjectInfo memory) {
        RegistryStorageV1 storage $ = _getStorage();
        return $._info[$._nftIdByAddress[object]];
    }

    function isRegistered(NftId nftId) public view override returns (bool) {
        return _getStorage()._info[nftId].objectType.gtz();
    }

    function isRegistered(address object) external view override returns (bool) {
        return _getStorage()._nftIdByAddress[object].gtz();
    }

    // special case to retrive a gif service
    function getServiceAddress(
        string memory serviceName, 
        VersionPart majorVersion
    ) external view override returns (address) 
    {
        bytes32 serviceNameHash = keccak256(abi.encode(serviceName));
        return _getStorage()._service[serviceNameHash][majorVersion];
    }

    function getProtocolOwner() external view override returns (address) {
        return _getStorage()._protocolOwner;
    }

    function getChainNft() external view override returns (IChainNft) {
        return _getStorage()._chainNft;
    }

    // from IVersionable
    function getVersion() public pure virtual override returns (Version) {
        return VersionLib.toVersion(1, 0, 0);
    } 

    // from IOwnable
    function getOwner() public view override returns (address owner) {
        return ownerOf(address(this));
    }

    // from IRegisterable
    function getRegistry() external view override returns (IRegistry) {
        return this;
    }

    function getInitialInfo() 
        external 
        view 
        override 
        returns (ObjectInfo memory, bytes memory)
    {
        RegistryStorageV1 storage $ = _getStorage();
        return (
            $._info[$._nftId],
            bytes("")
        );
    }

    function getNftId() external view override (IRegisterable) returns (NftId) {
        return _getStorage()._nftId;
    }

    // Internals

    function _verifyContract(
        ObjectInfo memory info
    )
        internal
        view
    {
        RegistryStorageV1 storage $ = _getStorage();

        if($._isContract[info.objectType] == false) {
            revert NotContractType(info.objectType);
        }

        if(info.objectAddress == address(0)) {
            revert ContractAddressZero();
        }

        if(info.objectAddress == info.initialOwner) {
            revert SelfRegistration();
        }
        
        if($._nftIdByAddress[info.objectAddress].gtz()) { 
            revert ContractAlreadyRegistered(info.objectAddress);
        }
        // TODO why do we need it here:
        // 1) contract owner is registryOwner
        //   'info.objectAddress != owner' guarantees that registryOwner will not be able to regiter itself -> registryOwner allways not registered... 
        //    if registryOwner wants to become registered/registrar in the future? -> it MUST transfer ownership first -> thus will became unable to use register()
        //    then if _nftId transfered to registered contract -> it MUST not be able to use register() -> catched by this require
        // 2) contract owner is not registryOwner 
        //    situations like: owner is Product which calls RegistryService.registerInstance() -> Product will become an owner of Instance -> catched by this require 
        if($._nftIdByAddress[info.initialOwner].gtz()) {
            revert ContractOwnerIsRegistered(info.initialOwner);
        }
    }

    function _verifyObject(
        address registrar,
        address parent,
        ObjectInfo memory info
    )
        internal
        view
    {
        RegistryStorageV1 storage $ = _getStorage();

        if($._isContract[info.objectType]) {
            revert NotObjectType(info.objectType);
        }

        if(info.objectAddress > address(0)) {
            revert ObjectAddressNotZero();
        }

        if(info.initialOwner == address(0)) {
            revert InitialOwnerIsZero();
        }

        if(info.initialOwner == parent) {
            revert InitialOwnerIsParent();
        }

        if(info.initialOwner == registrar) {
            revert InitialOwnerIsRegistrar();
        }

        if($._nftIdByAddress[parent].eqz()) {
            revert ParentNotRegistered(parent);
        }

        if($._nftIdByAddress[parent] != info.parentNftId) {
            revert ParentMismatch(info.parentNftId); 
        }
    }

    function _registerInfo(ObjectInfo memory info, bool isContract)
        internal
        returns(NftId nftId)
    {
        RegistryStorageV1 storage $ = _getStorage();
        uint256 mintedTokenId = $._chainNft.mint(
            info.initialOwner,
            EMPTY_URI);
        nftId = toNftId(mintedTokenId);

        info.nftId = nftId;
        $._info[nftId] = info;

        if(isContract) {
            $._nftIdByAddress[info.objectAddress] = nftId; 
        }

        emit LogObjectRegistered(nftId, info.parentNftId, info.objectType, info.objectAddress, info.initialOwner);
    }
    /// @dev protocol registration used to anchor the dip ecosystem relations
    function _registerProtocol() 
        internal
        onlyInitializing
        virtual
    {
        RegistryStorageV1 storage $ = _getStorage();

        uint256 protocolId = $._chainNftInternal.PROTOCOL_NFT_ID();
        NftId protocolNftId = toNftId(protocolId);

        $._chainNftInternal.mint($._protocolOwner, protocolId);

        $._info[protocolNftId] = ObjectInfo(
            protocolNftId,
            zeroNftId(), // parent
            PROTOCOL(),
            address(0),
            $._protocolOwner,
            ""
        );
    }

    /// @dev registry registration
    /// might also register the global registry when not on mainnet
    function _registerRegistry() 
        internal
        onlyInitializing
        virtual
        returns(NftId registryNftId) 
    {
        RegistryStorageV1 storage $ = _getStorage();

        uint256 registryId = $._chainNftInternal.calculateTokenId(2);
        registryNftId = toNftId(registryId);

        NftId parentNftId;

        if(registryId != $._chainNftInternal.GLOBAL_REGISTRY_ID()) 
        {// we're not the global registry
            _registerGlobalRegistry();
            parentNftId = toNftId($._chainNftInternal.GLOBAL_REGISTRY_ID());
        }
        else 
        {// we are global registry
            parentNftId = toNftId($._chainNftInternal.PROTOCOL_NFT_ID());
        }

        $._chainNftInternal.mint($._protocolOwner, registryId);

        $._info[registryNftId] = ObjectInfo(
            registryNftId,
            parentNftId,
            REGISTRY(),
            address(this), 
            $._protocolOwner,
            "" 
        );
        $._nftIdByAddress[address(this)] = registryNftId;
    }


    /// @dev global registry registration for non mainnet registries
    function _registerGlobalRegistry() 
        internal
        onlyInitializing
        virtual
    {
        RegistryStorageV1 storage $ = _getStorage();

        uint256 globalRegistryId = $._chainNftInternal.GLOBAL_REGISTRY_ID();
        $._chainNftInternal.mint($._protocolOwner, globalRegistryId);

        NftId globalRegistryNftId = toNftId(globalRegistryId);

        $._info[globalRegistryNftId] = ObjectInfo(
            globalRegistryNftId,
            toNftId($._chainNftInternal.PROTOCOL_NFT_ID()), // parent
            REGISTRY(),
            address(0), // contract address
            $._protocolOwner,
            "" // data
        );
    }

    /// @dev defines which object - parent types relations are allowed to register
    // IMPORTANT: each object type MUST have the only parent type
    // IMPORTANT: DO NOT use "zero type" here
    function _setupValidObjectParentCombinations() internal onlyInitializing {
        RegistryStorageV1 storage $ = _getStorage();
        // registry as parent
        $._isValidCombination[TOKEN()][REGISTRY()] = true;
        $._isValidCombination[SERVICE()][REGISTRY()] = true;
        $._isValidCombination[INSTANCE()][REGISTRY()] = true;

        // instance as parent
        $._isValidCombination[PRODUCT()][INSTANCE()] = true;
        $._isValidCombination[DISTRIBUTION()][INSTANCE()] = true;
        $._isValidCombination[ORACLE()][INSTANCE()] = true;
        $._isValidCombination[POOL()][INSTANCE()] = true;

        // product as parent
        $._isValidCombination[POLICY()][PRODUCT()] = true;

        // pool as parent
        $._isValidCombination[BUNDLE()][POOL()] = true;
        $._isValidCombination[STAKE()][POOL()] = true;

        // define registerable types associated with contracts
        $._isContract[SERVICE()] = true;
        $._isContract[TOKEN()] = true;            
        $._isContract[INSTANCE()] = true;
        $._isContract[PRODUCT()] = true;
        $._isContract[POOL()] = true;
        $._isContract[ORACLE()] = true;
        $._isContract[DISTRIBUTION()] = true;
    }

    // TODO check how usage of "$.data" influences gas costs 
    // IMPORTANT Every new version must implement this function
    // keep it private -> if unreachable from the next version then not included in its byte code
    // each version MUST use the same REGISTRY_LOCATION_V1, just change return type
    function _getStorage() private pure returns (RegistryStorageV1 storage $) {
        assembly {
            $.slot := REGISTRY_LOCATION_V1
        }
    }

    // From Versionable 

    /// @dev top level initializer function
    // Expected to be called from proxy constructor,
    // thus msg.sender is proxy deployer, NOT protocolOwner 
    // The protocol owner will get ownership of the
    // protocol nft and the global registry nft (both minted here) 
    function _initialize(address protocolOwner, bytes memory data)
        internal
        initializer
        virtual override
    {
        RegistryStorageV1 storage $ = _getStorage();

        assert($._chainNftInternal == 0);

        $._protocolOwner = protocolOwner;

        // deploy NFT 
        $._chainNftInternal = new ChainNft(address(this));// adds 10kb to deployment size
        $._chainNft = IChainNft($._chainNftInternal);
        
        // initial registry setup
        _registerProtocol();
        $._nftId = _registerRegistry();

        // set object parent relations
        _setupValidObjectParentCombinations();

        _registerInterface(type(IRegistry).interfaceId);
    }
}
