// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {FoundryRandom} from "foundry-random/FoundryRandom.sol";

import {Test, Vm, console} from "../../lib/forge-std/src/Test.sol";

import {blockBlocknumber} from "../../contracts/type/Blocknumber.sol";
import {VersionLib, Version, VersionPart, VersionPartLib } from "../../contracts/type/Version.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {Timestamp, TimestampLib} from "../../contracts/type/Timestamp.sol";
import {Blocknumber, BlocknumberLib} from "../../contracts/type/Blocknumber.sol";
import {ObjectType, ObjectTypeLib, toObjectType, zeroObjectType, PROTOCOL, REGISTRY, TOKEN, SERVICE, INSTANCE, PRODUCT, POOL, ORACLE, DISTRIBUTION, DISTRIBUTOR, BUNDLE, POLICY, STAKE} from "../../contracts/type/ObjectType.sol";
import {RoleId} from "../../contracts/type/RoleId.sol";

import {IService} from "../../contracts/shared/IService.sol";

import {ChainNft} from "../../contracts/registry/ChainNft.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {RegistryServiceManager} from "../../contracts/registry/RegistryServiceManager.sol";
import {ReleaseManager} from "../../contracts/registry/ReleaseManager.sol";
import {RegistryAccessManager} from "../../contracts/registry/RegistryAccessManager.sol";

import {Staking} from "../../contracts/staking/Staking.sol";
import {StakingManager} from "../../contracts/staking/StakingManager.sol";

import {TokenRegistry} from "../../contracts/registry/TokenRegistry.sol";
//import {DistributionServiceManager} from "../../contracts/distribution/DistributionServiceManager.sol";

import {RegistryServiceManagerMock} from "../mock/RegistryServiceManagerMock.sol";
import {RegistryServiceMock} from "../mock/RegistryServiceMock.sol";
import {RegistryServiceTestConfig} from "../registryService/RegistryServiceTestConfig.sol";
import {Dip} from "../../contracts/mock/Dip.sol";


// Helper functions to test IRegistry.ObjectInfo structs 
function eqObjectInfo(IRegistry.ObjectInfo memory a, IRegistry.ObjectInfo memory b) pure returns (bool isSame) {
    return (
        (a.nftId == b.nftId) &&
        (a.parentNftId == b.parentNftId) &&
        (a.objectType == b.objectType) &&
        (a.objectAddress == b.objectAddress) &&
        (a.initialOwner == b.initialOwner) &&
        (a.data.length == b.data.length) &&
        keccak256(a.data) == keccak256(b.data)
    );
}

function zeroObjectInfo() pure returns (IRegistry.ObjectInfo memory) {
    return (
        IRegistry.ObjectInfo(
            NftIdLib.zero(),
            NftIdLib.zero(),
            zeroObjectType(),
            false,
            address(0),
            address(0),
            bytes("")
        )
    );
}

function toBool(uint256 uintVal) pure returns (bool boolVal)
{
    assembly {
        boolVal := uintVal
    }
}

