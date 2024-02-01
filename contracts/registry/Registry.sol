// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;


import {NftId, toNftId, zeroNftId, NftIdLib} from "../types/NftId.sol";
import {Version, VersionPart, VersionLib, VersionPartLib} from "../types/Version.sol";
import {ObjectType, PROTOCOL, REGISTRY, TOKEN, SERVICE, INSTANCE, STAKE, PRODUCT, DISTRIBUTION, ORACLE, POOL, POLICY, BUNDLE} from "../types/ObjectType.sol";

import {IRegisterable} from "../shared/IRegisterable.sol";
import {IService} from "../shared/IService.sol";
import {ERC165} from "../shared/ERC165.sol";

import {ChainNft} from "./ChainNft.sol";
import {IRegistry} from "./IRegistry.sol";
import {IRegistryService} from "./IRegistryService.sol";
import {ITransferInterceptor} from "./ITransferInterceptor.sol";
import {RegistryServiceReleaseManager} from "./RegistryServiceReleaseManager.sol";

// IMPORTANT
// Each NFT minted by registry is accosiated with:
// 1) NFT owner
// 2) registred contract OR object stored in registered (parent) contract
// Four registration flows:
// 1) non IRegisterable address by registryOwner (TOKEN)
// 2) IRegisterable address by registryOwner (SERVICE)
// 3) IRegisterable address by approved service (INSTANCE, COMPONENT)
// 4) state object by approved service (POLICY, BUNDLE, STAKE)

