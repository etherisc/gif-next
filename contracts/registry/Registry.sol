// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegisterable} from "../shared/IRegisterable.sol";
import {IService} from "../instance/service/IService.sol";

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
    mapping(NftId nftId => address owner) private _owner;
    mapping(address object => NftId nftId) private _nftIdByAddress;
    mapping(ObjectType objectType => bool) private _isValidType;
    mapping(ObjectType objectType => mapping(ObjectType objectParentType => bool)) private _isValidParentType;

    mapping(NftId nftId => string stringValue) private _string;
    mapping(bytes32 serviceNameHash => mapping(VersionPart majorVersion => address service)) _service;

    NftId private _nftId;
    IChainNft private _chainNft;
    ChainNft private _chainNftInternal;
    address private _initialOwner;

    // TODO refactor once registry becomes upgradable
    function initialize(address chainNft) public {
        require(
            address(_chainNft) == address(0),
            "ERROR:REG-001:ALREADY_INITIALIZED"
        );

        _initialOwner = msg.sender;
        _chainNft = IChainNft(chainNft);
        _chainNftInternal = ChainNft(chainNft);

        // initial registry setup
        _registerProtocol();
        _nftId = _registerRegistry();

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
        require(
            _nftIdByAddress[objectAddress].eqz(),
            "ERROR:REG-002:ALREADY_REGISTERED"
        );

        IRegisterable registerable = IRegisterable(objectAddress);
        require(
            registerable.supportsInterface(type(IRegisterable).interfaceId),
            "ERROR:REG-003:NOT_REGISTERABLE"
        );

        ObjectType objectType = registerable.getType();
        require(
            _isValidType[objectType],
            "ERROR:REG-004:TYPE_INVALID"
        );

        NftId parentNftId = registerable.getParentNftId();
        require(
            isRegistered(parentNftId),
            "ERROR:REG-005:PARENT_NOT_REGISTERED"
        );

        require(
            _isValidParentType[objectType][_info[parentNftId].objectType],
            "ERROR:REG-006:PARENT_TYPE_INVALID"
        );

        // also check that nftId and parentNFtId are on the same chain if applicable

        // nft minting
        uint256 mintedTokenId = _chainNft.mint(
            registerable.getInitialOwner(),
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
            _string[nftId] = serviceName;

            require(
                _service[serviceNameHash][majorVersion] == address(0),
                "ERROR:REG-008:ALREADY_REGISTERED"
            );
            _service[serviceNameHash][majorVersion] = objectAddress;
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
        // TODO add more validation
        require(
            objectType == POLICY() || objectType == BUNDLE(),
            "ERROR:REG-010:TYPE_INVALID"
        );

        uint256 mintedTokenId = _chainNft.mint(initialOwner, EMPTY_URI);
        nftId = toNftId(mintedTokenId);

        ObjectInfo memory info = ObjectInfo(
            nftId,
            parentNftId,
            objectType,
            address(0),
            initialOwner,
            data
        );

        _info[nftId] = info;

        // add logging
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

    function getName(
        NftId nftId
    ) external view returns (string memory name) {
        return _string[nftId];
    }

    function getOwner(NftId nftId) external view override returns (address) {
        return _chainNft.ownerOf(nftId.toInt());
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
    function register() external pure override returns (NftId nftId) {
        return zeroNftId();
    }

    function getType() external pure override returns (ObjectType objectType) {
        return REGISTRY();
    }

    function getInitialOwner() external view override returns (address) {
        return _initialOwner;
    }


    function getOwner() public view override returns (address owner) {
        owner = this.getOwner(_nftId);
        return owner != address(0) ? owner : _initialOwner;
    }

    function getNftId() external view override returns (NftId nftId) {
        return _nftId;
    }

    function getParentNftId() external view returns (NftId nftId) {
        // we're the global registry
        if(block.chainid == 1) {
            return toNftId(_chainNftInternal.PROTOCOL_NFT_ID());
        }
        else {
            return toNftId(_chainNftInternal.GLOBAL_REGISTRY_ID());
        }
    }

    function getData() external pure returns (bytes memory data) {
        return "";
    }

    function requireSenderIsOwner() external view override returns (bool senderIsOwner) {
        require(
            msg.sender == getOwner(),
            "ERROR:REG-020:NOT_OWNER"
        );

        return true;
    }

    /// @dev defines which types are allowed to register
    function _setupValidTypes() internal {
        _isValidType[REGISTRY()] = true; // only for global registry 
        _isValidType[TOKEN()] = true;
        _isValidType[SERVICE()] = true;
        _isValidType[INSTANCE()] = true;
        _isValidType[STAKE()] = true;
        _isValidType[PRODUCT()] = true;
        _isValidType[ORACLE()] = true;
        _isValidType[POOL()] = true;
        _isValidType[POLICY()] = true;
        _isValidType[BUNDLE()] = true;
    }

    /// @dev defines which types - parent type relations are allowed to register
    function _setupValidParentTypes() internal {
        // registry as parent
        _isValidParentType[TOKEN()][REGISTRY()] = true;
        _isValidParentType[SERVICE()][REGISTRY()] = true;
        _isValidParentType[INSTANCE()][REGISTRY()] = true;

        // instance as parent
        _isValidParentType[PRODUCT()][INSTANCE()] = true;
        _isValidParentType[DISTRIBUTOR()][INSTANCE()] = true;
        _isValidParentType[ORACLE()][INSTANCE()] = true;
        _isValidParentType[POOL()][INSTANCE()] = true;

        // product as parent
        _isValidParentType[POLICY()][PRODUCT()] = true;

        // pool as parent
        _isValidParentType[BUNDLE()][POOL()] = true;
        _isValidParentType[STAKE()][POOL()] = true;
    }

    /// @dev protocol registration used to anchor the dip ecosystem relations
    function _registerProtocol() virtual internal {
        uint256 protocolId = _chainNftInternal.PROTOCOL_NFT_ID();
        _chainNftInternal.mint(_initialOwner, protocolId);

        NftId protocolNftid = toNftId(protocolId);
        ObjectInfo memory protocolInfo = ObjectInfo(
            protocolNftid,
            zeroNftId(), // parent nft id
            PROTOCOL(),
            address(0), // contract address
            _initialOwner,
            "" // data
        );

        _info[protocolNftid] = protocolInfo;
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

        _chainNftInternal.mint(_initialOwner, registryId);
        _registerObjectInfo(this, registryNftId);
    }


    /// @dev global registry registration for non mainnet registries
    function _registerGlobalRegistry() virtual internal {
        uint256 globalRegistryId = _chainNftInternal.GLOBAL_REGISTRY_ID();
        _chainNftInternal.mint(_initialOwner, globalRegistryId);

        NftId globalRegistryNftId = toNftId(globalRegistryId);
        ObjectInfo memory globalRegistryInfo = ObjectInfo(
            globalRegistryNftId,
            toNftId(_chainNftInternal.PROTOCOL_NFT_ID()),
            REGISTRY(),
            address(0), // contract address
            _initialOwner,
            "" // data
        );

        _info[globalRegistryNftId] = globalRegistryInfo;
    }


    function _registerObjectInfo(
        IRegisterable registerable,
        NftId nftId
    ) internal virtual {
        address objectAddress = address(registerable);
        ObjectInfo memory info = ObjectInfo(
            nftId,
            registerable.getParentNftId(),
            registerable.getType(),
            objectAddress,
            registerable.getInitialOwner(),
            registerable.getData()
        );

        _info[nftId] = info;
        _nftIdByAddress[objectAddress] = nftId;

        // add logging
    }

}
