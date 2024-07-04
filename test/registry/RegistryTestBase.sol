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
    event LogChainRegistryRegistration(NftId nftId, uint256 chainId, address chainRegistryAddress);

    VersionPart public constant VERSION = VersionPart.wrap(3);

    RegistryServiceManagerMock public registryServiceManagerMock;
    RegistryServiceMock public registryServiceMock;

    IERC20Metadata public dip;

    address public globalRegistry = makeAddr("globalRegistry");
    address public registryOwner = makeAddr("registryOwner");
    address public outsider = makeAddr("outsider");
    address public gifAdmin = registryOwner;
    address public gifManager = registryOwner;
    address public stakingOwner = registryOwner;

    RegistryAdmin registryAdmin;
    StakingManager stakingManager;
    Staking staking;
    ReleaseRegistry releaseRegistry;

    Registry public registry;
    address public registryAddress;
    TokenRegistry public tokenRegistry;
    ChainNft public chainNft;

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
    EnumerableSet.AddressSet internal _addresses; // set of all addresses (actors + registered + initial owners) + zero address
    EnumerableSet.AddressSet internal _registeredAddresses; // set of all registered addresses
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
    mapping(VersionPart version => mapping(ObjectType serviceDomain => address)) public _service;

    // aditional part to check service related getters
    struct ServiceInfo{
        VersionPart version;
        ObjectType domain;
    }
    mapping(NftId nftId => ServiceInfo) public _serviceInfo;

    uint public _servicesCount;


    function setUp() public virtual
    {
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
        
        chainNft = ChainNft(registry.getChainNftAddress());
        registryNftId = registry.getNftId(address(registry));
        registryAddress = address(registry);
        stakingNftId = registry.getNftId(address(staking));

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
                registryAddress, 
                releaseSalt);
        }

        registryServiceMock = RegistryServiceMock(address(registryServiceManagerMock.getRegistryService()));
        releaseRegistry.registerService(registryServiceMock);
        registryServiceManagerMock.linkToProxy();
        registryServiceNftId = registry.getNftId(address(registryServiceMock));

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
            // both are the same
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
            registryNftId = NftIdLib.toNftId(
                chainNft.calculateTokenId(registry.REGISTRY_TOKEN_SEQUENCE_ID())
            );

            globalRegistryInfo = IRegistry.ObjectInfo(
                globalRegistryNftId,
                protocolNftId,
                REGISTRY(),
                false,
                globalRegistry,
                registry.NFT_LOCK_ADDRESS(),
                "" 
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

        stakingInfo = IRegistry.ObjectInfo(
            stakingNftId,
            registryNftId,
            STAKING(),
            false,
            address(staking), // must be without erc721 receiver support?
            stakingOwner,
            ""
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

        // protocol 1101
        // gloabal registry 2101
        // local registry 2xxxx
        // local staking 3xxx
        // local registry service 4xxx
        _nextId = 5; // starting nft index after deployment

        // special case: need 0 in _nftIds[] set, assume registry always have zeroObjectInfo registered as NftIdLib.zero
        _info[NftIdLib.zero()] = zeroObjectInfo();
        _info[protocolNftId] = protocolInfo;
        _info[globalRegistryNftId] = globalRegistryInfo;
        _info[registryNftId] = registryInfo;
        _info[stakingNftId] = stakingInfo;
        _info[registryServiceNftId] = registryServiceInfo; 

        _nftIdByAddress[address(registry)] = registryNftId;
        _nftIdByAddress[address(staking)] = stakingNftId;
        _nftIdByAddress[address(registryServiceMock)] = registryServiceNftId;

        _service[VERSION][REGISTRY()] = address(registryServiceMock);
        _serviceInfo[registryServiceNftId] = ServiceInfo(VERSION, REGISTRY());
        _servicesCount = 1;

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
        EnumerableSet.add(_addresses, address(registryServiceMock));
        EnumerableSet.add(_addresses, address(registry)); // IMPORTANT: do not use as sender -> can not call itself
        EnumerableSet.add(_addresses, address(staking));

        EnumerableSet.add(_registeredAddresses, address(registryServiceMock));
        EnumerableSet.add(_registeredAddresses, address(registry));
        EnumerableSet.add(_registeredAddresses, address(staking));

        // also core types used in register() function
        // registerService() and registerWithCustomType() disallow this types being registered
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
        _addressName[address(registry)] = "Registry";
        _addressName[address(staking)] = "Staking";
        _addressName[address(registryServiceMock)] = "registryServiceMock";
        
        _errorName[IAccessManaged.AccessManagedUnauthorized.selector] = "AccessManagedUnauthorized"; 
        //_errorName[IRegistry.ErrorRegistryCallerNotReleaseRegistry.selector] = "ErrorRegistryCallerNotReleaseManager"; 
        _errorName[IRegistry.ErrorRegistryParentAddressZero.selector] = "ErrorRegistryParentAddressZero"; 
        _errorName[IRegistry.ErrorRegistryContractAlreadyRegistered.selector] = "ErrorRegistryContractAlreadyRegistered";
        _errorName[IRegistry.ErrorRegistryTypesCombinationInvalid.selector] = "ErrorRegistryTypesCombinationInvalid";
        _errorName[IRegistry.ErrorRegistryCoreTypeRegistration.selector] = "ErrorRegistryCoreTypeRegistration";
        _errorName[IRegistry.ErrorRegistryServiceAddressZero.selector] = "ErrorRegistryServiceAddressZero";
        _errorName[IRegistry.ErrorRegistryServiceVersionZero.selector] = "ErrorRegistryServiceVersionZero";
        _errorName[IRegistry.ErrorRegistryDomainZero.selector] = "ErrorRegistryDomainZero";
        _errorName[IRegistry.ErrorRegistryDomainAlreadyRegistered.selector] = "ErrorRegistryDomainAlreadyRegistered";
        _errorName[IRegistry.ErrorRegistryNotService.selector] = "ErrorRegistryNotService";
        _errorName[IRegistry.ErrorRegistryServiceParentNotRegistry.selector] = "ErrorRegistryServiceParentNotRegistry";
        _errorName[IERC721Errors.ERC721InvalidReceiver.selector] = "ERC721InvalidReceiver";
    }

    // call after every succesfull registration with register() or registerWithCustomType() functions, before checks
    function _afterRegistration(IRegistry.ObjectInfo memory info) internal virtual
    {
        _nextId++;

        NftId nftId = info.nftId;

        assertEq(_info[nftId].nftId.toInt(), 0, "Test error: _info[nftId].nftId already set");
        _info[nftId] = info;
        
        assertFalse(EnumerableSet.contains(_nftIds, info.nftId.toInt()), "Test error: _nftIds already contains nftId");
        EnumerableSet.add(_nftIds , nftId.toInt());

        EnumerableSet.add(_addresses, info.initialOwner);

        if(info.objectAddress > address(0)) { 
            assertEq(_nftIdByAddress[info.objectAddress].toInt(), 0, "Test error: _nftIdByAddress already set");
            _nftIdByAddress[info.objectAddress] = nftId; 

            //assertFalse(EnumerableSet.contains(_addresses, info.objectAddress), "Test error: _addresses already contains objectAddress"); // previously initial owner can become registerable
            assertFalse(EnumerableSet.contains(_registeredAddresses, info.objectAddress), "Test error: _registeredAddresses already contains objectAddress");
            EnumerableSet.add(_addresses, info.objectAddress);
            EnumerableSet.add(_registeredAddresses, info.objectAddress);
        }
    }

    // call after every succesfull registration with registerService() function, before checks
    function _afterServiceRegistration(IRegistry.ObjectInfo memory info, VersionPart version, ObjectType domain) internal 
    {
        assertEq(info.objectType.toInt(), SERVICE().toInt(), "Test error: _afterServiceRegistration() called with non-service object");
        _afterRegistration(info);

        NftId nftId = info.nftId;
        assertEq(_service[version][domain], address(0), "Test error: _service[version][domain] already set");
        assertEq(_serviceInfo[nftId].version.toInt(), 0, "Test error: _serviceInfo[nftId].version already set");
        assertEq(_serviceInfo[nftId].domain.toInt(), 0, "Test error: _serviceInfo[nftId].domain already set");
        _service[version][domain] = info.objectAddress;
        _serviceInfo[info.nftId] = ServiceInfo(version, domain);
        _servicesCount++;
    }

    // ----------- getters checks ----------- //

    // assert all getters (with each registered nftId / address)
    function _checkRegistryGetters() internal
    {
        // solhint-disable-next-line
        console.log("Checking all Registry getters");

        // check getters without args
        //console.log("   checking getters without args");

        assertEq(registry.getChainNftAddress(), address(chainNft), "getChainNftAddress() returned unexpected value");
        assertEq(registry.getReleaseRegistryAddress(), address(releaseRegistry), "getReleaseRegistryAddress() returned unexpected value");
        assertEq(registry.getStakingAddress(), address(staking), "getStakingAddress() returned unexpected value");
        assertEq(registry.getTokenRegistryAddress(), address(tokenRegistry), "getTokenRegistryAddress() returned unexpected value");
        assertEq(registry.getRegistryAdminAddress(), address(registryAdmin), "getRegistryAdminAddress() returned unexpected value");
        assertEq(registry.getAuthority(), address(registryAdmin.authority()), "getAuthority() returned unexpected value");

        assertEq(registry.getObjectCount(), EnumerableSet.length(_nftIds) - 1, "getObjectCount() returned unexpected value");// -1 because of NftIdLib.zero in the set
        assertEq(registry.getOwner(), registry.NFT_LOCK_ADDRESS(), "getOwner() returned unexpected value");
        assertEq(registry.getNftId().toInt(), registryNftId.toInt(), "getNftId() returned unexpected value");
        assertEq(registry.getProtocolNftId().toInt(), protocolNftId.toInt(), "getProtocolNftId() returned unexpected value");
        // TODO mirror chain id state in local state, use it in this check
        if(block.chainid == 1) {
            assertEq(registry.chainIds(), 1, "getChainIds() returned unexpected value #1");
        } else {
            assertEq(registry.chainIds(), 2, "getChainIds() returned unexpected value #2");
        }
        // TODO mirror release state in local state, use it in this checks
        assertEq(registry.getInitialVersion().toInt(), VERSION.toInt(), "getInitialVersion() returned unexpected value");
        // TODO next version points to the version undergoing deployment or to the latest active (if no new release was created since activation)
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
            zeroObjectInfo(),
            VersionLib.zeroVersion().toMajorPart(), // version
            ObjectTypeLib.zero(), // domain
            address(0) // owner
        );

        // loop through every registered nftId
        // _nftIds[] MUST contain NftIdLib.zero()
        uint servicesFound = 0;

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
                nftId, 
                _info[nftId],
                _serviceInfo[nftId].version,
                _serviceInfo[nftId].domain,
                owner
            );

            // special case service
            if(_info[nftId].objectType == SERVICE())
            {
                servicesFound++;
                assertTrue(_servicesCount >= servicesFound, "Test error: found more registered services than expected");
            }
        }

        assertEq(_servicesCount, servicesFound, "Test error: found less registered services than expected");        
    }

    // assert getters related to a single nftId
    function _assert_registry_getters(
        NftId nftId, 
        IRegistry.ObjectInfo memory expectedInfo, 
        VersionPart expectedVersion,
        ObjectType expectedDomain,
        address expectedOwner
    ) 
        internal
    {
        // check "by nftId getters"
        //console.log("       checking by nftId getters with nftId ", nftId.toInt());
        assertTrue(eqObjectInfo(registry.getObjectInfo(nftId), expectedInfo), "getObjectInfo(nftId) returned unexpected value");
        if(expectedOwner > address(0)) { // expect registered
            assertTrue(registry.isRegistered(nftId), "isRegistered(nftId) returned unexpected value #1");
            assertEq(registry.ownerOf(nftId), expectedOwner, "ownerOf(nftId) returned unexpected value");
        }
        else {// expect not registered
            assertFalse(registry.isRegistered(nftId), "isRegistered(nftId) returned unexpected value #2"); 
            vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, nftId));
            registry.ownerOf(nftId);
        }

        // check "by address getters"
        //console.log("       checking by address getters with nftId ", nftId.toInt());
        if(expectedInfo.objectAddress > address(0)) 
        {// expect contract
            assertEq(registry.getNftId(expectedInfo.objectAddress).toInt(), nftId.toInt(), "getNftId(address) returned unexpected value");
            assertTrue(eqObjectInfo(registry.getObjectInfo(expectedInfo.objectAddress), expectedInfo), "getObjectInfo(address) returned unexpected value");
            if(expectedOwner > address(0)) {  // expect registered
                assertTrue(registry.isRegistered(expectedInfo.objectAddress), "isRegistered(address) returned unexpected value #1");
                assertEq(registry.ownerOf(expectedInfo.objectAddress), expectedOwner, "ownerOf(address) returned unexpected value");

            } else {// expect not registered
                assertFalse(registry.isRegistered(expectedInfo.objectAddress), "isRegistered(address) returned unexpected value #2"); 
                vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, nftId));
                registry.ownerOf(expectedInfo.objectAddress);
            }
        }

        if(
            _info[_info[nftId].parentNftId].objectType == INSTANCE() &&
            expectedInfo.objectAddress > address(0) // because custom type for INSTANCE can have 0 address
        ) {
            assertTrue(registry.isRegisteredComponent(expectedInfo.objectAddress), "isRegisteredComponent(nftId) returned unexpected value #1");
        } else {
            assertFalse(registry.isRegisteredComponent(expectedInfo.objectAddress), "isRegisteredComponent(nftId) returned unexpected value #2");
        }

        if(expectedInfo.objectType == SERVICE())
        {            
            assertEq(_service[expectedVersion][expectedDomain] , expectedInfo.objectAddress , "Test error: _info[] inconsictent with _service[][] #1");

            assertTrue(registry.isRegisteredService(expectedInfo.objectAddress), "isRegisteredService(nftId) returned unexpected value #1");
            assertEq(registry.getServiceAddress(expectedDomain, expectedVersion) , expectedInfo.objectAddress, "getServiceAddress(type, versionPart) returned unexpected value #1");  
        }
        else
        {
            assertEq(_service[expectedVersion][expectedDomain] , address(0) , "Test error: _info[] inconsictent with _service[][] #2");

            assertFalse(registry.isRegisteredService(expectedInfo.objectAddress), "isRegisteredService(nftId) returned unexpected value #2");
            assertEq(registry.getServiceAddress(expectedDomain, expectedVersion), address(0) , "getServiceAddress(type, versionPart) returned unexpected value #2");  
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
        } else if(info.objectAddress > address(0) && _nftIdByAddress[info.objectAddress] != NftIdLib.zero()) {
            expectedRevertMsg = abi.encodeWithSelector(IRegistry.ErrorRegistryContractAlreadyRegistered.selector, info.objectAddress);
            expectRevert = true;
        } else if(info.initialOwner == address(0) || info.initialOwner.code.length != 0)
        {// ERC721 check, assume none of GIF contracts are supporting erc721 receiver interface -> components and tokens could but not now
            //console.log("initialOwner is in addresses set: %s", EnumerableSet.contains(_addresses, info.initialOwner));
            //console.log("initialOwner codehash: %s", uint(info.initialOwner.codehash));
            expectedRevertMsg = abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, info.initialOwner);
            expectRevert = true;
        }

        // TODO add interceptor checks
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
        if(expectRevert)
        {
            vm.expectRevert(revertMsg);
        }
        else
        {
            NftId expectedTokenId = NftIdLib.toNftId(chainNft.calculateTokenId(_nextId));
            vm.expectEmit(address(registry));
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

        nftId = registry.registerService(info, version, domain); 
        info.nftId = nftId;

        if(expectRevert == false)
        {
            assertEq(nftId.toInt(), chainNft.calculateTokenId(_nextId), "registerService() returned unexpected nftId");

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
        if(_sender != address(releaseRegistry)) 
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

        if(sender != address(releaseRegistry)) {
            _startPrank(address(releaseRegistry));

            _assert_registerService_withChecks(info, version ,domain);

            _stopPrank();
        }
    }

    // -------------- register() related test functions ---------------- //

    // assert call to register() function
    function _assert_register(IRegistry.ObjectInfo memory info, bool expectRevert, bytes memory revertMsg) internal returns (NftId nftId)
    {
        if(expectRevert)
        {
            vm.expectRevert(revertMsg);
        }
        else
        {
            NftId expectedNftId = NftIdLib.toNftId(chainNft.calculateTokenId(_nextId));
            vm.expectEmit(address(registry));
            emit LogRegistration(
                expectedNftId, 
                info.parentNftId, 
                info.objectType, 
                info.isInterceptor,
                info.objectAddress, 
                info.initialOwner
            );
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

        if(sender != address(registryServiceMock)) {
            _startPrank(address(registryServiceMock));

            _assert_register_withChecks(info);

            _stopPrank();
        }
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
            NftId expectedNftId = NftIdLib.toNftId(chainNft.calculateTokenId(_nextId));
            vm.expectEmit(address(registry));
            emit LogRegistration(
                expectedNftId, 
                info.parentNftId, 
                info.objectType, 
                info.isInterceptor,
                info.objectAddress, 
                info.initialOwner
            );
        }

        nftId = registry.registerWithCustomType(info);
        info.nftId = nftId;

        if(expectRevert == false)
        {
            assertEq(nftId.toInt(), chainNft.calculateTokenId(_nextId), "registerWithCustomType() returned unexpected nftId");

            _afterRegistration(info);

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

        if(sender != address(registryServiceMock)) {
            _startPrank(address(registryServiceMock));

            _assert_registerWithCustomType_withChecks(info);

            _stopPrank();
        }
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

    function _getSenderName() internal view returns(string memory) {

        if(Strings.equal(_addressName[_sender], "")) {
            return Strings.toString(uint160(_sender));
        }
        return _addressName[_sender];
    }

    function _getTypeName(ObjectType objectType) internal view returns(string memory) {
        if(Strings.equal(_typeName[objectType], "")) {
            return Strings.toString(objectType.toInt());
        }

        return _typeName[objectType];
    }

    function _getObjectTypeAtIndex(uint256 index) internal view returns (ObjectType) {
        return ObjectTypeLib.toObjectType(EnumerableSet.at(_types, (index % EnumerableSet.length(_types))));
    }

    function _getNftIdAtIndex(uint256 index) internal view returns (NftId) {
        return NftIdLib.toNftId(EnumerableSet.at(_nftIds, (index % EnumerableSet.length(_nftIds))));
    }

    function _getAddressAtIndex(uint256 index) internal view returns (address) {
        return EnumerableSet.at(_addresses, (index % EnumerableSet.length(_addresses)));
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
