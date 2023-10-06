// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegisterable} from "../shared/IRegisterable.sol";
import {IService} from "../instance/base/IService.sol";

import {IChainNft} from "./IChainNft.sol";
import {ChainNft} from "./ChainNft.sol";
import {IRegistry} from "./IRegistry.sol";
import {NftId, toNftId, zeroNftId, NftIdLib} from "../types/NftId.sol";
import {VersionPart} from "../types/Version.sol";
import {ObjectType, PROTOCOL, REGISTRY, TOKEN, SERVICE, INSTANCE, STAKE, PRODUCT, DISTRIBUTOR, ORACLE, POOL, POLICY, BUNDLE} from "../types/ObjectType.sol";

// TODO make registry upgradable
contract Registry is
    IRegisterable,
    IRegistry
{
    using NftIdLib for NftId;

    string public constant EMPTY_URI = "";

    mapping(NftId nftId => ObjectInfo info) private _info;
    mapping(address object => NftId nftId) private _nftIdByAddress;
    mapping(NftId registrator => mapping(
            ObjectType parentType => mapping(
            ObjectType objectType => bool))) private _allowed;

    mapping(NftId nftId => string stringValue) private _string;
    mapping(bytes32 serviceNameHash => mapping(VersionPart majorVersion => address service)) _service;

    NftId private _nftId;
    ChainNft private _chainNft;
    ChainNft private _chainNftInternal;

    // @dev will own protocol nft and registry nft(s) minted during initialize
    address private _protocolOwner;

    modifier onlyAllowedForContract(ObjectInfo memory info) {
        NftId registrator = _nftIdByAddress[msg.sender];
        ObjectType objectType = info.objectType;
        ObjectType parentType = _info[info.parentNftId].objectType;
        require(_allowed[registrator][objectType][parentType] == true, "ERROR:REG-001:NOT_ALLOWED");
        _;
    }
    modifier onlyAllowedForOwner(ObjectInfo memory info) {
        ObjectType objectType = info.objectType;
        ObjectType parentType = _info[info.parentNftId].objectType;
        require(_allowed[_nftId][objectType][parentType] == true, "ERROR:REG-002:NOT_ALLOWED");
        require(info.objectAddress != msg.sender, "ERROR:REG-003:NOT_ALLOWED");
        _;
    }
    modifier onlyOwner() {
        require(getOwner() == msg.sender, "ERROR:REG-004:NOT_OWNER");
        _;
    }
    // TODO refactor once registry becomes upgradable
    // @Dev the protocol owner will get ownership of the
    // protocol nft and the global registry nft minted in this 
    // initializer function 
    function initialize(address protocolOwner) public {
        require(
            address(_chainNft) == address(0),
            "ERROR:REG-005:ALREADY_INITIALIZED"
        );
        _protocolOwner = protocolOwner;

        _chainNft = new ChainNft(address(this));
        _chainNftInternal = ChainNft(_chainNft);

        // initial registry setup
        _registerProtocol();
        _nftId = _registerRegistry();

        // set allowance for registry owner
        approve(_nftId, SERVICE(), REGISTRY());
        approve(_nftId, TOKEN(), REGISTRY());
    }

    // @dev owner either registers contracts or objects, but never both
    function register(ObjectInfo memory info) 
        public
        override
        onlyOwner() 
        onlyAllowedForOwner(info)
        returns (NftId nftId)
    {
        return _registerContract(msg.sender, info);
    }
    // @dev give approval for registered contract or owner
    function approve(
        NftId nftId,
        ObjectType object,
        ObjectType parent
    ) 
        public
        override
        onlyOwner()
    {
        if(nftId != _nftId) {
            require(
                _info[nftId].objectType == SERVICE(),
                 "ERROR:REG-006:NOT_SERVICE"
            );
            address objectAddress = _info[nftId].objectAddress;
            require(
                _nftIdByAddress[objectAddress].gtz(),
                "ERROR:REG-007:NOT_REGISTERED");
        }

        require(object.gtz() && parent.gtz(),
                "ERROR:REG-012:NOT_REGISTERED");
        
        _allowed[nftId][object][parent] = true;
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
        return _allowed[nftId][object][parent];
    }

    function registerFrom(address from, ObjectInfo memory info)
        external
        onlyAllowedForContract(info)
        returns(NftId nftId)
    {
        require(from != msg.sender, "ERROR:REG-008:NOT_ALLOWED");

        if(info.objectAddress == address(0)) {
            return _registerObject(from, info);// from is registred storage contract
        } else {
            return _registerContract(from, info);// from is contract owner
        }
    }

    function _registerContract(address owner, ObjectInfo memory info)
        internal
        returns(NftId nftId)
    {
        require(_nftIdByAddress[info.objectAddress].eqz(), "ERROR:REG-009:ALREADY_REGISTERED");
        require(_nftIdByAddress[owner].eqz(), "ERROR:REG-010:OWNER_REGISTERED");
        require(info.initialOwner == owner, "ERROR:REG-015:NOT_OWNER");

        uint256 mintedTokenId = _chainNft.mint(
            owner, 
            EMPTY_URI);
        nftId = toNftId(mintedTokenId);
        info.nftId = nftId;

        _info[nftId] = info;
        _nftIdByAddress[info.objectAddress] = nftId;

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
            _string[nftId] = serviceName;

            require(
                _service[serviceNameHash][majorVersion] == address(0),
                "ERROR:REG-014:ALREADY_REGISTERED"
            );
            _service[serviceNameHash][majorVersion] = info.objectAddress;
        }
    }
    function _registerObject(address from, ObjectInfo memory info)
        internal 
        returns(NftId nftId)
    {
        require(_nftIdByAddress[from].gtz(), "ERROR:REG-011:NOT_REGISTERED");
        require(info.parentNftId == _nftIdByAddress[from], "NOT_PARENT");

        uint256 mintedTokenId = _chainNft.mint(
            info.initialOwner,
            EMPTY_URI);
        nftId = toNftId(mintedTokenId);
        info.nftId = nftId;
        _info[nftId] = info;
    }

    function getObjectCount() external view override returns (uint256) {
        return _chainNft.totalSupply();
    }

    function getNftId(
        address object
    ) external view override returns (NftId id) {
        return _nftIdByAddress[object];
    }

    function isRegistered(
        NftId nftId
    ) public view override returns (bool) {
        return _info[nftId].objectType.gtz();
    }

    function isRegistered(
        address object
    ) external view override returns (bool) {
        return _nftIdByAddress[object].gtz();
    }

    function getObjectInfo(
        NftId nftId
    ) external view override returns (ObjectInfo memory info) {
        return _info[nftId];
    }

    function getObjectInfo(
        address object
    ) external view override returns (ObjectInfo memory info) {
        return _info[_nftIdByAddress[object]];
    }

    function getName(
        NftId nftId
    ) external view returns (string memory name) {
        return _string[nftId];
    }

    function ownerOf(NftId nftId) public view override returns (address) {
        return _chainNft.ownerOf(nftId.toInt());
    }

    function ownerOf(address contractAddress) public view returns (address) {
        return _chainNft.ownerOf(_nftIdByAddress[contractAddress].toInt());
    }

    function getChainNft() external view override returns (IChainNft) {
        return _chainNft;
    }

    // special case to retrive a gif service
    function getServiceAddress(string memory serviceName, VersionPart majorVersion) external view override returns (address serviceAddress) {
        bytes32 serviceNameHash = keccak256(abi.encode(serviceName));
        return _service[serviceNameHash][majorVersion];
    }

    // from IERC165
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IRegistry).interfaceId;
    }

    // from IRegistryLinked
    function getRegistry() external view override returns (IRegistry registry) {
        return this;
    }

    // from IRegisterable
    function getInfo() public view override returns (IRegistry.ObjectInfo memory info) {
        return _info[_nftId];
    }

    function getInitialInfo() external view override returns (IRegistry.ObjectInfo memory) {
        return _info[_nftId];
    }
    function getOwner() public view override returns (address owner) {
        return ownerOf(address(this));
    }

    function getNftId() external view override (IRegisterable) returns (NftId nftId) {
        return _nftId;
    }

    // registry specific functions
    function getProtocolOwner() external view override returns (address) {
        return _protocolOwner;
    }

    /// @dev protocol registration used to anchor the dip ecosystem relations
    function _registerProtocol() virtual internal {
        uint256 protocolId = _chainNftInternal.PROTOCOL_NFT_ID();
        NftId protocolNftId = toNftId(protocolId);

        _chainNftInternal.mint(_protocolOwner, protocolId);

         _info[protocolNftId] = ObjectInfo(
            protocolNftId,
            zeroNftId(), // parent
            PROTOCOL(),
            address(0),
            _protocolOwner,
            ""
         );
    }
    /// @dev registry registration
    /// might also register the global registry when not on mainnet
    function _registerRegistry() virtual internal returns (NftId registryNftId) {
        uint256 registryId = _chainNftInternal.calculateTokenId(2);
        registryNftId = toNftId(registryId);

        // we're not the global registry
        if(registryId != _chainNftInternal.GLOBAL_REGISTRY_ID()) {
            _registerGlobalRegistry();
        }

        _chainNftInternal.mint(_protocolOwner, registryId);

        NftId parentNftId = block.chainid == 1 ?
                            toNftId(_chainNftInternal.PROTOCOL_NFT_ID()) :
                            toNftId(_chainNftInternal.GLOBAL_REGISTRY_ID());

        _info[registryNftId] = ObjectInfo(
            registryNftId,
            parentNftId,
            REGISTRY(),
            address(this), 
            _protocolOwner,
            "" 
         );
        _nftIdByAddress[address(this)] = registryNftId;
    }


    /// @dev global registry registration for non mainnet registries
    function _registerGlobalRegistry() virtual internal {
        uint256 globalRegistryId = _chainNftInternal.GLOBAL_REGISTRY_ID();
        _chainNftInternal.mint(_protocolOwner, globalRegistryId);

        NftId globalRegistryNftId = toNftId(globalRegistryId);
        ObjectInfo memory globalRegistryInfo = ObjectInfo(
            globalRegistryNftId,
            toNftId(_chainNftInternal.PROTOCOL_NFT_ID()),
            REGISTRY(),
            address(0), // contract address
            _protocolOwner,
            "" // data
        );

        _info[globalRegistryNftId] = globalRegistryInfo;
    }
}