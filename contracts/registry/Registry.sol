// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {NftId, NftIdLib} from "../type/NftId.sol";
import {VersionPart} from "../type/Version.sol";
import {ObjectType, PROTOCOL, REGISTRY, SERVICE, INSTANCE, STAKE, STAKING, PRODUCT, DISTRIBUTION, DISTRIBUTOR, ORACLE, POOL, POLICY, BUNDLE} from "../type/ObjectType.sol";

import {ChainNft} from "./ChainNft.sol";
import {IRegistry} from "./IRegistry.sol";
import {IRegisterable} from "../shared/IRegisterable.sol";
import {ReleaseRegistry} from "./ReleaseRegistry.sol";
import {TokenRegistry} from "./TokenRegistry.sol";
import {RegistryAdmin} from "./RegistryAdmin.sol";
import {SidenetContract} from "../shared/MainnetId.sol";

/// @dev IMPORTANT
// Each NFT minted by registry is accosiated with:
// 1) NFT owner
// 2) registred contract OR object stored in registered (parent) contract
// Three registration flows:
// 1) registerService() -> registers IService address by ReleaseRegistry (ReleaseRegistry is set at deployment time)
// 2) register() -> registers IRegisterable address by IService (INSTANCE, PRODUCT, POOL, DISTRIBUTION, ORACLE)
// 3)            -> registers object by IService (POLICY, BUNDLE, STAKE)

