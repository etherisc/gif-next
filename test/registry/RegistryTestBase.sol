// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {FoundryRandom} from "foundry-random/FoundryRandom.sol";

import {console} from "../../lib/forge-std/src/Test.sol";

import {VersionLib, Version, VersionPart, VersionPartLib } from "../../contracts/type/Version.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {Timestamp, TimestampLib} from "../../contracts/type/Timestamp.sol";
import {Blocknumber, BlocknumberLib} from "../../contracts/type/Blocknumber.sol";
import {ObjectType, ObjectTypeLib, PROTOCOL, REGISTRY, STAKING, SERVICE, INSTANCE, PRODUCT, POOL, ORACLE, DISTRIBUTION, DISTRIBUTOR, BUNDLE, POLICY, STAKE, STAKING} from "../../contracts/type/ObjectType.sol";
import {RoleId} from "../../contracts/type/RoleId.sol";

import {ChainNft} from "../../contracts/registry/ChainNft.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {ReleaseRegistry} from "../../contracts/registry/ReleaseRegistry.sol";
import {RegistryAdmin} from "../../contracts/registry/RegistryAdmin.sol";
import {ServiceMockAuthorizationV3} from "./ServiceMockAuthorizationV3.sol";
import {Staking} from "../../contracts/staking/Staking.sol";
import {StakingManager} from "../../contracts/staking/StakingManager.sol";
import {TokenRegistry} from "../../contracts/registry/TokenRegistry.sol";

import {RegisterableMock} from "../mock/RegisterableMock.sol";
import {RegistryServiceManagerMock} from "../mock/RegistryServiceManagerMock.sol";
import {RegistryServiceMock} from "../mock/RegistryServiceMock.sol";
import {GifDeployer} from "../base/GifDeployer.sol";



