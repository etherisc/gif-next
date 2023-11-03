// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

//import {IRegisterable} from "../shared/IRegisterable.sol";
import {IRegisterable_new} from "../shared/IRegisterable_new.sol";
import {IService} from "../instance/base/IService.sol";

import {IChainNft} from "./IChainNft.sol";
import {ChainNft} from "./ChainNft.sol";
//import {IRegistry} from "./IRegistry.sol";
import {IRegistry_new} from "./IRegistry_new.sol";
import {NftId, toNftId, zeroNftId, NftIdLib} from "../types/NftId.sol";
import {Version, VersionPart, VersionLib} from "../types/Version.sol";
import {ObjectType, PROTOCOL, REGISTRY, TOKEN, SERVICE, INSTANCE, STAKE, PRODUCT, DISTRIBUTION, ORACLE, POOL, POLICY, BUNDLE} from "../types/ObjectType.sol";

import {Versionable} from "../shared/Versionable.sol";


contract Registry_new is
    Versionable,
    IRegisterable_new,// Registerable_new
    IRegistry_new
{
    using NftIdLib for NftId;

    string public constant EMPTY_URI = "";

    // TODO do not use gif-next in namespace id
    // TODO ask openzeppelin about public location
    // keccak256(abi.encode(uint256(keccak256("gif-next.contracts.registry.Registry.sol")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant REGISTRY_LOCATION_V1 = 0x6548007c3f4340f82f348c576c0ff69f4f529cadd5ad41f96aae61abceeaa300;

    // IMPORTANT Every new version with storage changes must implement its own struct
    // copy paste previous version and add changes
    // @custom:storage-location erc7201:gif-next.contracts.registry.Registry.sol
    struct RegistryStorageV1 {

        mapping(NftId nftId => ObjectInfo info) _info;
        mapping(address object => NftId nftId) _nftIdByAddress;
        mapping(NftId registrator => mapping(
                ObjectType parentType => mapping(
                ObjectType objectType => bool))) _allowed;

        mapping(NftId nftId => string stringValue) _string;
        mapping(bytes32 serviceNameHash => mapping(
                VersionPart majorVersion => address service)) _service;

        NftId _nftId;
        IChainNft _chainNft;
        ChainNft _chainNftInternal;

        /// @dev will own protocol nft and registry nft(s) minted during initialize
        address _protocolOwner;
        // if struct goes here
        // then you cannot add new vars after
    }

    /// @dev allowance for nft accosiated with registered (contract) address 
    modifier onlyAllowedForRegistrar(ObjectInfo memory info) {
        RegistryStorageV1 storage $ = _storage();
        NftId registrar = $._nftIdByAddress[msg.sender];
        ObjectType objectType = info.objectType;
        ObjectType parentType = $._info[info.parentNftId].objectType;
        require($._allowed[registrar][objectType][parentType] == true, "ERROR:REG-001:NOT_ALLOWED");
        _;
    }
    /// @dev alowance for nft accosiated with registry owner
    modifier onlyAllowedForOwner(ObjectInfo memory info) {
        RegistryStorageV1 storage $ = _storage();
        ObjectType objectType = info.objectType;
        ObjectType parentType = $._info[info.parentNftId].objectType;
        require($._allowed[$._nftId][objectType][parentType] == true, "ERROR:REG-002:NOT_ALLOWED");
        _;
    }
    modifier onlyOwner() {
        require(getOwner() == msg.sender, "ERROR:REG-004:NOT_OWNER");
        _;
    }

    /// @dev owner registers contracts only
    function register(ObjectInfo memory info) 
        public
        onlyOwner() 
        onlyAllowedForOwner(info)
        //override
        returns (NftId nftId)
    {
        nftId = _registerContract(msg.sender, info);

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
            RegistryStorageV1 storage $ = _storage();
            $._string[nftId] = serviceName;

            require(
                $._service[serviceNameHash][majorVersion] == address(0),
                "ERROR:REG-014:ALREADY_REGISTERED"
            );
            $._service[serviceNameHash][majorVersion] = info.objectAddress;
        }
    }

    function approve(
        NftId nftId,
        ObjectType object,
        ObjectType parent
    ) 
        public
        onlyOwner()
        //override
    {
        RegistryStorageV1 storage $ = _storage();

        if(nftId != $._nftId) {
            require(
                $._info[nftId].objectType == SERVICE(),
                "ERROR:REG-006:NOT_SERVICE"
            );
            address objectAddress = $._info[nftId].objectAddress;
            require(
                $._nftIdByAddress[objectAddress].gtz(),
                "ERROR:REG-007:NOT_REGISTERED"
            );
        }

        require(object.gtz() && parent.gtz(),
                "ERROR:REG-012:ZERO_TYPE"
        );
        
        $._allowed[nftId][object][parent] = true;

        emit Approval(nftId, object, parent);
    }

    function allowance(
        NftId nftId, 
        ObjectType object, 
        ObjectType parent
    ) 
        external
        view 
        returns (bool)
    {
        RegistryStorageV1 storage $ = _storage();
        return $._allowed[nftId][object][parent];
    }

    /// @dev only registered and approved contract
    function registerFrom(address from, ObjectInfo memory info)
        external
        onlyAllowedForRegistrar(info)
        returns(NftId nftId)
    {
        require(from != msg.sender, "ERROR:REG-008:NOT_ALLOWED"); 
        require(from > address(0), "ERROR:REG-016:ZERO_ADDRESS");

        if(info.objectAddress == address(0)) {
            return _registerObject(from, info);// from is registered storage contract and parent
        } else {
            return _registerContract(from, info);// from is contract owner
        }
    }

    // from IVersionable
    function getVersion() public pure virtual override returns (Version) {
        return VersionLib.toVersion(1, 0, 0);
    } 

    // from IRegistry
    function getObjectCount() external view override returns (uint256) {
        RegistryStorageV1 storage $ = _storage();
        return $._chainNft.totalSupply();
    }

    function getNftId(address object) external view override returns (NftId id) {
        return _storage()._nftIdByAddress[object];
    }

    function getName(NftId nftId) external view returns (string memory name) {
        return _storage()._string[nftId];
    }

    function ownerOf(NftId nftId) public view override returns (address) {
        return _storage()._chainNft.ownerOf(nftId.toInt());
    }

    function ownerOf(address contractAddress) public view returns (address) {
        RegistryStorageV1 storage $ = _storage();
        return $._chainNft.ownerOf($._nftIdByAddress[contractAddress].toInt());
    }

    function getObjectInfo(NftId nftId) external view override returns (ObjectInfo memory) {
        return _storage()._info[nftId];
    }

    function getObjectInfo(address object) external view override returns (ObjectInfo memory) {
        RegistryStorageV1 storage $ = _storage();
        return $._info[$._nftIdByAddress[object]];
    }

    function isRegistered(NftId nftId) public view override returns (bool) {
        return _storage()._info[nftId].objectType.gtz();
    }

    function isRegistered(address object) external view override returns (bool) {
        return _storage()._nftIdByAddress[object].gtz();
    }

    // special case to retrive a gif service
    function getServiceAddress(
        string memory serviceName, 
        VersionPart majorVersion
    ) external view override returns (address) 
    {
        bytes32 serviceNameHash = keccak256(abi.encode(serviceName));
        return _storage()._service[serviceNameHash][majorVersion];
    }

    function getProtocolOwner() external view override returns (address) {
        return _storage()._protocolOwner;
    }

    function getChainNft() external view override returns (IChainNft) {
        return _storage()._chainNft;
    }

    // from IERC165
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IRegistry_new).interfaceId;
    }

    // from IOwnable
    function getOwner() public view override returns (address owner) {
        return ownerOf(address(this));
    }

    // from IRegisterable
    function getRegistry() external view override returns (IRegistry_new) {
        return this;
    }

    /*function getInfo() public view override returns (IRegistry_new.ObjectInfo memory info) {
        RegistryStorageV1 storage $ = _storage();
        return $._info[$._nftId];
    }*/

    /*function getInitialInfo() external view override returns (IRegistry_new.ObjectInfo memory) {
        return getInfo();
    }*/
    /*function getInitialInfo() external pure override returns (IRegistry_new.ObjectInfo memory) {
        return ObjectInfo(
            zeroNftId(), // nftId
            zeroNftId(), // parentNftId
            REGISTRY(),
            address(0), // objectAddress
            address(0), // initialOwner
            ""//data
        );
    }*/ 

    function getInfo() 
        public 
        view 
        override 
        returns (IRegistry_new.ObjectInfo memory, bytes memory) 
    {
        RegistryStorageV1 storage $ = _storage();
        return (
            $._info[$._nftId],
            bytes("")
        );
    }  
    function getInitialInfo() 
        external 
        view 
        override 
        returns (IRegistry_new.ObjectInfo memory, bytes memory)
    {
        return getInfo();
        /*return(
            ObjectInfo(
                zeroNftId(), // nftId
                zeroNftId(), // parentNftId
                REGISTRY(),
                address(0), // objectAddress
                address(0), // initialOwner
                ""//data
            ),
            bytes("")
        );*/
    }

    function getNftId() external view override (IRegisterable_new) returns (NftId) {
        return _storage()._nftId;
    }

    // Registry specific functions

    function _registerContract(address owner, ObjectInfo memory info)
        internal
        returns(NftId nftId)
    {
        RegistryStorageV1 storage $ = _storage();

        require(info.initialOwner == owner, "ERROR:REG-015:NOT_OWNER");
        require(info.objectAddress != owner, "ERROR:REG-003:SELF_REGISTRATION");

        require($._nftIdByAddress[info.objectAddress].eqz(), "ERROR:REG-009:ALREADY_REGISTERED");
        require($._nftIdByAddress[owner].eqz(), "ERROR:REG-010:OWNER_REGISTERED");

        uint256 mintedTokenId = $._chainNft.mint(
            owner, 
            EMPTY_URI);
        nftId = toNftId(mintedTokenId);
        info.nftId = nftId;

        $._info[nftId] = info;
        $._nftIdByAddress[info.objectAddress] = nftId;
    }

    function _registerObject(address from, ObjectInfo memory info)
        internal 
        returns(NftId nftId)
    {
        RegistryStorageV1 storage $ = _storage();

        require($._nftIdByAddress[from].gtz(), "ERROR:REG-011:FROM_NOT_REGISTERED");
        require($._nftIdByAddress[from] == info.parentNftId, "ERROR:REG-017:FROM_NOT_PARENT");

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

        RegistryStorageV1 storage $ = _storage();

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

        RegistryStorageV1 storage $ = _storage();

        uint256 registryId = $._chainNftInternal.calculateTokenId(2);
        registryNftId = toNftId(registryId);

        // we're not the global registry
        if(registryId != $._chainNftInternal.GLOBAL_REGISTRY_ID()) {
            _registerGlobalRegistry();
        }

        $._chainNftInternal.mint($._protocolOwner, registryId);

        NftId parentNftId = block.chainid == 1 ?
                            toNftId($._chainNftInternal.PROTOCOL_NFT_ID()) :
                            toNftId($._chainNftInternal.GLOBAL_REGISTRY_ID());

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

        RegistryStorageV1 storage $ = _storage();

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

    // TODO check how usage of "$.data" influences gas costs 
    // IMPORTANT Every new version must implement this function
    // keep it private -> if unreachable from the next version then not included in its byte code
    // each version MUST use the same REGISTRY_LOCATION_V1, just change return type
    function _storage() private pure returns (RegistryStorageV1 storage $) {
        assembly {
            $.slot := REGISTRY_LOCATION_V1
        }
    }

    // From Versionable 

    /// @dev the protocol owner will get ownership of the
    // protocol nft and the global registry nft minted in this 
    // initializer function 
    function _initialize(bytes memory data)
        internal
        onlyInitializing
        virtual override
    {
        address protocolOwner = abi.decode(data, (address));
        RegistryStorageV1 storage $ = _storage();

        require(
            address($._chainNft) == address(0),
            "ERROR:REG-005:ALREADY_INITIALIZED"
        );
        $._protocolOwner = protocolOwner;

        // deploy NFT 
        $._chainNftInternal = new ChainNft(address(this));// adds 10kb to deployment size
        $._chainNft = IChainNft($._chainNftInternal);
        
        // use nft
        //_chainNft = IChainNft(nft);
        //_chainNftInternal = ChainNft(nft);

        // initial registry setup
        _registerProtocol();
        $._nftId = _registerRegistry();

        // set default allowance for registry owner
        approve($._nftId, SERVICE(), REGISTRY());
        approve($._nftId, TOKEN(), REGISTRY());
    }
}