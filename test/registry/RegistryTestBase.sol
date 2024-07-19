// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {FoundryRandom} from "foundry-random/FoundryRandom.sol";

import {console} from "../../lib/forge-std/src/Test.sol";

import {VersionPart} from "../../contracts/type/Version.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {ObjectType, ObjectTypeLib, PROTOCOL, REGISTRY, STAKING, SERVICE, INSTANCE, PRODUCT, POOL, ORACLE, DISTRIBUTION, DISTRIBUTOR, BUNDLE, POLICY, STAKE, STAKING} from "../../contracts/type/ObjectType.sol";

import {ChainNft} from "../../contracts/registry/ChainNft.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {ReleaseRegistry} from "../../contracts/registry/ReleaseRegistry.sol";
import {RegistryAdmin} from "../../contracts/registry/RegistryAdmin.sol";
import {TokenRegistry} from "../../contracts/registry/TokenRegistry.sol";
import {Staking} from "../../contracts/staking/Staking.sol";
import {StakingManager} from "../../contracts/staking/StakingManager.sol";
import {StakingStore} from "../../contracts/staking/StakingStore.sol";
import {StakingReader} from "../..//contracts/staking/StakingReader.sol";


import {RegisterableMock} from "../mock/RegisterableMock.sol";
import {RegistryServiceManagerMock} from "../mock/RegistryServiceManagerMock.sol";
import {RegistryServiceMock} from "../mock/RegistryServiceMock.sol";
import {ServiceMockAuthorizationV3} from "./ServiceMockAuthorizationV3.sol";

import {GifDeployer} from "../base/GifDeployer.sol";



