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
    mapping(NftId nftId => address owner) private _owner;// TODO: use _chainNft.ownerOf(nftId)...
    mapping(address object => NftId nftId) private _nftIdByAddress;

    mapping(NftId nftId => string stringValue) private _string;
    mapping(bytes32 serviceNameHash => mapping(VersionPart majorVersion => address service)) _service;

    NftId private _nftId;// TODO move to register's info
    IChainNft private _chainNft;
    ChainNft private _chainNftInternal;
    address private _initialOwner;// TODO move to register's info

    mapping(ObjectType callerType => mapping(ObjectType parentType => mapping(ObjectType objectType => bool))) private _allowed;

    modifier onlyService() {
        NftId senderNftId = _nftIdByAddress[msg.sender]; 
        require(_info[senderNftId].objectType == SERVICE(), "ERROR:REG-002:NOT_SERVICE");
        _;
    }
    modifier onlyOwner() {
        require(getOwner() == msg.sender, "ERROR:REG-003:NOT_OWNER");
        _;
    } 

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
        _setRegistrables();
    }

    // Registration
    // what? -> who? -> how?
    // SERVICE()/TOKEN()/INSTANCE()/COMPONENT() -> only owner -> directly
    // INSTANCE() -> any address -> through SERVICE() (any not registered address)
    // COMPONENT() -> any address -> through SERVICE() (any not regisetred address, with role from INSTANCE() )
    // BUNDLE()/POLICY() -> only INSTANCE() -> directly  
    // assumption: Service_X will never register Instance/Component for Service_Y -> need to check whole chain from object to service...
    // assumption: Owner will behave well...
    // question: If unknown contract registers other contract and then itself became registred?
    // TODO: enforce "registration on the same hierarchy branch"
    function registerForService(address registrator, address registrable)
        external 
        override 
        onlyService() // only service capable of registring objects   register<-service
        returns(NftId nftId)
    {
        IRegisterable registrableContract = IRegisterable(registrable);
        ObjectInfo memory info = registrableContract.getInfo(); // TODO: provided by Service???

        return _registerContract(SERVICE(), registrator, registrable, info);
    }

    function registerService(address serviceAddress)
        external 
        override 
        //OnlyOwner()
        returns(NftId nftId)
    {
        IService service = IService(serviceAddress);
        require(
            service.supportsInterface(type(IService).interfaceId),
            "ERROR:REG-007:NOT_SERVICE"
        );
        ObjectInfo memory info = service.getInfo();

        nftId = _registerContract(REGISTRY(), getOwner(), serviceAddress, info);

        // special case services
        // assumption: Service is trusted contract 
        if(info.objectType == SERVICE()) { // afterServiceRegistration()
            string memory serviceName = service.getName();
            VersionPart majorVersion = service.getMajorVersion();
            bytes32 serviceNameHash = keccak256(abi.encode(serviceName));

            // service specific state
            _string[nftId] = serviceName;

            require(
                _service[serviceNameHash][majorVersion] == address(0),
                "ERROR:REG-008:ALREADY_REGISTERED"
            );
            _service[serviceNameHash][majorVersion] = serviceAddress;
        }
    }

    function registerToken(address token, ObjectInfo memory tokenInfo) 
        external
        override 
        //OnlyOwner()
        returns(NftId nftId)
    {
        return _registerContract(REGISTRY(), getOwner(), token, tokenInfo);
    }

    function registerForInstance(ObjectInfo memory object)
        external 
        override 
        returns(NftId nftId)
        //OnlyInstance()
    {
        NftId instanceNftId = _nftIdByAddress[msg.sender];
        require(_info[instanceNftId].objectType == INSTANCE(), "ERROR:REG-002:UNKNOWN_INSTANCE");

        require(_info[object.parentNftId].parentNftId == instanceNftId, "ERROR:REG_002:WRONG_INSTANCE");// mismatch

        return _registerObject(INSTANCE(), object);
    }

    // TODO is it possible to verify hash(contract.code + contract.storage)?
    // callerType -> registerForService() or other function
    // registrator -> who uses service to register something
    // registrable, info -> is what registered
    function _registerContract(ObjectType callerType, address registrator, address registrable, ObjectInfo memory info)
        internal  
        returns(NftId nftId)
    {
        require(_nftIdByAddress[registrable].eqz(), "ERROR:REG-002:ALREADY_REGISTERED");
        require(_nftIdByAddress[registrator].eqz(), "ERROR:REG-003:ALREADY_REGISTERED");// registred contract can not register another contract

        ObjectType parentType = _info[info.parentNftId].objectType;
        require(_allowed[callerType][parentType][info.objectType] == true);// type is valid, parent type is valid, parent is registered
        
        uint256 mintedTokenId = _chainNft.mint(
            info.initialOwner, // TODO any intrinsic for deployer address?
            EMPTY_URI);
        nftId = toNftId(mintedTokenId);

        info.nftId = nftId;
        info.objectAddress = registrable;

        _info[nftId] = info;
        _nftIdByAddress[registrable] = nftId;
    }

    function _registerObject(ObjectType callerType, ObjectInfo memory info)
        internal 
        returns(NftId nftId)
    {
        ObjectType parentType = _info[info.parentNftId].objectType;
        require(_allowed[callerType][parentType][info.objectType] == true);// type is valid, parent type is valid, parent is registered

        uint256 mintedTokenId = _chainNft.mint(
            info.initialOwner,
            EMPTY_URI);
        nftId = toNftId(mintedTokenId);

        info.nftId = nftId;
        info.objectAddress = address(0);

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

    function getInfo() public view returns (IRegistry.ObjectInfo memory info) {
        
        if(this.isRegistered(address(this))) {// TODO always registered?
            return this.getObjectInfo(address(this));
        }

        return IRegistry.ObjectInfo(
            zeroNftId(),
            getParentNftId(),
            REGISTRY(),
            address(this),
            _initialOwner, 
            getData()
        );  
    }

    function getType() public pure override returns (ObjectType objectType) {
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

    function getParentNftId() public view returns (NftId nftId) {
        // we're the global registry
        if(block.chainid == 1) {
            return toNftId(_chainNftInternal.PROTOCOL_NFT_ID());
        }
        else {
            return toNftId(_chainNftInternal.GLOBAL_REGISTRY_ID());
        }
    }

    function getData() public pure returns (bytes memory data) {
        return "";
    }

    function requireSenderIsOwner() external view override returns (bool senderIsOwner) {
        require(
            msg.sender == getOwner(),
            "ERROR:REG-020:NOT_OWNER"
        );

        return true;
    }

    function _setRegistrables() virtual internal 
    {
        // _allowed[function][object][parent]
        // for instance
        _allowed[SERVICE()][POLICY()][PRODUCT()] = true;
        _allowed[SERVICE()][BUNDLE()][POOL()] = true;

        // for service -> indirect
        _allowed[SERVICE()][PRODUCT()][INSTANCE()] = true;
        _allowed[SERVICE()][POOL()][INSTANCE()] = true;
        _allowed[SERVICE()][ORACLE()][INSTANCE()]= true;
        _allowed[SERVICE()][INSTANCE()][REGISTRY()] = true;
        
        // for owner 
        _allowed[REGISTRY()][SERVICE()][REGISTRY()] = true; 
        _allowed[REGISTRY()][TOKEN()][REGISTRY()] = true; 
    } 

    /// @dev protocol registration used to anchor the dip ecosystem relations
    function _registerProtocol() virtual internal {
        uint256 protocolId = _chainNftInternal.PROTOCOL_NFT_ID();
        _chainNftInternal.mint(_initialOwner, protocolId);// TODO protocol have 0 as owner?

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
    // TODO refactor
    /// @dev registry registration
    /// might also register the global registry when not on mainnet
    function _registerRegistry() virtual internal returns (NftId registryNftId) {
        uint256 registryId = _chainNftInternal.calculateTokenId(2);
        registryNftId = toNftId(registryId);

        // we're not the global registry
        if(registryId != _chainNftInternal.GLOBAL_REGISTRY_ID()) {
            _registerGlobalRegistry();// TODO return after call??
        }

        IRegistry.ObjectInfo memory info = getInfo();
        info.nftId = registryNftId;
        
        _chainNftInternal.mint(_initialOwner, registryId);

        _registerContract(REGISTRY(), msg.sender, address(this), info);
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
}