/// @title Chain Registry contract implementing IRegistry.
/// @notice See IRegistry for method details.
contract Registry is
    SidenetContract,
    Initializable,
    AccessManaged,
    IRegistry
{
    using NftIdLib for NftId;

    address public NFT_LOCK_ADDRESS = address(0x1);
    uint256 public constant REGISTRY_TOKEN_SEQUENCE_ID = 2;
    uint256 public constant STAKING_TOKEN_SEQUENCE_ID = 3;
    string public constant EMPTY_URI = "";

    /// @dev stores the deployer address and allows to create initializers
    /// that are restricted to the deployer address.
    address public immutable _deployer;

    mapping(NftId nftId => ObjectInfo info) internal _info;
    mapping(address object => NftId nftId) internal _nftIdByAddress;

    mapping(VersionPart version => mapping(ObjectType serviceDomain => address)) private _service;

    mapping(ObjectType objectType => bool) private _coreTypes;

    mapping(ObjectType objectType => mapping(
            ObjectType parentType => bool)) private _coreContractCombinations;

    mapping(ObjectType objectType => mapping(
            ObjectType parentType => bool)) private _coreObjectCombinations;

    RegistryAdmin public immutable _admin;
    ChainNft public immutable _chainNft;

    NftId public immutable _protocolNftId;
    NftId public immutable _globalRegistryNftId;
    NftId public immutable _registryNftId;
    NftId public _stakingNftId;

    address public _tokenRegistryAddress;
    address public _stakingAddress;
    ReleaseRegistry public _releaseRegistry;

    modifier onlyDeployer() {
        if (msg.sender != _deployer) {
            revert ErrorRegistryCallerNotDeployer();
        }
        _;
    }

    modifier onlyReleaseRegistry() {
        if(msg.sender != address(_releaseRegistry)) {
            revert ErrorRegistryCallerNotReleaseRegistry();
        }
        _;
    }

    /// @dev Creates the registry contract and populates it with the protocol and registry objects.
    /// Internally deploys the ChainNft contract.
    // TODO consider storing global registry address as constant
    constructor(RegistryAdmin admin, address globalRegistry)
        AccessManaged(admin.authority())
    {
        _deployer = msg.sender;
        _admin = admin;
        // deploy NFT 
        _chainNft = new ChainNft(address(this));

        // initial registry setup
        _protocolNftId = _registerProtocol();
        _globalRegistryNftId = _registerGlobalRegistry(globalRegistry);
        _registryNftId = _registerRegistry();

        // set object types and object parent relations
        _setupValidCoreTypesAndCombinations();
    }


    /// @dev Wires release registry and token to registry (this contract).
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
        _releaseRegistry = ReleaseRegistry(releaseRegistry);
        _tokenRegistryAddress = tokenRegistry;
        _stakingAddress = staking;

        _stakingNftId = _registerStaking();
    }

    /// @inheritdoc IRegistry
    function register(ObjectInfo memory info)
        external
        restricted
        returns(NftId nftId)
    {
        ObjectType objectType = info.objectType;
        ObjectType parentType = _info[info.parentNftId].objectType;

        // check type combinations for core objects
        if(info.objectAddress == address(0)) {
            if(_coreObjectCombinations[objectType][parentType] == false) {
                revert ErrorRegistryTypesCombinationInvalid(objectType, parentType);
            }
        }
        // check type combinations for contract objects
        else {
            if(_coreContractCombinations[objectType][parentType] == false) {
                revert ErrorRegistryTypesCombinationInvalid(objectType, parentType);
            }
        }

        nftId = _register(info);
    }


    /// @inheritdoc IRegistry
    function registerService(
        ObjectInfo memory info, 
        VersionPart version, 
        ObjectType domain
    )
        external
        onlyReleaseRegistry
        returns(NftId nftId)
    {
        // check service address is defined
        address service = info.objectAddress;
        if(service == address(0)) {
            revert ErrorRegistryServiceAddressZero();
        }

        // check version is defined
        if(version.eqz()) {
            revert ErrorRegistryServiceVersionZero();
        }

        // check domain is defined
        if(domain.eqz()) {
            revert ErrorRegistryDomainZero(service);
        }

        // check contract has not already been registered
        if(_service[version][domain] != address(0)) {
            revert ErrorRegistryDomainAlreadyRegistered(service, version, domain);
        }

        // check service has proper type
        if(info.objectType != SERVICE()) {
            revert ErrorRegistryNotService(service, info.objectType);
        }

        // check that parent has registry type
        if(info.parentNftId != _registryNftId) {
            revert ErrorRegistryServiceParentNotRegistry(info.parentNftId);
        }        

        _service[version][domain] = service;
        nftId = _register(info);

        emit LogServiceRegistration(version, domain);
    }


    /// @inheritdoc IRegistry
    function registerWithCustomType(ObjectInfo memory info)
        external
        restricted
        returns(NftId nftId)
    {
        ObjectType objectType = info.objectType;
        ObjectType parentType = _info[info.parentNftId].objectType;

        if(_coreTypes[objectType]) {
            revert ErrorRegistryCoreTypeRegistration();
        }

        if(
            parentType == PROTOCOL() ||
            parentType == SERVICE()
        ) {
            revert ErrorRegistryTypesCombinationInvalid(objectType, parentType);
        }

        nftId = _register(info);
    }


    /// @dev earliest GIF major version 
    function getInitialVersion() external view returns (VersionPart) {
        return _releaseRegistry.getInitialVersion();
    }

    /// @dev next GIF release version to be released
    function getNextVersion() external view returns (VersionPart) {
        return _releaseRegistry.getNextVersion();
    }

    /// @dev latest active GIF release version 
    function getLatestVersion() external view returns (VersionPart) { 
        return _releaseRegistry.getLatestVersion();
    }

    function getReleaseInfo(VersionPart version) external view returns (ReleaseInfo memory) {
        return _releaseRegistry.getReleaseInfo(version);
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
        return _releaseRegistry.isActiveRelease(version);
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

    function getReleaseRegistryAddress() external view returns (address) {
        return address(_releaseRegistry);
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

    /// @dev global registry registration
    function _registerGlobalRegistry(address globalRegistry)
        internal
        returns (NftId globalRegistryNftId)
    {
        uint256 globalRegistryId = _chainNft.GLOBAL_REGISTRY_ID();
        globalRegistryNftId = NftIdLib.toNftId(globalRegistryId);

        _info[globalRegistryNftId] = ObjectInfo({
            nftId: globalRegistryNftId,
            parentNftId: _protocolNftId,
            objectType: REGISTRY(),
            isInterceptor: false,
            objectAddress: globalRegistry,
            initialOwner: NFT_LOCK_ADDRESS,
            data: ""
        });

        _nftIdByAddress[address(this)] = globalRegistryNftId;
        _chainNft.mint(NFT_LOCK_ADDRESS, globalRegistryId);
    }

    /// @dev registry registration
    function _registerRegistry() 
        internal 
        virtual
        returns (NftId registryNftId)
    {
        uint256 registryId = _chainNft.calculateTokenId(REGISTRY_TOKEN_SEQUENCE_ID);
        registryNftId = NftIdLib.toNftId(registryId);

        _info[registryNftId] = ObjectInfo({
            nftId: registryNftId,
            parentNftId: _globalRegistryNftId,
            objectType: REGISTRY(),
            isInterceptor: false,
            objectAddress: address(this), 
            initialOwner: NFT_LOCK_ADDRESS,
            data: "" 
        });

        _nftIdByAddress[address(this)] = registryNftId;
        _chainNft.mint(NFT_LOCK_ADDRESS, registryId);
    }

    /// @dev staking registration
    function _registerStaking()
        private
        onlyInitializing()
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
        _chainNft.mint(stakingOwner, stakingId);
    }

    /// @dev defines which object - parent types relations are allowed to register
    /// EACH object type MUST have only one parent type across ALL mappings
    function _setupValidCoreTypesAndCombinations() 
        private
    {
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

        _coreContractCombinations[STAKING()][REGISTRY()] = true; // only for chain staking contract
        _coreContractCombinations[INSTANCE()][REGISTRY()] = true;

        // components with instance parent
        _coreContractCombinations[PRODUCT()][INSTANCE()] = true;
        _coreContractCombinations[DISTRIBUTION()][INSTANCE()] = true;
        _coreContractCombinations[ORACLE()][INSTANCE()] = true;
        _coreContractCombinations[POOL()][INSTANCE()] = true;

        // objects with coponent parents
        _coreObjectCombinations[DISTRIBUTOR()][DISTRIBUTION()] = true;
        _coreObjectCombinations[POLICY()][PRODUCT()] = true;
        _coreObjectCombinations[BUNDLE()][POOL()] = true;

        // staking
        _coreObjectCombinations[STAKE()][PROTOCOL()] = true;
        _coreObjectCombinations[STAKE()][INSTANCE()] = true;
    }
}
