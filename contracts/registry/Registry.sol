// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {NftId, NftIdLib} from "../type/NftId.sol";
import {VersionPart, VersionPartLib} from "../type/Version.sol";
import {ObjectType, ObjectTypeLib, PROTOCOL, REGISTRY, SERVICE, INSTANCE, STAKE, STAKING, PRODUCT, DISTRIBUTION, DISTRIBUTOR, ORACLE, POOL, POLICY, BUNDLE} from "../type/ObjectType.sol";

import {ChainNft} from "./ChainNft.sol";
import {IRegistry} from "./IRegistry.sol";
import {IRelease} from "./IRelease.sol";
import {IRegisterable} from "../shared/IRegisterable.sol";
import {IStaking} from "../staking/IStaking.sol";
import {ReleaseRegistry} from "./ReleaseRegistry.sol";
import {TokenRegistry} from "./TokenRegistry.sol";
import {RegistryAdmin} from "./RegistryAdmin.sol";
import {Versionable} from "../shared/Versionable.sol";
import {VersionLib, Version} from "../type/Version.sol";

/// @dev IMPORTANT
// Each NFT minted by registry is accosiated with:
// 1) NFT owner
// 2) registred contract OR object stored in registered (parent) contract
// Five registration flows:
// 1) registerService() -> registers IService address by ReleaseRegistry (ReleaseRegistry is set at deployment time)
// 2) register() -> registers IRegisterable address by IService (INSTANCE, PRODUCT, POOL, DISTRIBUTION, ORACLE)
// 3)            -> registers object by IService (POLICY, BUNDLE, STAKE)
// 4) registerWithCustomType() -> registers IRegisterable address with custom type by IService
// 5) registerRegistry() -> registers IRegistry address (from different chain) by GifAdmin. Works ONLY on mainnet. 
//                          Note: getters by address MUST not be used with this address (will return 0 or data related to different object or even revert)


function GIF_INITIAL_RELEASE() pure returns (VersionPart) {
    return VersionPartLib.toVersionPart(3);
}


