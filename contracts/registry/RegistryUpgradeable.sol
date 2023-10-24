// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin5/contracts/proxy/utils/Initializable.sol";

import {IRegisterable} from "../shared/IRegisterable.sol";
import {IService} from "../instance/base/IService.sol";

import {IChainNft} from "./IChainNft.sol";
import {ChainNft} from "./ChainNft.sol";
import {IRegistry} from "./IRegistry.sol";
import {NftId, toNftId, zeroNftId, NftIdLib} from "../types/NftId.sol";
import {Version, VersionPart, VersionLib} from "../types/Version.sol";
import {ObjectType, PROTOCOL, REGISTRY, TOKEN, SERVICE, INSTANCE, STAKE, PRODUCT, DISTRIBUTION, ORACLE, POOL, POLICY, BUNDLE} from "../types/ObjectType.sol";

import {VersionableUpgradeable} from "../shared/VersionableUpgradeable.sol";


/// IMPORTANT
// Upgradeable contract MUST:
// 1) inherit from Versionable
// 2) implement version() function
// 3) implement initialize() function with initializer modifier 
// 4) implement upgrade() function with reinitializer(version().toInt()) modifier
// 5) have onlyInitialising modifier for each function callable during deployment and/or upgrade
// 6) use default empty constructor -> _disableInitializer() called from Versionable contructor
// 7) use namespace storage
contract RegistryUpgradeable is
    VersionableUpgradeable,
    IRegisterable,
    IRegistry
{
    //--- constants -----------------------------------------------------------------
    string public constant EMPTY_URI = "";

    // keccak256(abi.encode(uint256(keccak256("etherisc.storage.Registry")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 internal constant STORAGE_LOCATION_V1 = 0x6548007c3f4340f82f348c576c0ff69f4f529cadd5ad41f96aae61abceeaa300;

    //--- storage layout -------------------------------------------------------------

    // @custom:storage-location erc7201:etherisc.storage.Registry
    struct StorageV1 {
        mapping(NftId nftId => ObjectInfo info) info;
        mapping(address object => NftId nftId) nftIdByAddress;
        mapping(ObjectType objectType => bool) isValidType;
        mapping(ObjectType objectType => mapping(ObjectType objectParentType => bool)) isValidParentType;

        mapping(NftId nftId => string stringValue) name;
        mapping(bytes32 serviceNameHash => mapping(VersionPart majorVersion => address service)) service;

        NftId nftId;
        IChainNft chainNft;
        ChainNft chainNftInternal;
        address initialOwner;
        /// @dev will own protocol nft and registry nft(s) minted during initialize
        address _protocolOwner;
    }

    //--- state --------------------------------------------------------------------

    //--- external/public state changing functions  --------------------------------

    function register(
        address objectAddress
    )
    // TODO add authz (only services may register components etc)
    // we have to check how we do authz for registring services (just restrict to protocol owner/registry owner)
        external
        virtual override
        returns (NftId nftId)
    {
        StorageV1 storage $ = _getStorageV1();

        require(
            $.nftIdByAddress[objectAddress].eqz(),
            "ERROR:REG-002:ALREADY_REGISTERED"
        );

        IRegisterable registerable = IRegisterable(objectAddress);
        require(
            registerable.supportsInterface(type(IRegisterable).interfaceId),
            "ERROR:REG-003:NOT_REGISTERABLE"
        );

        ObjectType objectType = registerable.getType();
        require(
            $.isValidType[objectType],
            "ERROR:REG-004:TYPE_INVALID"
        );

        NftId parentNftId = registerable.getParentNftId();
        require(
            isRegistered(parentNftId),
            "ERROR:REG-005:PARENT_NOT_REGISTERED"
        );

        require(
            $.isValidParentType[objectType][$.info[parentNftId].objectType],
            "ERROR:REG-006:PARENT_TYPE_INVALID"
        );

        // also check that nftId and parentNFtId are on the same chain if applicable

        // nft minting
        uint256 mintedTokenId = $.chainNft.mint(
            registerable.getOwner(),
            EMPTY_URI
        );

        nftId = toNftId(mintedTokenId);

        // special case services
        if(registerable.getType() == SERVICE()) {
            IService service = IService(objectAddress);
            require(
                service.supportsInterface(type(IService).interfaceId),
                "ERROR:REG-007:NOTservice"
            );

            string memory serviceName = service.getName();
            VersionPart majorVersion = service.getMajorVersion();
            bytes32 serviceNameHash = keccak256(abi.encode(serviceName));

            // service specific state
            $.name[nftId] = serviceName;

            require(
                $.service[serviceNameHash][majorVersion] == address(0),
                "ERROR:REG-008:ALREADY_REGISTERED"
            );
            $.service[serviceNameHash][majorVersion] = objectAddress;
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
        virtual override
        returns (
            // TODO add onlyRegisteredInstance
            NftId nftId
        )
    {
        StorageV1 storage $ = _getStorageV1();

        // TODO add more validation
        require(
            objectType == POLICY() || objectType == BUNDLE(),
            "ERROR:REG-010:TYPE_INVALID"
        );

        uint256 mintedTokenId = $.chainNft.mint(initialOwner, EMPTY_URI);
        nftId = toNftId(mintedTokenId);

        ObjectInfo memory info = ObjectInfo(
            nftId,
            parentNftId,
            objectType,
            address(0),
            initialOwner,
            data
        );

        $.info[nftId] = info;

        // add logging
    }

    //--- external/public view and pure functions  --------------------------------

    function getObjectCount() external view override returns (uint256) {
        return _getStorageV1().chainNft.totalSupply();
    }

    function getNftId(
        address object
    ) external view override returns (NftId id) {
        return _getStorageV1().nftIdByAddress[object];
    }

    function isRegistered(
        NftId nftId
    ) public view override returns (bool) {
        return _getStorageV1().info[nftId].objectType.gtz();
    }

    function isRegistered(
        address object
    ) external view override returns (bool) {
        return _getStorageV1().nftIdByAddress[object].gtz();
    }

    function getObjectInfo(
        NftId nftId
    ) external view override returns (ObjectInfo memory info) {
        return _getStorageV1().info[nftId];
    }

    function getName(
        NftId nftId
    ) external view returns (string memory name) {
        return _getStorageV1().name[nftId];
    }

    function getOwner(
        NftId nftId
    ) external view override returns (address) {
        return _getStorageV1().chainNft.ownerOf(nftId.toInt());
    }

    function getChainNft() external view override returns (IChainNft) {
        return _getStorageV1().chainNft;
    }

    // special case to retrive a gif service
    function getServiceAddress(
        string memory serviceName, 
        VersionPart majorVersion
    ) external view override returns (address serviceAddress) {
        bytes32 serviceNameHash = keccak256(abi.encode(serviceName));
        return _getStorageV1().service[serviceNameHash][majorVersion];
    }

    function getProtocolOwner() external view override returns (address) {
        return _getStorageV1()._protocolOwner;
    }

    //--- from Registerable --------------------------------------
    // TODO 
    // 1) Registerable can not register itself -> otherwise register have to trust owner address provided by registerable
    // registerable owner MUST call register and provide registerable address
    // it will work if component was delegate called ??? NO
    // owner-DELEGATE_CALL->component.register()-CALL->registryService->register()
    // owner-CALL->proxy-DELEGATE_CALL->compoment.register()-CALL->registryService->register()
    // 2) Who is msg.sender here???
    //  Registration of Instance or Service (any deployed by GIF contract) msg.sender is done in proxe contructor
    function register() external pure override returns (NftId nftId) {
        return zeroNftId();
    }

    function getType() external pure override returns (ObjectType objectType) {
        return REGISTRY();
    }

    function getOwner() public view override returns (address owner) {
        StorageV1 storage $ = _getStorageV1();
        return $.nftId.gtz() ? this.getOwner($.nftId) : $.initialOwner;
    }

    function getNftId() public view override (IRegisterable, IRegistry) returns (NftId nftId) {
        return _getStorageV1().nftId;
    }

    function getParentNftId() public view returns (NftId nftId) {
        StorageV1 storage $ = _getStorageV1();
        // we're the global registry
        /*if(block.chainid == 1) {
            return toNftId($.chainNftInternal.PROTOCOL_NFT_ID());
        }
        else {
            return toNftId($.chainNftInternal.GLOBAL_REGISTRY_ID());
        }*/
        nftId = $.info[$.nftId].parentNftId;
    }

    function getData() public pure returns (bytes memory data) {
        return "";
    }

    //--- from IRegistryLinked  --------------------------------------

    function getRegistry() external view override returns (IRegistry registry) {
        return this;
    }

    //--- from Versionable --------------------------------------

    /// @dev the protocol owner will get ownership of the
    // protocol nft and the global registry nft minted in this 
    // initializer function 
    function initialize(
        address implementation,
        address activatedBy,
        bytes memory data
    )
        public
        virtual override 
        initializer
    {
        _updateVersionHistory(implementation, activatedBy);
        _initializeV01(data);
    }

    // can not upgrade to the first version
    function upgrade(
        address implementation,
        address activatedBy,
        bytes memory data
    )
        external
        virtual
    {
        revert();
    }

    function getVersion() public pure virtual override returns (Version) {
        return VersionLib.toVersion(1, 0, 0);
    } 

    //--- IERC165 support -----------------------------------

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IRegistry).interfaceId;
    }

    //--- all intenal and private functions -----------------------------------

    function _initializeV01(bytes memory data) 
        internal 
        onlyInitializing
    {
        StorageV1 storage $ = _getStorageV1();

        require(
            address($.chainNft) == address(0),
            "ERROR:REG-001:ALREADY_INITIALIZED"
        );

        address protocolOwner = abi.decode(data, (address));
        $.initialOwner = msg.sender; // TODO here delegate call from proxy constructor, msg.sender is proxy deployer -> Proxy.sol
        $._protocolOwner = protocolOwner;

        // deploy NFT 
        $.chainNftInternal = new ChainNft(address(this));// adds 10kb to deployment size
        $.chainNft = IChainNft($.chainNftInternal);
        
        // initial registry setup
        _registerProtocol();
        $.nftId = _registerRegistry();

        // setup rules for further registrations
        _setupValidTypes();
        _setupValidParentTypes();
    }

    /// @dev defines which types are allowed to register
    function _setupValidTypes() internal onlyInitializing {
        StorageV1 storage $ = _getStorageV1();
        $.isValidType[REGISTRY()] = true; // only for global registry 
        $.isValidType[TOKEN()] = true;
        $.isValidType[SERVICE()] = true;
        $.isValidType[INSTANCE()] = true;
        $.isValidType[STAKE()] = true;
        $.isValidType[PRODUCT()] = true;
        $.isValidType[ORACLE()] = true;
        $.isValidType[POOL()] = true;
        $.isValidType[DISTRIBUTION()] = true;
        $.isValidType[POLICY()] = true;
        $.isValidType[BUNDLE()] = true;
    }

    /// @dev defines which types - parent type relations are allowed to register
    function _setupValidParentTypes() internal onlyInitializing {
        StorageV1 storage $ = _getStorageV1();
        // registry as parent
        $.isValidParentType[TOKEN()][REGISTRY()] = true;
        $.isValidParentType[SERVICE()][REGISTRY()] = true;
        $.isValidParentType[INSTANCE()][REGISTRY()] = true;

        // instance as parent
        $.isValidParentType[PRODUCT()][INSTANCE()] = true;
        $.isValidParentType[DISTRIBUTION()][INSTANCE()] = true;
        $.isValidParentType[ORACLE()][INSTANCE()] = true;
        $.isValidParentType[POOL()][INSTANCE()] = true;

        // product as parent
        $.isValidParentType[POLICY()][PRODUCT()] = true;

        // pool as parent
        $.isValidParentType[BUNDLE()][POOL()] = true;
        $.isValidParentType[STAKE()][POOL()] = true;
    }

    /// @dev protocol registration used to anchor the dip ecosystem relations
    function _registerProtocol() 
        virtual 
        internal
        onlyInitializing 
    {
        StorageV1 storage $ = _getStorageV1();

        uint256 protocolId = $.chainNftInternal.PROTOCOL_NFT_ID();
        $.chainNftInternal.mint($._protocolOwner, protocolId);

        NftId protocolNftid = toNftId(protocolId);
        ObjectInfo memory protocolInfo = ObjectInfo(
            protocolNftid,
            zeroNftId(), // parent nft id
            PROTOCOL(),
            address(0), // contract address
            $._protocolOwner,
            "" // data
        );

        $.info[protocolNftid] = protocolInfo;
    }

    /// @dev registry registration
    /// might also register the global registry when not on mainnet
    function _registerRegistry() 
        virtual 
        internal
        onlyInitializing 
        returns (NftId registryNftId) 
    {
        StorageV1 storage $ = _getStorageV1();

        uint256 registryId = $.chainNftInternal.calculateTokenId(2);
        registryNftId = toNftId(registryId);

        // we're not the global registry
        if(registryId != $.chainNftInternal.GLOBAL_REGISTRY_ID()) {
            _registerGlobalRegistry();
        }

        $.chainNftInternal.mint($._protocolOwner, registryId);

        // TODO error when deploying registry proxy 
        // in that case "this" is proxy address, "msg.sender" is proxy deployer, here in delegate call
        // _registerObjectInfo() treats "this" as "IRegisterable"
        // thus registerable.anyFunction() calls proxy... 
        /*_registerObjectInfo(this, registryNftId);*/

        NftId parentNftId;
        // we're the global registry
        if(block.chainid == 1) {
            parentNftId = toNftId($.chainNftInternal.PROTOCOL_NFT_ID());
        }
        else {
            parentNftId = toNftId($.chainNftInternal.GLOBAL_REGISTRY_ID());
        }
        ObjectInfo memory registryInfo = ObjectInfo(
            registryNftId,
            parentNftId, // registerable is proxy address, when in delegate call  
            REGISTRY(),
            address(this),  // proxy address
            $._protocolOwner, // registry owner is different from proxy owner 
            ""
        );

        $.info[registryNftId] = registryInfo;
        $.nftIdByAddress[address(this)] = registryNftId;

        // add logging
    }


    /// @dev global registry registration for non mainnet registries
    function _registerGlobalRegistry() 
        virtual 
        internal
        onlyInitializing
    {
        StorageV1 storage $ = _getStorageV1();

        uint256 globalRegistryId = $.chainNftInternal.GLOBAL_REGISTRY_ID();
        $.chainNftInternal.mint($._protocolOwner, globalRegistryId);

        NftId globalRegistryNftId = toNftId(globalRegistryId);
        ObjectInfo memory globalRegistryInfo = ObjectInfo(
            globalRegistryNftId,
            toNftId($.chainNftInternal.PROTOCOL_NFT_ID()),
            REGISTRY(),
            address(0), // contract address
            $._protocolOwner,
            "" // data
        );

        $.info[globalRegistryNftId] = globalRegistryInfo;
    }

    function _registerObjectInfo(
        IRegisterable registerable,
        NftId nftId
    ) 
        internal 
        virtual
        onlyInitializing
    {
        address objectAddress = address(registerable);
        ObjectInfo memory info = ObjectInfo(
            nftId,
            registerable.getParentNftId(), 
            registerable.getType(),
            objectAddress,
            registerable.getOwner(),
            registerable.getData()
        );

        StorageV1 storage $ = _getStorageV1();
        $.info[nftId] = info;
        $.nftIdByAddress[objectAddress] = nftId;

        // add logging
    }

    // TODO: private or internal ?
    // 1) new version have access only to its own storage slot (if previous versions did not expose theirs)
    //    - have to chain initializers
    //      + simple
    //      - slow/costly, initialization gas usage will grow faster then 1) 
    //      - initialization functions count/code likely will grow with each new version
    //    - new functions have access only to a local storage slot
    // 2) each intializer of each version have access to each "registry storage locations" he knows about -> 
    //    + no initializers chaining
    //    + new variables can be added to older versions storage hmmm...redefine storage struct 
    function _getStorageV1()
        private
        pure
        returns (StorageV1 storage s)
    {
        // solhint-disable no-inline-assembly
        assembly {
            s.slot := STORAGE_LOCATION_V1
        }
    }
}

/*
    **************** New implementation is set from delegate call ******************
    Implementation controled proxy?
    1). Proxy allows implV1 to change proxy.implementation variable to a new one (e.g. ImplV2) -> this is called reinitialization
    2). calls to proxy after reinitialization will point to new implementation -> like switching context -> old implementsations cuts itself from proxy
    2). Proxy can have:
        a). safe implementation which it uses after construction by default
            safe implementation allows one reinitialization to implementation needed (can be done in one call after initialization)
        b). two impelemtations
            the first for upgrades (have reinitialize function which changes the address the second one)
            the second for appication specific stuff
*/