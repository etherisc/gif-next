// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {FoundryRandom} from "foundry-random/FoundryRandom.sol";

import {Vm, console} from "../../lib/forge-std/src/Test.sol";
import {TestGifBase} from "../base/TestGifBase.sol";

import {blockBlocknumber} from "../../contracts/type/Blocknumber.sol";
import {VersionLib, Version, VersionPart, VersionPartLib } from "../../contracts/type/Version.sol";
import {NftId, toNftId, zeroNftId} from "../../contracts/type/NftId.sol";
import {Timestamp, TimestampLib} from "../../contracts/type/Timestamp.sol";
import {Blocknumber, BlocknumberLib} from "../../contracts/type/Blocknumber.sol";
import {ObjectType, ObjectTypeLib, toObjectType, zeroObjectType, PROTOCOL, REGISTRY, TOKEN, SERVICE, INSTANCE, PRODUCT, POOL, ORACLE, DISTRIBUTION, BUNDLE, POLICY, STAKE} from "../../contracts/type/ObjectType.sol";
import {RoleId} from "../../contracts/type/RoleId.sol";

import {IService} from "../../contracts/shared/IService.sol";

import {ChainNft} from "../../contracts/registry/ChainNft.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {RegistryServiceManager} from "../../contracts/registry/RegistryServiceManager.sol";
import {ReleaseManager} from "../../contracts/registry/ReleaseManager.sol";
import {RegistryAccessManager} from "../../contracts/registry/RegistryAccessManager.sol";
import {TokenRegistry} from "../../contracts/registry/TokenRegistry.sol";
import {DistributionServiceManager} from "../../contracts/distribution/DistributionServiceManager.sol";

import {RegistryServiceManagerMock} from "../mock/RegistryServiceManagerMock.sol";
import {RegistryServiceMock} from "../mock/RegistryServiceMock.sol";




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
            zeroNftId(),
            zeroNftId(),
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