/// @dev Chain Registry contract implementing IRegistry.
/// IRegistry for method details.
contract Registry is
    Initializable,
    AccessManaged,
    Versionable,
    IRegistry
{
    /// @dev Protocol NFT ID
    NftId public immutable PROTOCOL_NFT_ID;

    /// @dev Global registry NFT ID
    NftId public immutable GLOBAL_REGISTRY_NFT_ID;

    /// @dev Global registry address on mainnet.
    address public immutable GLOBAL_REGISTRY_ADDRESS;

    /// @dev Registry NFT ID
    NftId public immutable REGISTRY_NFT_ID;

    /// @dev Deployer address that authorizes the initializer of this contract.
    address public immutable DEPLOYER;

    /// @dev Registry admin contract for this registry.
    RegistryAdmin public immutable ADMIN;

    /// @dev Chain NFT contract that keeps track of the ownership of all registered objects.
    ChainNft public immutable CHAIN_NFT;

    address public constant NFT_LOCK_ADDRESS = address(0x1);
    uint256 public constant REGISTRY_TOKEN_SEQUENCE_ID = 2;
    uint256 public constant STAKING_TOKEN_SEQUENCE_ID = 3;
    string public constant EMPTY_URI = "";

    /// @dev keep track of different registries on different chains
    mapping(uint256 chainId => NftId registryNftId) private _registryNftIdByChainId;
    uint256[] private _chainId;

    /// @dev keep track of object info, data and address reverse lookup
    mapping(NftId nftId => ObjectInfo info) private _info;
    mapping(NftId nftId => bytes data) private _data;
    mapping(address object => NftId nftId) private _nftIdByAddress;

    /// @dev keep track of service addresses by version and domain
    mapping(VersionPart version => mapping(ObjectType serviceDomain => address)) private _service;

    mapping(ObjectType objectType => bool) private _coreTypes;

    mapping(ObjectType objectType => mapping(
            ObjectType parentType => bool)) private _coreContractCombinations;

    mapping(ObjectType objectType => mapping(
            ObjectType parentType => bool)) private _coreObjectCombinations;

    NftId private _stakingNftId;

    ReleaseRegistry private _releaseRegistry;
    address private _tokenRegistryAddress;
    address private _stakingAddress;

    modifier onlyDeployer() {
        if (msg.sender != DEPLOYER) {
            revert ErrorRegistryCallerNotDeployer();
        }
        _;
    }

    // TODO when create2 strategy is added to ignition:
    // 1. move globalRegistry arg out from constructor into initialize()
    // 2. add testRegistry_deployChainRegistryAtGlobalRegistryAddress
    /// @dev Creates the registry contract and populates it with the protocol and registry objects.
    /// Internally deploys the ChainNft contract.
    constructor(RegistryAdmin admin, address globalRegistry)
        AccessManaged(admin.authority())
    {
        DEPLOYER = msg.sender;
        ADMIN = admin;
        GLOBAL_REGISTRY_ADDRESS = _getGlobalRegistryAddress(globalRegistry);

        // deploy NFT 
        CHAIN_NFT = new ChainNft(address(this));
        GLOBAL_REGISTRY_NFT_ID = NftIdLib.toNftId(
            CHAIN_NFT.GLOBAL_REGISTRY_ID());

        // initial registry setup
        PROTOCOL_NFT_ID = _registerProtocol();
        REGISTRY_NFT_ID = _registerRegistry();

        // set object types and object parent relations
        _setupValidCoreTypesAndCombinations();
    }


    /// @dev Wires release registry, token registry and staking contract to this registry.
    /// MUST be called by release registry.
    function initialize(
        address releaseRegistry,
        address tokenRegistry,
        address staking
    )
        external
        initializer()
        onlyDeployer()
    {
        // store links to supporting contracts
        _releaseRegistry = ReleaseRegistry(releaseRegistry);
        _tokenRegistryAddress = tokenRegistry;
        _stakingAddress = staking;

        // register staking contract
        _stakingNftId = _registerStaking();
    }

    /// @inheritdoc IRegistry
    function registerRegistry(
        NftId nftId,
        uint256 chainId, 
        address registryAddress,
        VersionPart release
    )
        external
        restricted()
    {
        // registration of chain registries only allowed on mainnet
        if (block.chainid != 1) {
            revert ErrorRegistryNotOnMainnet(block.chainid);
        }

        // registry chain id is not zero
        if(chainId == 0) {
            revert ErrorRegistryChainRegistryChainIdZero(nftId);
        }

        // registry address is not zero
        if (registryAddress == address(0)) {
            revert ErrorRegistryChainRegistryAddressZero(nftId, chainId);
        }

        // registry nft id matches registry chain id
        uint256 expectedRegistryId = CHAIN_NFT.calculateTokenId(REGISTRY_TOKEN_SEQUENCE_ID, chainId);
        if (nftId != NftIdLib.toNftId(expectedRegistryId)) {
            revert ErrorRegistryChainRegistryNftIdInvalid(nftId, chainId);
        }

        emit LogRegistryChainRegistryRegistered(nftId, chainId, registryAddress);

        _registerRegistryForNft(
            chainId,
            ObjectInfo({
                nftId: nftId,
                parentNftId: REGISTRY_NFT_ID,
                objectType: REGISTRY(),
                release: release,
                isInterceptor: false,
                objectAddress: registryAddress}),
            false); // do not update address lookup for objects on a different chain
    }

    // TODO limit service owner to registry admin?
    /// @inheritdoc IRegistry
    function registerService(
        ObjectInfo memory info,
        address initialOwner,
        ObjectType domain,
        bytes memory data
    )
        external
        restricted()
        returns(NftId nftId)
    {
        // service address is defined
        address service = info.objectAddress;
        if(service == address(0)) {
            revert ErrorRegistryServiceAddressZero();
        }

        // version is defined
        VersionPart release = info.release;
        if(release.eqz()) {
            revert ErrorRegistryServiceVersionZero(service);
        }
        // service domain is defined
        if(domain.eqz()) {
            revert ErrorRegistryServiceDomainZero(service, release);
        }

        // service has proper type
        if(info.objectType != SERVICE()) {
            revert ErrorRegistryNotService(service, info.objectType);
        }

        // service parent has registry type
        if(info.parentNftId != REGISTRY_NFT_ID) {
            revert ErrorRegistryServiceParentNotRegistry(service, release, info.parentNftId);
        }

        // service has not already been registered
        if(_service[release][domain] != address(0)) {
            revert ErrorRegistryServiceDomainAlreadyRegistered(service, release, domain);
        }

        _service[release][domain] = service;

        emit LogRegistryServiceRegistered(release, domain);

        nftId = _register(info, initialOwner, data);
    }


    /// @inheritdoc IRegistry
    function register(ObjectInfo memory info, address initialOwner, bytes memory data)
        external
        restricted()
        returns(NftId nftId)
    {
        address objectAddress = info.objectAddress;
        ObjectType objectType = info.objectType;
        VersionPart parentRelease = _info[info.parentNftId].release;

        // specialized functions have to be used to register registries and services
        if(objectType == REGISTRY() || objectType == STAKING() || objectType == SERVICE()) {
            revert ErrorRegistryObjectTypeNotSupported(objectType);
        }

        // this indidirectly enforces that the parent is registered
        // parentType would be zero for a non-registered parent which is never a valid type combination
        ObjectType parentType = _info[info.parentNftId].objectType;

        // check type combinations for core objects
        if(objectAddress == address(0)) {
            if(_coreObjectCombinations[objectType][parentType] == false) {
                revert ErrorRegistryTypeCombinationInvalid(objectAddress, objectType, parentType);
            }
        }
        // check type combinations for contract objects
        else {
            if(_coreContractCombinations[objectType][parentType] == false) {
                revert ErrorRegistryTypeCombinationInvalid(objectAddress, objectType, parentType);
            }
        }

        _checkRelease(info.release, parentRelease, parentType);

        nftId = _register(info, initialOwner, data);
    }


    /// @inheritdoc IRegistry
    function registerWithCustomType(ObjectInfo memory info, address initialOwner, bytes memory data)
        external
        restricted()
        returns(NftId nftId)
    {
        ObjectType objectType = info.objectType;
        ObjectType parentType = _info[info.parentNftId].objectType;
        VersionPart parentRelease = _info[info.parentNftId].release;

        if(_coreTypes[objectType]) {
            revert ErrorRegistryCoreTypeRegistration();
        }

        if(
            objectType == ObjectTypeLib.zero() ||
            parentType == ObjectTypeLib.zero() ||
            parentType == PROTOCOL() ||
            parentType == STAKING() ||
            parentType == SERVICE()
        ) {
            revert ErrorRegistryTypeCombinationInvalid(info.objectAddress, objectType, parentType);
        }

        _checkRelease(info.release, parentRelease, parentType);

        nftId = _register(info, initialOwner, data);
    }

    function _checkRelease(
        VersionPart objectRelease, 
        VersionPart parentRelease,
        ObjectType parentType
    ) internal view
    {
        VersionPart senderRelease = _info[_nftIdByAddress[msg.sender]].release;

        // assume:
        // 1) only address with role can reach this function -> caller is registered registry service
        // 2) locked registry service can not call registry -> no "caller is locked" check is needed
        if(parentType == PROTOCOL()) {
            // STAKING for PROTOCOL, parent release is 0
            if(senderRelease != objectRelease) {
                revert ErrorRegistryReleaseMismatch(objectRelease, parentRelease, senderRelease);
            }
        }
        else if(senderRelease != objectRelease || senderRelease != parentRelease) {
            revert ErrorRegistryReleaseMismatch(objectRelease, parentRelease, senderRelease);
        }
    }

    /// @dev earliest GIF major version 
    function getInitialRelease() external view returns (VersionPart) {
        return GIF_INITIAL_RELEASE();
    }

    /// @dev next GIF release version to be released
    function getNextRelease() external view returns (VersionPart) {
        return _releaseRegistry.getNextVersion();
    }

    /// @dev latest active GIF release version 
    function getLatestRelease() external view returns (VersionPart) { 
        return _releaseRegistry.getLatestVersion();
    }

    function getReleaseInfo(VersionPart release) external view returns (IRelease.ReleaseInfo memory) {
        return _releaseRegistry.getReleaseInfo(release);
    }

    function chainIds() public view returns (uint256) {
        return _chainId.length;
    }

    function getChainId(uint256 idx) public view returns (uint256) {
        return _chainId[idx];
    }

    function getRegistryNftId(uint256 chainId) public view returns (NftId nftId) {
        return _registryNftIdByChainId[chainId];
    }

    function getObjectCount() external view returns (uint256) {
        return CHAIN_NFT.totalSupply();
    }

    function getNftId() external view returns (NftId nftId) {
        return REGISTRY_NFT_ID;
    }

    function getProtocolNftId() external view returns (NftId nftId) {
        return PROTOCOL_NFT_ID;
    }

    function getNftIdForAddress(address object) external view returns (NftId id) {
        return _nftIdByAddress[object];
    }

    function ownerOf(NftId nftId) public view returns (address) {
        return CHAIN_NFT.ownerOf(nftId.toInt());
    }

    function isOwnerOf(NftId nftId, address expectedOwner) public view returns (bool) {
        return CHAIN_NFT.ownerOf(nftId.toInt()) == expectedOwner;
    }

    function ownerOf(address contractAddress) public view returns (address) {
        return CHAIN_NFT.ownerOf(_nftIdByAddress[contractAddress].toInt());
    }

    function getObjectInfo(NftId nftId) external view returns (ObjectInfo memory) {
        return _info[nftId];
    }

    function getParentNftId(NftId nftId) external view returns (NftId parentNftId) {
        return _info[nftId].parentNftId;
    }

    function isObjectType(address contractAddress, ObjectType expectedObjectType, VersionPart release) external view returns (bool) {
        NftId nftId = _nftIdByAddress[contractAddress];
        return isObjectType(nftId, expectedObjectType, release);
    }

    function isObjectType(NftId nftId, ObjectType expectedObjectType, VersionPart release) public view returns (bool) {
        return (
            _info[nftId].objectType == expectedObjectType &&
            _info[nftId].release == release
        );
    }

    function getObjectRelease(NftId nftId) external view returns (VersionPart release)  {
        return _info[nftId].release;
    }

    function getObjectAddress(NftId nftId) external view returns (address) {
        return _info[nftId].objectAddress;
    }

    function getObjectInfo(address object) external view returns (ObjectInfo memory) {
        return _info[_nftIdByAddress[object]];
    }

    function getObjectData(NftId nftId) external view returns (bytes memory data) {
        return _data[nftId];
    }

    function getObjectData(address objectAddress) external view returns (bytes memory data) {
        return _data[_nftIdByAddress[objectAddress]];
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
        return _releaseRegistry.isActiveRelease(version);
    }

    function getStakingAddress() external view returns (address staking) {
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

    function getReleaseRegistryAddress() external view returns (address) {
        return address(_releaseRegistry);
    }

    function getChainNftAddress() external view override returns (address) {
        return address(CHAIN_NFT);
    }

    function getRegistryAdminAddress() external view returns (address) {
        return address(ADMIN);
    }

    function getAuthority() external view returns (address) {
        return ADMIN.authority();
    }

    function getOwner() public view returns (address owner) {
        return ownerOf(address(this));
    }

    // Versionable

    function getVersion() public pure override returns (Version) {
        return VersionLib.toVersion(GIF_INITIAL_RELEASE().toInt(), 0 , 0);
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
    function _register(ObjectInfo memory info, address initialOwner, bytes memory data)
        internal
        returns(NftId nftId)
    {
        NftId parentNftId = info.parentNftId; // do not care here, can not be 0
        ObjectInfo memory parentInfo = _info[parentNftId];
    
        // global registry is never parent when not on mainnet
        if(block.chainid != 1) {
            if(parentNftId == GLOBAL_REGISTRY_NFT_ID) {
                revert ErrorRegistryGlobalRegistryAsParent(info.objectAddress, info.objectType);
            }
        }

        address interceptorAddress = _getInterceptor(
            info.isInterceptor, 
            info.objectType, 
            info.objectAddress, 
            parentInfo.isInterceptor, 
            parentInfo.objectAddress);

        uint256 tokenId = CHAIN_NFT.mint(
            initialOwner,
            interceptorAddress,
            EMPTY_URI);

        nftId = NftIdLib.toNftId(tokenId);
        info.nftId = nftId;

        _info[nftId] = info;
        if(data.length > 0) {
            _data[nftId] = data;
        }
        _setAddressForNftId(nftId, info.objectAddress);

        emit LogRegistryObjectRegistered(
            nftId, 
            parentNftId, 
            info.objectType,
            info.release,
            info.isInterceptor, 
            info.objectAddress, 
            initialOwner);
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
        uint256 protocolId = CHAIN_NFT.PROTOCOL_NFT_ID();
        protocolNftId = NftIdLib.toNftId(protocolId);

        _registerForNft(
            ObjectInfo({
                nftId: protocolNftId,
                parentNftId: NftIdLib.zero(),
                objectType: PROTOCOL(),
                release: VersionPartLib.toVersionPart(0),
                isInterceptor: false, 
                objectAddress: address(0)}),
            NFT_LOCK_ADDRESS, // initial owner of protocol
            true);
    }

    /// @dev register this registry
    function _registerRegistry() 
        internal 
        virtual
        returns (NftId registryNftId)
    {
        // initial assignment
        registryNftId = GLOBAL_REGISTRY_NFT_ID;

        // register global registry
        _registerRegistryForNft(
            1, // mainnet chain id
            ObjectInfo({
                nftId: GLOBAL_REGISTRY_NFT_ID,
                parentNftId: PROTOCOL_NFT_ID,
                objectType: REGISTRY(),
                release: getRelease(),
                isInterceptor: false,
                objectAddress: GLOBAL_REGISTRY_ADDRESS}),
            block.chainid == 1);// update address lookup for global registry only on mainnet

        // if not on mainnet: register this registry with global registry as parent
        if (block.chainid != 1) {

            // modify registry nft id to local registry when not on mainnet
            registryNftId = NftIdLib.toNftId(
                CHAIN_NFT.calculateTokenId(REGISTRY_TOKEN_SEQUENCE_ID));

            _registerRegistryForNft(
                block.chainid, 
                ObjectInfo({
                    nftId: registryNftId,
                    parentNftId: GLOBAL_REGISTRY_NFT_ID,
                    objectType: REGISTRY(),
                    release: getRelease(),
                    isInterceptor: false,
                    objectAddress: address(this)}),
                true);
        }
    }

    /// @dev staking registration
    function _registerRegistryForNft(
        uint256 chainId,
        ObjectInfo memory info,
        bool updateAddressLookup
    )
        private
    {
        if (!_registryNftIdByChainId[chainId].eqz()) {
            revert ErrorRegistryChainRegistryAlreadyRegistered(info.nftId, chainId);
        }

        // update registry lookup variables
        _registryNftIdByChainId[chainId] = info.nftId;
        _chainId.push(chainId);

        // register the registry info
        _registerForNft(
            info,
            NFT_LOCK_ADDRESS, // initial owner of any registry
            updateAddressLookup); 
    }

    /// @dev staking registration
    function _registerStaking()
        private
        returns (NftId stakingNftId)
    {
        address stakingOwner = IRegisterable(_stakingAddress).getOwner();
        uint256 stakingId = CHAIN_NFT.calculateTokenId(STAKING_TOKEN_SEQUENCE_ID);
        stakingNftId = NftIdLib.toNftId(stakingId);

        _registerForNft( 
            ObjectInfo({
                nftId: stakingNftId,
                parentNftId: REGISTRY_NFT_ID,
                objectType: STAKING(),
                release: VersionPartLib.toVersionPart(3),
                isInterceptor: false,
                objectAddress: _stakingAddress}),
            stakingOwner,
            true); 

        IStaking(_stakingAddress).initializeTokenHandler();
    }

    /// @dev Register the provided object info for the specified NFT ID.
    function _registerForNft(
        ObjectInfo memory info,
        address initialOwner,
        bool updateAddressLookup
    )
        internal
    {
        _info[info.nftId] = info;

        if (updateAddressLookup) {
            _setAddressForNftId(info.nftId, info.objectAddress);
        }

        // calls nft receiver
        CHAIN_NFT.mint(initialOwner, info.nftId.toInt());
    }

    function _setAddressForNftId(NftId nftId, address objectAddress)
        internal
    {
        if (objectAddress != address(0)) {
            if (_nftIdByAddress[objectAddress].gtz()) { 
                revert ErrorRegistryContractAlreadyRegistered(objectAddress);
            }

            _nftIdByAddress[objectAddress] = nftId;
        }
    }

    function _getGlobalRegistryAddress(address globalRegistry) internal view returns (address) {
        if (block.chainid == 1) {
            return address(this);
        } else {
            return globalRegistry;
        }
    }

    /// @dev defines which object - parent types relations are allowed to register
    /// EACH object type MUST have only one parent type across ALL mappings
    // the only EXCEPTION is STAKE, can have any number of parent types
    function _setupValidCoreTypesAndCombinations() 
        private
    {
        _coreTypes[PROTOCOL()] = true;
        _coreTypes[REGISTRY()] = true;
        _coreTypes[SERVICE()] = true;
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

        // types combinations allowed to use with register() function ONLY
        _coreContractCombinations[INSTANCE()][REGISTRY()] = true;

        // components with instance parent
        _coreContractCombinations[PRODUCT()][INSTANCE()] = true;

        // components with product parent
        _coreContractCombinations[DISTRIBUTION()][PRODUCT()] = true;
        _coreContractCombinations[ORACLE()][PRODUCT()] = true;
        _coreContractCombinations[POOL()][PRODUCT()] = true;

        // objects with component parents
        _coreObjectCombinations[POLICY()][PRODUCT()] = true;
        _coreObjectCombinations[DISTRIBUTOR()][DISTRIBUTION()] = true;
        _coreObjectCombinations[BUNDLE()][POOL()] = true;

        // staking
        _coreObjectCombinations[STAKE()][PROTOCOL()] = true;
        _coreObjectCombinations[STAKE()][INSTANCE()] = true;
    }
}
