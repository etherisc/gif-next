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
import {ITransferInterceptor} from "./ITransferInterceptor.sol";

import {IOwnable} from "../shared/IOwnable.sol";
import {ERC165} from "../shared/ERC165.sol";


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
    // register
    error NotRegistryService();
    error ZeroParentAddress();
    error ContractAlreadyRegistered(address objectAddress);
    error InvalidServiceVersion(VersionPart majorVersion);
    error ServiceNameAlreadyRegistered(string name, VersionPart majorVersion);
            
    // approve
    error NotOwner();
    error NotRegisteredContract(NftId registrarNftId);
    error NotService(NftId registrarNftId);
    error InvalidTypesCombination(ObjectType objectType, ObjectType parentType);

    uint256 public constant MAJOR_VERSION_MIN = 3;
    address public constant NFT_LOCK_ADDRESS = address(0x1);
    uint256 public constant REGISTRY_SERVICE_TOKEN_SEQUENCE_ID = 3;
    string public constant EMPTY_URI = "";

    mapping(NftId nftId => ObjectInfo info) _info;
    mapping(address object => NftId nftId) _nftIdByAddress;

    mapping(NftId registrator => mapping(
            ObjectType objectType => bool)) _isApproved;

    mapping(ObjectType objectType => mapping(
            ObjectType parentType => bool)) _isValidContractCombination;

    mapping(ObjectType objectType => mapping(
            ObjectType parentType => bool)) _isValidObjectCombination;

    mapping(NftId nftId => string name) _string;
    mapping(bytes32 serviceNameHash => mapping(
            VersionPart majorVersion => address service)) _service;

    NftId _registryNftId;
    NftId _serviceNftId; // set in stone upon registry creation
    IChainNft _chainNft;
    ChainNft _chainNftInternal;

    /*
    modifier onlyInitialOwner() {
        if(
            msg.sender != getOwner() ||
            msg.sender != _info[_registryNftId].initialOwner) {
            revert NotInitialOwner();
        }
    }*/

    modifier onlyOwner() {
        if(msg.sender != getOwner()) {
            revert NotOwner();
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
        require(registryOwner > address(0), "Registry: protocol owner is 0");
        require(majorVersion.toInt() == MAJOR_VERSION_MIN, "Registry: initial major version of registry service is not MAJOR_VERSION_MIN");

        // deploy NFT 
        _chainNftInternal = new ChainNft(address(this));// adds 10kb to deployment size
        _chainNft = IChainNft(_chainNftInternal);

        // initial registry setup
        _registerProtocol();
        _registerRegistry(registryOwner);
        _registerRegistryService(registryOwner);

        // set object parent relations
        _setupValidObjectParentCombinations();

        _registerInterface(type(IRegistry).interfaceId);
        _registerInterface(type(IOwnable).interfaceId);
    }

    /// @dev registry protects only from tampering existing records and invalid types pairs
    // IMPORTANT: rare case when parentNftId is not registered and == next nftId -> technincally this is ZeroParentAddress error
    // to catch this check parent address before minting !!!!
    // TODO service registration means its approval for some type?
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
            if(objectType == SERVICE())
            {
                (
                    string memory serviceName,
                    VersionPart majorVersion
                ) = abi.decode(info.data, (string, VersionPart));
                bytes32 serviceNameHash = keccak256(abi.encode(serviceName));

                // TODO MUST guarantee consistency of registerable.getVersion() and majorVersion here
                // TODO update _serviceNftId when registryService with new major version is registered? -> it is fixed in current setup
                // TODO do not use names -> each object type is registered by corresponding service -> conflicting with approve()
                if(
                    majorVersion.toInt() < MAJOR_VERSION_MIN ||
                    (majorVersion.toInt() > MAJOR_VERSION_MIN &&
                    _service[serviceNameHash][VersionLib.toVersionPart(majorVersion.toInt() - 1)] == address(0) )
                ) {
                    revert InvalidServiceVersion(majorVersion);
                }
                
                if(_service[serviceNameHash][majorVersion] != address(0)) {
                    revert ServiceNameAlreadyRegistered(serviceName, majorVersion);
                }

                _string[nftId] = serviceName;
                _service[serviceNameHash][majorVersion] = contractAddress;

                emit LogServiceNameRegistration(serviceName, majorVersion); 
            }
        }
        else
        {
            if(_isValidObjectCombination[objectType][parentType] == false) {
                revert InvalidTypesCombination(objectType, parentType);
            }
        }

        emit LogRegistration(nftId, info.parentNftId, info.objectType, info.objectAddress, info.initialOwner);
    }

    function registerFrom(
        address from, 
        ObjectInfo memory info
    ) external returns (NftId nftId) 
    {
        revert();
    }
    

    /// @dev 
    // msg.sender - registry owner 
    //     CAN approve only registered service contract
    //     CAN approve any combination specified in _isValidCombination
    //     CAN NOT approve itself
    // TODO in case where exists exactly one registered service per objectType (and major version):
    // - registration and approve is a single operation, no need for separate approve() function
    // - then approve can be used to adding new valid object-parent combinations???
    function approve(
        NftId serviceNftId,
        ObjectType objectType,
        ObjectType parentType 
    ) 
        public
        onlyOwner()
    {
        address serviceAddress = _info[serviceNftId].objectAddress;
            
        if(_nftIdByAddress[serviceAddress].eqz()) {
            revert NotRegisteredContract(serviceNftId);
        }

        if(_info[serviceNftId].objectType != SERVICE()) {
            revert NotService(serviceNftId);
        }

        if(
            _isValidContractCombination[objectType][parentType] == false &&
            _isValidObjectCombination[objectType][parentType] == false) {
            revert InvalidTypesCombination(objectType, parentType);
        }

        _isApproved[serviceNftId][objectType] = true;

        emit LogApproval(serviceNftId, objectType);
    }

    /// @dev returns false for registry owner nft
    // TODO allowance by address?
    // TODO checked by registry service -> but registry owner can upgrade registry service not to check allowance....
    function allowance(
        NftId nftId,
        ObjectType object
    ) 
        public
        view 
        returns (bool)
    {
        return _isApproved[nftId][object];
    }

    // from IRegistry
    function getObjectCount() external view override returns (uint256) {
        
        return _chainNft.totalSupply();
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

    function getServiceName(NftId nftId) external view returns (string memory) {
        return _string[nftId];
    }

    // special case to retrive a gif service
    function getServiceAddress(
        string memory serviceName, 
        VersionPart majorVersion
    ) external view returns (address)
    {
        bytes32 serviceNameHash = keccak256(abi.encode(serviceName));
        return _service[serviceNameHash][majorVersion];
    }

    function getChainNft() external view override returns (IChainNft) {
        return _chainNft;
    }

    // from IOwnable
    function getOwner() public view returns (address owner) {
        return ownerOf(address(this));
    }

    // Internals, called only in constructor

    /// @dev protocol registration used to anchor the dip ecosystem relations
    function _registerProtocol() 
        internal
    {
        uint256 protocolId = _chainNftInternal.PROTOCOL_NFT_ID();
        NftId protocolNftId = toNftId(protocolId);

        _chainNftInternal.mint(NFT_LOCK_ADDRESS, protocolId);

        _info[protocolNftId] = ObjectInfo(
            protocolNftId,
            zeroNftId(), // parent
            PROTOCOL(),
            false, // isInterceptor
            address(0), // objectAddress
            NFT_LOCK_ADDRESS,// initialOwner
            ""
        );
    }

    /// @dev registry registration
    /// might also register the global registry when not on mainnet
    function _registerRegistry(address registryOwner) 
        internal
    {
        uint256 registryId = _chainNftInternal.calculateTokenId(2);
        NftId registryNftId = toNftId(registryId);

        NftId parentNftId;

        if(registryId != _chainNftInternal.GLOBAL_REGISTRY_ID()) 
        {// we're not the global registry
            _registerGlobalRegistry();
            parentNftId = toNftId(_chainNftInternal.GLOBAL_REGISTRY_ID());
        }
        else 
        {// we are global registry
            parentNftId = toNftId(_chainNftInternal.PROTOCOL_NFT_ID());
        }

        _chainNftInternal.mint(registryOwner, registryId);

        _info[registryNftId] = ObjectInfo(
            registryNftId,
            parentNftId,
            REGISTRY(),
            false, // isInterceptor
            address(this), 
            registryOwner,
            "" 
        );
        _nftIdByAddress[address(this)] = registryNftId;
        _registryNftId = registryNftId;
    }


    /// @dev global registry registration for non mainnet registries
    function _registerGlobalRegistry() 
        internal
    {
        uint256 globalRegistryId = _chainNftInternal.GLOBAL_REGISTRY_ID();

        _chainNftInternal.mint(NFT_LOCK_ADDRESS, globalRegistryId);

        NftId globalRegistryNftId = toNftId(globalRegistryId);

        _info[globalRegistryNftId] = ObjectInfo(
            globalRegistryNftId,
            toNftId(_chainNftInternal.PROTOCOL_NFT_ID()), // parent
            REGISTRY(),
            false, // isInterceptor
            address(0), // objectAddress
            NFT_LOCK_ADDRESS, // initialOwner
            "" // data
        );
    }

    function _registerRegistryService(address registryOwner)
        internal
    {
        uint256 serviceId = _chainNftInternal.calculateTokenId(REGISTRY_SERVICE_TOKEN_SEQUENCE_ID);
        NftId serviceNftId = toNftId(serviceId);        

        _chainNftInternal.mint(registryOwner, serviceId);

        _info[serviceNftId] = ObjectInfo(
            serviceNftId,
            _registryNftId,
            SERVICE(),
            false, // isInterceptor
            msg.sender, // service deploys registry
            registryOwner, // initialOwner,
            "" 
        );

        _nftIdByAddress[msg.sender] = serviceNftId;

        string memory serviceName = "RegistryService";
        bytes32 serviceNameHash = keccak256(abi.encode(serviceName));
        _service[serviceNameHash][VersionLib.toVersionPart(MAJOR_VERSION_MIN)] = msg.sender;
        _string[serviceNftId] = serviceName;
        _serviceNftId = serviceNftId;
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

    /// @dev defines which object - parent types relations are allowed to register
    // IMPORTANT: 
    // 1) EACH object type MUST have only one parent type across ALL mappings
    // 2) DO NOT use object type (e.g. POLCY, BUNDLE, STAKE) as parent type
    // 3) DO NOT use REGISTRY as object type
    // 2) DO NOT use PROTOCOL and "zeroObjectType"
    function _setupValidObjectParentCombinations() 
        internal 
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