contract RegistryTestBase is GifDeployer, FoundryRandom {

    // keep indentical to IRegistry events
    event LogRegistration(NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, address objectAddress, address initialOwner);
    event LogServiceRegistration(VersionPart majorVersion, ObjectType domain);
    event LogChainRegistryRegistration(NftId nftId, uint256 chainId, address registry);

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

    GifCore public core;

    address public _sender; // use with _startPrank(), _stopPrank()
    uint public _nextId; // use with core.chainNft.calculateId()

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

        core = deployCore(
            globalRegistry,
            gifAdmin,
            gifManager,
            stakingOwner);
        
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
            core.releaseRegistry.createNextRelease();

            // TODO do we need preparation phase now?
            (
                address releaseAccessManager,
                VersionPart releaseVersion,
                bytes32 releaseSalt
            ) = core.releaseRegistry.prepareNextRelease(
                new ServiceMockAuthorizationV3(),
                salt);

            registryServiceManagerMock = new RegistryServiceManagerMock{salt: releaseSalt}(
                releaseAccessManager, 
                address(core.registry), 
                releaseSalt);
        }

        registryServiceMock = RegistryServiceMock(address(registryServiceManagerMock.getRegistryService()));
        core.releaseRegistry.registerService(registryServiceMock);
        registryServiceManagerMock.linkToProxy();

        core.releaseRegistry.activateNextRelease();
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
                core.registry.NFT_LOCK_ADDRESS(),
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
                address(core.registry),
                core.registry.NFT_LOCK_ADDRESS(),
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
                core.registry.NFT_LOCK_ADDRESS(),
                "" 
            );

            registryNftId = NftIdLib.toNftId(
                core.chainNft.calculateTokenId(core.registry.REGISTRY_TOKEN_SEQUENCE_ID())
            );

            registryInfo = IRegistry.ObjectInfo(
                registryNftId,
                globalRegistryNftId,
                REGISTRY(),
                false,
                address(core.registry),
                core.registry.NFT_LOCK_ADDRESS(),
                "" 
            );
        }

        stakingNftId = NftIdLib.toNftId(
            core.chainNft.calculateTokenId(core.registry.STAKING_TOKEN_SEQUENCE_ID())
        );

        stakingInfo = IRegistry.ObjectInfo(
            stakingNftId,
            registryNftId,
            STAKING(),
            false,
            address(core.staking), // must be without erc721 receiver support?
            stakingOwner,
            ""
        );

        registryServiceNftId = NftIdLib.toNftId(
            core.chainNft.calculateTokenId(core.registry.STAKING_TOKEN_SEQUENCE_ID() + 1)
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
            require(core.registry.getObjectCount() == 4, "Test error: starting core.registry.objectCount() != 4 on mainnet");
            _nextId = 5;
        } else {
            // protocol 1101 -> id 1
            // global registry 2101 -> id 2
            // local registry 2xxxx -> id 2
            // local staking 3xxx -> id 3
            // local registry service 4xxx -> id 4
            require(core.registry.getObjectCount() == 5, "Test error: starting core.registry.objectCount() != 5 not on mainnet");
            _nextId = 5;
        }

        // special case: need 0 in _nftIds[] set, assume registry always have zeroObjectInfo registered as NftIdLib.zero
        _info[protocolNftId] = protocolInfo;
        _info[globalRegistryNftId] = globalRegistryInfo;
        _info[registryNftId] = registryInfo;
        _info[stakingNftId] = stakingInfo;
        _info[registryServiceNftId] = registryServiceInfo; 

        _nftIdByAddress[globalRegistryInfo.objectAddress] = globalRegistryNftId;
        _nftIdByAddress[registryInfo.objectAddress] = registryNftId;
        _nftIdByAddress[address(core.staking)] = stakingNftId;
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
        EnumerableSet.add(_addresses, address(core.staking));
        EnumerableSet.add(_addresses, address(core.tokenRegistry));
        EnumerableSet.add(_addresses, address(core.releaseRegistry));
        EnumerableSet.add(_addresses, address(core.accessManager));
        EnumerableSet.add(_addresses, address(core.registryAdmin));
        EnumerableSet.add(_addresses, address(core.stakingManager));
        EnumerableSet.add(_addresses, address(core.stakingReader));
        EnumerableSet.add(_addresses, address(core.stakingStore));
        EnumerableSet.add(_addresses, address(core.chainNft));
        EnumerableSet.add(_addresses, address(registryServiceMock));

        // TODO add libraries addresses?
        EnumerableSet.add(_contractAddresses, globalRegistryInfo.objectAddress);
        EnumerableSet.add(_contractAddresses, registryInfo.objectAddress);
        EnumerableSet.add(_contractAddresses, address(core.staking));
        EnumerableSet.add(_contractAddresses, address(core.tokenRegistry));
        EnumerableSet.add(_contractAddresses, address(core.releaseRegistry));
        EnumerableSet.add(_contractAddresses, address(core.accessManager));
        EnumerableSet.add(_contractAddresses, address(core.registryAdmin));
        EnumerableSet.add(_contractAddresses, address(core.stakingManager));
        EnumerableSet.add(_contractAddresses, address(core.stakingReader));
        EnumerableSet.add(_contractAddresses, address(core.stakingStore));
        EnumerableSet.add(_contractAddresses, address(core.chainNft));
        EnumerableSet.add(_contractAddresses, address(registryServiceMock));

        EnumerableSet.add(_registeredAddresses, globalRegistryInfo.objectAddress);
        EnumerableSet.add(_registeredAddresses, registryInfo.objectAddress);
        EnumerableSet.add(_registeredAddresses, address(core.staking));
        EnumerableSet.add(_registeredAddresses, address(registryServiceMock));

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
        _isCoreContractTypesCombo[STAKING()][REGISTRY()] = true;
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
        _addressName[address(core.staking)] = "Staking";
        _addressName[address(registryServiceMock)] = "registryServiceMock";
        
        _errorName[IAccessManaged.AccessManagedUnauthorized.selector] = "AccessManagedUnauthorized"; 
        //_errorName[IRegistry.ErrorRegistryCallerNotReleaseRegistry.selector] = "ErrorRegistryCallerNotReleaseManager"; 
        //_errorName[IRegistry.ErrorRegistryParentAddressZero.selector] = "ErrorRegistryParentAddressZero"; 
        _errorName[IRegistry.ErrorRegistryContractAlreadyRegistered.selector] = "ErrorRegistryContractAlreadyRegistered";
        _errorName[IRegistry.ErrorRegistryTypesCombinationInvalid.selector] = "ErrorRegistryTypesCombinationInvalid";
        _errorName[IRegistry.ErrorRegistryCoreTypeRegistration.selector] = "ErrorRegistryCoreTypeRegistration";
        _errorName[IRegistry.ErrorRegistryServiceAddressZero.selector] = "ErrorRegistryServiceAddressZero";
        _errorName[IRegistry.ErrorRegistryServiceVersionZero.selector] = "ErrorRegistryServiceVersionZero";
        _errorName[IRegistry.ErrorRegistryDomainZero.selector] = "ErrorRegistryDomainZero";
        _errorName[IRegistry.ErrorRegistryDomainAlreadyRegistered.selector] = "ErrorRegistryDomainAlreadyRegistered";
        _errorName[IRegistry.ErrorRegistryNotService.selector] = "ErrorRegistryNotService";
        _errorName[IRegistry.ErrorRegistryServiceParentNotRegistry.selector] = "ErrorRegistryServiceParentNotRegistry";
        _errorName[IRegistry.ErrorRegistryNftIdInvalid.selector] = "ErrorRegistryNftIdInvalid";
        _errorName[IERC721Errors.ERC721InvalidReceiver.selector] = "ERC721InvalidReceiver";
    }

    // call after every succesfull registration with register() or registerWithCustomType() functions, before checks
    function _afterRegistration(
        IRegistry.ObjectInfo memory info, 
        bool updateAddressLookup, // false after registerRegistry(), true otherwise
        bool incrementTokenIdCounter // false after registerRegistry(), true otherwise
    )
     internal virtual
    {
        if(incrementTokenIdCounter) {
            _nextId++;
        }

        NftId nftId = info.nftId;

        assertEq(_info[nftId].nftId.toInt(), 0, "Test error: _info[nftId].nftId already set");
        _info[nftId] = info;
        
        assertFalse(EnumerableSet.contains(_nftIds, info.nftId.toInt()), "Test error: _nftIds already contains nftId");
        EnumerableSet.add(_nftIds , nftId.toInt());

        EnumerableSet.add(_addresses, info.initialOwner);

        if(info.objectAddress > address(0)) {

            if(updateAddressLookup) {
                assertEq(_nftIdByAddress[info.objectAddress].toInt(), 0, "Test error: _nftIdByAddress[address] already set");
                _nftIdByAddress[info.objectAddress] = nftId;
            }

            //assertFalse(EnumerableSet.contains(_addresses, info.objectAddress), "Test error: _addresses already contains objectAddress"); // previously initial owner can become registerable
            assertFalse(EnumerableSet.contains(_registeredAddresses, info.objectAddress), "Test error: _registeredAddresses already contains objectAddress");
            //assertFalse(EnumerableSet.contains(_contractAddresses, info.objectAddress), "Test error: _contractAddresses already contains objectAddress"); // previously member of _contractAddresses becomes registered
            EnumerableSet.add(_addresses, info.objectAddress);
            EnumerableSet.add(_registeredAddresses, info.objectAddress);
            EnumerableSet.add(_contractAddresses, info.objectAddress);
        }

        // check registered object right away to spot errors early
        //_assert_registry_getters(nftId, info.initialOwner);//, _serviceInfo[info.nftId].version, _serviceInfo[info.nftId].domain, info.initialOwner, _registryInfo[nftId].chainId);
    }

    function _afterRegistrationWithCustomType(IRegistry.ObjectInfo memory info) internal
    {
        assertFalse(EnumerableSet.contains(_types, info.objectType.toInt()), "Test error: _afterRegistrationWithCustomType() called with core type object");
        _afterRegistration(info, true, true);
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

        _afterRegistration(info, true, true);
    }

    function _afterRegistryRegistration(NftId nftId, uint64 chainId, address registry) internal
    {
        assertTrue(block.chainid == 1, "Test error: _afterRegistryRegistration() called not on mainnet");

        assertEq(nftId.toInt(), core.chainNft.calculateTokenId(core.registry.REGISTRY_TOKEN_SEQUENCE_ID(), chainId), "Test error: _registryNftIdByChainId[chainId] inconsictent with core.chainNft.calculateTokenId[REGISTRY_TOKEN_SEQUENCE_ID, chainId]");
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
            registry,
            registryInfo.initialOwner,
            ""
        );

        _afterRegistration(info, false, false);
    }

    // ----------- getters checks ----------- //

    // assert all getters (with each registered nftId / address)
    function _checkRegistryGetters() internal
    {
        // solhint-disable-next-line
        //console.log("Checking all Registry getters");

        // check getters without args
        //console.log("   checking getters without args");

        assertEq(core.registry.getChainNftAddress(), address(core.chainNft), "getChainNftAddress() returned unexpected value");
        assertEq(core.registry.getReleaseRegistryAddress(), address(core.releaseRegistry), "getReleaseRegistryAddress() returned unexpected value");
        assertEq(core.registry.getStakingAddress(), address(core.staking), "getStakingAddress() returned unexpected value");
        assertEq(core.registry.getTokenRegistryAddress(), address(core.tokenRegistry), "getTokenRegistryAddress() returned unexpected value");
        assertEq(core.registry.getRegistryAdminAddress(), address(core.registryAdmin), "getRegistryAdminAddress() returned unexpected value");
        assertEq(core.registry.getAuthority(), address(core.registryAdmin.authority()), "getAuthority() returned unexpected value");

        assertEq(core.registry.getObjectCount(), EnumerableSet.length(_nftIds) - 1, "getObjectCount() returned unexpected value");// -1 because of NftIdLib.zero in the set
        assertEq(core.registry.getOwner(), registryInfo.initialOwner, "getOwner() returned unexpected value");
        assertEq(core.registry.getNftId().toInt(), registryNftId.toInt(), "getNftId() returned unexpected value");
        assertEq(core.registry.getProtocolNftId().toInt(), protocolNftId.toInt(), "getProtocolNftId() returned unexpected value");

        // TODO mirror release state in local state, use it in this checks
        assertEq(core.registry.getInitialVersion().toInt(), VERSION.toInt(), "getInitialVersion() returned unexpected value");
        // TODO next version points to the version undergoing deployment or to the latest active (if no new release was created since activation)
        assertEq(core.registry.getNextVersion().toInt(), VERSION.toInt(), "getNextVersion() returned unexpected value");
        assertEq(core.registry.getLatestVersion().toInt(), VERSION.toInt(), "getLatestVersion() returned unexpected value");


        // check for zero address
        //console.log("   checking with 0 address");

        assertEq(core.registry.getNftId( address(0) ).toInt(), NftIdLib.zero().toInt(), "getNftId(0) returned unexpected value");
        assertTrue(eqObjectInfo(core.registry.getObjectInfo( address(0) ), zeroObjectInfo()), "getObjectInfo(0) returned unexpected value");
        assertFalse(core.registry.isRegistered( address(0) ), "isRegistered(0) returned unexpected value");
        assertFalse(core.registry.isRegisteredService( address(0) ), "isRegisteredService(0) returned unexpected value");
        assertFalse(core.registry.isRegisteredComponent( address(0) ), "isRegisteredComponent(0) returned unexpected value");

        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, NftIdLib.zero().toInt()));
        core.registry.ownerOf(address(0));


        // check for zeroNftId    
        //console.log("   checking with 0 nftId");

        assertTrue(eqObjectInfo(core.registry.getObjectInfo(NftIdLib.zero()), zeroObjectInfo()), "getObjectInfo(zeroNftId) returned unexpected value");
        assertFalse(core.registry.isRegistered(NftIdLib.zero()), "isRegistered(zeroNftId) returned unexpected value");

        NftId zero = NftIdLib.zero();
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, zero.toInt()));
        core.registry.ownerOf(zero);


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
                owner = core.chainNft.ownerOf(nftId.toInt());
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
        assertEq(core.registry.chainIds(), EnumerableSet.length(_chainIds), "getChainIds() returned unexpected value");
        for(uint i = 0; i < EnumerableSet.length(_chainIds); i++)
        {
            uint64 chainId = uint64(EnumerableSet.at(_chainIds, i));
            assertEq(core.registry.getChainId(i), chainId, "getChainId(i) returned unexpected value");

            NftId nftId = _registryNftIdByChainId[chainId];
            assertEq(core.registry.getRegistryNftId(chainId).toInt(), nftId.toInt(), "getRegistryNftId(chainId) returned unexpected value");

            // redundant calls?
            assertEq(core.registry.getObjectInfo(nftId).objectType.toInt(), REGISTRY().toInt(), "getObjectInfo(nftId).objectType returned unexpected value");
            _assert_registry_getters(
                nftId,
                core.chainNft.ownerOf(nftId.toInt()) // owner
            );
        }
    }

    // assert getters related to a single nftId
    function _assert_registry_getters(
        NftId nftId, // can call with non zero nftId while _info[nftId] is zero
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

        assertTrue(eqObjectInfo(core.registry.getObjectInfo(nftId), expectedInfo), "getObjectInfo(nftId) returned unexpected value");

        // only objectType & initialOwner are never 0 for registered something
        assertEq(expectedInfo.initialOwner == address(0), expectedInfo.objectType.eqz(), "Test error: expected objectType is inconsistent with expected initialOwner");

        if(expectedInfo.objectType.gtz()) { // expect registered
        
            if(nftId == protocolNftId) {// special case: parentType == 0 for protocolNftId
                assertTrue(expectedParentType.eqz(), "Test error: parent type is not zero for protocol nftId");
            } else {
                assertTrue(expectedParentType.gtz(), "Test error: parent type is zero for registered nftId");
            }

            assertTrue(core.registry.isRegistered(nftId), "isRegistered(nftId) returned unexpected value #1");
            assertEq(core.registry.ownerOf(nftId), expectedOwner, "ownerOf(nftId) returned unexpected value");
        }
        else {// expect not registered
            assertTrue(expectedParentType.eqz(), "Test error: expected parent type is not zero for non regitered nftId");

            assertFalse(core.registry.isRegistered(nftId), "isRegistered(nftId) returned unexpected value #2"); 
            vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, nftId));
            core.registry.ownerOf(nftId);
        }

        // check "by address getters"
        //console.log("       checking by address getters with nftId ", nftId.toInt());

        if(nftId == protocolNftId) 
        {// special case: expected objectAddress == 0 for protocolNftId
            assertTrue(eqObjectInfo(expectedInfo, protocolInfo), "Test error: _info[protocolNftId] != protocolInfo");
            assertEq(_nftIdByAddress[expectedInfo.objectAddress].toInt(), 0, "Test error: _nftIdByAddress[protocol] != 0");
            assertEq(_registryNftIdByChainId[expectedChainId].toInt(), 0, "Test error: protocol _registryNftIdByChainId[chainId] != 0");

            assertTrue(eqObjectInfo(core.registry.getObjectInfo(protocolInfo.objectAddress), zeroObjectInfo()), "getObjectInfo(address) returned unexpected value #1");
            assertEq(core.registry.getNftId(protocolInfo.objectAddress).toInt(), 0, "getNftId(address) returned unexpected value #1");
            assertEq(core.registry.isRegistered(protocolInfo.objectAddress), false, "isRegistered(address) returned unexpected value #1");
            vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 0));
            core.registry.ownerOf(protocolInfo.objectAddress);

            assertEq(core.registry.isRegisteredComponent(protocolInfo.objectAddress), false, "isRegisteredComponent(address) returned unexpected value #1");

            assertEq(core.registry.isRegisteredService(protocolInfo.objectAddress), false, "isRegisteredService(address) returned unexpected value #1");
            assertEq(core.registry.getServiceAddress(expectedDomain, expectedVersion) , address(0), "getServiceAddress(domain, version) returned unexpected value #1");

            assertEq(core.registry.getRegistryNftId(expectedChainId).toInt(), 0, "getRegistryNftId(chainId) returned unexpected value #1");
        } 
        else if(nftId == globalRegistryNftId) 
        {
            assertTrue(eqObjectInfo(expectedInfo, globalRegistryInfo), "Test error: _info[globalRegistryNftId] != globalRegistryInfo");
            assertEq(_nftIdByAddress[expectedInfo.objectAddress].toInt(), globalRegistryNftId.toInt(), "Test error: _nftIdByAddress[globalRegistry] != globalRegistryNftId");
            assertEq(_registryNftIdByChainId[expectedChainId].toInt(), globalRegistryNftId.toInt(), "Test error: _registryNftIdByChainId[chainId] != globalRegistryNftId");

            assertTrue(eqObjectInfo(core.registry.getObjectInfo(globalRegistryInfo.objectAddress), globalRegistryInfo), "getObjectInfo(address) returned unexpected value #2");
            assertEq(core.registry.getNftId(globalRegistryInfo.objectAddress).toInt(), globalRegistryNftId.toInt(), "getNftId(address) returned unexpected value #2");
            assertEq(core.registry.isRegistered(globalRegistryInfo.objectAddress), true, "isRegistered(address) returned unexpected value #2");
            assertEq(core.registry.ownerOf(globalRegistryInfo.objectAddress), globalRegistryInfo.initialOwner, "ownerOf(address) returned unexpected value #2");

            assertEq(core.registry.isRegisteredComponent(globalRegistryInfo.objectAddress), false, "isRegisteredComponent(address) returned unexpected value #2");

            assertEq(core.registry.isRegisteredService(globalRegistryInfo.objectAddress), false, "isRegisteredService(address) returned unexpected value #2");
            assertEq(core.registry.getServiceAddress(expectedDomain, expectedVersion) , address(0), "getServiceAddress(domain, version) returned unexpected value #2");

            assertEq(core.registry.getRegistryNftId(expectedChainId).toInt(), globalRegistryNftId.toInt(), "getRegistryNftId(chainId) returned unexpected value #2");
        } 
        else if(nftId == registryNftId) 
        {
            assertTrue(eqObjectInfo(expectedInfo, registryInfo), "Test error: _info[registryNftId] != registryInfo");
            assertEq(_nftIdByAddress[expectedInfo.objectAddress].toInt(), registryNftId.toInt(), "Test error: _nftIdByAddress[address] != registryNftId");
            assertEq(_registryNftIdByChainId[expectedChainId].toInt(), registryNftId.toInt(), "Test error: _registryNftIdByChainId[chainId] != registryNftId");

            assertTrue(eqObjectInfo(core.registry.getObjectInfo(registryInfo.objectAddress), registryInfo), "getObjectInfo(address) returned unexpected value #3");
            assertEq(core.registry.getNftId(registryInfo.objectAddress).toInt(), registryNftId.toInt(), "getNftId(address) returned unexpected value #3");
            assertEq(core.registry.isRegistered(registryInfo.objectAddress), true, "isRegistered(address) returned unexpected value #3");
            assertEq(core.registry.ownerOf(registryInfo.objectAddress), registryInfo.initialOwner, "ownerOf(address) returned unexpected value #3");

            assertEq(core.registry.isRegisteredComponent(registryInfo.objectAddress), false, "isRegisteredComponent(address) returned unexpected value #3");

            assertEq(core.registry.isRegisteredService(registryInfo.objectAddress), false, "isRegisteredService(address) returned unexpected value #3");
            assertEq(core.registry.getServiceAddress(expectedDomain, expectedVersion) , address(0), "getServiceAddress(domain, version) returned unexpected value #3");

            assertEq(core.registry.getRegistryNftId(expectedChainId).toInt(), registryNftId.toInt(), "getRegistryNftId(chainId) returned unexpected value #3"); 
        } 
        else if(expectedInfo.objectType == REGISTRY()) 
        {// chain registry
            assertNotEq(expectedInfo.objectAddress, address(0), "Test error: chain registry address == 0");
            assertEq(expectedInfo.initialOwner, registryInfo.initialOwner, "Test error: chain registry initialOwner != NFT_LOCK_ADDRESS");
            assertEq(_nftIdByAddress[expectedInfo.objectAddress].toInt(), 0, "Test error: _nftIdByAddress[registry] != 0");
            assertEq(_registryNftIdByChainId[expectedChainId].toInt(), expectedInfo.nftId.toInt(), "Test error: chain registry _registryNftIdByChainId[chainId] != _info[nftId].nftId");

            assertTrue(eqObjectInfo(core.registry.getObjectInfo(expectedInfo.objectAddress), zeroObjectInfo()), "getObjectInfo(address) returned unexpected value #4");
            assertEq(core.registry.getNftId(expectedInfo.objectAddress).toInt(), 0, "getNftId(address) returned unexpected value #4");
            assertEq(core.registry.isRegistered(expectedInfo.objectAddress), false, "isRegistered(address) returned unexpected value #4");
            vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 0));
            core.registry.ownerOf(expectedInfo.objectAddress);

            assertEq(core.registry.isRegisteredComponent(expectedInfo.objectAddress), false, "isRegisteredComponent(address) returned unexpected value #4");

            assertEq(core.registry.isRegisteredService(expectedInfo.objectAddress), false, "isRegisteredService(address) returned unexpected value #4");
            assertEq(core.registry.getServiceAddress(expectedDomain, expectedVersion) , address(0), "getServiceAddress(domain, version) returned unexpected value #4");

            assertEq(core.registry.getRegistryNftId(expectedChainId).toInt(), expectedInfo.nftId.toInt(), "getRegistryNftId(chainId) returned unexpected value #4");
        }
        else if(expectedInfo.objectType == SERVICE()) 
        {
            assertEq(expectedParentAddress, address(core.registry), "Test error: service parentAddress != registryAddress");
            assertEq(expectedParentType.toInt(), REGISTRY().toInt(), "Test error: service parentType != REGISTRY()");
            assertNotEq(expectedInfo.objectAddress, address(0), "Test error: service address == 0");
            assertEq(_nftIdByAddress[expectedInfo.objectAddress].toInt(), expectedInfo.nftId.toInt(), "Test error: service _nftIdByAddress[serviceAddress] != _info[nftId].nftId");
            assertEq(_registryNftIdByChainId[expectedChainId].toInt(), 0, "Test error: service _registryNftIdByChainId[chainId] != 0");

            assertTrue(eqObjectInfo(core.registry.getObjectInfo(expectedInfo.objectAddress), expectedInfo), "getObjectInfo(address) returned unexpected value #5");
            assertEq(core.registry.getNftId(expectedInfo.objectAddress).toInt(), expectedInfo.nftId.toInt(), "getNftId(address) returned unexpected value #5");
            assertEq(core.registry.isRegistered(expectedInfo.objectAddress), true, "isRegistered(address) returned unexpected value #5");
            assertEq(core.registry.ownerOf(expectedInfo.objectAddress), expectedOwner, "ownerOf(address) returned unexpected value #5");

            assertEq(core.registry.isRegisteredComponent(expectedInfo.objectAddress), false, "isRegisteredComponent(address) returned unexpected value #5");

            assertEq(core.registry.isRegisteredService(expectedInfo.objectAddress), true, "isRegisteredService(address) returned unexpected value #5");
            assertEq(core.registry.getServiceAddress(expectedDomain, expectedVersion) , expectedInfo.objectAddress, "getServiceAddress(domain, version) returned unexpected value #5");

            assertEq(core.registry.getRegistryNftId(expectedChainId).toInt(), 0, "getRegistryNftId(chainId) returned unexpected value #5");
        } 
        else if(expectedParentType == INSTANCE()) 
        {
            assertEq(_registryNftIdByChainId[expectedChainId].toInt(), 0, "Test error: instance _registryNftIdByChainId[chainId] != 0");

            if(expectedInfo.objectAddress > address(0)) 
            { // contract for INSTANCE
                assertEq(_nftIdByAddress[expectedInfo.objectAddress].toInt(), expectedInfo.nftId.toInt(), "Test error: _nftIdByAddress[_info[nftId].objectAddress] != _info[nftId].nftId #1");

                assertTrue(eqObjectInfo(core.registry.getObjectInfo(expectedInfo.objectAddress), expectedInfo), "getObjectInfo(address) returned unexpected value #6");
                assertEq(core.registry.getNftId(expectedInfo.objectAddress).toInt(), expectedInfo.nftId.toInt(), "getNftId(address) returned unexpected value #6");
                assertEq(core.registry.isRegistered(expectedInfo.objectAddress), true, "isRegistered(address) returned unexpected value #6");
                assertEq(core.registry.ownerOf(expectedInfo.objectAddress), expectedOwner, "ownerOf(address) returned unexpected value #6");

                assertEq(core.registry.isRegisteredComponent(expectedInfo.objectAddress), true, "isRegisteredComponent(address) returned unexpected value #6");
            }
            else 
            { // object for INSTANCE
                assertEq(_nftIdByAddress[expectedInfo.objectAddress].toInt(), 0, "Test error: _nftIdByAddress[_info[nftId].objectAddress] != 0 #1");
    
                assertTrue(eqObjectInfo(core.registry.getObjectInfo(expectedInfo.objectAddress), zeroObjectInfo()), "getObjectInfo(address) returned unexpected value #6.5");
                assertEq(core.registry.getNftId(expectedInfo.objectAddress).toInt(), 0, "getNftId(address) returned unexpected value #6.5");
                assertEq(core.registry.isRegistered(expectedInfo.objectAddress), false, "isRegistered(address) returned unexpected value #6.5");
                vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 0));
                core.registry.ownerOf(expectedInfo.objectAddress);

                assertEq(core.registry.isRegisteredComponent(expectedInfo.objectAddress), false, "isRegisteredComponent(address) returned unexpected value #6.5");
            }

            assertEq(core.registry.isRegisteredService(expectedInfo.objectAddress), false, "isRegisteredService(address) returned unexpected value #6");
            assertEq(core.registry.getServiceAddress(expectedDomain, expectedVersion) , address(0), "getServiceAddress(domain, version) returned unexpected value #6"); 

            assertEq(core.registry.getRegistryNftId(expectedChainId).toInt(), 0, "getRegistryNftId(chainId) returned unexpected value #6");
        }
        else if(expectedInfo.objectAddress > address(0)) 
        {// the rest contracts
            assertEq(_nftIdByAddress[expectedInfo.objectAddress].toInt(), expectedInfo.nftId.toInt(), "Test error: _nftIdByAddress[_info[nftId].objectAddress] != _info[nftId].nftId #2");
            assertEq(_registryNftIdByChainId[expectedChainId].toInt(), 0, "Test error: _registryNftIdByChainId[chainId] != 0 #1");

            assertTrue(eqObjectInfo(core.registry.getObjectInfo(expectedInfo.objectAddress), expectedInfo), "getObjectInfo(address) returned unexpected value #7");
            assertEq(core.registry.getNftId(expectedInfo.objectAddress).toInt(), expectedInfo.nftId.toInt(), "getNftId(address) returned unexpected value #7");
            assertEq(core.registry.isRegistered(expectedInfo.objectAddress), true, "isRegistered(address) returned unexpected value #7");
            assertEq(core.registry.ownerOf(expectedInfo.objectAddress), expectedOwner, "ownerOf(address) returned unexpected value #7");

            assertEq(core.registry.isRegisteredComponent(expectedInfo.objectAddress), false, "isRegisteredComponent(address) returned unexpected value #7");

            assertEq(core.registry.isRegisteredService(expectedInfo.objectAddress), false, "isRegisteredService(address) returned unexpected value #7");
            assertEq(core.registry.getServiceAddress(expectedDomain, expectedVersion) , address(0), "getServiceAddress(domain, version) returned unexpected value #7");

            assertEq(core.registry.getRegistryNftId(expectedChainId).toInt(), 0, "getRegistryNftId(chainId) returned unexpected value #7"); 
        }
        else 
        { // the rest objects, some checks are redundant?
            assertEq(_nftIdByAddress[expectedInfo.objectAddress].toInt(), 0, "Test error: _nftIdByAddress[_info[nftId].objectAddress] != 0 #2");
            assertEq(_registryNftIdByChainId[expectedChainId].toInt(), 0, "Test error: _registryNftIdByChainId[chainId] != 0 #2");

            assertTrue(eqObjectInfo(core.registry.getObjectInfo(expectedInfo.objectAddress), zeroObjectInfo()), "getObjectInfo(address) returned unexpected value #8");
            assertEq(core.registry.getNftId(expectedInfo.objectAddress).toInt(), 0, "getNftId(address) returned unexpected value #8");
            assertEq(core.registry.isRegistered(expectedInfo.objectAddress), false, "isRegistered(address) returned unexpected value #8");
            vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 0));
            core.registry.ownerOf(expectedInfo.objectAddress);

            assertEq(core.registry.isRegisteredComponent(expectedInfo.objectAddress), false, "isRegisteredComponent(address) returned unexpected value #8");

            assertEq(core.registry.isRegisteredService(expectedInfo.objectAddress), false, "isRegisteredService(address) returned unexpected value #8");
            assertEq(core.registry.getServiceAddress(expectedDomain, expectedVersion) , address(0), "getServiceAddress(domain, version) returned unexpected value #8");

            assertEq(core.registry.getRegistryNftId(expectedChainId).toInt(), 0, "getRegistryNftId(chainId) returned unexpected value #8"); 
        }
    }

    // checks performed during internal _register() function call
    function _internalRegisterChecks(IRegistry.ObjectInfo memory info) internal view returns (bool expectRevert, bytes memory expectedRevertMsg)
    {
        NftId parentNftId = info.parentNftId;
        address parentAddress = _info[parentNftId].objectAddress;

        /*if(info.objectType != STAKE() && parentAddress == address(0)) {
            expectedRevertMsg = abi.encodeWithSelector(IRegistry.ErrorRegistryParentAddressZero.selector);
            expectRevert = true;
        } else*/ if(block.chainid != 1 && parentNftId == globalRegistryNftId) {
            expectedRevertMsg = abi.encodeWithSelector(IRegistry.ErrorRegistryGlobalRegistryAsParent.selector, info.objectType, parentNftId);
            expectRevert = true;
        } else if(info.objectAddress > address(0) && _nftIdByAddress[info.objectAddress].gtz()) {
            expectedRevertMsg = abi.encodeWithSelector(IRegistry.ErrorRegistryContractAlreadyRegistered.selector, info.objectAddress);
            expectRevert = true;
        } else if(info.initialOwner == address(0) || info.initialOwner.code.length != 0) { // EnumerableSet.contains(_contractAddresses, info.initialOwner)) {
            // "to" address is invalid for some reason
            // assume all contracts addresses are without IERC721Receiver support 
            // assume none of GIF contracts are supporting erc721 receiver interface -> components and tokens could but not now
            //console.log("initialOwner is in addresses set: %s", EnumerableSet.contains(_addresses, info.initialOwner));
            //console.log("initialOwner codehash: %s", uint(info.initialOwner.codehash));
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
        address registry,
        bool expectRevert, 
        bytes memory revertMsg) internal //returns (NftId nftId)
    {
        console.log("chain id", block.chainid);

        if(expectRevert)
        {
            vm.expectRevert(revertMsg);
        }
        else
        {
            NftId expectedNftId = NftIdLib.toNftId(core.chainNft.calculateTokenId(core.registry.REGISTRY_TOKEN_SEQUENCE_ID(), chainId));
            vm.expectEmit(address(core.registry));
            emit LogChainRegistryRegistration(expectedNftId, chainId, registry);
        }

        /*NftId nftId = */
        core.registry.registerRegistry(nftId, chainId, registry); 

        if(expectRevert == false)
        {
            //assertEq(nftId.toInt(), core.chainNft.calculateTokenId(core.registry.REGISTRY_TOKEN_SEQUENCE_ID(), chainId, "registerRegistry() returned unexpected nftId"));

            _afterRegistryRegistration(nftId, chainId, registry); 

            _checkRegistryGetters();

            // solhint-disable-next-line
            console.log("Registered:"); 
            _logObjectInfo(_info[nftId]);
            console.log("nftIdByAddress ", _nftIdByAddress[registry].toInt());
            console.log("");
            //_logObjectInfo(core.registry.getObjectInfo(nftId));
            //console.log(core.registry.getNftId(registry).toInt());
            //console.log("");
            // solhint-enable
        }
    }

    function _assert_registerRegistry_withChecks(NftId nftId, uint64 chainId, address registry) public //returns (NftId nftId)
    {
        bool expectRevert;
        bytes memory expectedRevertMsg;

        //console.log("   Doing registerRegistry() function checks");
        (expectRevert, expectedRevertMsg) = _registerRegistryChecks(nftId, chainId, registry);

        //console.log("   Calling registerRegistry()");
        //nftId = 
        _assert_registerRegistry(nftId, chainId, registry, expectRevert, expectedRevertMsg);
    }

    function _registerRegistryChecks(NftId nftId, uint256 chainId, address registry) internal returns (bool expectRevert, bytes memory expectedRevertMsg)
    {
        if(_sender != gifAdmin) 
        {// auth check
            expectedRevertMsg = abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, _sender);
            expectRevert = true;
        } else if (block.chainid != 1) {// registration of chain registries only allowed on mainnet
            expectedRevertMsg = abi.encodeWithSelector(IRegistry.ErrorRegistryNotOnMainnet.selector, block.chainid);
            expectRevert = true;
        } else if(_info[nftId].objectType.gtz()) {
            expectedRevertMsg = abi.encodeWithSelector(IRegistry.ErrorRegistryAlreadyRegistered.selector, nftId);
            expectRevert = true;
        } else if(nftId.toInt() != core.chainNft.calculateTokenId(core.registry.REGISTRY_TOKEN_SEQUENCE_ID(), chainId)) {
            expectedRevertMsg = abi.encodeWithSelector(IRegistry.ErrorRegistryNftIdInvalid.selector, nftId, chainId);
            expectRevert = true;
        } else if(registry == address(0)) {
            expectedRevertMsg = abi.encodeWithSelector(IRegistry.ErrorRegistryAddressZero.selector, nftId);
            expectRevert = true;
        }
    }
    // TODO remove call with gifAdmin from test function -> add test_registerRegistry_withValidSender() tests
    function registerRegistry_testFunction(
        address sender,
        NftId nftId,
        uint64 chainId,
        address registry) public //returns (NftId nftId)
    {
        vm.assume(chainId > 0);

        _startPrank(sender);

        _assert_registerRegistry_withChecks(nftId, chainId, registry);

        _stopPrank();
/*
        if(sender != gifAdmin) {
            _startPrank(gifAdmin);

            _assert_registerRegistry_withChecks(nftId, chainId, registry);

            _stopPrank();
        }
*/
    }

    // -------------- registerService() related test functions ---------------- //

    // assert call to registerService() function
    function _assert_registerService(
        IRegistry.ObjectInfo memory info,
        VersionPart version,
        ObjectType domain,
        bool expectRevert, 
        bytes memory revertMsg) internal returns (NftId nftId)
    {   
        console.log("chain id", block.chainid);

        if(expectRevert)
        {
            vm.expectRevert(revertMsg);
        }
        else
        {
            NftId expectedTokenId = NftIdLib.toNftId(core.chainNft.calculateTokenId(_nextId));
            vm.expectEmit(address(core.registry));
            emit LogRegistration(
                expectedTokenId,
                info.parentNftId, 
                info.objectType, 
                info.isInterceptor,
                info.objectAddress, 
                info.initialOwner
            );

            vm.expectEmit();
            emit LogServiceRegistration(version, domain);
        }

        nftId = core.registry.registerService(info, version, domain); 
        info.nftId = nftId;

        if(expectRevert == false)
        {
            assertEq(nftId.toInt(), core.chainNft.calculateTokenId(_nextId), "registerService() returned unexpected nftId");

            _afterServiceRegistration(info, version, domain);

            _checkRegistryGetters();

            // solhint-disable-next-line
            console.log("Registered:"); 
            _logObjectInfo(info);
            console.log("");
            // solhint-enable
        }
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
        if(_sender != address(core.releaseRegistry)) 
        {// auth check
            expectedRevertMsg = abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, _sender);
            expectRevert = true;
        } else if(info.objectAddress == address(0)) {
            expectedRevertMsg = abi.encodeWithSelector(
                IRegistry.ErrorRegistryServiceAddressZero.selector);
            expectRevert = true;
        } else if(version.eqz()) {
            expectedRevertMsg = abi.encodeWithSelector(
                IRegistry.ErrorRegistryServiceVersionZero.selector);
            expectRevert = true;
        } else if(domain.eqz()) {
            expectedRevertMsg = abi.encodeWithSelector(
                IRegistry.ErrorRegistryDomainZero.selector,
                info.objectAddress);
            expectRevert = true;
        } else if(info.objectType != SERVICE()) {
            expectedRevertMsg = abi.encodeWithSelector(
                IRegistry.ErrorRegistryNotService.selector,
                info.objectAddress,
                info.objectType);
            expectRevert = true;
        } else if(info.parentNftId != registryNftId) {
            expectedRevertMsg = abi.encodeWithSelector(
                IRegistry.ErrorRegistryServiceParentNotRegistry.selector,
                info.parentNftId);
            expectRevert = true;
        } else if(_service[version][domain] > address(0)) {
            expectedRevertMsg = abi.encodeWithSelector(
                IRegistry.ErrorRegistryDomainAlreadyRegistered.selector,
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
            NftId expectedNftId = NftIdLib.toNftId(core.chainNft.calculateTokenId(_nextId));
            vm.expectEmit(address(core.registry));
            emit LogRegistration(
                expectedNftId, 
                info.parentNftId, 
                info.objectType, 
                info.isInterceptor,
                info.objectAddress, 
                info.initialOwner
            );
        }

        nftId = core.registry.register(info);
        info.nftId = nftId;

        if(expectRevert == false)
        {
            assertEq(nftId.toInt(), core.chainNft.calculateTokenId(_nextId), "register() returned unexpected nftId");

            _afterRegistration(info, true, true);

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
            expectedRevertMsg = abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, _sender);
            expectRevert = true;
        } else if(info.objectAddress > address(0)) 
        {
            //if(_coreContractTypesCombos.contains(ObjectTypePairLib.toObjectTypePair(info.objectType, parentType)) == false)
            if(_isCoreContractTypesCombo[info.objectType][parentType] == false)
            {// parent must be registered + object-parent types combo must be valid
                expectedRevertMsg = abi.encodeWithSelector(IRegistry.ErrorRegistryTypesCombinationInvalid.selector, info.objectType, parentType);
                expectRevert = true;
            }
        } else 
        {
            //if(_coreObjectTypesCombos.contains(ObjectTypePairLib.toObjectTypePair(info.objectType, parentType)) == false)
            if(_isCoreObjectTypesCombo[info.objectType][parentType] == false)
            {// state object checks, parent must be registered + object-parent types combo must be valid
                expectedRevertMsg = abi.encodeWithSelector(IRegistry.ErrorRegistryTypesCombinationInvalid.selector, info.objectType, parentType);
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
        if(expectRevert)
        {
            vm.expectRevert(revertMsg);
        }
        else
        {
            NftId expectedNftId = NftIdLib.toNftId(core.chainNft.calculateTokenId(_nextId));
            vm.expectEmit(address(core.registry));
            emit LogRegistration(
                expectedNftId, 
                info.parentNftId, 
                info.objectType, 
                info.isInterceptor,
                info.objectAddress, 
                info.initialOwner
            );
        }

        nftId = core.registry.registerWithCustomType(info);
        info.nftId = nftId;

        if(expectRevert == false)
        {
            assertEq(nftId.toInt(), core.chainNft.calculateTokenId(_nextId), "registerWithCustomType() returned unexpected nftId");

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
    function _registerWithCustomTypeChecks(IRegistry.ObjectInfo memory info) internal returns (bool expectRevert, bytes memory expectedRevertMsg)
    {
        NftId parentNftId = info.parentNftId;
        ObjectType parentType = _info[parentNftId].objectType;

        if(_sender != address(registryServiceMock)) 
        {// auth check
            expectedRevertMsg = abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, _sender);
            expectRevert = true;
        } else if(EnumerableSet.contains(_types, info.objectType.toInt()) && info.objectType.toInt() != ObjectTypeLib.zero().toInt()) { // check for 0 because _types contains zero type
            expectedRevertMsg = abi.encodeWithSelector(IRegistry.ErrorRegistryCoreTypeRegistration.selector);
            expectRevert = true;
        } else if( // custom type can not be 0 AND its parent type can not be 0 / PROTOCOL / SERVICE
            info.objectType == ObjectTypeLib.zero() ||
            parentType == ObjectTypeLib.zero() ||
            parentType == PROTOCOL() || 
            parentType == SERVICE()
        ) { 
            expectedRevertMsg = abi.encodeWithSelector(IRegistry.ErrorRegistryTypesCombinationInvalid.selector, info.objectType, parentType);
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
        } while(EnumerableSet.contains(_registeredAddresses, addr));
    }

    // returns valid random, non mainnet chanId
    function _getRandomChainId() public returns (uint64 chainId) {
        do {
            chainId = uint64(randomNumber(type(uint64).max));
        } while(chainId == 1 || chainId == 0);
    }

    // returns valid random chainId which is not in _chainIds set
    // DO NOT use this function before RegistryTestBase.setUp() is called
    function _getNotRegisteredRandomChainId() public returns (uint64 chainId) {
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