contract RegistryTestBase is TestGifBase, FoundryRandom {

    // keep indentical to IRegistry events
    event LogRegistration(NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, address objectAddress, address initialOwner);
    event LogServiceRegistration(VersionPart majorVersion, ObjectType domain);

    bytes32 public constant EOA_CODEHASH = 0xC5D2460186F7233C927E7DB2DCC703C0E500B653CA82273B7BFAD8045D85A470;

    uint8 public constant GIF_VERSION = 3;

    RegistryServiceManagerMock public registryServiceManagerMock;
    RegistryServiceMock public registryServiceMock;

    address public _sender; // use with _startPrank(), _stopPrank()
    uint public _nextId; // use with chainNft.calculateId()

    NftId public protocolNftId = toNftId(1101);
    NftId public globalRegistryNftId = toNftId(2101);
    NftId public registryServiceNftId = toNftId(33133705);

    IRegistry.ObjectInfo public protocolInfo;
    IRegistry.ObjectInfo public globalRegistryInfo; // chainId dependent
    IRegistry.ObjectInfo public registryInfo; // chainId dependent
    IRegistry.ObjectInfo public registryServiceInfo;

    EnumerableSet.AddressSet internal _addresses; // set of all addresses (actors + registered + initial owners)
    EnumerableSet.AddressSet internal _registeredAddresses;

    ObjectType[] public _types; 

    EnumerableSet.UintSet internal _nftIds;

    mapping(address => string name) public _addressName;

    mapping(ObjectType objectType => string name) public _typeName;

    mapping(bytes4 errorSelector => string name) public _errorName;

    mapping(ObjectType objectType => mapping(
            ObjectType parentType => bool)) public _isValidContractTypesCombo;

    mapping(ObjectType objectType => mapping(
            ObjectType parentType => bool)) public _isValidObjectTypesCombo;

    mapping(NftId nftId => mapping(
            ObjectType objectType => bool)) public _isApproved;// tracks approved state

    mapping(NftId nftId => IRegistry.ObjectInfo info) public _info; // tracks registered state
    mapping(address => NftId nftId) public _nftIdByAddress; 

    struct ServiceInfo {
        NftId nftId;
        address address_;
    }

    mapping(ObjectType => mapping(
            VersionPart majorVersion => ServiceInfo info)) public _service;

    uint public _servicesCount;

    function setUp() public virtual override
    {
        _startPrank(registryOwner);

        _deployRegistry();

        _deployRegistryServiceMock();

        _stopPrank();

        // Tests bookeeping
        _afterDeployment();
    }
/*
    function _deployRegistry() internal
    {
        registryAccessManager = new RegistryAccessManager();

        releaseManager = new ReleaseManager(
            registryAccessManager,
            VersionPartLib.toVersionPart(3));

        address registryAddress = address(releaseManager.getRegistry());
        registry = Registry(registryAddress);

        address chainNftAddress = registry.getChainNftAddress();
        chainNft = ChainNft(chainNftAddress);

        tokenRegistry = new TokenRegistry(registryAddress);

        registryAccessManager.initialize(registryOwner, registryOwner, address(releaseManager), address(tokenRegistry));
    }
*/

    function _deployRegistryServiceMock() internal
    {
        bytes32 salt = "0x5678";
        bytes32 releaseSalt = keccak256(
            bytes.concat(
                bytes32(uint(3)),
                salt));

        releaseManager.createNextRelease();

        IRegistry.ConfigStruct[] memory config = new IRegistry.ConfigStruct[](1);
        config[0] = IRegistry.ConfigStruct(
                address(0), // TODO calculate
                new RoleId[](0),
                new bytes4[][](0),
                new RoleId[](0)
        );

        (
            address releaseAccessManager, 
            VersionPart releaseVersion,
            bytes32 releaseSalt2
        ) = releaseManager.prepareNextRelease(config, salt);

        registryServiceManager = new RegistryServiceManagerMock{salt: releaseSalt}(
            releaseAccessManager, 
            registryAddress, 
            releaseSalt);

        registryServiceMock = RegistryServiceMock(address(registryServiceManager.getRegistryService()));

        releaseManager.registerService(registryService);

        releaseManager.activateNextRelease();

        registryServiceManager.linkOwnershipToServiceNft();
    }

    // call right after registry deployment, before checks
    function _afterDeployment() internal
    {
        // SECTION: Registered entries bookeeping

        protocolInfo = IRegistry.ObjectInfo(
                protocolNftId,
                zeroNftId(),
                PROTOCOL(),
                false,
                address(0),
                NFT_LOCK_ADDRESS,
                ""
        );

        if(block.chainid == 1) 
        {
            registryNftId = globalRegistryNftId;

            // both are the same
            globalRegistryInfo = IRegistry.ObjectInfo(
                registryNftId,
                protocolNftId,
                REGISTRY(),
                false,
                address(registry),
                registryOwner,
                "" 
            );

            registryInfo = globalRegistryInfo;
        }
        else
        {
            registryNftId = toNftId(23133705);

            globalRegistryInfo = IRegistry.ObjectInfo(
                globalRegistryNftId,
                protocolNftId,
                REGISTRY(),
                false,
                address(0),
                NFT_LOCK_ADDRESS,
                "" 
            );

            registryInfo = IRegistry.ObjectInfo(
                registryNftId,
                globalRegistryNftId,
                REGISTRY(),
                false,
                address(registry),
                registryOwner,
                "" 
            );
        }

        registryServiceInfo = IRegistry.ObjectInfo(
            registryServiceNftId,
            registryNftId,
            SERVICE(),
            false,
            address(registryService), // must be without erc721 receiver support?
            registryOwner,
            ""
        );
        
        _nextId = 4; // starting nft index after deployment

        // special case: need 0 in _nftIds[] set, assume registry always have zeroObjectInfo registered as zeroNftId
        _info[zeroNftId()] = zeroObjectInfo();
        _info[protocolNftId] = protocolInfo;
        _info[globalRegistryNftId] = globalRegistryInfo;
        _info[registryNftId] = registryInfo;
        _info[registryServiceNftId] = registryServiceInfo; 

        _nftIdByAddress[address(registry)] = registryNftId;
        _nftIdByAddress[address(registryService)] = registryServiceNftId;

        _service[SERVICE()][VersionLib.toVersionPart(GIF_VERSION)].nftId = registryServiceNftId;
        _service[SERVICE()][VersionLib.toVersionPart(GIF_VERSION)].address_ = address(registryService);

        _servicesCount = 1;

        // SECTION: Test sets 

        // special case: need 0 in _nftIds[] set, assume registry always have zeroNftId but is not (and can not be) registered
        EnumerableSet.add(_nftIds, zeroNftId().toInt());
        // registered nfts
        EnumerableSet.add(_nftIds, protocolNftId.toInt());
        EnumerableSet.add(_nftIds, globalRegistryNftId.toInt());
        EnumerableSet.add(_nftIds, registryNftId.toInt());
        EnumerableSet.add(_nftIds, registryServiceNftId.toInt());

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
        // TODO add random type...

        // 0 is in the set because _addresses is not used for getters checks
        EnumerableSet.add(_addresses, address(0));
        EnumerableSet.add(_addresses, outsider);
        EnumerableSet.add(_addresses, registryOwner);
        EnumerableSet.add(_addresses, address(registryService));
        EnumerableSet.add(_addresses, address(registry)); // IMPORTANT: do not use as sender -> can not call itself

        EnumerableSet.add(_registeredAddresses, address(registryService));
        EnumerableSet.add(_registeredAddresses, address(registry));

        // SECTION: Valid object-parent types combinations

        // registry as parent
        _isValidContractTypesCombo[TOKEN()][REGISTRY()] = true;
        _isValidContractTypesCombo[SERVICE()][REGISTRY()] = true;

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
        _typeName[POLICY()] = "POLICY";
        _typeName[BUNDLE()] = "BUNDLE";
        _typeName[STAKE()] = "STAKE";

        _addressName[registryOwner] = "registryOwner";
        _addressName[outsider] = "outsider";
        _addressName[address(registry)] = "Registry";
        _addressName[address(registryService)] = "registryService";
        
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

    // TODO move service part to _afterServiceRegistration_setUp
    function _afterRegistration_setUp(IRegistry.ObjectInfo memory info) internal 
    {
        _nextId++;

        NftId nftId = info.nftId;
        assert(_info[nftId].nftId == zeroNftId());

        EnumerableSet.add(_nftIds , nftId.toInt());
        _info[nftId] = info;

        if(info.objectAddress > address(0)) { 
            assert(_nftIdByAddress[info.objectAddress] == zeroNftId());
            _nftIdByAddress[info.objectAddress] = nftId; 

            EnumerableSet.add(_addresses, info.objectAddress);
            EnumerableSet.add(_addresses, info.initialOwner);

            EnumerableSet.add(_registeredAddresses, info.objectAddress);
        }
    }

    function _afterServiceRegistration_setUp(IRegistry.ObjectInfo memory info) internal 
    {
        _afterRegistration_setUp(info);

        _servicesCount++;

        (
            ObjectType serviceDomain,
            VersionPart majorVersion
        ) = _decodeServiceParameters(info.data);

        NftId nftId = info.nftId;
        assert(_service[serviceDomain][majorVersion].nftId.eqz());
        _service[serviceDomain][majorVersion].nftId = nftId;
        _service[serviceDomain][majorVersion].address_ = info.objectAddress;
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

    function _decodeServiceParameters(bytes memory data) internal pure returns(ObjectType serviceType, VersionPart majorVersion)
    {
        // solhint-disable no-console
        //console.log("Decoding service parameters");
        (
            serviceType,
            majorVersion
        ) = abi.decode(data, (ObjectType, VersionPart));
        // no try/catch support for abi.decode
        //    try _decodeServiceParameters(info) returns(string memory name, VersionPart majorVersion) {
        //        console.log("  serviceName: %s", name);   
        //        console.log(" majorVersion: %s", majorVersion.toInt());
        //    } catch {
        //        console.log("unable to decode data");
        //    }
        //console.log("Decoding ok");
        // solhint-enable
    }

    function _nextServiceName() internal view returns (string memory) 
    {
        return string.concat("TestService #", Strings.toString(_servicesCount));   
    }

    function _checkNonUpgradeableRegistryGetters() internal
    {
        // solhint-disable-next-line
        //console.log("Checking all IRegistry getters");

        // check getters without args
        assertEq(registry.getChainNftAddress(), address(chainNft), "getChainNft() returned unexpected value");
        assertEq(registry.getObjectCount(), EnumerableSet.length(_nftIds) - 1, "getObjectCount() returned unexpected value");// -1 because of zeroNftId in the set
        //assertEq(registry.getOwner(), registryOwner, "getOwner() returned unexpected value");

        // check for zero address
        assertEq(registry.getNftId( address(0) ).toInt(), zeroNftId().toInt(), "getNftId(0) returned unexpected value");        
        assertTrue( eqObjectInfo( registry.getObjectInfo( address(0) ), zeroObjectInfo() ), "getObjectInfo(0) returned unexpected value");
        assertFalse(registry.isRegistered( address(0) ), "isRegistered(0) returned unexpected value");
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, zeroNftId()));
        registry.ownerOf(address(0));
        // check for zeroNftId    
        assertTrue( eqObjectInfo( registry.getObjectInfo( zeroNftId() ), zeroObjectInfo() ), "getObjectInfo(zeroNftId) returned unexpected value");
        assertFalse(registry.isRegistered( zeroNftId() ), "isRegistered(zeroNftId) returned unexpected value");
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, zeroNftId()));
        registry.ownerOf(zeroNftId());
        //_assert_registry_getters(zeroNftId(), zeroObjectInfo(), address(0)); // _nftIds[] and _info[] have this combinaion
        // check for random non registered nftId
        NftId unknownNftId;
        do {
            unknownNftId = toNftId(randomNumber(type(uint96).max));
        } while(EnumerableSet.contains(_nftIds, unknownNftId.toInt())); 
        _assert_registry_getters(unknownNftId, zeroObjectInfo(), address(0)); 

        // loop through every registered nftId
        // _nftIds[] MUST contain zeroNftId()
        uint servicesFound = 0;

        for(uint nftIdx = 0; nftIdx < EnumerableSet.length(_nftIds); nftIdx++)
        {
            NftId nftId = toNftId(EnumerableSet.at(_nftIds, nftIdx));

            assertNotEq(nftId.toInt(), unknownNftId.toInt(), "Test error: unknownfNftId can not be registered");
            assertEq(nftId.toInt(), _info[nftId].nftId.toInt(), "Test error: _info[someNftId].nftId != someNftId");

            address owner;
            if(nftId == zeroNftId()) 
            {// special case: not registered, has 0 owner
                owner = address(0);
            } else {
                owner = chainNft.ownerOf(nftId.toInt());
            }

            _assert_registry_getters(nftId, _info[nftId], owner);

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
    function _assert_registry_getters(NftId nftId, IRegistry.ObjectInfo memory expectedInfo, address expectedOwner) internal
    {
        // solhint-disable no-console
        /*console.log("Checking IRegistry getters for nftId: %s", nftId.toInt());
        console.log("Expected:");
        _logObjectInfo(expectedInfo);
        console.log("        owner: %s\n", expectedOwner);

        IRegistry.ObjectInfo memory actualInfo = registry.getObjectInfo(nftId);
        console.log("Actual:");
        _logObjectInfo(actualInfo);
        console.log("");*/
        // solhint-enable

        // check "by nftId getters"
        assertTrue( eqObjectInfo(registry.getObjectInfo(nftId) , expectedInfo), "getObjectInfo(nftId) returned unexpected value");
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
        if(expectedInfo.objectAddress > address(0)) 
        {// expect contract
            assertEq(registry.getNftId(expectedInfo.objectAddress).toInt(), nftId.toInt(), "getNftId(address) returned unexpected value");
            assertTrue( eqObjectInfo(registry.getObjectInfo(expectedInfo.objectAddress) , expectedInfo), "getObjectInfo(address) returned unexpected value");
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
            ObjectType serviceType;
            VersionPart majorVersion;
            
            if(nftId == registryServiceNftId) 
            {// special case: registry service is registered during deployment -> data is empty
                serviceType = REGISTRY();
                majorVersion = VersionLib.toVersionPart(GIF_VERSION);
            }
            else
            {
                (
                    serviceType,
                    majorVersion
                ) = _decodeServiceParameters(expectedInfo.data);
            }

            // TODO add case with multiple major versions -> parametrize service major version
            assertEq(_service[serviceType][majorVersion].nftId.toInt() , nftId.toInt() , "Test error: _info[] inconsictent with _service[][] #1");
            assertEq(_service[serviceType][majorVersion].address_ , expectedInfo.objectAddress , "Test error: _info[] inconsictent with _service[][] #2");
            //assertEq(registry.getServiceName(nftId) , serviceName , "getServiceName(nftId) returned unexpected value");
            assertEq(registry.getServiceAddress(serviceType, majorVersion) , expectedInfo.objectAddress, "getServiceAddress(type, versionPart) returned unexpected value");  
        }
    }

    function _assert_register(IRegistry.ObjectInfo memory info, bool expectRevert, bytes memory revertMsg) internal returns (NftId nftId)
    {   
        ObjectType serviceDomain;
        VersionPart majorVersion;

        // solhint-disable no-console
        //console.log("Registering:"); 
        //_logObjectInfo(info);
        if(info.objectType == SERVICE()) {
            (
                serviceDomain,
                majorVersion
            ) = _decodeServiceParameters(info.data);
            //console.log("  serviceType: %s", serviceType.toInt());   
            //console.log(" majorVersion: %s", majorVersion.toInt());  
        } 
        /*console.log("-------------");  
        console.log("   parentType: %s", _typeName[_info[info.parentNftId].objectType]);
        console.log("parentAddress: %s", _info[info.parentNftId].objectAddress);
        console.log("       sender: %s", _getSenderName());
        console.log("expect revert: %s", expectRevert);
        console.log("revert reason: %s\n", _errorName[bytes4(revertMsg)]);*/
        // solhint-enable

        if(expectRevert)
        {
            vm.expectRevert(revertMsg);
        }
        else
        {
            if(info.objectType == SERVICE()) {
                vm.expectEmit();
                emit LogServiceRegistration(majorVersion, serviceDomain);
            }
            vm.expectEmit();
            emit LogRegistration(
                toNftId(chainNft.calculateTokenId(_nextId)), 
                info.parentNftId, 
                info.objectType, 
                info.isInterceptor,
                info.objectAddress, 
                info.initialOwner
            );
        }

        nftId = registry.register(info); 

        if(expectRevert == false)
        {
            assertEq(nftId.toInt(), chainNft.calculateTokenId(_nextId), "register() returned unexpected nftId");

            info.nftId = nftId;

            
            if(info.objectType == SERVICE()) {
                _afterServiceRegistration_setUp(info);
            } 
            else {
                _afterRegistration_setUp(info);
            }

            _checkNonUpgradeableRegistryGetters();

            // solhint-disable-next-line
            //console.log("registered { nftId: %d , type: %s }\n", nftId.toInt(), _typeName[info.objectType]);
            console.log("Registered:"); 
            _logObjectInfo(info);
            console.log(""); 
        }
    }

    function _assert_register_withChecks(IRegistry.ObjectInfo memory info) internal returns (NftId nftId)
    {
        bool expectRevert;
        bytes memory expectedRevertMsg;
        NftId parentNftId = info.parentNftId;
        ObjectType parentType = _info[parentNftId].objectType;

        if(_sender != address(registryService)) 
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

        if(expectRevert) {
            nftId = _assert_register(info, expectRevert, expectedRevertMsg);
        } else {
            nftId = _assert_internalRegister_withChecks(info);
        }
    }

    function _assert_registerService_withChecks(IRegistry.ObjectInfo memory info) internal returns (NftId nftId)
    {
        bool expectRevert;
        bytes memory expectedRevertMsg;

        

        if(_sender != address(releaseManager)) 
        {// auth check
            expectedRevertMsg = abi.encodeWithSelector(IRegistry.ErrorRegistryCallerNotReleaseManager.selector);
            expectRevert = true;
        }

        if(expectRevert) {
            nftId = _assert_register(info, expectRevert, expectedRevertMsg);
        } else {
            nftId = _assert_internalRegister_withChecks(info);
        }
    }

    function _assert_internalRegister_withChecks(IRegistry.ObjectInfo memory info) internal returns(NftId nftId)
    {
        bool expectRevert;
        bytes memory expectedRevertMsg;
        NftId parentNftId = info.parentNftId;
        address parentAddress = _info[parentNftId].objectAddress;

        if(parentAddress == address(0)) 
        {// special case: MUST NOT register with global registry as parent when not on mainnet (global registry have valid type as parent but 0 address in this case)
            expectedRevertMsg = abi.encodeWithSelector(IRegistry.ErrorRegistryParentAddressZero.selector);
            expectRevert = true;
        }
        else if(
            info.initialOwner == address(0) || 
            (info.initialOwner.codehash != EOA_CODEHASH &&//EnumerableSet.contains(_registeredAddresses, info.initialOwner) 
            info.initialOwner.codehash != 0)
        )// now none of GIF contracts are supporting erc721 receiver interface -> components and tokens could but not now
        {// ERC721 check
            //console.log("initialOwner is in addresses set: %s", EnumerableSet.contains(_addresses, info.initialOwner));
            //console.log("initialOwner codehash: %s", uint(info.initialOwner.codehash));
            //console.log("EOA codehash %s", uint(EOA_CODEHASH));
            expectedRevertMsg = abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, info.initialOwner);
            expectRevert = true;
        }
        else if(info.objectAddress > address(0))
        {// contract checks
            if(_nftIdByAddress[info.objectAddress] != zeroNftId()) {
                expectedRevertMsg = abi.encodeWithSelector(IRegistry.ErrorRegistryContractAlreadyRegistered.selector, info.objectAddress);
                expectRevert = true;
            }
        }
        
        nftId = _assert_register(info, expectRevert, expectedRevertMsg);
    }
}
