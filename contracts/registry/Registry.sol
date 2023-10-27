// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin5/contracts/proxy/utils/Initializable.sol";

import {IRegisterable} from "../shared/IRegisterable.sol";
import {IService} from "../instance/base/IService.sol";

import {IChainNft} from "./IChainNft.sol";
import {ChainNft} from "./ChainNft.sol";
import {IRegistry} from "./IRegistry.sol";
import {NftId, toNftId, zeroNftId, NftIdLib} from "../types/NftId.sol";
import {Version, VersionPart, VersionLib} from "../types/Version.sol";
import {ObjectType, PROTOCOL, REGISTRY, TOKEN, SERVICE, INSTANCE, STAKE, PRODUCT, DISTRIBUTION, ORACLE, POOL, POLICY, BUNDLE} from "../types/ObjectType.sol";

import {Versionable} from "../shared/Versionable.sol";


contract Registry is
    Versionable,
    IRegisterable,
    IRegistry
{
    using NftIdLib for NftId;

    string public constant EMPTY_URI = "";

    // IMPORTANT Every new version with storage changes must implement its own struct
    // copy paste previous version and add changes
    // @custom:storage-location erc7201:gif-next.contracts.registry.Registry.sol
    struct StorageV1 {

        mapping(NftId nftId => ObjectInfo info) _info;
        mapping(address object => NftId nftId) _nftIdByAddress;
        mapping(ObjectType objectType => bool) _isValidType;
        mapping(ObjectType objectType => mapping(ObjectType objectParentType => bool)) _isValidParentType;

        mapping(NftId nftId => string stringValue) _string;
        mapping(bytes32 serviceNameHash => mapping(VersionPart majorVersion => address service)) _service;

        NftId _nftId;
        IChainNft _chainNft;
        ChainNft _chainNftInternal;
        address _initialOwner;

        /// @dev will own protocol nft and registry nft(s) minted during initialize
        address _protocolOwner;
        // if struct goes here
        // then you cannot add new vars here
    }

    // TODO do not use gif-next in namespace id
    // TODO ask openzeppelin about public location
    // keccak256(abi.encode(uint256(keccak256("gif-next.contracts.registry.Registry.sol")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant LOCATION_V1 = 0x6548007c3f4340f82f348c576c0ff69f4f529cadd5ad41f96aae61abceeaa300;

    // TODO check how usage of "$.data" influences gas costs 
    // IMPORTANT Every new version must implement this function
    // keep it private -> if unreachable from the next version then not included in its byte code
    // each version MUST use the same locationV1, just change return type
    function _getStorage() private pure returns (StorageV1 storage $) {
        assembly {
            $.slot := LOCATION_V1
        }
    }

    /// @dev the protocol owner will get ownership of the
    // protocol nft and the global registry nft minted in this 
    // initializer function 
    function _initialize(bytes memory data) 
        internal
        onlyInitializing
        virtual override
    {
        address protocolOwner = abi.decode(data, (address));
        StorageV1 storage $ = _getStorage();

         // TODO here delegate call from proxy constructor, msg.sender is proxy deployer -> Proxy.sol
        $._initialOwner = msg.sender;
        $._protocolOwner = protocolOwner;

        // TODO call another contract which keeps and deploys ChainNft byte code  
        // deploy NFT 
        $._chainNftInternal = new ChainNft(address(this));// adds 10kb to deployment size
        $._chainNft = IChainNft($._chainNftInternal);
        
        // initial registry setup
        _registerProtocol();
        $._nftId = _registerRegistry();

        // setup rules for further registrations
        _setupValidTypes();
        _setupValidParentTypes();
    }

    function register(
        address objectAddress
    )
    // TODO add authz (only services may register components etc)
    // we have to check how we do authz for registring services (just restrict to protocol owner/registry owner)
    external override returns (NftId nftId) {
        StorageV1 storage $ = _getStorage();

        require(
            $._nftIdByAddress[objectAddress].eqz(),
            "ERROR:REG-002:ALREADY_REGISTERED"
        );

        IRegisterable registerable = IRegisterable(objectAddress);
        require(
            registerable.supportsInterface(type(IRegisterable).interfaceId),
            "ERROR:REG-003:NOT_REGISTERABLE"
        );

        ObjectType objectType = registerable.getType();
        require(
            $._isValidType[objectType],
            "ERROR:REG-004:TYPE_INVALID"
        );

        NftId parentNftId = registerable.getParentNftId();
        require(
            isRegistered(parentNftId),
            "ERROR:REG-005:PARENT_NOT_REGISTERED"
        );

        require(
            $._isValidParentType[objectType][$._info[parentNftId].objectType],
            "ERROR:REG-006:PARENT_TYPE_INVALID"
        );

        // also check that nftId and parentNFtId are on the same chain if applicable

        // nft minting
        uint256 mintedTokenId = $._chainNft.mint(
            registerable.getOwner(),
            EMPTY_URI
        );

        nftId = toNftId(mintedTokenId);

        // special case services
        if(registerable.getType() == SERVICE()) {
            IService service = IService(objectAddress);
            require(
                service.supportsInterface(type(IService).interfaceId),
                "ERROR:REG-007:NOT_SERVICE"
            );

            string memory serviceName = service.getName();
            VersionPart majorVersion = service.getMajorVersion();
            bytes32 serviceNameHash = keccak256(abi.encode(serviceName));

            // service specific state
            $._string[nftId] = serviceName;

            require(
                $._service[serviceNameHash][majorVersion] == address(0),
                "ERROR:REG-008:ALREADY_REGISTERED"
            );
            $._service[serviceNameHash][majorVersion] = objectAddress;
        }

        // create object info and link nft id with it
        _registerObjectInfo(registerable, nftId);
    }


    function registerObjectForInstance(
        NftId parentNftId,
        ObjectType objectType,
        address initialOwner,
        bytes memory data
    )
        external
        override
        returns (
            // TODO add onlyRegisteredInstance
            NftId nftId
        )
    {
        StorageV1 storage $ = _getStorage();

        // TODO add more validation
        require(
            objectType == POLICY() || objectType == BUNDLE(),
            "ERROR:REG-010:TYPE_INVALID"
        );

        uint256 mintedTokenId = $._chainNft.mint(initialOwner, EMPTY_URI);
        nftId = toNftId(mintedTokenId);

        ObjectInfo memory info = ObjectInfo(
            nftId,
            parentNftId,
            objectType,
            address(0),
            initialOwner,
            data
        );

        $._info[nftId] = info;

        // add logging
    }

    function getObjectCount() external view override returns (uint256) {
        return _getStorage()._chainNft.totalSupply();
    }

    function getNftId(
        address object
    ) external view override returns (NftId id) {
        return _getStorage()._nftIdByAddress[object];
    }

    function isRegistered(
        NftId nftId
    ) public view override returns (bool) {
        return _getStorage()._info[nftId].objectType.gtz();
    }

    function isRegistered(
        address object
    ) external view override returns (bool) {
        return _getStorage()._nftIdByAddress[object].gtz();
    }

    function getObjectInfo(
        NftId nftId
    ) external view override returns (ObjectInfo memory info) {
        return _getStorage()._info[nftId];
    }

    function getName(
        NftId nftId
    ) external view returns (string memory name) {
        return _getStorage()._string[nftId];
    }

    function getOwner(NftId nftId) external view override returns (address) {
        return _getStorage()._chainNft.ownerOf(nftId.toInt());
    }

    function getChainNft() external view override returns (IChainNft) {
        return _getStorage()._chainNft;
    }

    // special case to retrive a gif service
    function getServiceAddress(string memory serviceName, VersionPart majorVersion) external view override returns (address serviceAddress) {
        bytes32 serviceNameHash = keccak256(abi.encode(serviceName));
        return _getStorage()._service[serviceNameHash][majorVersion];
    }

    // from IERC165
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IRegistry).interfaceId;
    }

    // from IRegistryLinked
    function getRegistry() external view override returns (IRegistry registry) {
        return this;
    }

    // from IVersionable
    function getVersion() public pure virtual override returns (Version) {
        return VersionLib.toVersion(1, 0, 0);
    } 

    // from IRegisterable
    // TODO 
    // 1) Registerable can not register itself -> otherwise register have to trust owner address provided by registerable
    // registerable owner MUST call register and provide registerable address
    // 2) Who is msg.sender here???
    function register() external pure override returns (NftId nftId) {
        return zeroNftId();
    }

    function getType() external pure override returns (ObjectType objectType) {
        return REGISTRY();
    }

    function getOwner() public view override returns (address owner) {
        StorageV1 storage $ = _getStorage();
        return $._nftId.gtz() ? this.getOwner($._nftId) : $._initialOwner;
    }

    function getNftId() public view override (IRegisterable, IRegistry) returns (NftId nftId) {
        return _getStorage()._nftId;
    }

    function getParentNftId() public view returns (NftId nftId) {
        StorageV1 storage $ = _getStorage();
        nftId = $._info[$._nftId].parentNftId;
    }

    function getData() public pure returns (bytes memory data) {
        return "";
    }

    // registry specific functions
    function getProtocolOwner() external view override returns (address) {
        return _getStorage()._protocolOwner;
    }

    /// @dev defines which types are allowed to register
    function _setupValidTypes() internal onlyInitializing {
        StorageV1 storage $ = _getStorage();
        $._isValidType[REGISTRY()] = true; // only for global registry 
        $._isValidType[TOKEN()] = true;
        $._isValidType[SERVICE()] = true;
        $._isValidType[INSTANCE()] = true;
        $._isValidType[STAKE()] = true;
        $._isValidType[PRODUCT()] = true;
        $._isValidType[ORACLE()] = true;
        $._isValidType[POOL()] = true;
        $._isValidType[DISTRIBUTION()] = true;
        $._isValidType[POLICY()] = true;
        $._isValidType[BUNDLE()] = true;
    }

    /// @dev defines which types - parent type relations are allowed to register
    function _setupValidParentTypes() internal onlyInitializing {
        StorageV1 storage $ = _getStorage();
        // registry as parent
        $._isValidParentType[TOKEN()][REGISTRY()] = true;
        $._isValidParentType[SERVICE()][REGISTRY()] = true;
        $._isValidParentType[INSTANCE()][REGISTRY()] = true;

        // instance as parent
        $._isValidParentType[PRODUCT()][INSTANCE()] = true;
        $._isValidParentType[DISTRIBUTION()][INSTANCE()] = true;
        $._isValidParentType[ORACLE()][INSTANCE()] = true;
        $._isValidParentType[POOL()][INSTANCE()] = true;

        // product as parent
        $._isValidParentType[POLICY()][PRODUCT()] = true;

        // pool as parent
        $._isValidParentType[BUNDLE()][POOL()] = true;
        $._isValidParentType[STAKE()][POOL()] = true;
    }

    /// @dev protocol registration used to anchor the dip ecosystem relations
    function _registerProtocol() 
        virtual 
        internal
        onlyInitializing 
    {
        StorageV1 storage $ = _getStorage();

        uint256 protocolId = $._chainNftInternal.PROTOCOL_NFT_ID();
        $._chainNftInternal.mint($._protocolOwner, protocolId);

        NftId protocolNftid = toNftId(protocolId);
        ObjectInfo memory protocolInfo = ObjectInfo(
            protocolNftid,
            zeroNftId(), // parent nft id
            PROTOCOL(),
            address(0), // contract address
            $._protocolOwner,
            "" // data
        );

        $._info[protocolNftid] = protocolInfo;
    }

    /// @dev registry registration
    /// might also register the global registry when not on mainnet
    function _registerRegistry() 
        virtual 
        internal
        onlyInitializing 
        returns (NftId registryNftId) 
    {
        StorageV1 storage $ = _getStorage();

        uint256 registryId = $._chainNftInternal.calculateTokenId(2);
        registryNftId = toNftId(registryId);

        // we're not the global registry
        if(registryId != $._chainNftInternal.GLOBAL_REGISTRY_ID()) {
            _registerGlobalRegistry();
        }

        $._chainNftInternal.mint($._protocolOwner, registryId);

        NftId parentNftId;
        // we're the global registry
        if(block.chainid == 1) {
            parentNftId = toNftId($._chainNftInternal.PROTOCOL_NFT_ID());
        }
        else {
            parentNftId = toNftId($._chainNftInternal.GLOBAL_REGISTRY_ID());
        }
        ObjectInfo memory registryInfo = ObjectInfo(
            registryNftId,
            parentNftId,
            REGISTRY(),
            address(this),  // proxy address
            $._protocolOwner, // registry owner is different from proxy owner 
            ""
        );

        $._info[registryNftId] = registryInfo;
        $._nftIdByAddress[address(this)] = registryNftId;

        // add logging
    }


    /// @dev global registry registration for non mainnet registries
    function _registerGlobalRegistry() 
        virtual 
        internal
        onlyInitializing
    {
        StorageV1 storage $ = _getStorage();

        uint256 globalRegistryId = $._chainNftInternal.GLOBAL_REGISTRY_ID();
        $._chainNftInternal.mint($._protocolOwner, globalRegistryId);

        NftId globalRegistryNftId = toNftId(globalRegistryId);
        ObjectInfo memory globalRegistryInfo = ObjectInfo(
            globalRegistryNftId,
            toNftId($._chainNftInternal.PROTOCOL_NFT_ID()),
            REGISTRY(),
            address(0), // contract address
            $._protocolOwner,
            "" // data
        );

        $._info[globalRegistryNftId] = globalRegistryInfo;
    }

    function _registerObjectInfo(
        IRegisterable registerable,
        NftId nftId
    ) 
        internal 
        virtual
    {
        address objectAddress = address(registerable);
        ObjectInfo memory info = ObjectInfo(
            nftId,
            registerable.getParentNftId(), 
            registerable.getType(),
            objectAddress,
            registerable.getOwner(),
            registerable.getData()
        );

        StorageV1 storage $ = _getStorage();
        $._info[nftId] = info;
        $._nftIdByAddress[objectAddress] = nftId;

        // add logging
    }

}