contract RegistryTestBase is GifDeployer, FoundryRandom {

    // keep indentical to IRegistry events
    event LogRegistration(NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, address objectAddress, address initialOwner);
    event LogServiceRegistration(VersionPart majorVersion, ObjectType domain);
    event LogChainRegistryRegistration(NftId nftId, uint256 chainId, address registry);

    // keep identical to ChainNft events
    event LogTokenInterceptorAddress(uint256 tokenId, address interceptor);

    // keep identical to IERC721 events
    event Transfer(address indexed from, address indexed to, uint256 indexed value);    

    // keep identical to MockInterceptor events
    event LogNftMintIntercepted(address to, uint256 tokenId);

    VersionPart public constant VERSION = VersionPart.wrap(3);

    RegistryServiceManagerMock public registryServiceManagerMock;
    RegistryServiceMock public registryServiceMock;

    IERC20Metadata public dip;

    address public globalRegistry = makeAddr("globalRegistry"); // address of global registry when not on mainnet
    address public registryOwner = makeAddr("registryOwner");
    address public outsider = makeAddr("outsider");
    address public gifAdmin = registryOwner;
    address public gifManager = registryOwner;
    address public stakingOwner = registryOwner;

    AccessManager public accessManager;
    RegistryAdmin public registryAdmin;
    Registry public registry;
    ChainNft public chainNft;
    ReleaseRegistry public releaseRegistry;
    TokenRegistry public tokenRegistry;
    StakingManager public stakingManager;
    Staking public staking;
    StakingStore public stakingStore;
    StakingReader public stakingReader;

    address public _sender; // use with _startPrank(), _stopPrank()
    uint public _nextId; // use with chainNft.calculateId()

    NftId public protocolNftId = NftIdLib.toNftId(1101);
    NftId public globalRegistryNftId = NftIdLib.toNftId(2101);
    NftId public registryNftId; // chainId dependent
    NftId public stakingNftId; // chainId dependent

    IRegistry.ObjectInfo public protocolInfo;
    IRegistry.ObjectInfo public globalRegistryInfo; // chainId dependent
    IRegistry.ObjectInfo public registryInfo; // chainId dependent
    IRegistry.ObjectInfo public stakingInfo; // chainId dependent
    IRegistry.ObjectInfo public registryServiceInfo;// chainId dependent

    // test sets
    EnumerableSet.AddressSet internal _addresses; // set of all addresses (actors + contracts + initial owners) + zero address
    EnumerableSet.AddressSet internal _contractAddresses; // set of all contract addresses (registered + non registered)
    EnumerableSet.AddressSet internal _registeredAddresses; // set of all registered contract addresses
    // on mainnet: set of all registered chain registries addresses
    // not on mainnet: keeps only global registry
    EnumerableSet.AddressSet internal _withoutLookupAddresses; // set of all registered contracts which have no _nftIdByAddress[] set at registration (chain registries)
    // set of all registered contracts which have _nftIdByAddress[] set at registration (NOT chain registries)
    EnumerableSet.AddressSet internal _withLookupAddresses; // set of all registered contracts which have _nftIdByAddress[] set at registration (NOT chain registries)
    // TODO add max values to this sets?
    EnumerableSet.UintSet internal _nftIds; // set of all registered nfts + zero nft
    EnumerableSet.UintSet internal _types; // set of all core types + zero type

    mapping(address => string name) public _addressName;
    mapping(ObjectType objectType => string name) public _typeName;
    mapping(bytes4 errorSelector => string name) public _errorName;

    // track valid core types (registered through register() function only)
    mapping(ObjectType objectType => bool) public _isCoreType;

    // tracks valid core object-parent types combinations (registered through register() function only)
    mapping(ObjectType objectType => mapping(
            ObjectType parentType => bool)) public _isCoreContractTypesCombo;
    mapping(ObjectType objectType => mapping(
            ObjectType parentType => bool)) public _isCoreObjectTypesCombo;

    // tracks registered state
    mapping(NftId nftId => IRegistry.ObjectInfo info) public _info;
    mapping(address => NftId nftId) public _nftIdByAddress;

    // track registered service state
    mapping(VersionPart version => mapping(ObjectType serviceDomain => address)) public _service;

    // track registered registry state
    mapping(uint256 chanId => NftId registryNftId) public _registryNftIdByChainId;
    EnumerableSet.UintSet internal _chainIds;

    // aditional part to check service related getters
    struct ServiceInfo{
        VersionPart version;
        ObjectType domain;
    }
    mapping(NftId nftId => ServiceInfo) public _serviceInfo;

    uint public _servicesCount;

    // additional part to check registry related getters
    struct RegistryInfo{
        uint64 chainId;
    }
    mapping(NftId nftId => RegistryInfo) public _registryInfo;


    function setUp() public virtual
    {
        // solhint-disable
        console.log("tx origin", tx.origin);
        console.log("chain id", block.chainid);
        // solhint-enable

        bytes32 salt = "0x1234";

        (
            dip,
            registry,
            tokenRegistry,
            releaseRegistry,
            registryAdmin,
            stakingManager,
            staking
        ) = deployCore(
            globalRegistry,
            gifAdmin,
            gifManager,
            stakingOwner);

        accessManager = AccessManager(registryAdmin.authority()); 
        
        chainNft = ChainNft(registry.getChainNftAddress());
        registryNftId = registry.getNftIdForAddress(address(registry));

        stakingStore = staking.getStakingStore();
        stakingReader = staking.getStakingReader();
        stakingNftId = registry.getNftIdForAddress(address(staking));

        _startPrank(registryOwner);
        _deployRegistryServiceMock();
        _stopPrank();

        // Tests book keeping
        _afterDeployment();
    }

    function _deployRegistryServiceMock() internal
    {
        bytes32 salt = "0x5678";
        {
            releaseRegistry.createNextRelease();

            // TODO do we need preparation phase now?
            (
                address releaseAccessManager,
                VersionPart releaseVersion,
                bytes32 releaseSalt
            ) = releaseRegistry.prepareNextRelease(
                new ServiceMockAuthorizationV3(),
                salt);

            registryServiceManagerMock = new RegistryServiceManagerMock{salt: releaseSalt}(
                releaseAccessManager, 
                address(registry), 
                releaseSalt);
        }

        registryServiceMock = RegistryServiceMock(address(registryServiceManagerMock.getRegistryService()));
        releaseRegistry.registerService(registryServiceMock);
        registryServiceManagerMock.linkToProxy();
        registryServiceNftId = registry.getNftIdForAddress(address(registryServiceMock));

        releaseRegistry.activateNextRelease();
    }

    // ---------- tests state bookeeping ---------- //

    // call right after registry deployment, before checks
    function _afterDeployment() internal
    {
        // SECTION: Registered entries bookeeping

        protocolInfo = IRegistry.ObjectInfo(
                protocolNftId,
                NftIdLib.zero(),
                PROTOCOL(),
                false,
                address(0),
                registry.NFT_LOCK_ADDRESS(),
                ""
        );

        if(block.chainid == 1) 
        {
            // both are the  same
            globalRegistryInfo = IRegistry.ObjectInfo(
                globalRegistryNftId,
                protocolNftId,
                REGISTRY(),
                false,
                address(registry),
                registry.NFT_LOCK_ADDRESS(),
                "" 
            );

            registryNftId = globalRegistryNftId;
            registryInfo = globalRegistryInfo;
        }
        else
        {
            globalRegistryInfo = IRegistry.ObjectInfo(
                globalRegistryNftId,
                protocolNftId,
                REGISTRY(),
                false,
                globalRegistry,
                registry.NFT_LOCK_ADDRESS(),
                "" 
            );

            registryNftId = NftIdLib.toNftId(
                chainNft.calculateTokenId(registry.REGISTRY_TOKEN_SEQUENCE_ID())
            );

            registryInfo = IRegistry.ObjectInfo(
                registryNftId,
                globalRegistryNftId,
                REGISTRY(),
                false,
                address(registry),
                registry.NFT_LOCK_ADDRESS(),
                "" 
            );
        }

        stakingNftId = NftIdLib.toNftId(
            chainNft.calculateTokenId(registry.STAKING_TOKEN_SEQUENCE_ID())
        );

        stakingInfo = IRegistry.ObjectInfo(
            stakingNftId,
            registryNftId,
            STAKING(),
            false,
            address(staking), // must be without erc721 receiver support?
            stakingOwner,
            ""
        );

        registryServiceNftId = NftIdLib.toNftId(
            chainNft.calculateTokenId(registry.STAKING_TOKEN_SEQUENCE_ID() + 1)
        );

        registryServiceInfo = IRegistry.ObjectInfo(
            registryServiceNftId,
            registryNftId,
            SERVICE(),
            false,
            address(registryServiceMock), // must be without erc721 receiver support?
            registryOwner,
            ""
        );

        if(block.chainid == 1) {
            // protocol 1101 -> id 1
            // global registry 2101 -> id 2
            // global staking 3xxx -> id 3
            // global registry service 4xxx -> id 4
            require(registry.getObjectCount() == 4, "Test error: starting registry.objectCount() != 4 after deployment on mainnet");
            _nextId = 5;
        } else {
            // protocol 1101 -> id 1
            // global registry 2101 -> id 2
            // local registry 2xxxx -> id 2
            // local staking 3xxx -> id 3
            // local registry service 4xxx -> id 4
            require(registry.getObjectCount() == 5, "Test error: starting registry.objectCount() != 5 after deployment not on mainnet");
            _nextId = 5;
        }

        // special case: need 0 in _nftIds[] set, assume registry always have zeroObjectInfo registered as NftIdLib.zero
        _info[protocolNftId] = protocolInfo;
        _info[globalRegistryNftId] = globalRegistryInfo;
        _info[registryNftId] = registryInfo;
        _info[stakingNftId] = stakingInfo;
        _info[registryServiceNftId] = registryServiceInfo; 

        if(block.chainid == 1) {
            // now globalRegistry is the only registry and have address lookup set
            _nftIdByAddress[globalRegistryInfo.objectAddress] = globalRegistryNftId;
        } else {
            // now globalRegistry and registry are both registered but only registry have address lookup set
            _nftIdByAddress[registryInfo.objectAddress] = registryNftId;
        }
        _nftIdByAddress[address(staking)] = stakingNftId;
        _nftIdByAddress[address(registryServiceMock)] = registryServiceNftId;

        _service[VERSION][REGISTRY()] = address(registryServiceMock);
        _serviceInfo[registryServiceNftId] = ServiceInfo(VERSION, REGISTRY());
        _servicesCount = 1;

        _registryNftIdByChainId[1] = globalRegistryNftId;
        _registryNftIdByChainId[block.chainid] = registryNftId;

        EnumerableSet.add(_chainIds, 1);
        EnumerableSet.add(_chainIds, uint64(block.chainid));

        _registryInfo[globalRegistryNftId].chainId = 1;
        _registryInfo[registryNftId].chainId = uint64(block.chainid);

        // SECTION: Test sets 

        // special case: need 0 in _nftIds[] set, assume registry always have NftIdLib.zero but is not (and can not be) registered
        EnumerableSet.add(_nftIds, NftIdLib.zero().toInt());

        // registered nfts
        EnumerableSet.add(_nftIds, protocolNftId.toInt());
        EnumerableSet.add(_nftIds, globalRegistryNftId.toInt());
        EnumerableSet.add(_nftIds, registryNftId.toInt());
        EnumerableSet.add(_nftIds, stakingNftId.toInt());
        EnumerableSet.add(_nftIds, registryServiceNftId.toInt());

        // 0 is in the set because _addresses is not used for getters checks
        EnumerableSet.add(_addresses, address(0));
        EnumerableSet.add(_addresses, outsider);
        EnumerableSet.add(_addresses, registryOwner);
        EnumerableSet.add(_addresses, globalRegistryInfo.objectAddress);
        EnumerableSet.add(_addresses, registryInfo.objectAddress); // IMPORTANT: do not use as sender -> can not call itself
        EnumerableSet.add(_addresses, address(staking));
        EnumerableSet.add(_addresses, address(tokenRegistry));
        EnumerableSet.add(_addresses, address(releaseRegistry));
        EnumerableSet.add(_addresses, address(accessManager));
        EnumerableSet.add(_addresses, address(registryAdmin));
        EnumerableSet.add(_addresses, address(stakingManager));
        EnumerableSet.add(_addresses, address(stakingReader));
        EnumerableSet.add(_addresses, address(stakingStore));
        EnumerableSet.add(_addresses, address(chainNft));
        EnumerableSet.add(_addresses, address(registryServiceMock));

        // TODO add libraries addresses?
        EnumerableSet.add(_contractAddresses, globalRegistryInfo.objectAddress);
        EnumerableSet.add(_contractAddresses, registryInfo.objectAddress);
        EnumerableSet.add(_contractAddresses, address(staking));
        EnumerableSet.add(_contractAddresses, address(tokenRegistry));
        EnumerableSet.add(_contractAddresses, address(releaseRegistry));
        EnumerableSet.add(_contractAddresses, address(accessManager));
        EnumerableSet.add(_contractAddresses, address(registryAdmin));
        EnumerableSet.add(_contractAddresses, address(stakingManager));
        EnumerableSet.add(_contractAddresses, address(stakingReader));
        EnumerableSet.add(_contractAddresses, address(stakingStore));
        EnumerableSet.add(_contractAddresses, address(chainNft));
        EnumerableSet.add(_contractAddresses, address(registryServiceMock));

        EnumerableSet.add(_registeredAddresses, globalRegistryInfo.objectAddress);
        EnumerableSet.add(_registeredAddresses, registryInfo.objectAddress);
        EnumerableSet.add(_registeredAddresses, address(staking));
        EnumerableSet.add(_registeredAddresses, address(registryServiceMock));

        if(block.chainid == 1) {
            EnumerableSet.add(_withLookupAddresses, globalRegistryInfo.objectAddress);
            EnumerableSet.add(_withLookupAddresses, address(staking));
            EnumerableSet.add(_withLookupAddresses, address(registryServiceMock));
        } else {
            EnumerableSet.add(_withoutLookupAddresses, globalRegistryInfo.objectAddress);

            EnumerableSet.add(_withLookupAddresses, registryInfo.objectAddress);
            EnumerableSet.add(_withLookupAddresses, address(staking));
            EnumerableSet.add(_withLookupAddresses, address(registryServiceMock));
        }

        // also core types used in register() function
        // registerWithCustomType() disallow this types being registered
        EnumerableSet.add(_types, ObjectTypeLib.zero().toInt());
        EnumerableSet.add(_types, PROTOCOL().toInt());
        EnumerableSet.add(_types, REGISTRY().toInt());
        EnumerableSet.add(_types, SERVICE().toInt());
        EnumerableSet.add(_types, INSTANCE().toInt());
        EnumerableSet.add(_types, PRODUCT().toInt());
        EnumerableSet.add(_types, POOL().toInt());
        EnumerableSet.add(_types, DISTRIBUTION().toInt());
        EnumerableSet.add(_types, ORACLE().toInt());
        EnumerableSet.add(_types, POLICY().toInt());
        EnumerableSet.add(_types, BUNDLE().toInt());
        EnumerableSet.add(_types, DISTRIBUTOR().toInt());
        EnumerableSet.add(_types, STAKING().toInt());
        EnumerableSet.add(_types, STAKE().toInt());

        // SECTION: Valid object-parent types combinations

        // registry as parent
        _isCoreContractTypesCombo[INSTANCE()][REGISTRY()] = true;

        // instance as parent
        _isCoreContractTypesCombo[PRODUCT()][INSTANCE()] = true;
        _isCoreContractTypesCombo[DISTRIBUTION()][INSTANCE()] = true;
        _isCoreContractTypesCombo[POOL()][INSTANCE()] = true;
        _isCoreContractTypesCombo[ORACLE()][INSTANCE()] = true;

        // component as parent
        _isCoreObjectTypesCombo[DISTRIBUTOR()][DISTRIBUTION()] = true;
        _isCoreObjectTypesCombo[POLICY()][PRODUCT()] = true;
        _isCoreObjectTypesCombo[BUNDLE()][POOL()] = true;

        _isCoreObjectTypesCombo[STAKE()][PROTOCOL()] = true;
        _isCoreObjectTypesCombo[STAKE()][INSTANCE()] = true;

        // SECTION: Names for logging

        _typeName[ObjectTypeLib.zero()] = "ZERO";
        _typeName[PROTOCOL()] = "PROTOCOL";
        _typeName[REGISTRY()] = "REGISTRY";
        _typeName[STAKING()] = "STAKING";
        _typeName[SERVICE()] = "SERVICE";
        _typeName[INSTANCE()] = "INSTANCE";
        _typeName[PRODUCT()] = "PRODUCT";
        _typeName[POOL()] = "POOL";
        _typeName[ORACLE()] = "ORACLE";
        _typeName[DISTRIBUTION()] = "DISTRIBUTION";
        _typeName[DISTRIBUTOR()] = "DISTRIBUTOR";
        _typeName[POLICY()] = "POLICY";
        _typeName[BUNDLE()] = "BUNDLE";
        _typeName[STAKE()] = "STAKE";

        _addressName[registryOwner] = "registryOwner";
        _addressName[outsider] = "outsider";
        _addressName[globalRegistryInfo.objectAddress] = "GlobalRegistry";
        _addressName[registryInfo.objectAddress] = "Registry"; // global have name "Registry" on mainnet
        _addressName[address(staking)] = "Staking";
        _addressName[address(registryServiceMock)] = "registryServiceMock";
        
        _errorName[IAccessManaged.AccessManagedUnauthorized.selector] = "AccessManagedUnauthorized";
        _errorName[IRegistry.ErrorRegistryCallerNotDeployer.selector] = "ErrorRegistryCallerNotDeployer"; // TODO not used in tests!!!
        _errorName[IRegistry.ErrorRegistryNotOnMainnet.selector] = "ErrorRegistryNotOnMainnet";
        _errorName[IRegistry.ErrorRegistryChainRegistryChainidZero.selector] = "ErrorRegistryChainRegistryChainidZero";
        _errorName[IRegistry.ErrorRegistryChainRegistryAddressZero.selector] = "ErrorRegistryChainRegistryAddressZero";
        _errorName[IRegistry.ErrorRegistryChainRegistryNftIdInvalid.selector] = "ErrorRegistryChainRegistryNftIdInvalid";
        _errorName[IRegistry.ErrorRegistryChainRegistryAlreadyRegistered.selector] = "ErrorRegistryChainRegistryAlreadyRegistered";
        _errorName[IRegistry.ErrorRegistryServiceAddressZero.selector] = "ErrorRegistryServiceAddressZero";
        //_errorName[IRegistry.ErrorRegistryServiceVersionMismatch.selector] = "ErrorRegistryServiceVersionMismatch";
        //_errorName[IRegistry.ErrorRegistryServiceVersionNotDeploying.selector] = "ErrorRegistryServiceVersionNotDeploying";
        _errorName[IRegistry.ErrorRegistryServiceDomainZero.selector] = "ErrorRegistryServiceDomainZero";
        _errorName[IRegistry.ErrorRegistryNotService.selector] = "ErrorRegistryNotService";
        _errorName[IRegistry.ErrorRegistryServiceParentNotRegistry.selector] = "ErrorRegistryServiceParentNotRegistry";
        _errorName[IRegistry.ErrorRegistryServiceDomainAlreadyRegistered.selector] = "ErrorRegistryServiceDomainAlreadyRegistered";
        _errorName[IRegistry.ErrorRegistryCoreTypeRegistration.selector] = "ErrorRegistryCoreTypeRegistration";
        _errorName[IRegistry.ErrorRegistryGlobalRegistryAsParent.selector] = "ErrorRegistryGlobalRegistryAsParent";
        _errorName[IRegistry.ErrorRegistryTypesCombinationInvalid.selector] = "ErrorRegistryTypesCombinationInvalid";
        _errorName[IRegistry.ErrorRegistryContractAlreadyRegistered.selector] = "ErrorRegistryContractAlreadyRegistered";
        _errorName[IERC721Errors.ERC721InvalidReceiver.selector] = "ERC721InvalidReceiver";
    }

    // call after every succesfull registration with register() or registerWithCustomType() functions, before checks
    function _afterRegistration(
        IRegistry.ObjectInfo memory info
    )
     internal virtual
    {
        _nextId++;

        NftId nftId = info.nftId;

        assertEq(_info[nftId].nftId.toInt(), 0, "Test error: _info[nftId].nftId already set #1");
        _info[nftId] = info;
        
        assertFalse(EnumerableSet.contains(_nftIds, info.nftId.toInt()), "Test error: _nftIds already contains nftId #1");
        EnumerableSet.add(_nftIds , nftId.toInt());

        EnumerableSet.add(_addresses, info.initialOwner);

        if(info.objectAddress > address(0)) {

            assertEq(_nftIdByAddress[info.objectAddress].toInt(), 0, "Test error: _nftIdByAddress[address] already set");
            _nftIdByAddress[info.objectAddress] = nftId;

            if(EnumerableSet.contains(_withoutLookupAddresses, info.objectAddress)) {// chain registry have same address as registered contract
                assertTrue(EnumerableSet.contains(_registeredAddresses, info.objectAddress), "Test error: _registeredAddresses does not contain objectAddress");
            } else { // no chain registry with same address -> contract not in registered addresses set
                assertFalse(EnumerableSet.contains(_registeredAddresses, info.objectAddress), "Test error: _registeredAddresses already contains objectAddress");
            }

            //assertFalse(EnumerableSet.contains(_addresses, info.objectAddress), "Test error: _addresses already contains objectAddress"); // previously initial owner can become registerable
            //assertFalse(EnumerableSet.contains(_contractAddresses, info.objectAddress), "Test error: _contractAddresses already contains objectAddress"); // previously member of _contractAddresses becomes registered
            EnumerableSet.add(_addresses, info.objectAddress);
            EnumerableSet.add(_registeredAddresses, info.objectAddress);
            EnumerableSet.add(_contractAddresses, info.objectAddress);

            assertFalse(EnumerableSet.contains(_withLookupAddresses, info.objectAddress), "Test error: _withLookupAddresses already contains objectAddress");
            EnumerableSet.add(_withLookupAddresses, info.objectAddress);
        }

        // check registered object right away to spot errors early
        //_assert_registry_getters(nftId, info.initialOwner);//, _serviceInfo[info.nftId].version, _serviceInfo[info.nftId].domain, info.initialOwner, _registryInfo[nftId].chainId);
    }

    function _afterRegistrationWithCustomType(IRegistry.ObjectInfo memory info) internal
    {
        assertFalse(EnumerableSet.contains(_types, info.objectType.toInt()), "Test error: _afterRegistrationWithCustomType() called with core type object");
        _afterRegistration(info);
    }


    // call after every succesfull registration with registerService() function, before checks
    function _afterServiceRegistration(IRegistry.ObjectInfo memory info, VersionPart version, ObjectType domain) internal 
    {
        assertEq(info.objectType.toInt(), SERVICE().toInt(), "Test error: _afterServiceRegistration() called with non-service object");
        assertNotEq(version.toInt(), 0, "Test error: _afterServiceRegistration() called with version 0");
        assertNotEq(domain.toInt(), 0, "Test error: _afterServiceRegistration() called with domain 0");

        NftId nftId = info.nftId;
        assertEq(_service[version][domain], address(0), "Test error: _service[version][domain] already set");
        assertEq(_serviceInfo[nftId].version.toInt(), 0, "Test error: _serviceInfo[nftId].version already set");
        assertEq(_serviceInfo[nftId].domain.toInt(), 0, "Test error: _serviceInfo[nftId].domain already set");
        _service[version][domain] = info.objectAddress;
        _serviceInfo[nftId] = ServiceInfo(version, domain);
        _servicesCount++;

        _afterRegistration(info);
    }

    function _afterRegistryRegistration(NftId nftId, uint64 chainId, address registryAddress) internal
    {
        assertTrue(block.chainid == 1, "Test error: _afterRegistryRegistration() called not on mainnet");
        assertTrue(registryAddress != address(0), "Test error: _afterRegistryRegistration() is called with 0 registry address");
        //assertNotEq(registry, globalRegistryInfo.objectAddress, "Test error: _afterRegistryRegistration() called with globalRegistry address"); // chain registry can have global address

        assertEq(nftId.toInt(), chainNft.calculateTokenId(registry.REGISTRY_TOKEN_SEQUENCE_ID(), chainId), "Test error: _registryNftIdByChainId[chainId] inconsictent with chainNft.calculateTokenId[REGISTRY_TOKEN_SEQUENCE_ID, chainId]");
        assertTrue(_registryNftIdByChainId[chainId].eqz(), "Test error: _registryNftIdByChainId[chainId] already set");
        assertFalse(EnumerableSet.contains(_chainIds, chainId), "Test error: _chainIds[] already contains chainId"); 

        _registryNftIdByChainId[chainId] = nftId;
        EnumerableSet.add(_chainIds, chainId);
        _registryInfo[nftId].chainId = chainId;

        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            globalRegistryNftId,
            REGISTRY(),
            false, // isInterceptor
            registryAddress,
            registryInfo.initialOwner,
            ""
        );

        // store info without address lookup and _nextId increment
        NftId nftId = info.nftId;

        assertEq(_info[nftId].nftId.toInt(), 0, "Test error: _info[nftId].nftId already set #2");
        _info[nftId] = info;
        

        // update test sets
        assertFalse(EnumerableSet.contains(_nftIds, info.nftId.toInt()), "Test error: _nftIds already contains nftId #2");
        EnumerableSet.add(_nftIds , nftId.toInt());

        EnumerableSet.add(_addresses, info.initialOwner);

        // can have arbitrary number of chain registries but only 1 NON chain registry contract with same address
        if(EnumerableSet.contains(_registeredAddresses, info.objectAddress)) { // non registry contract and(or) chain registry(ies) with such address is already registered
            if(EnumerableSet.contains(_withLookupAddresses, info.objectAddress)) { // non registry contract with such address is already registered
                assertTrue(_nftIdByAddress[info.objectAddress].gtz(), "Test error: _nftIdByAddress[info.objectAddress] not set for registered contract");
            }
        } else { // no contract or chain registry with such address is registered
            assertFalse(EnumerableSet.contains(_withoutLookupAddresses, info.objectAddress), "Test error: _withoutLookupAddresses already contains objectAddress");
            assertFalse(EnumerableSet.contains(_withLookupAddresses, info.objectAddress), "Test error: _withLookupAddresses already contains objectAddress");
        }

        EnumerableSet.add(_addresses, info.objectAddress);
        EnumerableSet.add(_registeredAddresses, info.objectAddress);
        EnumerableSet.add(_contractAddresses, info.objectAddress);

        //assertFalse(EnumerableSet.contains(_withoutLookupAddresses, info.objectAddress), "Test error: _withoutLookupAddresses already contains objectAddress"); // chain registries can have same addresses
        EnumerableSet.add(_withoutLookupAddresses, info.objectAddress);
    }

    // ----------- getters checks ----------- //

    // assert all getters (with each registered nftId / address)
    function _checkRegistryGetters() internal
    {
        // solhint-disable-next-line
        //console.log("Checking all Registry getters");

        // check getters without args
        //console.log("   checking getters without args");

        assertEq(registry.getChainNftAddress(), address(chainNft), "getChainNftAddress() returned unexpected value");
        assertEq(registry.getReleaseRegistryAddress(), address(releaseRegistry), "getReleaseRegistryAddress() returned unexpected value");
        assertEq(registry.getStakingAddress(), address(staking), "getStakingAddress() returned unexpected value");
        assertEq(registry.getTokenRegistryAddress(), address(tokenRegistry), "getTokenRegistryAddress() returned unexpected value");
        assertEq(registry.getRegistryAdminAddress(), address(registryAdmin), "getRegistryAdminAddress() returned unexpected value");
        assertEq(registry.getAuthority(), address(registryAdmin.authority()), "getAuthority() returned unexpected value");

        assertEq(registry.getObjectCount(), EnumerableSet.length(_nftIds) - 1, "getObjectCount() returned unexpected value");// -1 because of NftIdLib.zero in the set
        assertEq(registry.getOwner(), registryInfo.initialOwner, "getOwner() returned unexpected value");
        assertEq(registry.getNftId().toInt(), registryNftId.toInt(), "getNftId() returned unexpected value");
        assertEq(registry.getProtocolNftId().toInt(), protocolNftId.toInt(), "getProtocolNftId() returned unexpected value");

        // TODO mirror release state in local state, use it in this checks
        assertEq(registry.getInitialVersion().toInt(), VERSION.toInt(), "getInitialVersion() returned unexpected value");
        // next version points to: 
        // 1. "initial version - 1" if 0 releases where ever created 
        // 2. the version undergoing deployment  
        // 3. the latest activated version if no new releases where created since then
        assertEq(registry.getNextVersion().toInt(), VERSION.toInt(), "getNextVersion() returned unexpected value");
        assertEq(registry.getLatestVersion().toInt(), VERSION.toInt(), "getLatestVersion() returned unexpected value");


        // check for zero address
        //console.log("   checking with 0 address");

        assertEq(registry.getNftId( address(0) ).toInt(), NftIdLib.zero().toInt(), "getNftId(0) returned unexpected value");
        assertTrue(eqObjectInfo(registry.getObjectInfo( address(0) ), zeroObjectInfo()), "getObjectInfo(0) returned unexpected value");
        assertFalse(registry.isRegistered( address(0) ), "isRegistered(0) returned unexpected value");
        assertFalse(registry.isRegisteredService( address(0) ), "isRegisteredService(0) returned unexpected value");
        assertFalse(registry.isRegisteredComponent( address(0) ), "isRegisteredComponent(0) returned unexpected value");

        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, NftIdLib.zero().toInt()));
        registry.ownerOf(address(0));


        // check for zeroNftId    
        //console.log("   checking with 0 nftId");

        assertTrue(eqObjectInfo(registry.getObjectInfo(NftIdLib.zero()), zeroObjectInfo()), "getObjectInfo(zeroNftId) returned unexpected value");
        assertFalse(registry.isRegistered(NftIdLib.zero()), "isRegistered(zeroNftId) returned unexpected value");

        NftId zero = NftIdLib.zero();
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, zero.toInt()));
        registry.ownerOf(zero);


        // check for random non registered nftId
        //console.log("   checking with random not registered nftId"); 
        NftId unknownNftId;
        do {
            unknownNftId = NftIdLib.toNftId(randomNumber(type(uint96).max));
        } while(EnumerableSet.contains(_nftIds, unknownNftId.toInt())); 
        _assert_registry_getters(
            unknownNftId,
            address(0) // owner
        );

        // loop through every registered nftId
        // _nftIds[] MUST contain NftIdLib.zero() -> why? -> already checked getters with 0 nftId?
        uint servicesFound = 0;
        uint registriesFound = 0;

        for(uint nftIdx = 0; nftIdx < EnumerableSet.length(_nftIds); nftIdx++)
        {
            NftId nftId = NftIdLib.toNftId(EnumerableSet.at(_nftIds, nftIdx));

            assertNotEq(nftId.toInt(), unknownNftId.toInt(), "Test error: unknownfNftId can not be registered");
            assertEq(nftId.toInt(), _info[nftId].nftId.toInt(), "Test error: _info[someNftId].nftId != someNftId");

            address owner;
            if(nftId == NftIdLib.zero()) 
            {// special case: not registered, has 0 owner
                owner = address(0);
            } else {
                owner = chainNft.ownerOf(nftId.toInt());
            }

            //console.log("   checking with nftId from set, nftId: ", nftId.toInt());
            _assert_registry_getters(
                nftId, // can call with non zero nftId while _info[nftId] is zero
                owner
            );

            // special case service
            if(_info[nftId].objectType == SERVICE())
            {
                servicesFound++;
                assertTrue(_servicesCount >= servicesFound, "Test error: found more registered services than expected");
            }

            // special case registry
            if(_info[nftId].objectType == REGISTRY())
            {
                registriesFound++;
                assertTrue(EnumerableSet.length(_chainIds) >= registriesFound, "Test error: found more registered registries than expected");
            }
        }

        assertEq(_servicesCount, servicesFound, "Test error: found less registered services than expected");
        assertEq(EnumerableSet.length(_chainIds), registriesFound, "Test error: found less registered registries than expected");

        // loop through every registered chainId 
        assertEq(registry.chainIds(), EnumerableSet.length(_chainIds), "getChainIds() returned unexpected value");
        for(uint i = 0; i < EnumerableSet.length(_chainIds); i++)
        {
            uint64 chainId = uint64(EnumerableSet.at(_chainIds, i));
            assertEq(registry.getChainId(i), chainId, "getChainId(i) returned unexpected value");

            NftId nftId = _registryNftIdByChainId[chainId];
            assertEq(registry.getRegistryNftId(chainId).toInt(), nftId.toInt(), "getRegistryNftId(chainId) returned unexpected value");

            // redundant calls?
            assertEq(registry.getObjectInfo(nftId).objectType.toInt(), REGISTRY().toInt(), "getObjectInfo(nftId).objectType returned unexpected value");
            _assert_registry_getters(
                nftId,
                chainNft.ownerOf(nftId.toInt()) // owner
            );
        }
    }

    // assert getters related to a single nftId
    function _assert_registry_getters(
        NftId nftId, // can be called with non zero nftId while _info[nftId] is zero
        address expectedOwner)

        internal
    {   
        IRegistry.ObjectInfo memory expectedInfo = _info[nftId];

        address expectedParentAddress = _info[expectedInfo.parentNftId].objectAddress;
        ObjectType expectedParentType = _info[expectedInfo.parentNftId].objectType;

        VersionPart expectedVersion = _serviceInfo[nftId].version;
        ObjectType expectedDomain = _serviceInfo[nftId].domain;

        uint64 expectedChainId = _registryInfo[nftId].chainId;

        // check "by nftId getters"
        //console.log("       checking by nftId getters with nftId ", nftId.toInt());

        assertTrue(eqObjectInfo(registry.getObjectInfo(nftId), expectedInfo), "getObjectInfo(nftId) returned unexpected value");

        // only objectType & initialOwner are never 0 for registered something
        assertEq(expectedInfo.initialOwner == address(0), expectedInfo.objectType.eqz(), "Test error: expected objectType is inconsistent with expected initialOwner");

        if(expectedInfo.objectType.gtz()) { // expect registered
        
            if(nftId == protocolNftId) {// special case: parentType == 0 for protocolNftId
                assertTrue(expectedParentType.eqz(), "Test error: parent type is not zero for protocol nftId");
            } else {
                assertTrue(expectedParentType.gtz(), "Test error: parent type is zero for registered nftId");
            }

            assertTrue(registry.isRegistered(nftId), "isRegistered(nftId) returned unexpected value #1");
            assertEq(registry.ownerOf(nftId), expectedOwner, "ownerOf(nftId) returned unexpected value");
        }
        else {// expect not registered
            assertTrue(expectedParentType.eqz(), "Test error: expected parent type is not zero for non regitered nftId");

            assertFalse(registry.isRegistered(nftId), "isRegistered(nftId) returned unexpected value #2"); 
            vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, nftId));
            registry.ownerOf(nftId);
        }

        // check "by address getters"
        //console.log("       checking by address getters with nftId ", nftId.toInt());

        if(nftId == protocolNftId) 
        {// special case: expected objectAddress == 0 for protocolNftId
            //require(false, "_assert_registry_getters reached point 1");
            assertTrue(eqObjectInfo(expectedInfo, protocolInfo), "Test error: _info[protocolNftId] != protocolInfo");
            assertEq(_nftIdByAddress[protocolInfo.objectAddress].toInt(), 0, "Test error: _nftIdByAddress[protocol] != 0");
            assertEq(_registryNftIdByChainId[expectedChainId].toInt(), 0, "Test error: protocol _registryNftIdByChainId[chainId] != 0");

            assertTrue(eqObjectInfo(registry.getObjectInfo(protocolInfo.objectAddress), zeroObjectInfo()), "getObjectInfo(address) returned unexpected value #1");
            assertEq(registry.getNftId(protocolInfo.objectAddress).toInt(), 0, "getNftId(address) returned unexpected value #1");
            assertEq(registry.isRegistered(protocolInfo.objectAddress), false, "isRegistered(address) returned unexpected value #1");
            vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 0));
            registry.ownerOf(protocolInfo.objectAddress);

            assertEq(registry.isRegisteredComponent(protocolInfo.objectAddress), false, "isRegisteredComponent(address) returned unexpected value #1");

            assertEq(registry.isRegisteredService(protocolInfo.objectAddress), false, "isRegisteredService(address) returned unexpected value #1");
            assertEq(registry.getServiceAddress(expectedDomain, expectedVersion) , address(0), "getServiceAddress(domain, version) returned unexpected value #1");

            assertEq(registry.getRegistryNftId(expectedChainId).toInt(), 0, "getRegistryNftId(chainId) returned unexpected value #1");
        } 
        else if(nftId == globalRegistryNftId) 
        {
            assertTrue(eqObjectInfo(expectedInfo, globalRegistryInfo), "Test error: _info[globalRegistryNftId] != globalRegistryInfo");
            assertEq(_registryNftIdByChainId[expectedChainId].toInt(), globalRegistryNftId.toInt(), "Test error: _registryNftIdByChainId[chainId] != globalRegistryNftId");

            if(block.chainid == 1) 
            { // mainnet: address look up is set ONLY for global registry, chain registries can have global address
                //require(false, "_assert_registry_getters reached point 2");
                assertTrue(EnumerableSet.contains(_withLookupAddresses, globalRegistryInfo.objectAddress), "Test error: _withLookupAddresses does not contain globalRegistry on mainnet");

                assertEq(_nftIdByAddress[globalRegistryInfo.objectAddress].toInt(), globalRegistryNftId.toInt(), "Test error: _nftIdByAddress[globalRegistry] != globalRegistryNftId");
                // by address getters return global registry related
                assertTrue(eqObjectInfo(registry.getObjectInfo(globalRegistryInfo.objectAddress), globalRegistryInfo), "getObjectInfo(address) returned unexpected value #2");
                assertEq(registry.getNftId(globalRegistryInfo.objectAddress).toInt(), globalRegistryNftId.toInt(), "getNftId(address) returned unexpected value #2");
                assertEq(registry.isRegistered(globalRegistryInfo.objectAddress), true, "isRegistered(address) returned unexpected value #2");
                assertEq(registry.ownerOf(globalRegistryInfo.objectAddress), globalRegistryInfo.initialOwner, "ownerOf(address) returned unexpected value #2");

                assertEq(registry.isRegisteredComponent(globalRegistryInfo.objectAddress), false, "isRegisteredComponent(address) returned unexpected value #2");

                assertEq(registry.isRegisteredService(globalRegistryInfo.objectAddress), false, "isRegisteredService(address) returned unexpected value #2");
                assertEq(registry.getServiceAddress(expectedDomain, expectedVersion) , address(0), "getServiceAddress(domain, version) returned unexpected value #2");
            } 
            else 
            {// not mainnet: address look up is NOT set ONLY for global registry, no other registries
                assertTrue(EnumerableSet.contains(_withoutLookupAddresses, globalRegistryInfo.objectAddress), "Test error: _withoutLookupAddresses does not contain globalRegistry when not on mainnet");
                assertEq(EnumerableSet.length(_withoutLookupAddresses), 1, "Test error: _withoutLookupAddresses must contain only globalRegistry, only 1 element when not on mainnet");

                if(EnumerableSet.contains(_withLookupAddresses, globalRegistryInfo.objectAddress)) 
                {// contract with same address is registered -> check this contract is not REGISTRY
                    //require(false, "_assert_registry_getters reached point 3");
                    NftId nonRegistryContractNftId = _nftIdByAddress[globalRegistryInfo.objectAddress];
                    IRegistry.ObjectInfo memory nonRegistryContractInfo = _info[nonRegistryContractNftId];
                    address nonRegistryContractOwner = chainNft.ownerOf(nonRegistryContractNftId.toInt());
                    ObjectType nonRegistryContractDomain = _serviceInfo[nonRegistryContractNftId].domain;
                    VersionPart nonRegistryContractVersion = _serviceInfo[nonRegistryContractNftId].version;

                    assertTrue(nonRegistryContractNftId.gtz(), "Test error: _nftIdByAddress[nonRegistryContractNftId] == 0 #1");
                    assertTrue(nonRegistryContractInfo.objectType != REGISTRY(), "Test error: _info[nonRegistryContractNftId].objectType == REGISTRY #1");
                    // check they indeed have address collision
                    assertTrue(nonRegistryContractInfo.objectAddress == globalRegistryInfo.objectAddress, "Test error: _info[nonRegistryContractNftId].objectAddress != globalRegistryInfo.objectAddress");
                }
                else
                {// no contract with same address is NOT registered
                    //require(false, "_assert_registry_getters reached point 4");
                    assertEq(_nftIdByAddress[globalRegistryInfo.objectAddress].toInt(), 0, "Test error: _nftIdByAddress[globalRegistry] != 0 #1");
                    assertEq(_nftIdByAddress[expectedInfo.objectAddress].toInt(), 0, "Test error: _nftIdByAddress[globalRegistry] != 0 #2");

                    // by address getters return 0
                    assertTrue(eqObjectInfo(registry.getObjectInfo(globalRegistryInfo.objectAddress), zeroObjectInfo()), "getObjectInfo(address) returned unexpected value #2.2");
                    assertEq(registry.getNftId(globalRegistryInfo.objectAddress).toInt(), 0, "getNftId(address) returned unexpected value #2.2");
                    assertEq(registry.isRegistered(globalRegistryInfo.objectAddress), false, "isRegistered(address) returned unexpected value #2.2");
                    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 0));
                    registry.ownerOf(globalRegistryInfo.objectAddress);

                    assertEq(registry.isRegisteredComponent(globalRegistryInfo.objectAddress), false, "isRegisteredComponent(address) returned unexpected value #2.3");

                    assertEq(registry.isRegisteredService(globalRegistryInfo.objectAddress), false, "isRegisteredService(address) returned unexpected value #2.3");
                    assertEq(registry.getServiceAddress(expectedDomain, expectedVersion) , address(0), "getServiceAddress(domain, version) returned unexpected value #2.3");
                }
            }

            assertEq(registry.getRegistryNftId(expectedChainId).toInt(), globalRegistryNftId.toInt(), "getRegistryNftId(chainId) returned unexpected value #2");
        } 
        else if(nftId == registryNftId)
        {// not mainnet, registry have address lookup set
            //require(false, "_assert_registry_getters reached point 5");
            assertTrue(eqObjectInfo(expectedInfo, registryInfo), "Test error: _info[registryNftId] != registryInfo");
            assertEq(_nftIdByAddress[expectedInfo.objectAddress].toInt(), registryNftId.toInt(), "Test error: _nftIdByAddress[address] != registryNftId");
            assertEq(_registryNftIdByChainId[expectedChainId].toInt(), registryNftId.toInt(), "Test error: _registryNftIdByChainId[chainId] != registryNftId");

            assertTrue(eqObjectInfo(registry.getObjectInfo(registryInfo.objectAddress), registryInfo), "getObjectInfo(address) returned unexpected value #3");
            assertEq(registry.getNftId(registryInfo.objectAddress).toInt(), registryNftId.toInt(), "getNftId(address) returned unexpected value #3");
            assertEq(registry.isRegistered(registryInfo.objectAddress), true, "isRegistered(address) returned unexpected value #3");
            assertEq(registry.ownerOf(registryInfo.objectAddress), registryInfo.initialOwner, "ownerOf(address) returned unexpected value #3");

            assertEq(registry.isRegisteredComponent(registryInfo.objectAddress), false, "isRegisteredComponent(address) returned unexpected value #3");

            assertEq(registry.isRegisteredService(registryInfo.objectAddress), false, "isRegisteredService(address) returned unexpected value #3");
            assertEq(registry.getServiceAddress(expectedDomain, expectedVersion) , address(0), "getServiceAddress(domain, version) returned unexpected value #3");

            assertEq(registry.getRegistryNftId(expectedChainId).toInt(), registryNftId.toInt(), "getRegistryNftId(chainId) returned unexpected value #3"); 
        } 
        else if(expectedInfo.objectType == REGISTRY()) 
        {// mainnet, chain registry
            // 1. global registry is the only registry with address lookup set 
            // 2. arbitrary number of chain registries without address lookup is registered (any can have global address)
            // 3. for each unique chain registry address 1 other contract with same address can be registered (global registry is an example of such contract, registered by default)
            assertEq(block.chainid, 1, "Found registered chain registry when not on mainnet");
            assertTrue(EnumerableSet.contains(_withoutLookupAddresses, expectedInfo.objectAddress), "Test error: _withoutLookupAddresses does not contain registered chain registry on mainnet");

            assertNotEq(expectedInfo.objectAddress, address(0), "Test error: chain registry address == 0");
            assertEq(expectedInfo.initialOwner, registryInfo.initialOwner, "Test error: chain registry initialOwner != NFT_LOCK_ADDRESS");

            assertEq(_registryNftIdByChainId[expectedChainId].toInt(), expectedInfo.nftId.toInt(), "Test error: chain registry _registryNftIdByChainId[chainId] != _info[nftId].nftId");
            // mainnet:

            // in case expectedInfo.objectAddress = globqlRegistry address -> globalRegistryInfo
            if(EnumerableSet.contains(_withLookupAddresses, expectedInfo.objectAddress)) 
            {// contract with same address is registered, check it is not REGISTRY
                NftId nonRegistryContractNftId = _nftIdByAddress[expectedInfo.objectAddress];
                IRegistry.ObjectInfo memory nonRegistryContractInfo = _info[nonRegistryContractNftId];


                assertTrue(nonRegistryContractNftId.gtz(), "Test error: _nftIdByAddress[nonRegistryContractNftId] == 0 #2");

                // exception: global registry is the only member of _withLookupAddresses and REGISTRY type
                if(nonRegistryContractInfo.objectAddress != globalRegistryInfo.objectAddress) {
                    //require(false, "_assert_registry_getters reached point 6");
                    assertTrue(nonRegistryContractInfo.objectType != REGISTRY(), "Test error: _info[nonRegistryContractNftId].objectType == REGISTRY #2");
                }

                // check they indeed have address collision
                assertTrue(nonRegistryContractInfo.objectAddress == expectedInfo.objectAddress, "Test error: _info[nonRegistryContractNftId].objectAddress != expectedInfo.objectAddress");
            } 
            else 
            {// no contract with same address is not registered
                //require(false, "_assert_registry_getters reached point 7");
                assertEq(_nftIdByAddress[expectedInfo.objectAddress].toInt(), 0, "Test error: _nftIdByAddress[registry] != 0");

                assertTrue(eqObjectInfo(registry.getObjectInfo(expectedInfo.objectAddress), zeroObjectInfo()), "getObjectInfo(address) returned unexpected value #4.2");
                assertEq(registry.getNftId(expectedInfo.objectAddress).toInt(), 0, "getNftId(address) returned unexpected value #4.2");
                assertEq(registry.isRegistered(expectedInfo.objectAddress), false, "isRegistered(address) returned unexpected value #4.2");
                vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 0));
                registry.ownerOf(expectedInfo.objectAddress);

                assertEq(registry.isRegisteredComponent(expectedInfo.objectAddress), false, "isRegisteredComponent(address) returned unexpected value #4.3");

                assertEq(registry.isRegisteredService(expectedInfo.objectAddress), false, "isRegisteredService(address) returned unexpected value #4.4");
                assertEq(registry.getServiceAddress(expectedDomain, expectedVersion) , address(0), "getServiceAddress(domain, version) returned unexpected value #4.4");
            }

            assertEq(registry.getRegistryNftId(expectedChainId).toInt(), expectedInfo.nftId.toInt(), "getRegistryNftId(chainId) returned unexpected value #4");
        }
        else if(expectedInfo.objectType == SERVICE()) 
        {
            //require(false, "_assert_registry_getters reached point 8");
            assertEq(expectedParentAddress, address(registry), "Test error: service parentAddress != registryAddress");
            assertEq(expectedParentType.toInt(), REGISTRY().toInt(), "Test error: service parentType != REGISTRY()");
            assertNotEq(expectedInfo.objectAddress, address(0), "Test error: service address == 0");
            assertEq(_nftIdByAddress[expectedInfo.objectAddress].toInt(), expectedInfo.nftId.toInt(), "Test error: service _nftIdByAddress[serviceAddress] != _info[nftId].nftId");
            assertEq(_registryNftIdByChainId[expectedChainId].toInt(), 0, "Test error: service _registryNftIdByChainId[chainId] != 0");

            assertTrue(eqObjectInfo(registry.getObjectInfo(expectedInfo.objectAddress), expectedInfo), "getObjectInfo(address) returned unexpected value #5");
            assertEq(registry.getNftId(expectedInfo.objectAddress).toInt(), expectedInfo.nftId.toInt(), "getNftId(address) returned unexpected value #5");
            assertEq(registry.isRegistered(expectedInfo.objectAddress), true, "isRegistered(address) returned unexpected value #5");
            assertEq(registry.ownerOf(expectedInfo.objectAddress), expectedOwner, "ownerOf(address) returned unexpected value #5");

            assertEq(registry.isRegisteredComponent(expectedInfo.objectAddress), false, "isRegisteredComponent(address) returned unexpected value #5");

            assertEq(registry.isRegisteredService(expectedInfo.objectAddress), true, "isRegisteredService(address) returned unexpected value #5");
            assertEq(registry.getServiceAddress(expectedDomain, expectedVersion) , expectedInfo.objectAddress, "getServiceAddress(domain, version) returned unexpected value #5");

            assertEq(registry.getRegistryNftId(expectedChainId).toInt(), 0, "getRegistryNftId(chainId) returned unexpected value #5");
        } 
        else if(expectedParentType == INSTANCE()) 
        {
            assertEq(_registryNftIdByChainId[expectedChainId].toInt(), 0, "Test error: instance _registryNftIdByChainId[chainId] != 0");

            if(expectedInfo.objectAddress > address(0)) 
            { // contract for INSTANCE
                //require(false, "_assert_registry_getters reached point 9");
                assertEq(_nftIdByAddress[expectedInfo.objectAddress].toInt(), expectedInfo.nftId.toInt(), "Test error: _nftIdByAddress[_info[nftId].objectAddress] != _info[nftId].nftId #1");

                assertTrue(eqObjectInfo(registry.getObjectInfo(expectedInfo.objectAddress), expectedInfo), "getObjectInfo(address) returned unexpected value #6");
                assertEq(registry.getNftId(expectedInfo.objectAddress).toInt(), expectedInfo.nftId.toInt(), "getNftId(address) returned unexpected value #6");
                assertEq(registry.isRegistered(expectedInfo.objectAddress), true, "isRegistered(address) returned unexpected value #6");
                assertEq(registry.ownerOf(expectedInfo.objectAddress), expectedOwner, "ownerOf(address) returned unexpected value #6");

                assertEq(registry.isRegisteredComponent(expectedInfo.objectAddress), true, "isRegisteredComponent(address) returned unexpected value #6");
            }
            else 
            { // object for INSTANCE
                //require(false, "_assert_registry_getters reached point 10");
                assertEq(_nftIdByAddress[expectedInfo.objectAddress].toInt(), 0, "Test error: _nftIdByAddress[_info[nftId].objectAddress] != 0 #1");
    
                assertTrue(eqObjectInfo(registry.getObjectInfo(expectedInfo.objectAddress), zeroObjectInfo()), "getObjectInfo(address) returned unexpected value #6.5");
                assertEq(registry.getNftId(expectedInfo.objectAddress).toInt(), 0, "getNftId(address) returned unexpected value #6.5");
                assertEq(registry.isRegistered(expectedInfo.objectAddress), false, "isRegistered(address) returned unexpected value #6.5");
                vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 0));
                registry.ownerOf(expectedInfo.objectAddress);

                assertEq(registry.isRegisteredComponent(expectedInfo.objectAddress), false, "isRegisteredComponent(address) returned unexpected value #6.5");
            }

            assertEq(registry.isRegisteredService(expectedInfo.objectAddress), false, "isRegisteredService(address) returned unexpected value #6");
            assertEq(registry.getServiceAddress(expectedDomain, expectedVersion) , address(0), "getServiceAddress(domain, version) returned unexpected value #6"); 

            assertEq(registry.getRegistryNftId(expectedChainId).toInt(), 0, "getRegistryNftId(chainId) returned unexpected value #6");
        }
        else if(expectedInfo.objectAddress > address(0)) 
        {// the rest contracts
            //require(false, "_assert_registry_getters reached point 11");
            assertEq(_nftIdByAddress[expectedInfo.objectAddress].toInt(), expectedInfo.nftId.toInt(), "Test error: _nftIdByAddress[_info[nftId].objectAddress] != _info[nftId].nftId #2");
            assertEq(_registryNftIdByChainId[expectedChainId].toInt(), 0, "Test error: _registryNftIdByChainId[chainId] != 0 #1");

            assertTrue(eqObjectInfo(registry.getObjectInfo(expectedInfo.objectAddress), expectedInfo), "getObjectInfo(address) returned unexpected value #7");
            assertEq(registry.getNftId(expectedInfo.objectAddress).toInt(), expectedInfo.nftId.toInt(), "getNftId(address) returned unexpected value #7");
            assertEq(registry.isRegistered(expectedInfo.objectAddress), true, "isRegistered(address) returned unexpected value #7");
            assertEq(registry.ownerOf(expectedInfo.objectAddress), expectedOwner, "ownerOf(address) returned unexpected value #7");

            assertEq(registry.isRegisteredComponent(expectedInfo.objectAddress), false, "isRegisteredComponent(address) returned unexpected value #7");

            assertEq(registry.isRegisteredService(expectedInfo.objectAddress), false, "isRegisteredService(address) returned unexpected value #7");
            assertEq(registry.getServiceAddress(expectedDomain, expectedVersion) , address(0), "getServiceAddress(domain, version) returned unexpected value #7");

            assertEq(registry.getRegistryNftId(expectedChainId).toInt(), 0, "getRegistryNftId(chainId) returned unexpected value #7"); 
        }
        else 
        { // the rest objects, some checks are redundant?
            //require(false, "_assert_registry_getters reached point 12");
            assertEq(_nftIdByAddress[expectedInfo.objectAddress].toInt(), 0, "Test error: _nftIdByAddress[_info[nftId].objectAddress] != 0 #2");
            assertEq(_registryNftIdByChainId[expectedChainId].toInt(), 0, "Test error: _registryNftIdByChainId[chainId] != 0 #2");

            assertTrue(eqObjectInfo(registry.getObjectInfo(expectedInfo.objectAddress), zeroObjectInfo()), "getObjectInfo(address) returned unexpected value #8");
            assertEq(registry.getNftId(expectedInfo.objectAddress).toInt(), 0, "getNftId(address) returned unexpected value #8");
            assertEq(registry.isRegistered(expectedInfo.objectAddress), false, "isRegistered(address) returned unexpected value #8");
            vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 0));
            registry.ownerOf(expectedInfo.objectAddress);

            assertEq(registry.isRegisteredComponent(expectedInfo.objectAddress), false, "isRegisteredComponent(address) returned unexpected value #8");

            assertEq(registry.isRegisteredService(expectedInfo.objectAddress), false, "isRegisteredService(address) returned unexpected value #8");
            assertEq(registry.getServiceAddress(expectedDomain, expectedVersion) , address(0), "getServiceAddress(domain, version) returned unexpected value #8");

            assertEq(registry.getRegistryNftId(expectedChainId).toInt(), 0, "getRegistryNftId(chainId) returned unexpected value #8"); 
        }
    }

    // checks performed during internal _register() function call
    // note: RegisterRegistryFuzz and RegisterRegistryContinuous tests are not getting here because not using internal _register() function
    function _internalRegisterChecks(IRegistry.ObjectInfo memory info) internal view returns (bool expectRevert, bytes memory expectedRevertMsg)
    {
        NftId parentNftId = info.parentNftId;
        /*address parentAddress = _info[parentNftId].objectAddress;

        if(info.objectType != STAKE() && parentAddress == address(0)) {
            expectedRevertMsg = abi.encodeWithSelector(IRegistry.ErrorRegistryParentAddressZero.selector);
            expectRevert = true;
        } else*/ 
        if(block.chainid != 1 && parentNftId == globalRegistryNftId) {
            // note: RegisterServiceFuzz and RegisterServiceContinuous tests are not getting here because services allowed to have only registry as parent -> will catch ErrorRegistryServiceParentNotRegistry error in _registerServiceChecks()
            //require(false, "_internalRegisterChecks() check 1 is reached"); // TODO RegisterServiceFuzz, RegisterServiceContinuous, not reaching this point
            expectedRevertMsg = abi.encodeWithSelector(IRegistry.ErrorRegistryGlobalRegistryAsParent.selector, info.objectAddress, info.objectType);
            expectRevert = true;
        } else if(info.objectAddress > address(0) && _nftIdByAddress[info.objectAddress].gtz()) {
            //require(false, "_internalRegisterChecks() check 2 is reached");
            expectedRevertMsg = abi.encodeWithSelector(IRegistry.ErrorRegistryContractAlreadyRegistered.selector, info.objectAddress);
            expectRevert = true;
        } else if(info.initialOwner == address(0) || info.initialOwner.code.length != 0) { // EnumerableSet.contains(_contractAddresses, info.initialOwner)) {
            // "to" address is 0 or contract address
            // assume all contracts addresses are without IERC721Receiver support 
            // assume none of GIF contracts are supporting erc721 receiver interface -> components could but not now
            //console.log("initialOwner is in addresses set: %s", EnumerableSet.contains(_addresses, info.initialOwner));
            //console.log("initialOwner codehash: %s", uint(info.initialOwner.codehash));

            //require(false, "_internalRegisterChecks() check 3 is reached");
            expectedRevertMsg = abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, info.initialOwner);
            expectRevert = true;
        } // else if() {
        // ERC721InvalidSender -> "from" is not 0 -> token id already minted
        // }

        // TODO add interceptor checks
    }

    // -------------- registerRegistry() related test functions ----------------- //

    function _assert_registerRegistry(
        NftId nftId,
        uint64 chainId, 
        address registryAddress,
        bool expectRevert, 
        bytes memory revertMsg) internal
    {
        console.log("chain id", block.chainid);

        if(expectRevert)
        {
            vm.expectRevert(revertMsg);
        }
        else
        {
            uint256 expectedId = chainNft.calculateTokenId(registry.REGISTRY_TOKEN_SEQUENCE_ID(), chainId);
            NftId expectedNftId = NftIdLib.toNftId(expectedId);

            vm.expectEmit(address(registry));
            emit LogChainRegistryRegistration(expectedNftId, chainId, registryAddress);

            vm.expectEmit(address(chainNft));
            emit LogTokenInterceptorAddress(expectedId, address(0));

            vm.expectEmit(address(chainNft));
            emit Transfer(address(0), registryInfo.initialOwner, expectedId);
        }

        registry.registerRegistry(nftId, chainId, registryAddress); 

        if(expectRevert == false)
        {
            _afterRegistryRegistration(nftId, chainId, registryAddress); 

            _checkRegistryGetters();

            // solhint-disable-next-line
            console.log("Registered:"); 
            _logObjectInfo(_info[nftId]);
            console.log("nftIdByAddress ", _nftIdByAddress[registryAddress].toInt());
            console.log("");
            // solhint-enable
        }
    }

    function _assert_registerRegistry_withChecks(NftId nftId, uint64 chainId, address registry) public
    {
        bool expectRevert;
        bytes memory expectedRevertMsg;

        //console.log("   Doing registerRegistry() function checks");
        (expectRevert, expectedRevertMsg) = _registerRegistryChecks(nftId, chainId, registry);

        //console.log("   Calling registerRegistry()");
        _assert_registerRegistry(nftId, chainId, registry, expectRevert, expectedRevertMsg);
    }

    function _registerRegistryChecks(NftId nftId, uint64 chainId, address registryAddress) internal view returns (bool expectRevert, bytes memory expectedRevertMsg)
    {
        if(_sender != gifAdmin) 
        {// auth check
            //require(false, "_registerRegistryChecks() check 1 is reached");
            expectedRevertMsg = abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, _sender);
            expectRevert = true;
        } else if(block.chainid != 1) {// registration of chain registries only allowed on mainnet
            //require(false, "_registerRegistryChecks() check 2 is reached");
            expectedRevertMsg = abi.encodeWithSelector(IRegistry.ErrorRegistryNotOnMainnet.selector, block.chainid);
            expectRevert = true;
        } else if(chainId == 0) {
            //require(false, "_registerRegistryChecks() check 3 is reached");
            expectedRevertMsg = abi.encodeWithSelector(IRegistry.ErrorRegistryChainRegistryChainidZero.selector, nftId);
            expectRevert = true;
        } else if(registryAddress == address(0)) {
            //require(false, "_registerRegistryChecks() check 4 is reached");
            expectedRevertMsg = abi.encodeWithSelector(IRegistry.ErrorRegistryChainRegistryAddressZero.selector, nftId, chainId);
            expectRevert = true;
        } else if(nftId.toInt() != chainNft.calculateTokenId(registry.REGISTRY_TOKEN_SEQUENCE_ID(), chainId)) {
            //require(false, "_registerRegistryChecks() check 5 is reached");
            expectedRevertMsg = abi.encodeWithSelector(IRegistry.ErrorRegistryChainRegistryNftIdInvalid.selector, nftId, chainId);
            expectRevert = true;
        } else if(_info[nftId].objectType.gtz()) {
            //require(false, "_registerRegistryChecks() check 6 is reached");
            expectedRevertMsg = abi.encodeWithSelector(IRegistry.ErrorRegistryChainRegistryAlreadyRegistered.selector, nftId, chainId);
            expectRevert = true;
        } else if(_registryNftIdByChainId[chainId].gtz()) {
            require(false, "_registerRegistryChecks check 7 is reached"); // MUST not get here       
        }  
    }

    function registerRegistry_testFunction(
        address sender,
        NftId nftId,
        uint64 chainId,
        address registry) public
    {
        _startPrank(sender);

        _assert_registerRegistry_withChecks(nftId, chainId, registry);

        _stopPrank();
    }

    // -------------- registerService() related test functions ---------------- //
    /* TODO move to releaseRegistry tests
    // prepare new release and register service to set release registry in correct state
    function prepareReleaseToState(StateId state, bytes32 salt, bool registerService, IService service) public
    {
        vm.startPrank(gifAdmin);
        _next = VersionPartLib.toVersionPart(_next.toInt() + 1);
        VersionPart createdVersion = releaseRegistry.createNextRelease();
        vm.stopPrank();

        assertTrue(releaseRegistry.getState(createdVersion) == SCHEDULED());
        assertEq(createdVersion.toInt(), _next.toInt(), "Test error: _next is inconcistent with createNextRelease()");

        if(state == SCHEDULED()) {
            return;
        }

        vm.startPrank(gifManager);

        //bytes32 salt = bytes32(randomNumber(type(uint256).max));
        releaseRegistry.prepareNextRelease(
            new ServiceAuthorizationMock(createdVersion),
            salt
        );

        assertTrue(releaseRegistry.getState(createdVersion) == DEPLOYING());

        if(registerService)
        {
            RegistryServiceManagerMockV4 serviceManager;

            if(address(service) == address(0)) {
                // TODO register mock service for given version -> but services have pure getVersion()...
                // serviceManager = getRegistryServiceManagerMock(_next);
                serviceManager = new RegistryServiceManagerMockV4(
                        address(accessManager), // reuse
                        address(registry), 
                        salt);
                service = IService(serviceManager.getRegistryService());
            }
            IRegistry.ObjectInfo memory info = service.getInitialInfo();
            // TODO have to call releaseRegistry instead of calling registry directlly -> cannot use _assert_registerService() here and have to deploy proxyManager
            //registryTest._assert_registerService(info, _next, service.getDomain(), false, "");
            info.nftId = releaseRegistry.registerService(service);
            _afterServiceRegistration(
                info,
                service.getVersion().toMajorPart(),
                service.getDomain()
            );

            if(address(service) == address(0)) {
                serviceManager.linkToProxy();
            }
        }

        if(state == DEPLOYING()) {
            _stopPrank();
            return;
        }

        releaseRegistry.activateNextRelease(createdVersion);
        _latest = createdVersion;
        assertTrue(releaseRegistry.getState(createdVersion) == ACTIVE());


        if(state == ACTIVE()) {
            _stopPrank();
            return;
        }

        releaseRegistry.pauseRelease(createdVersion);    
        assertTrue(releaseRegistry.getState(createdVersion) == PAUSED());    

        if(state == PAUSED()) {
            _stopPrank();
            return;
        }

        require(false, "Test error: release state invalid");

        vm.stopPrank();
    }
    */

    // assert call to registerService() function
    function _assert_registerService(
        IRegistry.ObjectInfo memory info,
        VersionPart version,
        ObjectType domain,
        bool expectRevert, 
        bytes memory revertMsg) internal returns (NftId)
    {   
        console.log("chain id", block.chainid);
        //uint256 expectedId;
        //address interceptor;
        //uint expectedLogsCount;

        if(expectRevert)
        {
            vm.expectRevert(revertMsg);
        }
        else
        {
            //expectedLogsCount = 4;
            uint256 expectedId = chainNft.calculateTokenId(_nextId);
            NftId expectedNftId = NftIdLib.toNftId(expectedId);

            address interceptor = getInterceptor(
                info.isInterceptor, 
                info.objectType,
                info.objectAddress,
                _info[info.parentNftId].isInterceptor,
                _info[info.parentNftId].objectAddress
            );

            vm.expectEmit(address(registry));
            emit LogServiceRegistration(version, domain);

            vm.expectEmit(address(registry));
            emit LogRegistration(
                expectedNftId,
                info.parentNftId, 
                info.objectType, 
                info.isInterceptor,
                info.objectAddress, 
                info.initialOwner
            );

            vm.expectEmit(address(chainNft));
            emit LogTokenInterceptorAddress(
                expectedId, 
                interceptor
            );

            vm.expectEmit(address(chainNft));
            emit Transfer(address(0), info.initialOwner, expectedId);

            if(interceptor != address(0)) {
                //expectedLogsCount = 5;
                vm.expectEmit(interceptor);
                emit LogNftMintIntercepted(info.initialOwner, expectedId);// TODO sort of duplicate log...
            }
        }
        
        //vm.recordLogs();
        NftId nftId = registry.registerService(info, version, domain);
        info.nftId = nftId;

        if(expectRevert == false)
        {
            //Vm.Log[] memory entries = vm.getRecordedLogs();
            //assertEq(entries.length, expectedLogsCount, "registerService() created unexpected number of logs");
            assertEq(nftId.toInt(), chainNft.calculateTokenId(_nextId), "register() returned unexpected nftId");

            _afterServiceRegistration(info, version, domain);

            _checkRegistryGetters();

            // solhint-disable-next-line
            console.log("Registered:"); 
            _logObjectInfo(info);
            //console.log("interceptor: ", interceptor);
            //console.log("logs: ", expectedLogsCount);
            console.log("");
            // solhint-enable
        }

        return nftId;
    }
    // assert call to registerService() function
    function _assert_registerService_withChecks(IRegistry.ObjectInfo memory info, VersionPart version, ObjectType domain) internal returns (NftId nftId)
    {
        bool expectRevert;
        bytes memory expectedRevertMsg;

        console.log("   Doing registerService() function checks");
        (expectRevert, expectedRevertMsg) = _registerServiceChecks(info, version, domain);

        if(expectRevert) {
            console.log("       expectRevert : ", expectRevert);
            console.log("       revert reason:", _errorName[bytes4(expectedRevertMsg)]);
            console.log("   Skipping _register() checks due to expected revert");
        } else {
            console.log("   Doing _register() function checks");// TODO log on/off flag
            (expectRevert, expectedRevertMsg) = _internalRegisterChecks(info);
            if(expectRevert) {
                console.log("       expectRevert : ", expectRevert);
                console.log("       revert reason:", _errorName[bytes4(expectedRevertMsg)]);
            }
        }

        console.log("   Calling _registerService()");
        nftId = _assert_registerService(info, version, domain, expectRevert, expectedRevertMsg);
    }

    // checks performed during registerService() function call
    function _registerServiceChecks(IRegistry.ObjectInfo memory info, VersionPart version, ObjectType domain) internal view returns (bool expectRevert, bytes memory expectedRevertMsg)
    {
        VersionPart releaseVersion = releaseRegistry.getNextVersion();

        if(_sender != address(releaseRegistry)) 
        {// auth check
            //require(false, "_registerServiceChecks() check 1 is reached");
            expectedRevertMsg = abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, _sender);
            expectRevert = true;
        } else if(info.objectAddress == address(0)) {
            //require(false, "_registerServiceChecks() check 2 is reached");
            expectedRevertMsg = abi.encodeWithSelector(IRegistry.ErrorRegistryServiceAddressZero.selector);
            expectRevert = true;
        } else if (version.eqz()) {
            //require(false, "_registerServiceChecks() check 3 is reached");
            expectedRevertMsg = abi.encodeWithSelector(IRegistry.ErrorRegistryServiceVersionZero.selector, info.objectAddress);
            expectRevert = true;
        } /*else if(version != releaseVersion) {
            expectedRevertMsg = abi.encodeWithSelector(
                IRegistry.ErrorRegistryServiceVersionMismatch.selector,
                info.objectAddress,
                version,
                releaseVersion);
            expectRevert = true;
        } else if(releaseRegistry.getState(releaseVersion) != DEPLOYING()) {
            expectedRevertMsg = abi.encodeWithSelector(
                IRegistry.ErrorRegistryServiceVersionNotDeploying.selector,
                info.objectAddress,
                version
            );
            expectRevert = true;
        } */else if(domain.eqz()) {
            //require(false, "_registerServiceChecks() check 4 is reached");
            expectedRevertMsg = abi.encodeWithSelector(IRegistry.ErrorRegistryServiceDomainZero.selector, info.objectAddress, version);
            expectRevert = true;
        } else if(info.objectType != SERVICE()) {
            //require(false, "_registerServiceChecks() check 5 is reached");
            expectedRevertMsg = abi.encodeWithSelector(
                IRegistry.ErrorRegistryNotService.selector,
                info.objectAddress,
                info.objectType);
            expectRevert = true;
        } else if(info.parentNftId != registryNftId) {
            //require(false, "_registerServiceChecks() check 6 is reached");
            expectedRevertMsg = abi.encodeWithSelector(
                IRegistry.ErrorRegistryServiceParentNotRegistry.selector,
                info.objectAddress,
                version,
                info.parentNftId);
            expectRevert = true;
        } else if(_service[version][domain] > address(0)) { // note: registerService() continuous tests will not reach this point, but fuzz tests will
            //require(false, "_registerServiceChecks() check 7 is reached");
            expectedRevertMsg = abi.encodeWithSelector(
                IRegistry.ErrorRegistryServiceDomainAlreadyRegistered.selector,
                info.objectAddress,
                version,
                domain);
            expectRevert = true;
        }
    }

    function registerService_testFunction(address sender, IRegistry.ObjectInfo memory info, VersionPart version, ObjectType domain, bytes32 salt) public
    {
        // create registerable mock with provided salt and substitute it address in info
        RegisterableMock registerableMock = new RegisterableMock{salt: salt}(
            info.nftId,
            info.parentNftId,
            info.objectType,
            info.isInterceptor,
            info.initialOwner,
            info.data
        );
        info.objectAddress = address(registerableMock);

        registerService_testFunction(sender, info, version, domain);
    }

    function registerService_testFunction(address sender, IRegistry.ObjectInfo memory info, VersionPart version, ObjectType domain) public
    {
        // solhint-disable no-console
        vm.assume(
            info.initialOwner != 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D && // gives error (Invalid data) only during fuzzing when minting nft to foundry's cheatcodes contract
            info.initialOwner != 0x4e59b44847b379578588920cA78FbF26c0B4956C // Deterministic Deployment Proxy, on nft transfer callback tries Create2Deployer::create2()
        );
        // solhint-enable

        _startPrank(sender);

        _assert_registerService_withChecks(info, version, domain);

        _stopPrank();
    }

    // -------------- register() related test functions ---------------- //

    // assert call to register() function
    function _assert_register(IRegistry.ObjectInfo memory info, bool expectRevert, bytes memory revertMsg) internal returns (NftId nftId)
    {
        console.log("chain id ", block.chainid);

        if(expectRevert)
        {
            vm.expectRevert(revertMsg);
        }
        else
        {
            uint256 expectedId = chainNft.calculateTokenId(_nextId);
            NftId expectedNftId = NftIdLib.toNftId(expectedId);

            address interceptor = getInterceptor(
                info.isInterceptor, 
                info.objectType,
                info.objectAddress,
                _info[info.parentNftId].isInterceptor,
                _info[info.parentNftId].objectAddress
            );

            vm.expectEmit(address(registry));
            emit LogRegistration(
                expectedNftId,
                info.parentNftId, 
                info.objectType, 
                info.isInterceptor,
                info.objectAddress, 
                info.initialOwner
            );

            vm.expectEmit(address(chainNft));
            emit LogTokenInterceptorAddress(
                expectedId, 
                interceptor
            );

            vm.expectEmit(address(chainNft));
            emit Transfer(address(0), info.initialOwner, expectedId);

            if(interceptor != address(0)) {
                //expectedLogsCount = 4;
                vm.expectEmit(interceptor);
                emit LogNftMintIntercepted(info.initialOwner, expectedId);// TODO sort of duplicate log...
            }
        }

        nftId = registry.register(info);
        info.nftId = nftId;

        if(expectRevert == false)
        {
            assertEq(nftId.toInt(), chainNft.calculateTokenId(_nextId), "register() returned unexpected nftId");

            _afterRegistration(info);

            _checkRegistryGetters();

            // solhint-disable-next-line
            console.log("Registered:"); 
            _logObjectInfo(info);
            console.log("");
            // solhint-enable
        }
    }

    // assert call to register() function
    function _assert_register_withChecks(IRegistry.ObjectInfo memory info) internal returns (NftId nftId)
    {
        bool expectRevert;
        bytes memory expectedRevertMsg;

        console.log("   Doing register() function checks");
        (expectRevert, expectedRevertMsg) = _registerChecks(info);

        if(expectRevert) {
            console.log("       expectRevert : ", expectRevert);
            console.log("       revert reason:", _errorName[bytes4(expectedRevertMsg)]);
            console.log("   Skipping _register() checks due to expected revert");
        } else {
            console.log("   Doing _register() function checks");// TODO log on/off flag
            (expectRevert, expectedRevertMsg) = _internalRegisterChecks(info);
            if(expectRevert) {
                console.log("       expectRevert : ", expectRevert);
                console.log("       revert reason:", _errorName[bytes4(expectedRevertMsg)]);
            }
        }

        console.log("   Calling register()");
        nftId = _assert_register(info, expectRevert, expectedRevertMsg);
    }

    // checks performed during register() function call
    function _registerChecks(IRegistry.ObjectInfo memory info) internal view returns (bool expectRevert, bytes memory expectedRevertMsg)
    {
        NftId parentNftId = info.parentNftId;
        ObjectType parentType = _info[parentNftId].objectType;

        if(_sender != address(registryServiceMock)) 
        {// auth check
            //require(false, "_registerChecks() check 1 is reached");
            expectedRevertMsg = abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, _sender);
            expectRevert = true;
        } else if(info.objectAddress > address(0)) 
        {
            //if(_coreContractTypesCombos.contains(ObjectTypePairLib.toObjectTypePair(info.objectType, parentType)) == false)
            if(_isCoreContractTypesCombo[info.objectType][parentType] == false)
            {// parent must be registered + object-parent types combo must be valid
                //require(false, "_registerChecks() check 2 is reached");
                expectedRevertMsg = abi.encodeWithSelector(
                    IRegistry.ErrorRegistryTypesCombinationInvalid.selector, 
                    info.objectAddress,
                    info.objectType, 
                    parentType);
                expectRevert = true;
            }
        } else 
        {
            //if(_coreObjectTypesCombos.contains(ObjectTypePairLib.toObjectTypePair(info.objectType, parentType)) == false)
            if(_isCoreObjectTypesCombo[info.objectType][parentType] == false)
            {// parent must be registered + object-parent types combo must be valid
                //require(false, "_registerChecks() check 3 is reached");
                expectedRevertMsg = abi.encodeWithSelector(
                    IRegistry.ErrorRegistryTypesCombinationInvalid.selector, 
                    info.objectAddress,
                    info.objectType, 
                    parentType);
                expectRevert = true;
            }
        }
    }

    function register_testFunction(address sender, IRegistry.ObjectInfo memory info, bytes32 salt) public
    {
        // create registerable mock with provided salt and substitute it address in info
        RegisterableMock registerableMock = new RegisterableMock{salt: salt}(
            info.nftId,
            info.parentNftId,
            info.objectType,
            info.isInterceptor,
            info.initialOwner,
            info.data
        );
        info.objectAddress = address(registerableMock);

        register_testFunction(sender, info);
    }

    function register_testFunction(address sender, IRegistry.ObjectInfo memory info) public
    {
        // solhint-disable no-console
        vm.assume(
            info.initialOwner != 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D && // gives error (Invalid data) only during fuzzing when minting nft to foundry's cheatcodes contract
            info.initialOwner != 0x4e59b44847b379578588920cA78FbF26c0B4956C // Deterministic Deployment Proxy, on nft transfer callback onERC721Received() tries Create2Deployer::create2()
        );
        // solhint-enable

        _startPrank(sender);

        _assert_register_withChecks(info);

        _stopPrank();
    }

    // -------------- registerWithCustomType() related test functions ---------------- //

    // assert call to registryWithCustomType() function
    function _assert_registerWithCustomType(IRegistry.ObjectInfo memory info, bool expectRevert, bytes memory revertMsg) internal returns (NftId nftId)
    {
        console.log("chain id ", block.chainid);

        if(expectRevert)
        {
            vm.expectRevert(revertMsg);
        }
        else
        {
            uint256 expectedId = chainNft.calculateTokenId(_nextId);
            NftId expectedNftId = NftIdLib.toNftId(expectedId);

            address interceptor = getInterceptor(
                info.isInterceptor, 
                info.objectType,
                info.objectAddress,
                _info[info.parentNftId].isInterceptor,
                _info[info.parentNftId].objectAddress
            );

            vm.expectEmit(address(registry));
            emit LogRegistration(
                expectedNftId,
                info.parentNftId, 
                info.objectType, 
                info.isInterceptor,
                info.objectAddress, 
                info.initialOwner
            );

            vm.expectEmit(address(chainNft));
            emit LogTokenInterceptorAddress(
                expectedId, 
                interceptor
            );

            vm.expectEmit(address(chainNft));
            emit Transfer(address(0), info.initialOwner, expectedId);

            if(info.isInterceptor) {
                vm.expectEmit(info.initialOwner);
                emit LogNftMintIntercepted(info.initialOwner, expectedId);
            }
        }

        nftId = registry.registerWithCustomType(info);
        info.nftId = nftId;

        if(expectRevert == false)
        {
            assertEq(nftId.toInt(), chainNft.calculateTokenId(_nextId), "registerWithCustomType() returned unexpected nftId");

            _afterRegistrationWithCustomType(info);

            _checkRegistryGetters();

            // solhint-disable-next-line
            console.log("Registered:"); 
            _logObjectInfo(info);
            console.log("");
            // solhint-enable
        }
    }

    // assert call to registryWithCustomType() function
    function _assert_registerWithCustomType_withChecks(IRegistry.ObjectInfo memory info) internal returns (NftId nftId)
    {
        bool expectRevert;
        bytes memory expectedRevertMsg;

        console.log("   Doing registerWithCustomType() function checks");
        (expectRevert, expectedRevertMsg) = _registerWithCustomTypeChecks(info);

        if(expectRevert) {
            console.log("       expectRevert : ", expectRevert);
            console.log("       revert reason:", _errorName[bytes4(expectedRevertMsg)]);
            console.log("   Skipping _register() checks due to expected revert");
        } else {
            console.log("   Doing _register() function checks");
            (expectRevert, expectedRevertMsg) = _internalRegisterChecks(info);
            if(expectRevert) {
                console.log("       expectRevert : ", expectRevert);
                console.log("       revert reason:", _errorName[bytes4(expectedRevertMsg)]);
            }
        }

        console.log("   Calling registerWithCustomType()");
        nftId = _assert_registerWithCustomType(info, expectRevert, expectedRevertMsg);
    }

    // checks performed during registerWithCustomType() function call
    function _registerWithCustomTypeChecks(IRegistry.ObjectInfo memory info) internal view returns (bool expectRevert, bytes memory expectedRevertMsg)
    {
        NftId parentNftId = info.parentNftId;
        ObjectType parentType = _info[parentNftId].objectType;

        if(_sender != address(registryServiceMock)) 
        {// auth check
            //require(false, "_registerWithCustomTypeChecks() check 1 is reached");
            expectedRevertMsg = abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, _sender);
            expectRevert = true;
        } else if(EnumerableSet.contains(_types, info.objectType.toInt()) && info.objectType.toInt() != ObjectTypeLib.zero().toInt()) { // check for 0 because _types contains zero type
            //require(false, "_registerWithCustomTypeChecks() check 2 is reached");
            expectedRevertMsg = abi.encodeWithSelector(IRegistry.ErrorRegistryCoreTypeRegistration.selector);
            expectRevert = true;
        } else if( // custom type can not be 0 AND its parent type can not be 0 / PROTOCOL / SERVICE
            info.objectType == ObjectTypeLib.zero() ||
            parentType == ObjectTypeLib.zero() ||
            parentType == PROTOCOL() || 
            parentType == SERVICE()
        ) {
            //require(false, "_registerWithCustomTypeChecks() check 3 is reached"); 
            expectedRevertMsg = abi.encodeWithSelector(
                IRegistry.ErrorRegistryTypesCombinationInvalid.selector, 
                info.objectAddress,
                info.objectType, 
                parentType);
            expectRevert = true;
        }
    }

    function registerWithCustomType_testFunction(address sender, IRegistry.ObjectInfo memory info, bytes32 salt) public
    {
        // create registerable mock with provided salt and substitute it address in info
        RegisterableMock registerableMock = new RegisterableMock{salt: salt}(
            info.nftId,
            info.parentNftId,
            info.objectType,
            info.isInterceptor,
            info.initialOwner,
            info.data
        );
        info.objectAddress = address(registerableMock);

        registerWithCustomType_testFunction(sender, info);
    }

    function registerWithCustomType_testFunction(address sender, IRegistry.ObjectInfo memory info) public
    {
        // solhint-disable no-console
        vm.assume(
            info.initialOwner != 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D && // gives error (Invalid data) only during fuzzing when minting nft to foundry's cheatcodes contract
            info.initialOwner != 0x4e59b44847b379578588920cA78FbF26c0B4956C // Deterministic Deployment Proxy, on nft transfer callback tries Create2Deployer::create2()
        );
        // solhint-enable

        // TODO register contracts with IInterceptor interface support
        info.isInterceptor = false;

        _startPrank(sender);

        _assert_registerWithCustomType_withChecks(info);

        _stopPrank();
    }

    // -------------- helper functions ---------------- //

    function getInterceptor(
        bool isInterceptor, 
        ObjectType objectType,
        address objectAddress,
        bool parentIsInterceptor,
        address parentObjectAddress
    )
        public 
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

    function _startPrank(address sender_) internal {
        vm.startPrank(sender_);
        _sender = sender_;
    }

    function _stopPrank() internal {
        vm.stopPrank();
        _sender = tx.origin;
    }

    function _getSenderName() public view returns(string memory) {

        if(Strings.equal(_addressName[_sender], "")) {
            return Strings.toString(uint160(_sender));
        }
        return _addressName[_sender];
    }

    function _getTypeName(ObjectType objectType) public view returns(string memory) {
        if(Strings.equal(_typeName[objectType], "")) {
            return Strings.toString(objectType.toInt());
        }

        return _typeName[objectType];
    }

    function _getObjectTypeAtIndex(uint256 index) public view returns (ObjectType) {
        return ObjectTypeLib.toObjectType(EnumerableSet.at(_types, (index % EnumerableSet.length(_types))));
    }

    function _getNftIdAtIndex(uint256 index) public view returns (NftId) {
        return NftIdLib.toNftId(EnumerableSet.at(_nftIds, (index % EnumerableSet.length(_nftIds))));
    }

    function _getAddressAtIndex(uint256 index) public view returns (address) {
        return EnumerableSet.at(_addresses, (index % EnumerableSet.length(_addresses)));
    }

    // forge: chain ID must be less than 2^64 - 1
    function _getChainIdAtIndex(uint256 index) public view returns (uint64) {
        return uint64(EnumerableSet.at(_chainIds, (index % EnumerableSet.length(_chainIds))));
    }



    function _getRandomNotRegisteredAddress() public returns (address addr) {
            do {
                addr = address(uint160(randomNumber(type(uint160).max)));
            } while(EnumerableSet.contains(_registeredAddresses, addr) || addr == address(0));
    }

    // returns valid random, non mainnet chanId
    function _getRandomChainId() public returns (uint64 chainId) {
        do {
            chainId = uint64(randomNumber(type(uint64).max));
        } while(chainId == 1 || chainId == 0);
    }

    // returns valid random chainId which is not in _chainIds set
    // DO NOT use this function before RegistryTestBase.setUp() is called
    function _getRandomNotRegisteredChainId() public returns (uint64 chainId) {
        do {
            chainId = uint64(randomNumber(type(uint64).max));
        } while(EnumerableSet.contains(_chainIds, chainId) || chainId == 0);
    }

    function _logObjectInfo(IRegistry.ObjectInfo memory info) internal view {
        // solhint-disable no-console
        console.log("        nftId: %d", info.nftId.toInt());
        console.log("  parentNftId: %d", info.parentNftId.toInt());
        console.log("   objectType: %s", _getTypeName(info.objectType));
        console.log("objectAddress: %s", info.objectAddress);
        console.log("isInterceptor: %s", info.isInterceptor);
        console.log(" initialOwner: %s", info.initialOwner);
        //console.log("         data: %d", info.data);
        // solhint-enable
    }
}