contract RegistryTestBase is Test, FoundryRandom {

    // keep indentical to IRegistry events
    event LogRegistration(NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, address objectAddress, address initialOwner);
    event LogServiceRegistration(VersionPart majorVersion, ObjectType domain);

    bytes32 public constant EOA_CODEHASH = 0xC5D2460186F7233C927E7DB2DCC703C0E500B653CA82273B7BFAD8045D85A470;
    VersionPart public constant VERSION = VersionPart.wrap(3);

    RegistryServiceManagerMock public registryServiceManagerMock;
    RegistryServiceMock public registryServiceMock;

    IERC20Metadata public dip = new Dip();

    address public registryOwner = makeAddr("registryOwner");
    address public outsider = makeAddr("outsider");

    RegistryAccessManager accessManager;
    StakingManager stakingManager;
    Staking staking;
    ReleaseManager releaseManager;

    RegistryServiceManager public registryServiceManager;
    RegistryService public registryService;
    Registry public registry;
    address public registryAddress;
    TokenRegistry public tokenRegistry;
    ChainNft public chainNft;

    address public _sender; // use with _startPrank(), _stopPrank()
    uint public _nextId; // use with chainNft.calculateId()

    NftId public protocolNftId = NftIdLib.toNftId(1101);
    NftId public globalRegistryNftId = NftIdLib.toNftId(2101);
    NftId public registryNftId; // chainId dependent
    NftId public registryServiceNftId = NftIdLib.toNftId(33133705);

    IRegistry.ObjectInfo public protocolInfo;
    IRegistry.ObjectInfo public globalRegistryInfo; // chainId dependent
    IRegistry.ObjectInfo public registryInfo; // chainId dependent
    IRegistry.ObjectInfo public registryServiceInfo;

    // test sets
    EnumerableSet.AddressSet internal _addresses; // set of all addresses (actors + registered + initial owners)
    EnumerableSet.AddressSet internal _registeredAddresses;
    EnumerableSet.UintSet internal _nftIds;
    ObjectType[] public _types; 

    mapping(address => string name) public _addressName;
    mapping(ObjectType objectType => string name) public _typeName;
    mapping(bytes4 errorSelector => string name) public _errorName;

    // tracks valid object-parent types combinations
    mapping(ObjectType objectType => mapping(
            ObjectType parentType => bool)) public _isValidContractTypesCombo;
    mapping(ObjectType objectType => mapping(
            ObjectType parentType => bool)) public _isValidObjectTypesCombo;

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

        _startPrank(registryOwner);

        _deployRegistry();

        _deployRegistryServiceMock();

        _stopPrank();

        // Tests bookeeping
        _afterDeployment();
    }



    function _deployRegistry() internal
    {
        // 1) registry access manager
        // grants GIF_ADMIN_ROLE to registry owner as registryOwner is transaction sender
        // grants GIF_MANAGER_ROLE to registry owner via contructor argument
        accessManager = new RegistryAccessManager();

        // solhint-disable
        console.log("registry owner", registryOwner);
        console.log("registry access manager deployed:", address(accessManager));
        console.log("registry access manager authority", accessManager.authority());
        // solhint-enable

        // 2) release manager (registry/chain nft)
        releaseManager = new ReleaseManager(
            accessManager,
            VersionPartLib.toVersionPart(3),
            address(dip));

        registryAddress = releaseManager.getRegistryAddress();
        registry = Registry(registryAddress);

        registryNftId = registry.getNftId(address(registry));
        address chainNftAddress = registry.getChainNftAddress();
        chainNft = ChainNft(chainNftAddress);
        tokenRegistry = TokenRegistry(registry.getTokenRegistryAddress());

        // solhint-disable
        console.log("protocol nft id", chainNft.PROTOCOL_NFT_ID());
        console.log("global registry nft id", chainNft.GLOBAL_REGISTRY_ID());

        console.log("registry nft id", registry.getNftId(address(registry)).toInt());
        console.log("registry deployed at", address(registry));
        console.log("registry owner (opt 1)", registry.ownerOf(address(registry)));
        console.log("registry owner (opt 2)", registry.getOwner());

        console.log("release manager deployed at", address(releaseManager));
        console.log("release manager authority", releaseManager.authority());
        // solhint-enable

        // 3) initialize access rights for registry access manager
        accessManager.initialize(registryOwner, registryOwner, address(releaseManager), address(tokenRegistry));

        // solhint-disable
        console.log("token registry deployed at", address(tokenRegistry));
        console.log("registry access manager initialized", address(accessManager));
        // solhint-enable

        /* solhint-disable */
        console.log("token registry linked to nft", tokenRegistry.getNftId().toInt());
        console.log("token registry linked owner", tokenRegistry.getOwner());
        /* solhint-enable */
    }



    function _deployRegistryServiceMock() internal
    {
        bytes32 salt = "0x5678";

        // RegistryServiceManagerMock first deploys RegistryService and then upgrades to RegistryServiceMock
        // thus address is computed with RegistryService bytecode instead of RegistryServiceMock...
        RegistryServiceTestConfig config = new RegistryServiceTestConfig(
            releaseManager,
            type(RegistryServiceManagerMock).creationCode, // proxy manager
            type(RegistryService).creationCode, // implementation
            registryOwner,
            VersionPartLib.toVersionPart(3),
            salt);

        (
            address[] memory serviceAddress,
            RoleId[][] memory serviceRoles,
            RoleId[][] memory functionRoles,
            bytes4[][][] memory selectors
        ) = config.getConfig();

        releaseManager.createNextRelease();

        (
            address releaseAccessManager,
            VersionPart releaseVersion,
            bytes32 releaseSalt
        ) = releaseManager.prepareNextRelease(serviceAddress, serviceRoles, functionRoles, selectors, salt);

        registryServiceManagerMock = new RegistryServiceManagerMock{salt: releaseSalt}(
            releaseAccessManager, 
            registryAddress, 
            releaseSalt);

        registryServiceMock = RegistryServiceMock(address(registryServiceManagerMock.getRegistryService()));

        releaseManager.registerService(registryServiceMock);

        releaseManager.activateNextRelease();

        tokenRegistry.linkToRegistryService(); // links to registry service nft

        registryServiceManagerMock.linkOwnershipToServiceNft();

        registryServiceNftId = registry.getNftId(address(registryServiceMock));
    }

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
            registryNftId = NftIdLib.toNftId(23133705);

            globalRegistryInfo = IRegistry.ObjectInfo(
                globalRegistryNftId,
                protocolNftId,
                REGISTRY(),
                false,
                address(0),
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

        registryServiceInfo = IRegistry.ObjectInfo(
            registryServiceNftId,
            registryNftId,
            SERVICE(),
            false,
            address(registryServiceMock), // must be without erc721 receiver support?
            registryOwner,
            ""
        );

        _nextId = 4; // starting nft index after deployment

        // special case: need 0 in _nftIds[] set, assume registry always have zeroObjectInfo registered as NftIdLib.zero
        _info[NftIdLib.zero()] = zeroObjectInfo();
        _info[protocolNftId] = protocolInfo;
        _info[globalRegistryNftId] = globalRegistryInfo;
        _info[registryNftId] = registryInfo;
        _info[registryServiceNftId] = registryServiceInfo; 

        _nftIdByAddress[address(registry)] = registryNftId;
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
        EnumerableSet.add(_nftIds, registryServiceNftId.toInt());

        // 0 is in the set because _addresses is not used for getters checks
        EnumerableSet.add(_addresses, address(0));
        EnumerableSet.add(_addresses, outsider);
        EnumerableSet.add(_addresses, registryOwner);
        EnumerableSet.add(_addresses, address(registryServiceMock));
        EnumerableSet.add(_addresses, address(registry)); // IMPORTANT: do not use as sender -> can not call itself

        EnumerableSet.add(_registeredAddresses, address(registryServiceMock));
        EnumerableSet.add(_registeredAddresses, address(registry));

        _types.push(zeroObjectType());
        _types.push(PROTOCOL());
        _types.push(REGISTRY());
        _types.push(SERVICE());
        _types.push(TOKEN());
        _types.push(INSTANCE());
        _types.push(PRODUCT());
        _types.push(POOL());
        _types.push(ORACLE());
        _types.push(DISTRIBUTION());
        _types.push(POLICY());
        _types.push(BUNDLE());
        _types.push(STAKE());

        // SECTION: Valid object-parent types combinations

        // registry as parent
        //_isValidContractTypesCombo[SERVICE()][REGISTRY()] = true;

        _isValidContractTypesCombo[INSTANCE()][REGISTRY()] = true;

        // instance as parent
        _isValidContractTypesCombo[PRODUCT()][INSTANCE()] = true;
        _isValidContractTypesCombo[DISTRIBUTION()][INSTANCE()] = true;
        _isValidContractTypesCombo[ORACLE()][INSTANCE()] = true;
        _isValidContractTypesCombo[POOL()][INSTANCE()] = true;

        // product as parent
        _isValidObjectTypesCombo[POLICY()][PRODUCT()] = true;

        // pool as parent
        _isValidObjectTypesCombo[BUNDLE()][POOL()] = true;
        _isValidObjectTypesCombo[STAKE()][POOL()] = true;

        _isValidObjectTypesCombo[DISTRIBUTOR()][DISTRIBUTION()] = true;

        if(block.chainid == 1) {
            _isValidObjectTypesCombo[REGISTRY()][REGISTRY()] = true;
        }

        // SECTION: Names for logging

        _typeName[zeroObjectType()] = "ZERO";
        _typeName[PROTOCOL()] = "PROTOCOL";
        _typeName[REGISTRY()] = "REGISTRY";
        _typeName[SERVICE()] = "SERVICE";
        _typeName[TOKEN()] = "TOKEN";
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
        _addressName[address(registryServiceMock)] = "registryServiceMock";
        
        _errorName[IRegistry.ErrorRegistryCallerNotRegistryService.selector] = "ErrorRegistryCallerNotRegistryService"; 
        _errorName[IRegistry.ErrorRegistryCallerNotReleaseManager.selector] = "ErrorRegistryCallerNotReleaseManager"; 
        _errorName[IRegistry.ErrorRegistryParentAddressZero.selector] = "ErrorRegistryParentAddressZero"; 
        _errorName[IRegistry.ErrorRegistryContractAlreadyRegistered.selector] = "ErrorRegistryContractAlreadyRegistered";
        _errorName[IRegistry.ErrorRegistryTypesCombinationInvalid.selector] = "ErrorRegistryTypesCombinationInvalid";
        _errorName[IRegistry.ErrorRegistryCoreTypeRegistration.selector] = "ErrorRegistryCoreTypeRegistration";
        _errorName[IRegistry.ErrorRegistryDomainZero.selector] = "ErrorRegistryDomainZero";
        _errorName[IRegistry.ErrorRegistryDomainAlreadyRegistered.selector] = "ErrorRegistryDomainAlreadyRegistered";
        _errorName[IERC721Errors.ERC721InvalidReceiver.selector] = "ERC721InvalidReceiver";
    }

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

    function _afterServiceRegistration(IRegistry.ObjectInfo memory info, VersionPart version, ObjectType domain) internal 
    {
        assert(info.objectType.toInt() == SERVICE().toInt());
        _afterRegistration(info);

        NftId nftId = info.nftId;
        assertEq(_service[version][domain], address(0), "Test error: _service[version][domain] already set");
        assertEq(_serviceInfo[nftId].version.toInt(), 0, "Test error: _serviceInfo[nftId].version already set");
        assertEq(_serviceInfo[nftId].domain.toInt(), 0, "Test error: _serviceInfo[nftId].domain already set");
        _service[version][domain] = info.objectAddress;
        _serviceInfo[info.nftId] = ServiceInfo(version, domain);
        _servicesCount++;
    }

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

    function _checkRegistryGetters() internal
    {
        // solhint-disable-next-line
        console.log("Checking all IRegistry getters");

        // check getters without args
        console.log("   checking getters without args");
        assertEq(registry.getChainNftAddress(), address(chainNft), "getChainNft() returned unexpected value");
        assertEq(registry.getObjectCount(), EnumerableSet.length(_nftIds) - 1, "getObjectCount() returned unexpected value");// -1 because of NftIdLib.zero in the set
        //assertEq(registry.getOwner(), registryOwner, "getOwner() returned unexpected value");

        // check for zero address
        console.log("   checking with 0 address");        
        assertEq(registry.getNftId( address(0) ).toInt(), NftIdLib.zero().toInt(), "getNftId(0) returned unexpected value");        
        eqObjectInfo(registry.getObjectInfo( address(0) ), zeroObjectInfo());//, "getObjectInfo(0) returned unexpected value");

        assertFalse(registry.isRegistered( address(0) ), "isRegistered(0) returned unexpected value");
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, NftIdLib.zero()));
        registry.ownerOf(address(0));
        // check for zeroNftId    
        console.log("   checking with 0 nftId"); 
        eqObjectInfo( registry.getObjectInfo( NftIdLib.zero() ), zeroObjectInfo());//, "getObjectInfo(zeroNftId) returned unexpected value");
        assertFalse(registry.isRegistered( NftIdLib.zero() ), "isRegistered(zeroNftId) returned unexpected value");
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, NftIdLib.zero()));
        registry.ownerOf(NftIdLib.zero());
        //_assert_registry_getters(NftIdLib.zero(), zeroObjectInfo(), address(0)); // _nftIds[] and _info[] have this combinaion

        // check for random non registered nftId
        console.log("   checking with random not registered nftId"); 
        NftId unknownNftId;
        do {
            unknownNftId = NftIdLib.toNftId(randomNumber(type(uint96).max));
        } while(EnumerableSet.contains(_nftIds, unknownNftId.toInt())); 
        _assert_registry_getters(
            unknownNftId, 
            zeroObjectInfo(),
            VersionLib.zeroVersion().toMajorPart(),
            zeroObjectType(),
            address(0)
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

            console.log("   checking with nftId from set, nftId: ", nftId.toInt());
            _assert_registry_getters(
                nftId, 
                _info[nftId],
                _serviceInfo[nftId].version,
                _serviceInfo[nftId].domain,
                owner
            );

            // TODO is it needed? if yes implement for every type?
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
        console.log("       checking by nftId getters");
        eqObjectInfo(registry.getObjectInfo(nftId) , expectedInfo);//, "getObjectInfo(nftId) returned unexpected value");
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
        console.log("       checking by address getters");
        if(expectedInfo.objectAddress > address(0)) 
        {// expect contract
            assertEq(registry.getNftId(expectedInfo.objectAddress).toInt(), nftId.toInt(), "getNftId(address) returned unexpected value");
            eqObjectInfo(registry.getObjectInfo(expectedInfo.objectAddress) , expectedInfo);//, "getObjectInfo(address) returned unexpected value");
            if(expectedOwner > address(0)) {  // expect registered
                assertTrue(registry.isRegistered(expectedInfo.objectAddress), "isRegistered(address) returned unexpected value #1");
                assertEq(registry.ownerOf(expectedInfo.objectAddress), expectedOwner, "ownerOf(address) returned unexpected value");
            }
            else {// expect not registered
                assertFalse(registry.isRegistered(expectedInfo.objectAddress), "isRegistered(address) returned unexpected value #2"); 
                vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, nftId));
                registry.ownerOf(expectedInfo.objectAddress);
            }
        }

        if(expectedInfo.objectType == SERVICE())
        {            
            // TODO add case with multiple major versions -> parametrize service major version
            assertEq(_service[expectedVersion][expectedDomain] , expectedInfo.objectAddress , "Test error: _info[] inconsictent with _service[][] #1");
            assertEq(registry.getServiceAddress(expectedDomain, expectedVersion) , expectedInfo.objectAddress, "getServiceAddress(type, versionPart) returned unexpected value #1");  
        }
        else
        {
            assertEq(_service[expectedVersion][expectedDomain] , address(0) , "Test error: _info[] inconsictent with _service[][] #2");
            assertEq(registry.getServiceAddress(expectedDomain, expectedVersion) ,address(0) , "getServiceAddress(type, versionPart) returned unexpected value #2");  
        }
    }

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
            nftId = NftIdLib.toNftId(chainNft.calculateTokenId(_nextId));
            vm.expectEmit();
            emit LogRegistration(
                nftId,
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

    function _assert_register(IRegistry.ObjectInfo memory info, bool expectRevert, bytes memory revertMsg) internal returns (NftId nftId)
    {
        if(expectRevert)
        {
            vm.expectRevert(revertMsg);
        }
        else
        {
            vm.expectEmit();
            emit LogRegistration(
                NftIdLib.toNftId(chainNft.calculateTokenId(_nextId)), 
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

    function _registerServiceChecks(IRegistry.ObjectInfo memory info, VersionPart version, ObjectType domain) internal returns (bool expectRevert, bytes memory expectedRevertMsg)
    {
        if(_sender != address(releaseManager)) 
        {// auth check
            expectedRevertMsg = abi.encodeWithSelector(IRegistry.ErrorRegistryCallerNotReleaseManager.selector);
            expectRevert = true;
        } else if(domain.eqz()) {
            expectedRevertMsg = abi.encodeWithSelector(
                IRegistry.ErrorRegistryDomainZero.selector,
                info.objectAddress);
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

    function _registerChecks(IRegistry.ObjectInfo memory info) internal returns (bool expectRevert, bytes memory expectedRevertMsg)
    {
        NftId parentNftId = info.parentNftId;
        ObjectType parentType = _info[parentNftId].objectType;

        if(_sender != address(registryServiceMock)) 
        {// auth check
            expectedRevertMsg = abi.encodeWithSelector(IRegistry.ErrorRegistryCallerNotRegistryService.selector);
            expectRevert = true;
        } else if(info.objectAddress > address(0)) 
        {
            if(_isValidContractTypesCombo[info.objectType][parentType] == false) 
            {// parent must be registered + object-parent types combo must be valid
                expectedRevertMsg = abi.encodeWithSelector(IRegistry.ErrorRegistryTypesCombinationInvalid.selector, info.objectType, parentType);
                expectRevert = true;
            }
        } else 
        {
            if(_isValidObjectTypesCombo[info.objectType][parentType] == false) 
            {// state object checks, parent must be registered + object-parent types combo must be valid
                expectedRevertMsg = abi.encodeWithSelector(IRegistry.ErrorRegistryTypesCombinationInvalid.selector, info.objectType, parentType);
                expectRevert = true;
            }
        }
    }

    function _internalRegisterChecks(IRegistry.ObjectInfo memory info) internal returns (bool expectRevert, bytes memory expectedRevertMsg)
    {
        NftId parentNftId = info.parentNftId;
        address parentAddress = _info[parentNftId].objectAddress;

        if(parentAddress == address(0)) 
        {// special case: MUST NOT register with global registry as parent when not on mainnet (global registry have valid type as parent but 0 address in this case)
            expectedRevertMsg = abi.encodeWithSelector(IRegistry.ErrorRegistryParentAddressZero.selector);
            expectRevert = true;
        } else if(info.objectAddress > address(0) && _nftIdByAddress[info.objectAddress] != NftIdLib.zero())
        {// contract checks
            expectedRevertMsg = abi.encodeWithSelector(IRegistry.ErrorRegistryContractAlreadyRegistered.selector, info.objectAddress);
            expectRevert = true;
        } else if(
            info.initialOwner == address(0) || 
            (
                info.initialOwner.codehash != EOA_CODEHASH &&//EnumerableSet.contains(_registeredAddresses, info.initialOwner) 
                info.initialOwner.codehash != 0
            )
        )// now none of GIF contracts are supporting erc721 receiver interface -> components and tokens could but not now
        {// ERC721 check
            //console.log("initialOwner is in addresses set: %s", EnumerableSet.contains(_addresses, info.initialOwner));
            //console.log("initialOwner codehash: %s", uint(info.initialOwner.codehash));
            //console.log("EOA codehash %s", uint(EOA_CODEHASH));
            expectedRevertMsg = abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, info.initialOwner);
            expectRevert = true;
        }
    }

    function _assert_registerService_withChecks(IRegistry.ObjectInfo memory info, VersionPart version, ObjectType domain) internal returns (NftId nftId)
    {
        bool expectRevert;
        bytes memory expectedRevertMsg;

        console.log("   Doing registerService() function checks");
        (expectRevert, expectedRevertMsg) = _registerServiceChecks(info, version, domain);

        if(expectRevert) {
            console.log("       expectRevert : ", expectRevert);
            console.log("       revert reason:", _errorName[bytes4(expectedRevertMsg)]);
            console.log("   Skipping _register checks due to expected revert");
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

    function _assert_register_withChecks(IRegistry.ObjectInfo memory info) internal returns (NftId nftId)
    {
        bool expectRevert;
        bytes memory expectedRevertMsg;

        console.log("   Doing register() function checks");
        (expectRevert, expectedRevertMsg) = _registerChecks(info);

        if(expectRevert) {
            console.log("       expectRevert : ", expectRevert);
            console.log("       revert reason:", _errorName[bytes4(expectedRevertMsg)]);
            console.log("   Skipping _register checks due to expected revert");
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
}
