// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {InitializableCustom} from "../shared/InitializableCustom.sol";

import {NftId, NftIdLib} from "../type/NftId.sol";
import {VersionPart} from "../type/Version.sol";
import {ObjectType, PROTOCOL, REGISTRY, TOKEN, SERVICE, INSTANCE, STAKE, STAKING, PRODUCT, DISTRIBUTION, DISTRIBUTOR, ORACLE, POOL, POLICY, BUNDLE} from "../type/ObjectType.sol";

import {ChainNft} from "./ChainNft.sol";
import {IRegistry} from "./IRegistry.sol";
import {IRegisterable} from "../shared/IRegisterable.sol";
import {ReleaseManager} from "./ReleaseManager.sol";
import {TokenRegistry} from "./TokenRegistry.sol";
import {RegistryAdmin} from "./RegistryAdmin.sol";

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
    InitializableCustom,
    IRegistry
{
    address public NFT_LOCK_ADDRESS = address(0x1);
    uint256 public constant REGISTRY_TOKEN_SEQUENCE_ID = 2;
    uint256 public constant STAKING_TOKEN_SEQUENCE_ID = 3;
    string public constant EMPTY_URI = "";

    mapping(NftId nftId => ObjectInfo info) private _info;
    mapping(address object => NftId nftId) private _nftIdByAddress;

    mapping(VersionPart version => mapping(ObjectType serviceDomain => address)) private _service;

    mapping(ObjectType objectType => bool) private _coreTypes;

    mapping(ObjectType objectType => mapping(
            ObjectType parentType => bool)) private _coreContractCombinations;

    mapping(ObjectType objectType => mapping(
            ObjectType parentType => bool)) private _coreObjectCombinations;

    RegistryAdmin public immutable _admin;
    ChainNft public immutable _chainNft;

    NftId public immutable _protocolNftId;
    NftId public immutable _registryNftId;
    NftId public _stakingNftId;

    address public _tokenRegistryAddress;
    address public _stakingAddress;
    ReleaseManager public _releaseManager;

    // TODO 
    // 1). Registry and ReleaseManager must be treated as whole single entity. 
    //     But current limitations of EVM does not allow it -> require it to be splitted
    // 2). Keep onlyReleaseManager modifier
    // 3). Delete onlyRegistryService in favor of restricted
    // 4). (For GlobalRegistry ONLY) make registerChainRegistry() restricted to GIF_ADMIN_ROLE
    modifier onlyRegistryService() {
        if(!_releaseManager.isActiveRegistryService(msg.sender)) {
            revert ErrorRegistryCallerNotRegistryService();
        }
        _;
    }


    modifier onlyReleaseManager() {
        if(msg.sender != address(_releaseManager)) {
            revert ErrorRegistryCallerNotReleaseManager();
        }
        _;
    }


    constructor(RegistryAdmin admin) 
        InitializableCustom() 
    {
        _admin = admin;
        // deploy NFT 
        _chainNft = new ChainNft(address(this));

        // initial registry setup
        _protocolNftId = _registerProtocol();
        _registryNftId = _registerRegistry();

        // set object types and object parent relations
        _setupValidCoreTypesAndCombinations();
    }


    /// @dev wires release manager and token to registry (this contract).
    /// MUST be called by release manager.
    function initialize(
        address releaseManager,
        address tokenRegistry,
        address staking
    )
        external
        initializer()
    {
        _releaseManager = ReleaseManager(releaseManager);
        _tokenRegistryAddress = tokenRegistry;
        _stakingAddress = staking;

        _stakingNftId = _registerStaking();
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
        address service = info.objectAddress;
        /* must be guaranteed by release manager
        if(service == address(0)) {
            revert();
        }

        if(version.eqz()) {
            revert();
        }

        if(info.objectType != SERVICE()) {
            revert();
        }
        if(info.parentType != REGISTRY()) {
            revert();
        }        
        info.initialOwner == NFT_LOCK_ADDRESS <- if services are access managed
        */

        if(domain.eqz()) {
            revert ErrorRegistryDomainZero(service);
        }

        if(_service[version][domain] > address(0)) {
            revert ErrorRegistryDomainAlreadyRegistered(service, version, domain);
        }
        
        _service[version][domain] = service;

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

        // only valid core types combinations
        if(info.objectAddress == address(0)) 
        {
            if(_coreObjectCombinations[objectType][parentType] == false) {
                revert ErrorRegistryTypesCombinationInvalid(objectType, parentType);
            }
        }
        else
        {
            if(_coreContractCombinations[objectType][parentType] == false) {
                revert ErrorRegistryTypesCombinationInvalid(objectType, parentType);
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
            revert ErrorRegistryCoreTypeRegistration();
        }

        if(
            parentType == PROTOCOL() ||
            parentType == REGISTRY() ||
            parentType == SERVICE()
        ) {
            revert ErrorRegistryTypesCombinationInvalid(objectType, parentType);
        }

        _register(info);
    }


    /// @dev earliest GIF major version 
    function getInitialVersion() external view returns (VersionPart) {
        return _releaseManager.getInitialVersion();
    }

    /// @dev next GIF release version to be released
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

    function getNftId() external view returns (NftId nftId) {
        return _registryNftId;
    }

    function getProtocolNftId() external view returns (NftId nftId) {
        return _protocolNftId;
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

    function isActiveRelease(VersionPart version) external view returns (bool)
    {
        return _releaseManager.isActiveRelease(version);
    }

    function getStakingAddress() external view returns (address staking) {
        //return getObjectInfo(_stakingNftId).objectAddress;
        //return _info[_stakingNftId].objectAddress;
        return _stakingAddress;
    }

    function getTokenRegistryAddress() external view returns (address tokenRegistry) {
        return _tokenRegistryAddress;
    }

    function getServiceAddress(
        ObjectType serviceDomain, 
        VersionPart releaseVersion
    ) external view returns (address service)
    {
        service =  _service[releaseVersion][serviceDomain]; 
    }

    function getReleaseManagerAddress() external view returns (address) {
        return address(_releaseManager);
    }

    function getChainNftAddress() external view override returns (address) {
        return address(_chainNft);
    }

    function getRegistryAdminAddress() external view returns (address) {
        return address(_admin);
    }

    function getAuthority() external view returns (address) {
        return _admin.authority();
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
        bool isInterceptor = info.isInterceptor;
        address objectAddress = info.objectAddress;
        address owner = info.initialOwner;

        NftId parentNftId = info.parentNftId;
        ObjectInfo memory parentInfo = _info[parentNftId];
        ObjectType parentType = parentInfo.objectType; // see function header
        address parentAddress = parentInfo.objectAddress;

        // parent is contract -> need to check? -> check before minting
        // special case: staking: to protocol possible as well
        // special case: global registry nft as parent when not on mainnet -> global registry address is 0
        // special case: when parentNftId == _chainNft.mint(), check for zero parent address before mint
        // special case: when parentNftId == _chainNft.mint() && objectAddress == initialOwner
        if(objectType != STAKE()) {
            if(parentAddress == address(0)) {
                revert ErrorRegistryParentAddressZero();
            }
        }

        address interceptorAddress = _getInterceptor(
            isInterceptor, 
            objectType, 
            objectAddress, 
            parentInfo.isInterceptor, 
            parentAddress);

        uint256 tokenId = _chainNft.getNextTokenId();
        nftId = NftIdLib.toNftId(tokenId);
        info.nftId = nftId;
        _info[nftId] = info;

        if(objectAddress > address(0)) {
            if(_nftIdByAddress[objectAddress].gtz()) { 
                revert ErrorRegistryContractAlreadyRegistered(objectAddress);
            }

            _nftIdByAddress[objectAddress] = nftId;
        }

        emit LogRegistration(nftId, parentNftId, objectType, isInterceptor, objectAddress, owner);

        // calls nft receiver(1) and interceptor(2)
        uint256 mintedTokenId = _chainNft.mint(
            owner,
            interceptorAddress,
            EMPTY_URI);

        assert(mintedTokenId == tokenId);        
    }

    /// @dev obtain interceptor address for this nft if applicable, address(0) otherwise
    /// special case: STAKES (parent may be any type) -> no intercept call
    /// default case: 
    function _getInterceptor(
        bool isInterceptor, 
        ObjectType objectType,
        address objectAddress,
        bool parentIsInterceptor,
        address parentObjectAddress
    )
        internal 
        pure 
        returns (address interceptor) 
    {
        // no intercepting calls for stakes
        if (objectType == STAKE()) {
            return address(0);
        }

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
        returns (NftId protocolNftId)
    {
        uint256 protocolId = _chainNft.PROTOCOL_NFT_ID();
        protocolNftId = NftIdLib.toNftId(protocolId);

        _info[protocolNftId] = ObjectInfo({
            nftId: protocolNftId,
            parentNftId: NftIdLib.zero(),
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
        returns (NftId registryNftId)
    {
        uint256 registryId = _chainNft.calculateTokenId(REGISTRY_TOKEN_SEQUENCE_ID);
        registryNftId = NftIdLib.toNftId(registryId);
        NftId parentNftId;

        if(registryId != _chainNft.GLOBAL_REGISTRY_ID()) 
        {// we're not the global registry
            _registerGlobalRegistry();
            parentNftId = NftIdLib.toNftId(_chainNft.GLOBAL_REGISTRY_ID());
        }
        else 
        {// we are global registry
            parentNftId = _protocolNftId;
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
        _chainNft.mint(NFT_LOCK_ADDRESS, registryId);
    }

    /// @dev global registry registration for non mainnet registries
    function _registerGlobalRegistry() 
        private
    {
        uint256 globalRegistryId = _chainNft.GLOBAL_REGISTRY_ID();
        NftId globalRegistryNftId = NftIdLib.toNftId(globalRegistryId);

        _info[globalRegistryNftId] = ObjectInfo({
            nftId: globalRegistryNftId,
            parentNftId: NftIdLib.toNftId(_chainNft.PROTOCOL_NFT_ID()),
            objectType: REGISTRY(),
            isInterceptor: false,
            objectAddress: address(0),
            initialOwner: NFT_LOCK_ADDRESS,
            data: ""
        });

        _chainNft.mint(NFT_LOCK_ADDRESS, globalRegistryId);
    }
    // depends on _registryNftId and _stakingAddress
    function _registerStaking()
        private
        returns (NftId stakingNftId)
    {
        address stakingOwner = IRegisterable(_stakingAddress).getOwner();
        uint256 stakingId = _chainNft.calculateTokenId(STAKING_TOKEN_SEQUENCE_ID);
        stakingNftId = NftIdLib.toNftId(stakingId);

        _info[stakingNftId] = ObjectInfo({
            nftId: stakingNftId,
            parentNftId: _registryNftId,
            objectType: STAKING(),
            isInterceptor: false,
            objectAddress: _stakingAddress, 
            initialOwner: stakingOwner,
            data: "" 
        });

        _nftIdByAddress[_stakingAddress] = stakingNftId;
        // reverts if nftId was already minted
        _chainNft.mint(stakingOwner, stakingId);
    }

    /// @dev defines which object - parent types relations are allowed to register
    // IMPORTANT: 
    // 1) EACH object type MUST have only one parent type across ALL mappings
    // 2) DO NOT use object type (e.g. POLCY, BUNDLE, STAKE) as parent type
    // 3) DO NOT use REGISTRY as object type
    // 2) DO NOT use PROTOCOL and "ObjectTypeLib.zero"
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
        _coreTypes[DISTRIBUTOR()] = true;
        _coreTypes[ORACLE()] = true;
        _coreTypes[POLICY()] = true;
        _coreTypes[BUNDLE()] = true;
        _coreTypes[STAKING()] = true;
        _coreTypes[STAKE()] = true;

        uint256 registryId = _chainNft.calculateTokenId(REGISTRY_TOKEN_SEQUENCE_ID);
        if(registryId == _chainNft.GLOBAL_REGISTRY_ID()) {
            // we are global registry
            // object is registry from different chain
            // parent is global registry, this contract
            _coreContractCombinations[REGISTRY()][REGISTRY()] = true; // only for global regstry
            //_coreObjectCombinations[REGISTRY()][REGISTRY()] = true;
        } else {
            // we are not global registry
            // object is local registry, this contract
            // parent is global registry, object with 0 address or registry from mainnet???
        }
        _coreContractCombinations[STAKING()][REGISTRY()] = true; // only for chain staking contract
        _coreContractCombinations[TOKEN()][REGISTRY()] = true;
        //_coreContractCombinations[SERVICE()][REGISTRY()] = true;// do not need it here -> registerService() registers exactly this combination
        _coreContractCombinations[INSTANCE()][REGISTRY()] = true;

        _coreContractCombinations[PRODUCT()][INSTANCE()] = true;
        _coreContractCombinations[DISTRIBUTION()][INSTANCE()] = true;
        _coreContractCombinations[ORACLE()][INSTANCE()] = true;
        _coreContractCombinations[POOL()][INSTANCE()] = true;

        _coreObjectCombinations[DISTRIBUTOR()][DISTRIBUTION()] = true;
        _coreObjectCombinations[POLICY()][PRODUCT()] = true;
        _coreObjectCombinations[BUNDLE()][POOL()] = true;

        // staking
        _coreObjectCombinations[STAKE()][PROTOCOL()] = true;
        _coreObjectCombinations[STAKE()][INSTANCE()] = true;
    }
}
