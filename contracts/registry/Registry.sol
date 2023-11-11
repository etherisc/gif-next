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


// IMPORTANT
// Each NFT minted by registry is accosiated with:
// 1) NFT owner
// 2) registred contract OR object stored in registered (parent) contract


contract Registry is
    Versionable,
    IRegisterable,
    IRegistry
{
    using NftIdLib for NftId;

    string public constant EMPTY_URI = "";

    // TODO do not use gif-next in namespace id
    // keccak256(abi.encode(uint256(keccak256("gif-next.contracts.registry.Registry.sol")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant REGISTRY_LOCATION_V1 = 0x6548007c3f4340f82f348c576c0ff69f4f529cadd5ad41f96aae61abceeaa300;

    // IMPORTANT Every new version must implement its own storage struct
    // copy paste previous version and add changes
    // @custom:storage-location erc7201:gif-next.contracts.registry.Registry.sol
    struct RegistryStorageV1 {

        mapping(NftId nftId => ObjectInfo info) _info;
        mapping(address object => NftId nftId) _nftIdByAddress;

        mapping(NftId registrator => mapping(
                ObjectType objectType => bool)) _isApproved;

        mapping(ObjectType objectType => mapping(
                ObjectType parentType => bool)) _isValidParentType;

        mapping(NftId nftId => string stringValue) _string;
        mapping(bytes32 serviceNameHash => mapping(
                VersionPart majorVersion => address service)) _service;

        NftId _nftId;
        IChainNft _chainNft;
        ChainNft _chainNftInternal;

        /// @dev will own protocol nft and registry nft(s) minted during initialize
        address _protocolOwner;
    }

    /// @dev allowance for nft accosiated with registered (contract) address
    modifier onlyAllowedForRegistrar(ObjectInfo memory info) {
        RegistryStorageV1 storage $ = _getStorage();
        NftId registrar = $._nftIdByAddress[msg.sender];
        ObjectType objectType = info.objectType;
        ObjectType parentType = $._info[info.parentNftId].objectType;
        require(allowance(registrar, objectType, parentType), "ERROR:REG-001:NOT_APPROVED");
        _;
    }
    /// @dev allowance for nft accosiated with registry owner
    modifier onlyAllowedForOwner(ObjectInfo memory info) {
        RegistryStorageV1 storage $ = _getStorage();
        ObjectType objectType = info.objectType;
        ObjectType parentType = $._info[info.parentNftId].objectType;
        require($._isValidParentType[objectType][parentType], "ERROR:REG-006:PARENT_TYPE_INVALID");
        _;
    }

    modifier onlyOwner() {
        require(getOwner() == msg.sender, "ERROR:REG-004:NOT_OWNER");
        _;
    }

    /// @dev owner registers contracts only -> object address is never 0
    // owner registers any combination from _isValidParentType[][]
    function register(ObjectInfo memory info) 
        public
        onlyOwner() 
        onlyAllowedForOwner(info)
        returns (NftId nftId)
    {
        require(info.objectAddress > address(0), "ERROR:REG-003:ZERO_ADDRESS");
        
        nftId = _registerContract(msg.sender, info);// registry owner is contract owner

        // special case services 
        if(info.objectType == SERVICE()) {
            IService service = IService(info.objectAddress);
            require(
                service.supportsInterface(type(IService).interfaceId),
                "ERROR:REG-013:NOT_SERVICE"
            );

            string memory serviceName = service.getName();
            VersionPart majorVersion = service.getMajorVersion();
            bytes32 serviceNameHash = keccak256(abi.encode(serviceName));

            // service specific state
            RegistryStorageV1 storage $ = _getStorage();
            $._string[nftId] = serviceName;

            require(
                $._service[serviceNameHash][majorVersion] == address(0),
                "ERROR:REG-014:ALREADY_REGISTERED"
            );
            $._service[serviceNameHash][majorVersion] = info.objectAddress;
        }
    }

    /// @dev only registered and approved contract
    function registerFrom(address from, ObjectInfo memory info)
        external
        onlyAllowedForRegistrar(info)
        returns(NftId nftId)
    {
        require(from != msg.sender, "ERROR:REG-008:FROM_IS_SENDER"); 
        require(from > address(0), "ERROR:REG-016:ZERO_ADDRESS");

        if(info.objectAddress == address(0)) {
            return _registerObject(from, info);// from is registered storage contract and parent
        } else {
            return _registerContract(from, info);// from is contract owner
        }
    }

    /// @dev owner can approve only registered contract (registrar, service)
    // owner can approve only combinations specified in _isValidParentType
    // to approve, owner must provide valid combination 
    // if contract get approved -> it can registerFrom()
    // allowance is checked only during registerFrom()
    // self-approval not allowed
    function approve(
        NftId registrarNftId,
        ObjectType objectType,
        ObjectType parentType
    ) 
        public
        onlyOwner()
    {
        RegistryStorageV1 storage $ = _getStorage();

        require(
            registrarNftId != $._nftId,
            "ERROR:REG-005:SELF_ALLOWANCE"); 

        address registrarAddress = $._info[registrarNftId].objectAddress;
            
        require(
            $._nftIdByAddress[registrarAddress].gtz(),
            "ERROR:REG-007:NOT_REGISTERED");

        require(
            $._info[registrarNftId].objectType == SERVICE(),
            "ERROR:REG-006:NOT_SERVICE");
        // if exists a valid combination -> it will be checked during registerFrom()
        // assume valid combinations are constants -> can be upgraded
        require(
            $._isValidParentType[objectType][parentType],
            "ERROR:REG-007:OBJECT_PARENT_MISMATCH");

        $._isApproved[registrarNftId][objectType] = true;

        emit Approval(registrarNftId, objectType);
    }

    function allowance(
        NftId nftId, 
        ObjectType object,
        ObjectType parent
    ) 
        public
        view 
        returns (bool)
    {
        RegistryStorageV1 storage $ = _getStorage();
        return ($._isApproved[nftId][object] &&
                $._isValidParentType[object][parent]);
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

    // from IERC165
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IRegistry).interfaceId;
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

    // Registry specific functions

    function _registerContract(address owner, ObjectInfo memory info)
        internal
        returns(NftId nftId)
    {
        RegistryStorageV1 storage $ = _getStorage();

        require(info.initialOwner == owner, "ERROR:REG-015:NOT_OWNER");
        require(info.objectAddress != owner, "ERROR:REG-003:SELF_REGISTRATION");

        require($._nftIdByAddress[info.objectAddress].eqz(), "ERROR:REG-009:ALREADY_REGISTERED");
        // TODO do we need it here?
        require($._nftIdByAddress[owner].eqz(), "ERROR:REG-010:OWNER_REGISTERED");

        uint256 mintedTokenId = $._chainNft.mint(
            owner, 
            EMPTY_URI);
        nftId = toNftId(mintedTokenId);
        info.nftId = nftId;

        $._info[nftId] = info;
        $._nftIdByAddress[info.objectAddress] = nftId;
    }

    function _registerObject(address parent, ObjectInfo memory info)
        internal 
        returns(NftId nftId)
    {
        RegistryStorageV1 storage $ = _getStorage();

        require($._nftIdByAddress[parent].gtz(), "ERROR:REG-011:PARENT_NOT_REGISTERED");
        require($._nftIdByAddress[parent] == info.parentNftId, "ERROR:REG-017:NOT_PARENT");

        uint256 mintedTokenId = $._chainNft.mint(
            info.initialOwner, // trust  
            EMPTY_URI);
        nftId = toNftId(mintedTokenId);

        info.nftId = nftId;
        $._info[nftId] = info;
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
    function _setupValidParentTypes() internal onlyInitializing {
        RegistryStorageV1 storage $ = _getStorage();
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
        onlyInitializing
        virtual override
    {
        RegistryStorageV1 storage $ = _getStorage();

        require(
            address($._chainNft) == address(0),
            "ERROR:REG-005:ALREADY_INITIALIZED"
        );
        $._protocolOwner = protocolOwner;

        // deploy NFT 
        $._chainNftInternal = new ChainNft(address(this));// adds 10kb to deployment size
        $._chainNft = IChainNft($._chainNftInternal);
        
        // initial registry setup
        _registerProtocol();
        $._nftId = _registerRegistry();

        // set object parent relations
        _setupValidParentTypes();
    }
}
