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

import {IOwnable} from "../shared/IOwnable.sol";
import {ERC165} from "../shared/ERC165.sol";


// IMPORTANT
// Each NFT minted by registry is accosiated with:
// 1) NFT owner
// 2) registred contract OR object stored in registered (parent) contract
// Four registration flows:
// 1) non IRegisterable address by registryOwner (TOKEN)
// 2) IRegisterable address by registryOwner (SERVICE)
// 3) IRegisterable address by contract owner (INSTANCE, COMPONENT) -> wil be changed to "by approved service" 
// 4) state object by approved service

contract Registry is
    ERC165,
    IRegistry
{
    // register
    error NotRegistryService();
    error ContractAlreadyRegistered(address objectAddress);
    error InvalidServiceVersion(VersionPart majorVersion);
    error ServiceNameAlreadyRegistered(string name, VersionPart majorVersion);
            
    // approve
    error NotOwner();
    error NotRegisteredContract(NftId registrarNftId);
    error NotService(NftId registrarNftId);
    error InvalidTypesCombination(ObjectType objectType, ObjectType parentType);

    string public constant EMPTY_URI = "";

    address constant public NFT_LOCK_ADDRESS = address(0x1);

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

    /// @dev will own protocol, global registry, registry and registry service nfts minted during creation
    // TODO registry nft can be transfered while protocol, global registry and registry service nfts are not transferable
    // TODO get owner from one place -> nft contract
    address _protocolOwner;

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

    constructor(address protocolOwner, address registryService, string memory serviceName, VersionPart majorVersion)
    {
        // TODO registry owner can change, while protocol is not?
        _protocolOwner = protocolOwner;

        // deploy NFT 
        _chainNftInternal = new ChainNft(address(this));// adds 10kb to deployment size
        _chainNft = IChainNft(_chainNftInternal);

        // initial registry setup
        _registerProtocol();

        _registerRegistry();

        _registerRegistryService(registryService, serviceName, majorVersion);

        // set object parent relations
        _setupValidObjectParentCombinations();

        _registerInterface(type(IRegistry).interfaceId);
        _registerInterface(type(IOwnable).interfaceId);
    }

    /// @dev registry protects only from tampering existing records and invalid types pairs
    // TODO service registration means its approval for some type?
    function register(ObjectInfo memory info)
        external
        onlyRegistryService
        returns(NftId nftId)
    {
        uint256 mintedTokenId = _chainNft.mint(
            info.initialOwner,
            EMPTY_URI);
        nftId = toNftId(mintedTokenId);

        // TODO move nftId out of info struct
        // getters by nftId -> return struct without nftId
        // getters by address -> return nftId AND struct
        info.nftId = nftId;
        _info[nftId] = info;

        ObjectType objectType = info.objectType;
        ObjectType parentType = _info[info.parentNftId].objectType; 

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
            if(info.objectType == SERVICE())
            {
                (
                    string memory serviceName,
                    VersionPart majorVersion
                ) = abi.decode(info.data, (string, VersionPart));
                bytes32 serviceNameHash = keccak256(abi.encode(serviceName));

                // TODO MUST guarantee consistency of registerable.getVersion() and majorVersion here
                // TODO update _serviceNftId when registryService with new major version is registered? -> it is fixed in current setup -> upgrade registryService address?
                // TODO do not use names -> each object type is registered by corresponding service -> done through approve() -> merge approve() and service type here?
                if(
                    majorVersion.toInt() > 1 &&
                    _service[serviceNameHash][VersionLib.toVersionPart(majorVersion.toInt() - 1)] == address(0)) {
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

    // TODO allowance by address?
    /// @dev returns false for registry owner nft
    // TODO but registry owner can upgrade registry service not to check allowance....
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

    function getProtocolOwner() external view override returns (address) {
        return _protocolOwner;
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
            address(0),
            NFT_LOCK_ADDRESS,//_protocolOwner,
            ""
        );
    }

    /// @dev registry registration
    /// might also register the global registry when not on mainnet
    function _registerRegistry() 
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

        _chainNftInternal.mint(_protocolOwner, registryId);

        _info[registryNftId] = ObjectInfo(
            registryNftId,
            parentNftId,
            REGISTRY(),
            address(this), 
            _protocolOwner,
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
            address(0), // contract address
            NFT_LOCK_ADDRESS,//_protocolOwner,
            "" // data
        );
    }

    function _registerRegistryService(address serviceAddress, string memory serviceName, VersionPart majorVersion)
        internal
        returns(NftId serviceNftId) 
    {
        uint256 serviceId = _chainNftInternal.calculateTokenId(3);
        serviceNftId = toNftId(serviceId);        

        _chainNftInternal.mint(NFT_LOCK_ADDRESS, serviceId);

        _info[serviceNftId] = ObjectInfo(
            serviceNftId,
            _registryNftId,
            SERVICE(),
            serviceAddress, 
            NFT_LOCK_ADDRESS,//_protocolOwner,
            "" 
        );

        _nftIdByAddress[serviceAddress] = serviceNftId;

        bytes32 serviceNameHash = keccak256(abi.encode(serviceName));
        _service[serviceNameHash][majorVersion] = serviceAddress;
        _string[serviceNftId] = serviceName;
        _serviceNftId = serviceNftId;
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