contract Registry is
    ERC165,
    IRegistry
{
    uint256 public constant GIF_MAJOR_VERSION_AT_DEPLOYMENT = 3;
    address public constant NFT_LOCK_ADDRESS = address(0x1);
    uint256 public constant REGISTRY_TOKEN_SEQUENCE_ID = 2;
    uint256 public constant REGISTRY_SERVICE_TOKEN_SEQUENCE_ID = 3;
    string public constant EMPTY_URI = "";

    VersionPart internal _majorVersion;

    mapping(NftId nftId => ObjectInfo info) internal _info;
    mapping(address object => NftId nftId) internal _nftIdByAddress;

    mapping(ObjectType objectType => mapping(
            ObjectType parentType => bool)) internal _isValidContractCombination;

    mapping(ObjectType objectType => mapping(
            ObjectType parentType => bool)) internal _isValidObjectCombination;

    mapping(VersionPart majorVersion => mapping(
            ObjectType serviceType=> address service)) internal _service;

    NftId internal _registryNftId;
    NftId internal _serviceNftId; // set in stone upon registry creation
    ChainNft internal _chainNft;


    modifier onlyOwner() {
        if(msg.sender != getOwner()) {
            revert NotOwner(msg.sender);
        }
        _;
    }

    modifier onlyRegistryService() {
        if(msg.sender != _info[_serviceNftId].objectAddress) {
            revert NotRegistryService();
        }
        _;
    }

    constructor(address registryOwner, VersionPart majorVersion)
    {
        require(registryOwner > address(0), "Registry: registry owner is 0");

        // major version at constructor time
        _majorVersion = VersionLib.toVersionPart(GIF_MAJOR_VERSION_AT_DEPLOYMENT);
        emit LogInitialMajorVersionSet(_majorVersion);

        // deploy NFT 
        _chainNft = new ChainNft(address(this));// adds 10kb to deployment size

        // initial registry setup
        _registerProtocol();
        _registerRegistry(registryOwner);
        _registerRegistryService(registryOwner);

        // set object parent relations
        _setupValidObjectParentCombinations();

        _registerInterface(type(IRegistry).interfaceId);
    }

    // from IRegistry

    /// @dev latest GIF release version 
    function setMajorVersion(VersionPart newMajorVersion)
        external
        onlyOwner
    {
        // ensure major version increments is one
        uint256 oldMax = _majorVersion.toInt();
        uint256 newMax = newMajorVersion.toInt();
        if (newMax <= oldMax || newMax - oldMax != 1) {
            revert MajorVersionMaxIncreaseInvalid(newMajorVersion, _majorVersion);
        }

        _majorVersion = newMajorVersion;
        emit LogMajorVersionSet(_majorVersion);
    }

    /// @dev registry protects only against tampering existing records, registering with invalid types pairs and 0 parent address
    // TODO service registration means its approval for some type?
    // TODO registration of precompile addresses
    function register(ObjectInfo memory info)
        external
        onlyRegistryService
        returns(NftId nftId)
    {
        ObjectType objectType = info.objectType;
        NftId parentNftId = info.parentNftId;
        ObjectInfo memory parentInfo = _info[parentNftId];
        ObjectType parentType = parentInfo.objectType; // see function header
        address parentAddress = parentInfo.objectAddress;

        // parent is contract -> need to check? -> check before minting
        // special case: global registry nft as parent when not on mainnet -> global registry address is 0
        // special case: when parentNftId == _chainNft.mint(), check for zero parent address before mint
        // special case: when parentNftId == _chainNft.mint() && objectAddress == initialOwner
        if(parentAddress == address(0)) {
            revert ZeroParentAddress();
        }

        address interceptor = _getInterceptor(info.isInterceptor, info.objectAddress, parentInfo.isInterceptor, parentAddress);

        // TODO does external call
        uint256 mintedTokenId = _chainNft.mint(
            info.initialOwner,
            interceptor,
            EMPTY_URI);
        nftId = toNftId(mintedTokenId);

        // TODO move nftId out of info struct
        // getters by nftId -> return struct without nftId
        // getters by address -> return nftId AND struct
        info.nftId = nftId;
        _info[nftId] = info;

        if(info.objectAddress > address(0)) 
        {
            // TODO if need to add types latter -> at least call this check from registry service
            // parent is registered + object-parent types are valid
            if(_isValidContractCombination[objectType][parentType] == false) {
                revert InvalidTypesCombination(objectType, parentType);
            }

            address contractAddress = info.objectAddress;

            if(_nftIdByAddress[contractAddress].gtz()) { 
                revert ContractAlreadyRegistered(contractAddress);
            }

            _nftIdByAddress[contractAddress] = nftId;

            // special case
            if(objectType == SERVICE()) {
                _registerService(info);
            }
        }
        else
        {
            if(_isValidObjectCombination[objectType][parentType] == false) {
                revert InvalidTypesCombination(objectType, parentType);
            }
        }

        emit LogRegistration(info);
    }
    /// @dev earliest GIF major version 
    function getMajorVersionMin() external view returns (VersionPart) {
        return VersionLib.toVersionPart(GIF_MAJOR_VERSION_AT_DEPLOYMENT);
    }

    // TODO make distinction between active an not yet active version
    // need to be thought trough, not yet clear if necessary
    // need to answer question: what is the latest version during the upgrade process?
    // likely setting up a new gif version does not fit into a single tx
    // in this case we might want to have a period where the latest version is
    // in the process of being set up while the latest active version is 1 major release smaller
    /// @dev latest GIF major version (might not yet be active)
    function getMajorVersionMax() external view returns (VersionPart) {
        return _majorVersion;
    }

    /// @dev latest active GIF release version 
    function getMajorVersion() external view returns (VersionPart) { 
        return _majorVersion;
    }

    function getObjectCount() external view override returns (uint256) {
        return _chainNft.totalSupply();
    }

    function getNftId() external view returns (NftId nftId) {
        return _registryNftId;
    }

    function getNftId(address object) external view override returns (NftId id) {
        return _nftIdByAddress[object];
    }

    function ownerOf(NftId nftId) public view override returns (address) {
        return _chainNft.ownerOf(nftId.toInt());
    }

    function ownerOf(address contractAddress) public view returns (address) {
        return _chainNft.ownerOf(_nftIdByAddress[contractAddress].toInt());
    }

    function getObjectInfo(NftId nftId) external view override returns (ObjectInfo memory) {
        return _info[nftId];
    }

    function getObjectInfo(address object) external view override returns (ObjectInfo memory) {
        return _info[_nftIdByAddress[object]];
    }

    function isRegistered(NftId nftId) public view override returns (bool) {
        return _info[nftId].objectType.gtz();
    }

    function isRegistered(address object) external view override returns (bool) {
        return _nftIdByAddress[object].gtz();
    }

    // special case to retrive a gif service
    function getServiceAddress(
        ObjectType serviceType, 
        VersionPart releaseVersion
    ) external view returns (address)
    {
        return _service[releaseVersion][serviceType];
    }

    function getChainNft() external view override returns (ChainNft) {
        return _chainNft;
    }

    function getOwner() public view returns (address owner) {
        return ownerOf(address(this));
    }

    // Internals

    function _registerService(ObjectInfo memory info)
        internal
    {
        (
            ObjectType serviceType, // corresponds to unique serviceRole
            VersionPart majorVersion
        ) = abi.decode(info.data, (ObjectType, VersionPart));

        // ensures consistency of service.getVersion() and majorVersion here
        if(majorVersion != _majorVersion) {
            revert InvalidServiceVersion(majorVersion);
        }

        if(_service[majorVersion][serviceType] > address(0)) {
            revert ServiceAlreadyRegistered(serviceType, majorVersion);
        }

        _service[majorVersion][serviceType] = info.objectAddress;

        emit LogServiceRegistration(majorVersion, serviceType); 
    }

    /// @dev obtain interceptor address for this nft if applicable, address(0) otherwise
    function _getInterceptor(
        bool isInterceptor, 
        address objectAddress,
        bool parentIsInterceptor,
        address parentObjectAddress
    )
        internal 
        view 
        returns (address interceptor) 
    {
        if (objectAddress == address(0)) {
            if (parentIsInterceptor) {
                return parentObjectAddress;
            } else {
                return address(0);
            }
        }

        if (isInterceptor) {
            return objectAddress;
        }

        return address(0);
    }

    // Internals called only in constructor

    /// @dev protocol registration used to anchor the dip ecosystem relations
    function _registerProtocol() 
        private
    {
        uint256 protocolId = _chainNft.PROTOCOL_NFT_ID();
        NftId protocolNftId = toNftId(protocolId);

        _info[protocolNftId] = ObjectInfo({
            nftId: protocolNftId,
            parentNftId: zeroNftId(),
            objectType: PROTOCOL(),
            isInterceptor: false, 
            objectAddress: address(0),
            initialOwner: NFT_LOCK_ADDRESS,
            data: ""
        });

        _chainNft.mint(NFT_LOCK_ADDRESS, protocolId);
    }

    /// @dev registry registration
    /// might also register the global registry when not on mainnet
    function _registerRegistry() 
        private
    {
        uint256 registryId = _chainNft.calculateTokenId(REGISTRY_TOKEN_SEQUENCE_ID);
        NftId registryNftId = toNftId(registryId);
        NftId parentNftId;

        if(registryId != _chainNft.GLOBAL_REGISTRY_ID()) 
        {// we're not the global registry
            _registerGlobalRegistry();
            parentNftId = toNftId(_chainNft.GLOBAL_REGISTRY_ID());
        }
        else 
        {// we are global registry
            parentNftId = toNftId(_chainNft.PROTOCOL_NFT_ID());
        }

        _info[registryNftId] = ObjectInfo({
            nftId: registryNftId,
            parentNftId: parentNftId,
            objectType: REGISTRY(),
            isInterceptor: false,
            objectAddress: address(this), 
            initialOwner: NFT_LOCK_ADDRESS,
            data: "" 
        });
        _nftIdByAddress[address(this)] = registryNftId;
        _registryNftId = registryNftId;

        _chainNft.mint(NFT_LOCK_ADDRESS, registryId);
    }

    /// @dev global registry registration for non mainnet registries
    function _registerGlobalRegistry() 
        private
    {
        uint256 globalRegistryId = _chainNft.GLOBAL_REGISTRY_ID();
        NftId globalRegistryNftId = toNftId(globalRegistryId);

        _info[globalRegistryNftId] = ObjectInfo({
            nftId: globalRegistryNftId,
            parentNftId: toNftId(_chainNft.PROTOCOL_NFT_ID()),
            objectType: REGISTRY(),
            isInterceptor: false,
            objectAddress: address(0),
            initialOwner: NFT_LOCK_ADDRESS,
            data: ""
        });

        _chainNft.mint(NFT_LOCK_ADDRESS, globalRegistryId);
    }

    function _registerRegistryService(address registryOwner, VersionPart initialVersion)
        internal
    {
        uint256 serviceId = _chainNft.calculateTokenId(REGISTRY_SERVICE_TOKEN_SEQUENCE_ID);
        NftId serviceNftId = toNftId(serviceId);        

        _info[serviceNftId] = ObjectInfo({
            nftId: serviceNftId,
            parentNftId: _registryNftId,
            objectType: SERVICE(),
            isInterceptor: false,
            objectAddress: msg.sender, // service deploys registry
            initialOwner: registryOwner,
            data: abi.encode(SERVICE(), initialVersion) // TODO this parameters can change with upgrade -> registry must keep only constants
        });

        _nftIdByAddress[msg.sender] = serviceNftId;

        _service[initialVersion][SERVICE()] = msg.sender; // -> serviceNftId;

        _chainNft.mint(registryOwner, serviceId);
    }

    /// @dev defines which object - parent types relations are allowed to register
    // IMPORTANT: 
    // 1) EACH object type MUST have only one parent type across ALL mappings
    // 2) DO NOT use object type (e.g. POLCY, BUNDLE, STAKE) as parent type
    // 3) DO NOT use REGISTRY as object type
    // 2) DO NOT use PROTOCOL and "zeroObjectType"
    function _setupValidObjectParentCombinations() 
        private 
    {
        // registry as parent, ONLY registry owner
        _isValidContractCombination[TOKEN()][REGISTRY()] = true;
        _isValidContractCombination[SERVICE()][REGISTRY()] = true;

        // registry as parent, ONLY approved
        _isValidContractCombination[INSTANCE()][REGISTRY()] = true;

        // instance as parent, ONLY approved
        _isValidContractCombination[PRODUCT()][INSTANCE()] = true;
        _isValidContractCombination[DISTRIBUTION()][INSTANCE()] = true;
        _isValidContractCombination[ORACLE()][INSTANCE()] = true;
        _isValidContractCombination[POOL()][INSTANCE()] = true;

        // product as parent, ONLY approved
        _isValidObjectCombination[POLICY()][PRODUCT()] = true;

        // pool as parent, ONLY approved
        _isValidObjectCombination[BUNDLE()][POOL()] = true;
        _isValidObjectCombination[STAKE()][POOL()] = true;
    }
}
