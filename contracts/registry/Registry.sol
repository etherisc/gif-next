// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {NftId, toNftId, zeroNftId} from "../types/NftId.sol";
import {VersionPart} from "../types/Version.sol";
import {ObjectType, PROTOCOL, REGISTRY, TOKEN, SERVICE, INSTANCE, STAKE, PRODUCT, DISTRIBUTION, DISTRIBUTOR, ORACLE, POOL, POLICY, BUNDLE} from "../types/ObjectType.sol";

import {ChainNft} from "./ChainNft.sol";
import {IRegistry} from "./IRegistry.sol";
import {ReleaseManager} from "./ReleaseManager.sol";

// IMPORTANT
// Each NFT minted by registry is accosiated with:
// 1) NFT owner
// 2) registred contract OR object stored in registered (parent) contract
// Four registration flows:
// 1) IService address by release manager (SERVICE of domain SERVICE aka registry service aka release creation)
// 2) IService address by release manager (SERVICE of domain !SERVICE aka regular service)
// 3) IRegisterable address by regular service (INSTANCE, PRODUCT, POOL, DISTRIBUTION, ORACLE)
// 4) state object by regular service (POLICY, BUNDLE, STAKE)

contract Registry is
    IRegistry
{
    address public constant NFT_LOCK_ADDRESS = address(0x1);
    uint256 public constant REGISTRY_TOKEN_SEQUENCE_ID = 2;
    string public constant EMPTY_URI = "";

    mapping(NftId nftId => ObjectInfo info) private _info;
    mapping(address object => NftId nftId) private _nftIdByAddress;

    mapping(VersionPart version => mapping(ObjectType serviceDomain => address)) private _service;

    mapping(ObjectType objectType => bool) private _coreTypes;

    mapping(ObjectType objectType => mapping(
            ObjectType parentType => bool)) private _coreContractCombinations;

    mapping(ObjectType objectType => mapping(
            ObjectType parentType => bool)) private _coreObjectCombinations;

    NftId private _registryNftId;
    ChainNft private _chainNft;

    ReleaseManager private _releaseManager;

    modifier onlyRegistryService() {
        if(!_releaseManager.isActiveRegistryService(msg.sender)) {
            revert CallerNotRegistryService();
        }
        _;
    }

    modifier onlyReleaseManager() {
        if(msg.sender != address(_releaseManager)) {
            revert CallerNotReleaseManager();
        }
        _;
    }

    constructor()
    {
        _releaseManager = ReleaseManager(msg.sender);

        // deploy NFT 
        _chainNft = new ChainNft(address(this));

        // initial registry setup
        _registerProtocol();
        _registerRegistry();

        // set object types and object parent relations
        _setupValidCoreTypesAndCombinations();
    }

    function registerService(
        ObjectInfo memory info, 
        VersionPart version, 
        ObjectType domain
    )
        external
        onlyReleaseManager
        returns(NftId nftId)
    {
        /* must be guaranteed by release manager
        if(info.objectType != SERVICE()) {
            revert();
        }
        if(info.parentType != REGISTRY()) {
            revert();
        }        
        info.initialOwner == NFT_LOCK_ADDRESS <- if services are access managed
        */

        if(_service[version][domain] > address(0)) {
            revert ServiceAlreadyRegistered(info.objectAddress);
        }

        _service[version][domain] = info.objectAddress; // nftId;

        nftId = _register(info);

        emit LogServiceRegistration(version, domain);
    }

    function register(ObjectInfo memory info)
        external
        onlyRegistryService
        returns(NftId nftId)
    {
        ObjectType objectType = info.objectType;
        ObjectType parentType = _info[info.parentNftId].objectType;

        // TODO do not need it here -> SERVICE is no longer part of _coreContractCombinations
        // no service registrations
        if(objectType == SERVICE()) {
            revert ServiceRegistration();
        }

        // only valid core types combinations
        if(info.objectAddress == address(0)) 
        {
            if(_coreObjectCombinations[objectType][parentType] == false) {
                revert InvalidTypesCombination(objectType, parentType);
            }
        }
        else
        {
            if(_coreContractCombinations[objectType][parentType] == false) {
                revert InvalidTypesCombination(objectType, parentType);
            }
        }

        nftId = _register(info);
    }

    function registerWithCustomType(ObjectInfo memory info)
        external
        onlyRegistryService
        returns(NftId nftId)
    {
        ObjectType objectType = info.objectType;
        ObjectType parentType = _info[info.parentNftId].objectType;

        if(_coreTypes[objectType]) {
            revert CoreTypeRegistration();
        }

        if(

            parentType == PROTOCOL() ||
            parentType == REGISTRY() ||
            parentType == SERVICE()
        ) {
            revert InvalidTypesCombination(objectType, parentType);
        }

        _register(info);
    }


    /// @dev earliest GIF major version 
    function getInitialVersion() external view returns (VersionPart) {
        return _releaseManager.getInitialVersion();
    }

    // TODO make distinction between active an not yet active version
    // need to be thought trough, not yet clear if necessary
    // need to answer question: what is the latest version during the upgrade process?
    // likely setting up a new gif version does not fit into a single tx
    // in this case we might want to have a period where the latest version is
    // in the process of being set up while the latest active version is 1 major release smaller
    /// @dev latest GIF major version (might not yet be active)
    function getNextVersion() external view returns (VersionPart) {
        return _releaseManager.getNextVersion();
    }

    /// @dev latest active GIF release version 
    function getLatestVersion() external view returns (VersionPart) { 
        return _releaseManager.getLatestVersion();
    }

    function getReleaseInfo(VersionPart version) external view returns (ReleaseInfo memory) {
        return _releaseManager.getReleaseInfo(version);
    }

    function getObjectCount() external view returns (uint256) {
        return _chainNft.totalSupply();
    }

    function getReleaseManagerAddress() external view returns (address) {
        return address(_releaseManager);
    }

    function getNftId() external view returns (NftId nftId) {
        return _registryNftId;
    }

    function getNftId(address object) external view returns (NftId id) {
        return _nftIdByAddress[object];
    }

    function ownerOf(NftId nftId) public view returns (address) {
        return _chainNft.ownerOf(nftId.toInt());
    }

    function ownerOf(address contractAddress) public view returns (address) {
        return _chainNft.ownerOf(_nftIdByAddress[contractAddress].toInt());
    }

    function getObjectInfo(NftId nftId) external view returns (ObjectInfo memory) {
        return _info[nftId];
    }

    function getObjectInfo(address object) external view returns (ObjectInfo memory) {
        return _info[_nftIdByAddress[object]];
    }

    function isRegistered(NftId nftId) public view returns (bool) {
        return _info[nftId].objectType.gtz();
    }

    function isRegistered(address object) external view returns (bool) {
        return _nftIdByAddress[object].gtz();
    }

    function isRegisteredService(address object) external view returns (bool) {
        return _info[_nftIdByAddress[object]].objectType == SERVICE();
    }

    function isRegisteredComponent(address object) external view returns (bool) {
        NftId objectParentNftId = _info[_nftIdByAddress[object]].parentNftId;
        return _info[objectParentNftId].objectType == INSTANCE();
    }

    function isValidRelease(VersionPart version) external view returns (bool)
    {
        return _releaseManager.isValidRelease(version);
    }

    function getServiceAddress(
        ObjectType serviceDomain, 
        VersionPart releaseVersion
    ) external view returns (address service)
    {
        // TODO how can I get service address while release is not validated/activated ?!! -> user will check validity of release on its own
        //if(_releaseManager.isValidRelease(releaseVersion)) { 
            service =  _service[releaseVersion][serviceDomain]; 
        //}
    }

    function getChainNftAddress() external view override returns (address) {
        return address(_chainNft);
    }

    function getOwner() public view returns (address owner) {
        return ownerOf(address(this));
    }

    // IERC165

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        if(interfaceId == type(IERC165).interfaceId || interfaceId == type(IRegistry).interfaceId) {
            return true;
        }

        return false;
    }

    // Internals

    /// @dev registry protects only against tampering existing records, registering with invalid types pairs and 0 parent address
    // TODO registration of precompile addresses
    function _register(ObjectInfo memory info)
        internal
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
        // compute next nftId, do all checks and stores, mint() at most end...
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
            address contractAddress = info.objectAddress;

            if(_nftIdByAddress[contractAddress].gtz()) { 
                revert ContractAlreadyRegistered(contractAddress);
            }

            _nftIdByAddress[contractAddress] = nftId;
        }

        emit LogRegistration(nftId, parentNftId, objectType, info.isInterceptor, info.objectAddress, info.initialOwner);
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

    /// @dev defines which object - parent types relations are allowed to register
    // IMPORTANT: 
    // 1) EACH object type MUST have only one parent type across ALL mappings
    // 2) DO NOT use object type (e.g. POLCY, BUNDLE, STAKE) as parent type
    // 3) DO NOT use REGISTRY as object type
    // 2) DO NOT use PROTOCOL and "zeroObjectType"
    function _setupValidCoreTypesAndCombinations() 
        private 
    {
        _coreTypes[REGISTRY()] = true;
        _coreTypes[SERVICE()] = true;
        _coreTypes[TOKEN()] = true;
        _coreTypes[INSTANCE()] = true;
        _coreTypes[PRODUCT()] = true;
        _coreTypes[POOL()] = true;
        _coreTypes[DISTRIBUTION()] = true;
        _coreTypes[POLICY()] = true;
        _coreTypes[BUNDLE()] = true;
        _coreTypes[STAKE()] = true;
        
        // registry as parent, ONLY registry owner
        //_coreContractCombinations[REGISTRY()][REGISTRY()] = true; // only for global regstry
        _coreContractCombinations[TOKEN()][REGISTRY()] = true;
        //_coreContractCombinations[SERVICE()][REGISTRY()] = true;// do not need it here -> registerService() registers exactly this combination

        // registry as parent, ONLY approved
        _coreContractCombinations[INSTANCE()][REGISTRY()] = true;

        // instance as parent, ONLY approved
        _coreContractCombinations[PRODUCT()][INSTANCE()] = true;
        _coreContractCombinations[DISTRIBUTION()][INSTANCE()] = true;
        _coreContractCombinations[ORACLE()][INSTANCE()] = true;
        _coreContractCombinations[POOL()][INSTANCE()] = true;

        _coreObjectCombinations[DISTRIBUTOR()][DISTRIBUTION()] = true;

        // product as parent, ONLY approved
        _coreObjectCombinations[POLICY()][PRODUCT()] = true;

        // pool as parent, ONLY approved
        _coreObjectCombinations[BUNDLE()][POOL()] = true;
        _coreObjectCombinations[STAKE()][POOL()] = true;
    }
}
