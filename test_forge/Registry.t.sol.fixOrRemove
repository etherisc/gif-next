// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin5/contracts/access/Ownable.sol";
import {IERC721Errors} from "@openzeppelin5/contracts/interfaces/draft-IERC6093.sol";
import {IERC20Metadata} from "@openzeppelin5/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {EnumerableSet} from "@openzeppelin5/contracts/utils/structs/EnumerableSet.sol";
import {Strings} from "@openzeppelin5/contracts/utils/Strings.sol";
import { FoundryRandom } from "foundry-random/FoundryRandom.sol";

import {Test, Vm, console} from "../lib/forge-std/src/Test.sol";
import {blockTimestamp} from "../contracts/types/Timestamp.sol";
import {blockBlocknumber} from "../contracts/types/Blocknumber.sol";
import {VersionLib, Version, VersionPart} from "../contracts/types/Version.sol";
import {NftId, toNftId, zeroNftId} from "../contracts/types/NftId.sol";
import {Timestamp, TimestampLib} from "../contracts/types/Timestamp.sol";
import {Blocknumber, BlocknumberLib} from "../contracts/types/Blocknumber.sol";
import {ObjectType, ObjectTypeLib, toObjectType, zeroObjectType, PROTOCOL, REGISTRY, TOKEN, SERVICE, INSTANCE, PRODUCT, POOL, ORACLE, DISTRIBUTION, BUNDLE, POLICY, STAKE} from "../contracts/types/ObjectType.sol";


import {IVersionable} from "../contracts/shared/IVersionable.sol";
import {IRegisterable} from "../contracts/shared/IRegisterable.sol";
import {ProxyDeployer, ProxyWithProxyAdminGetter} from "../contracts/shared/Proxy.sol";
import {ChainNft} from "../contracts/registry/ChainNft.sol";
import {IChainNft} from "../contracts/registry/IChainNft.sol";

import {IRegistry} from "../contracts/registry/IRegistry.sol";
import {Registry} from "../contracts/registry/Registry.sol";

import {TestService} from "../contracts/test/TestService.sol";
import {TestRegisterable} from "../contracts/test/TestRegisterable.sol";
import {ERC165} from "../contracts/shared/ERC165.sol";
import {USDC} from "../contracts/test/Usdc.sol";

// Helper functions to test IRegistry.ObjectInfo structs 
function eqObjectInfo(IRegistry.ObjectInfo memory a, IRegistry.ObjectInfo memory b) pure returns (bool isSame) {
    return (
        (a.nftId == b.nftId) &&
        (a.parentNftId == b.parentNftId) &&
        (a.objectType == b.objectType) &&
        (a.objectAddress == b.objectAddress) &&
        (a.initialOwner == b.initialOwner) /*&&
        (a.data == b.data)*/
    );
}

function zeroObjectInfo() pure returns (IRegistry.ObjectInfo memory) {
    return (
        IRegistry.ObjectInfo(
            zeroNftId(),
            zeroNftId(),
            zeroObjectType(),
            address(0),
            address(0),
            bytes("")
        )
    );
}

contract Dummy {
    bool dummy;
}

contract RegistryTest is Test, FoundryRandom {

    address constant NFT_LOCK_ADDRESS = address(0x1);
    bytes32 constant EOA_CODEHASH = 0xC5D2460186F7233C927E7DB2DCC703C0E500B653CA82273B7BFAD8045D85A470;//keccak256("");
    uint constant ITTERATIONS_AMMOUNT = 250;

    address public proxyOwner = makeAddr("proxyOwner");
    address public outsider = makeAddr("outsider");// MUST != registryOwner
    address public registryOwner = makeAddr("registryOwner");
    //address public registryService = makeAddr("registryService"); // use address with dummy contract code -> must not support erc721 receiver interface

    address _sender; // use with _startPrank(), _stopPrank()
    address Address = address(15); // take next address for registration from here

    IRegistry public registry;
    ChainNft public chainNft;
    address public chainNftAddress;
    address public registryService = address(new Dummy());// must not support erc721 receiver interface
    NftId public protocolNftId = toNftId(1101);
    NftId public globalRegistryNftId = toNftId(2101);
    NftId public registryNftId; // chainId dependent
    NftId public registryServiceNftId = toNftId(33133705);
    IRegistry.ObjectInfo public protocolInfo;
    IRegistry.ObjectInfo public globalRegistryInfo; // chainId dependent
    IRegistry.ObjectInfo public registryInfo; // chainId dependent
    IRegistry.ObjectInfo public registryServiceInfo;

    EnumerableSet.AddressSet internal _addresses; // capable to receive nft -> EOA or contracts with IERCReceiver interface support ->  none of registered addresses 

    ObjectType[] public _types; 

    EnumerableSet.UintSet internal _nftIds;

    mapping(address => string name) public _addressName;

    mapping(ObjectType objectType => string name) public _typeName;

    mapping(bytes4 errorSelector => string name) public _errorName;


    mapping(ObjectType objectType => NftId nftId) public _nftIdByType;// default parent nft id for each type

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

    mapping(bytes32 serviceNameHash => mapping(
            VersionPart majorVersion => ServiceInfo info)) public _service;

    uint public _servicesCount;

    function setUp() public virtual
    {
        _startPrank(registryService);

        _deployNonUpgradeableRegistry();

        _stopPrank();

        // Tests bookeeping
        _afterRegistryDeploy();
    }

    // call right after registry deployment, before checks
    function _afterRegistryDeploy() internal
    {
        // SECTION: Registered entries bookeeping

        protocolInfo = IRegistry.ObjectInfo(
                protocolNftId,
                zeroNftId(),
                PROTOCOL(),
                address(0),
                NFT_LOCK_ADDRESS,//registryOwner,
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
                address(registry), // update when deployed 
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
                address(0),
                NFT_LOCK_ADDRESS,//registryOwner,
                "" 
            );

            registryInfo = IRegistry.ObjectInfo(
                registryNftId,
                globalRegistryNftId,
                REGISTRY(),
                address(registry), // update when deployed 
                registryOwner,
                "" 
            );
        }

        registryServiceInfo = IRegistry.ObjectInfo(
            registryServiceNftId,
            registryNftId,
            SERVICE(),
            registryService, // is dummy contract address without erc721 receiver support
            NFT_LOCK_ADDRESS,//registryOwner,
            ""
        );
        
        // special case: need 0 in _nftIds[] set, assume registry always have zeroNftId
        EnumerableSet.add(_nftIds, zeroNftId().toInt());
        // registered nfts
        EnumerableSet.add(_nftIds, protocolNftId.toInt());
        EnumerableSet.add(_nftIds, globalRegistryNftId.toInt());
        EnumerableSet.add(_nftIds, registryNftId.toInt());
        EnumerableSet.add(_nftIds, registryServiceNftId.toInt());

        // special case: need 0 in _nftIds[] set, assume registry always have zeroObjectInfo registered as zeroNftId
        _info[zeroNftId()] = zeroObjectInfo();
        _info[protocolNftId] = protocolInfo;
        _info[globalRegistryNftId] = globalRegistryInfo;
        _info[registryNftId] = registryInfo;
        _info[registryServiceNftId] = registryServiceInfo; 

        _nftIdByAddress[address(registry)] = registryNftId;
        _nftIdByAddress[registryService] = registryServiceNftId;

        bytes32 serviceNameHash = keccak256(abi.encode("RegistryService"));
        _service[serviceNameHash][VersionLib.toVersionPart(1)].nftId = registryServiceNftId;
        _service[serviceNameHash][VersionLib.toVersionPart(1)].address_ = registryService;

        _servicesCount = 1;

        // SECTION: Test sets 

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
        EnumerableSet.add(_addresses, registryService);
        EnumerableSet.add(_addresses, address(registry)); // IMPORTANT: do not use as sender -> can not call itself

        _nftIdByType[zeroObjectType()] = zeroNftId(); 
        _nftIdByType[PROTOCOL()] = protocolNftId;
        _nftIdByType[REGISTRY()] = registryNftId; // collision with globalRegistryNftId...have the same type
        _nftIdByType[SERVICE()] = registryServiceNftId; 

        // SECTION: Valid object-parent types combinations

        // registry as parent
        _isValidContractTypesCombo[TOKEN()][REGISTRY()] = true; // option4
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
        _addressName[registryService] = "registryService"; //for option4
        
        _errorName[Registry.NotRegistryService.selector] = "NotRegistryService"; 
        _errorName[Registry.ZeroParentAddress.selector] = "ZeroParentAddress"; 
        _errorName[Registry.ContractAlreadyRegistered.selector] = "ContractAlreadyRegistered";
        _errorName[Registry.InvalidServiceVersion.selector] = "InvalidServiceVersion";
        _errorName[Registry.ServiceNameAlreadyRegistered.selector] = "ServiceNameAlreadyRegistered";
        _errorName[Registry.NotOwner.selector] = "NotOwner";
        _errorName[Registry.NotRegisteredContract.selector] = "NotRegisteredContract";
        _errorName[Registry.NotService.selector] = "NotService"; 
        _errorName[Registry.InvalidTypesCombination.selector] = "InvalidTypesCombination"; 
        _errorName[IERC721Errors.ERC721InvalidReceiver.selector] = "ERC721InvalidReceiver";
    }

    function _afterRegistration_setUp(IRegistry.ObjectInfo memory info) internal 
    {
        NftId nftId = info.nftId;
        assert(_info[nftId].nftId == zeroNftId());

        EnumerableSet.add(_nftIds , nftId.toInt());
        _info[nftId] = info;

        if(info.objectAddress > address(0)) { 
            assert(_nftIdByAddress[info.objectAddress] == zeroNftId());
            _nftIdByAddress[info.objectAddress] = nftId; 

            EnumerableSet.add(_addresses, info.objectAddress);
            EnumerableSet.add(_addresses, info.initialOwner);
        }

        if(info.objectType == SERVICE())
        {
            _servicesCount++;

            (
                string memory serviceName,
                VersionPart majorVersion
            ) = _decodeServiceParameters(info.data);

            bytes32 serviceNameHash = keccak256(abi.encode(serviceName));
            assert(_service[serviceNameHash][majorVersion].nftId == zeroNftId());
            _service[serviceNameHash][majorVersion].nftId = nftId;
            _service[serviceNameHash][majorVersion].address_ = info.objectAddress;
        }
        

        // TODO starting _nftIdByType[info.objectType] value can be non zero
        //assertEq(_nftIdByType[info.objectType].toInt(), zeroNftId().toInt(), "Test error: _nftIdByType[] rewrite found");
        //_nftIdByType[info.objectType] = nftId;
    }

    function _startPrank(address sender_) internal {
        vm.startPrank(sender_);
        _sender = sender_;
    }

    function _stopPrank() internal {
        vm.stopPrank();
        _sender = tx.origin;
    }

    function _getSenderName() internal returns(string memory) {

        if(Strings.equal(_addressName[_sender], "")) {
            return Strings.toString(uint160(_sender));//"UNKNOWN";
        }
        return _addressName[_sender];
    }

    function _getTypeName(ObjectType objectType) internal returns(string memory) {
        if(Strings.equal(_typeName[objectType], "")) {
            return Strings.toString(objectType.toInt());
        }

        return _typeName[objectType];
    }

    function _logObjectInfo(IRegistry.ObjectInfo memory info) internal {
        console.log("        nftId: %d", info.nftId.toInt());
        console.log("  parentNftId: %d", info.parentNftId.toInt());
        console.log("   objectType: %s", _typeName[info.objectType]);
        console.log("objectAddress: %s", info.objectAddress);
        console.log(" initialOwner: %s", info.initialOwner);
        //console.log("         data: %d", info.data);
    }

    function _decodeServiceParameters(bytes memory data) internal returns(string memory serviceName, VersionPart majorVersion)
    {
        //console.log("Decoding service parameters");
        (
            serviceName,
            majorVersion
        ) = abi.decode(data, (string, VersionPart));
        // no try/catch support for abi.decode
        //    try _decodeServiceParameters(info) returns(string memory name, VersionPart majorVersion) {
        //        console.log("  serviceName: %s", name);   
        //        console.log(" majorVersion: %s", majorVersion.toInt());
        //    } catch {
        //        console.log("unable to decode data");
        //    }
        //console.log("Decoding ok");
    }

    function _nextAddress() internal returns (address nextAddress)
    {
        nextAddress = Address;
        Address = address(uint160(Address) + 1);
    }

    function _nextServiceName() internal returns (string memory name) 
    {
        name = string.concat("TestService #", Strings.toString(_servicesCount));   
    }

    // TODO test constructor arguments
    function _deployNonUpgradeableRegistry() internal
    {
        console.log("Deploying non upgradeable registry");

        bytes memory bytecode = abi.encodePacked(
            type(Registry).creationCode, 
            abi.encode(
                registryOwner, 
                "RegistryService", // name
                VersionLib.toVersionPart(1) // majorVersion
            )
        );
        
        address registryAddress;
        assembly {
            registryAddress := create(0, add(bytecode, 0x20), mload(bytecode))  

            if iszero(extcodesize(registryAddress)) {
                revert(0, 0)
            }
        }

        assertNotEq(registryAddress, address(0), "registry address is 0");
        console.log("registry address %s", registryAddress);

        registry = IRegistry(registryAddress);

        chainNftAddress = address(registry.getChainNft());
        chainNft = ChainNft(chainNftAddress);
        
        assertNotEq(chainNftAddress, address(0), "chain nft address is 0");
        console.log("chain nft address %s\n", chainNftAddress);

        assertEq(protocolNftId.toInt(), chainNft.PROTOCOL_NFT_ID(), "PROTOCOL_NFT_ID() returned unexpected value");
        assertEq(globalRegistryNftId.toInt(), chainNft.GLOBAL_REGISTRY_ID(), "GLOBAL_REGISTRY_ID() returned unexpected value" );
    }

    function _checkNonUpgradeableRegistryGetters() internal
    {
        //console.log("Checking all IRegistry getters");
        // check getters without args
        assertEq(registry.getProtocolOwner(), registryOwner, "getProtocolOwner() returned unexpected value");
        assertEq(address(registry.getChainNft()), chainNftAddress, "getChainNft() returned unexpected value");
        assertEq(registry.getObjectCount(), EnumerableSet.length(_nftIds) - 1, "getObjectCount() returned unexpected value");// -1 because of zeroNftId in the set

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

            //_assert_registry_getters(nftId, _info[nftId], _info[nftId].initialOwner); // assumes no transfers
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
    {// uncomment log to debug tests
        //console.log("Checking IRegistry getters for nftId: %s", nftId.toInt());
        //console.log("expected:");
        //_logObjectInfo(expectedInfo);
        //console.log("        owner: %s\n", expectedOwner);

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
            assertEq(registry.getNftId(expectedInfo.objectAddress).toInt(), nftId.toInt(), "getNftId(address) returned unexpected value #1");
            assertTrue( eqObjectInfo(registry.getObjectInfo(expectedInfo.objectAddress) , expectedInfo), "getObjectInfo(address) returned unexpected value #1");
            if(expectedOwner > address(0)) {  // expect registered
                assertTrue(registry.isRegistered(expectedInfo.objectAddress), "isRegistered(address) returned unexpected value #1");
                assertEq(registry.ownerOf(expectedInfo.objectAddress), expectedOwner, "ownerOf(address) returned unexpected value #1");
            }
            else {// expect not registered
                assertFalse(registry.isRegistered(expectedInfo.objectAddress), "isRegistered(address) returned unexpected value #2"); 
                vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, nftId));
                registry.ownerOf(expectedInfo.objectAddress);
            }
        } 
        else
        {// expect object - all getters with address return 0
            assertEq(registry.getNftId(address(0)).toInt(), zeroNftId().toInt(), "getNftId(address) returned unexpected value #2");
            assertTrue( eqObjectInfo(registry.getObjectInfo(address(0)) , zeroObjectInfo()), "getObjectInfo(address) returned unexpected value #2");
            assertFalse(registry.isRegistered(address(0)), "isRegistered(address) returned unexpected value #3"); // independent of registration
            vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, zeroNftId()));
            registry.ownerOf(address(0));
        }

        if(expectedInfo.objectType == SERVICE())
        {
            string memory serviceName;
            VersionPart majorVersion;
            
            if(nftId == registryServiceNftId) 
            {// special case: registry service is registered during deployment -> data is empty
                serviceName = "RegistryService";
                majorVersion = VersionLib.toVersionPart(1);
            }
            else
            {
                (
                    serviceName,
                    majorVersion
                ) = _decodeServiceParameters(expectedInfo.data);//abi.decode(_info[nftId].data, (string, VersionPart));
            }

            bytes32 serviceNameHash = keccak256(abi.encode(serviceName));

            assertEq(_service[serviceNameHash][majorVersion].nftId.toInt() , nftId.toInt() , "Test error: _info[] inconsictent with _service[][] #1");
            assertEq(_service[serviceNameHash][majorVersion].address_ , expectedInfo.objectAddress , "Test error: _info[] inconsictent with _service[][] #2");
            // TODO add case with multiple major versions -> parametrize service major version
            assertEq(registry.getServiceName(nftId) , serviceName , "getServiceName(nftId) returned unexpected value");
            assertEq(registry.getServiceAddress(serviceName, majorVersion) , expectedInfo.objectAddress, "getServiceAddress(name, versionPart) returned unexpected value");

            //assertEq(registry.getServiceName(nftId) , _serviceByNftId[nftId].name , "getServiceName(nftId) returned unexpected value");
            //string memory name = registry.getServiceName(nftId);
            //assertEq(registry.getServiceAddress(name, _serviceByNftId[nftId].majorVersion) , _serviceByNftId[nftId].address_, "getServiceAddress(name, versionPart) returned unexpected value");
            //assertEq(VersionLib.toVersionPart(1).toInt(), _serviceByNftId[nftId].majorVersion.toInt(), "Test error: unknown service major version found");     
        }

        _assert_allowance_all_types(nftId);
    }

    function _assert_allowance(NftId nftId, ObjectType objectType, bool assertValue) internal
    {// uncomment to debug test
        //console.log("checking allowance for { nftId: %d , objectType: %s }", nftId.toInt(), _typeName[objectType]);
        //console.log("expected: %s", assertValue);

        bool allowance = registry.allowance(nftId, objectType);

        assertEq(allowance, assertValue, "allowance(nftId, objectType) returned unexpected value");

        //console.log("returned: %s\n", allowance);
    }

    function _assert_allowance_all_types(NftId nftId) internal
    {
        //console.log("assert allowance { nftId: %s , objectType: ALL }\n", nftId.toInt());

        for(uint typeIdx = 0; typeIdx < _types.length; typeIdx++)
        {
            ObjectType objectType = _types[typeIdx];

            _assert_allowance(nftId, objectType, _isApproved[nftId][objectType]);
        }
    }
    // nftId has no allowance for all objectTypes
    function _assertFalse_allowance_all_types(NftId nftId) internal
    {
        //console.log("assertFalse allowance() for ALL types\n");

        for(uint typeIdx = 0; typeIdx < _types.length; typeIdx++)
        {
            ObjectType objectType = _types[typeIdx];

            _assert_allowance(nftId, objectType, false);
        }
    }

    function _assert_approve(NftId nftId, ObjectType objectType, ObjectType parentType, bytes memory revertMsg) internal
    {
        if(revertMsg.length == 0)
        {
            _assert_allowance(nftId, objectType, _isApproved[nftId][objectType] );
        }

        //console.log("approving { nftId: %d , objectType: %s , parentType: %s }", nftId.toInt(), _typeName[objectType], _typeName[parentType]);
        //console.log("sender: %s", _getSenderName());
        //revertMsg.length > 0 ? console.log("expect revert: true\n") :
        //                        console.log("expect revert: false\n");

        if(revertMsg.length > 0) 
        { 
            vm.expectRevert(revertMsg);
        }

        registry.approve(nftId, objectType, parentType);

        if(revertMsg.length == 0)
        {
            _isApproved[nftId][objectType] = true;
            //_assert_allowance(nftId, objectType, true); 
            _checkNonUpgradeableRegistryGetters();        
        }

        //console.log("----\n");
    }

    function _assert_approve_with_default_checks(NftId nftId, ObjectType objectType, ObjectType parentType) internal
    {
        bytes memory revertMsg;

        if(_sender != registryOwner) 
        {
            revertMsg = abi.encodeWithSelector(Registry.NotOwner.selector);             
        }
        else if(_nftIdByAddress[ _info[nftId].objectAddress ] == zeroNftId())
        {
            revertMsg = abi.encodeWithSelector(Registry.NotRegisteredContract.selector, nftId);
        }
        else if(_info[nftId].objectType != SERVICE()) 
        {
            revertMsg = abi.encodeWithSelector(Registry.NotService.selector, nftId);
        }
        else if(_isValidContractTypesCombo[objectType][parentType] == false &&
                _isValidObjectTypesCombo[objectType][parentType] == false) 
        {
            revertMsg = abi.encodeWithSelector(Registry.InvalidTypesCombination.selector, objectType, parentType);
        } 

        _assert_approve(nftId, objectType, parentType, revertMsg);
    }

    function _assert_register(IRegistry.ObjectInfo memory info, bool expectRevert, bytes memory revertMsg) internal returns (NftId nftId)
    {
        //console.log("registering:"); 
        //_logObjectInfo(info);
        if(info.objectType == SERVICE()) {
            (
                string memory name,
                VersionPart majorVersion
            ) = _decodeServiceParameters(info.data);
            //console.log("  serviceName: %s", name);   
            //console.log(" majorVersion: %s", majorVersion.toInt());  
        } 
        //console.log("-------------");  
        //console.log("   parentType: %s", _typeName[_info[info.parentNftId].objectType]);
        //console.log("parentAddress: %s", _info[info.parentNftId].objectAddress);
        //console.log("       sender: %s", _getSenderName());
        //console.log("expect revert: %s", expectRevert);
        //console.log("revert reason: %s\n", _errorName[bytes4(revertMsg)]);

        if(expectRevert)
        {
            vm.expectRevert(revertMsg);
        }

        nftId = registry.register(info); 

        if(expectRevert == false)
        {
            // TODO check new nftId by chainId and nfts count 
            assertNotEq(nftId.toInt(), zeroNftId().toInt(), "register() returned zeroNftId");
            assertNotEq(nftId.toInt(), protocolNftId.toInt(), "register() returned protocolNftId");
            assertNotEq(nftId.toInt(), globalRegistryNftId.toInt(), "register() returned globalRegistryNftId");
            assertNotEq(nftId.toInt(), registryNftId.toInt(), "register() returned registryNftId");
            assertNotEq(nftId.toInt(), registryServiceNftId.toInt(), "register() returned registryServiceNftId");

            info.nftId = nftId;

            _afterRegistration_setUp(info);

            _checkNonUpgradeableRegistryGetters();

            console.log("registered { nftId: %d , type: %s }\n", nftId.toInt(), _typeName[info.objectType]);
        }
        //console.log("returned: %d\n", nftId.toInt());
    }

    // TODO do not check service related errors here?
    function _assert_register_with_default_checks(IRegistry.ObjectInfo memory info) internal returns (NftId nftId)
    {
        bool expectRevert;
        bytes memory expectedRevertMsg;
        NftId parentNftId = info.parentNftId;
        address parentAddress = _info[parentNftId].objectAddress;
        ObjectType parentType = _info[parentNftId].objectType;

        if(_sender != registryService) 
        {// auth check
            expectedRevertMsg = abi.encodeWithSelector(Registry.NotRegistryService.selector);
            expectRevert = true;
        }
        else if(parentAddress == address(0)) 
        {// special case: MUST NOT register with global registry as parent when not on mainnet (global registry have valid type as parent but 0 address in this case)
            expectedRevertMsg = abi.encodeWithSelector(Registry.ZeroParentAddress.selector);
            expectRevert = true;
        }
        else if(
            info.initialOwner == address(0) || //info.initialOwner < address(0x0a) ||// 0 and precompiles  //codehash == 0 info.initialOwner.codehash != 0 &&
            (info.initialOwner.codehash != EOA_CODEHASH &&//EnumerableSet.contains(_addresses, info.initialOwner) 
            info.initialOwner.codehash != 0)
        )// now none of GIF contracts are supporting erc721 receiver interface -> components and tokens could -> but not now
        {// ERC721 check
            //console.log("initialOwner is in addresses set: %s", EnumerableSet.contains(_addresses, info.initialOwner));
            //console.log("initialOwner codehash: %s", uint(info.initialOwner.codehash));
            //console.log("EOA codehash %s", uint(EOA_CODEHASH));
            expectedRevertMsg = abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, info.initialOwner);
            expectRevert = true;
        }
        else if(info.objectAddress > address(0))
        {// contract checks
            if(_isValidContractTypesCombo[info.objectType][parentType] == false) 
            {// parent must be registered + object-parent types combo must be valid
                expectedRevertMsg = abi.encodeWithSelector(Registry.InvalidTypesCombination.selector, info.objectType, parentType);
                expectRevert = true;
            }
            else if(_nftIdByAddress[info.objectAddress] != zeroNftId())
            {
                expectedRevertMsg = abi.encodeWithSelector(Registry.ContractAlreadyRegistered.selector, info.objectAddress);
                expectRevert = true;
            }
            else if(info.objectType == SERVICE()) 
            {// service checks
                (
                    string memory serviceName,
                    VersionPart majorVersion
                ) = _decodeServiceParameters(info.data);
                bytes32 serviceNameHash = keccak256(abi.encode(serviceName));

                if(
                    majorVersion.toInt() == 0 ||
                    (majorVersion.toInt() > 1 &&
                    _service[serviceNameHash][VersionLib.toVersionPart(majorVersion.toInt() - 1)].address_ == address(0) )
                )
                {// major version > 0 and must increase by 1
                    expectedRevertMsg = abi.encodeWithSelector(Registry.InvalidServiceVersion.selector, majorVersion);
                    expectRevert = true;
                }
                else if(_service[serviceNameHash][majorVersion].address_ != address(0))
                {
                    expectedRevertMsg = abi.encodeWithSelector(Registry.ServiceNameAlreadyRegistered.selector, serviceName, majorVersion);
                    expectRevert = true;
                }
            }
        }
        else if(_isValidObjectTypesCombo[info.objectType][parentType] == false) 
        {// object checks, parent must be registered + object-parent types combo must be valid
            expectedRevertMsg = abi.encodeWithSelector(Registry.InvalidTypesCombination.selector, info.objectType, parentType);
            expectRevert = true;
        }
        
        nftId = _assert_register(info, expectRevert, expectedRevertMsg);
    }

    // previously failing cases 
    function test_register_specificCases() public
    {
        bytes memory data = abi.encode("TestService", VersionLib.toVersionPart(1));

        _startPrank(0xb6F322D9421ae42BBbB5CC277CE23Dbb08b3aC1f);

        _assert_register_with_default_checks(
            IRegistry.ObjectInfo(
                toNftId(16158753772191290777002328881),
                toNftId(193),
                toObjectType(160),
                0x9c538400FeC769e651E6552221C88A29660f0DE5,
                0x643A203932303038363435323830353333323539,
                ""                
            )
        );

        _stopPrank();
        _startPrank(registryService);

        // parentNftId == _chainNft.mint() && objectAddress == initialOwner
        _assert_register_with_default_checks(
            IRegistry.ObjectInfo(
                toNftId(3471),
                toNftId(43133705),
                toObjectType(128),
                0x6AB133Ce3481A06313b4e0B1bb810BCD670853a4,
                0x6AB133Ce3481A06313b4e0B1bb810BCD670853a4,
                ""              
            )
        );

        // precompile address as owner
        _assert_register_with_default_checks(
            IRegistry.ObjectInfo(
                toNftId(76658180398758015949026343204),
                toNftId(17762988911415987093326017078),
                toObjectType(21),
                0x85Cf4Fe71daF5271f8a5C1D4E6BB4bc91f792e27,
                0x0000000000000000000000000000000000000008,
                ""            
            )
        );

        // initialOwner is cheat codes contract address
        _assert_register_with_default_checks(
            IRegistry.ObjectInfo(
                toNftId(15842010466351085404296329522),
                toNftId(16017),
                toObjectType(19),
                0x0C168C3a4589B65fFf12444A0c88125a416927DD,
                0x7109709ECfa91a80626fF3989D68f67F5b1DD12D,
                ""        
            )
        );

        _assert_register_with_default_checks(
            IRegistry.ObjectInfo(
                toNftId(0),
                toNftId(162),
                toObjectType(0),
                0x733A203078373333613230333037383337333333,
                0x4e59b44847b379578588920cA78FbF26c0B4956C,
                ""        
            )
        );


//(133133705, 23133705, 40, 0x0000000000000000000000000000000000000001, 0x6AB133Ce3481A06313b4e0B1bb810BCD670853a4, 0x000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000
//ContractAlreadyRegistered(0x0000000000000000000000000000000000000001)
        _assert_register_with_default_checks(
            IRegistry.ObjectInfo(
                toNftId(133133705),
                registryNftId,
                SERVICE(),
                0x0000000000000000000000000000000000000001,
                0x6AB133Ce3481A06313b4e0B1bb810BCD670853a4,
                abi.encode("asasas", VersionLib.toVersionPart(1))
            )
        );

        _stopPrank();
        _startPrank(0x0000000000000000000000000000000042966C69);

        _assert_register_with_default_checks(
            IRegistry.ObjectInfo(
                toNftId(22045),
                toNftId(EnumerableSet.at(_nftIds, 2620112370 % EnumerableSet.length(_nftIds))),
                _types[199 % _types.length],
                address(0),
                0x7109709ECfa91a80626fF3989D68f67F5b1DD12D,
                ""        
            )
        );
        //0x0000000000000000000000000000000042966C69, 22045, 2620112370, 199, 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D]
        _stopPrank();
        _startPrank(0x000000000000000000000000000000000000185e);

        _assert_register_with_default_checks(
            IRegistry.ObjectInfo(
                toNftId(5764),
                toNftId(EnumerableSet.at(_nftIds, 1794 % EnumerableSet.length(_nftIds))),
                _types[167 % _types.length],
                address(0),
                0x7109709ECfa91a80626fF3989D68f67F5b1DD12D,
                ""        
            )
        );
        //0x000000000000000000000000000000000000185e, 5764, 1794, 167, 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D
        _stopPrank();
        
    }

    function test_ownerNftTransfer() public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            zeroNftId(), // any nftId
            registryNftId,
            SERVICE(),
            address(uint160(randomNumber(type(uint160).max))),
            outsider, // any address capable to receive nft
            abi.encode("NewService", VersionLib.toVersionPart(1))
        );

        bytes memory reason_NotRegistryService = abi.encodeWithSelector(Registry.NotRegistryService.selector);
        bytes memory reason_NotOwner = abi.encodeWithSelector(Registry.NotOwner.selector);

        _startPrank(outsider);

        _assert_register(info, true, reason_NotRegistryService);

        _assert_approve(registryServiceNftId, PRODUCT(), INSTANCE(), reason_NotOwner);

        _stopPrank();

        _startPrank(registryOwner);

        _assert_register(info, true, reason_NotRegistryService);

        _assert_approve(registryServiceNftId, PRODUCT(), INSTANCE(), "");


        chainNft.transferFrom(registryOwner, outsider, registryNftId.toInt());


        _assert_register(info, true, reason_NotRegistryService);

        _assert_approve(registryServiceNftId, POOL(), INSTANCE(), reason_NotOwner);

        _stopPrank();

        _startPrank(outsider);

        _assert_register(info, true, reason_NotRegistryService);

        _assert_approve(registryServiceNftId, POOL(), INSTANCE(), "");

        _stopPrank();

        _startPrank(registryService);

        _assert_register(info, false, "");

        _assert_approve(registryServiceNftId, ORACLE(), INSTANCE(), reason_NotOwner);

        _stopPrank();
    }
    
    function testFuzz_register(address sender, IRegistry.ObjectInfo memory info) public
    {
        // gives error (Invalid data) only during fuzzing when minting nft to foundry's cheatcodes contract
        vm.assume(info.initialOwner != 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

        // fuzz serviceName?
        if(info.objectType == SERVICE()) {
            info.data = abi.encode("TestService", VersionLib.toVersionPart(1));
        } else {
            info.data = "";
        }

        _startPrank(sender);

        _assert_register_with_default_checks(info); // NotRegistryService

        _stopPrank();

        if(sender != registryService) {
            _startPrank(registryService);

            _assert_register_with_default_checks(info);

            _stopPrank();
        }
    }

    // nftId - random
    // parentNftId - random
    // objectType - random
    // objectAddress - random
    // initialOwner - set of addresses (registered + senders)
    function testFuzz_register_000001(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, address objectAddress, uint initialOwnerIdx) public //, bytes memory data
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            objectType,
            objectAddress,
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            ""
        );

        testFuzz_register(sender, info);
    }

    
    function testFuzz_register_000010(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, uint objectAddressIdx, address initialOwner) public //, bytes memory data
    {

        
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            objectType,
            EnumerableSet.at(_addresses, objectAddressIdx % EnumerableSet.length(_addresses)),
            initialOwner,
            ""
        );

        testFuzz_register(sender, info);
    }

    
    function testFuzz_register_000011(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, uint objectAddressIdx, uint initialOwnerIdx) public //, bytes memory data
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            objectType,
            EnumerableSet.at(_addresses, objectAddressIdx % EnumerableSet.length(_addresses)),
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            ""
        );

        testFuzz_register(sender, info);
    }

    
    function testFuzz_register_000100(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, address objectAddress, address initialOwner) public //, bytes memory data
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            _types[objectTypeIdx % _types.length],
            objectAddress,
            initialOwner,
            ""
        );

        testFuzz_register(sender, info);
    }

    
    function testFuzz_register_000101(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, address objectAddress, uint initialOwnerIdx) public //, bytes memory data
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            _types[objectTypeIdx % _types.length],
            objectAddress,
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            ""
        );

        testFuzz_register(sender, info);
    }

    
    function testFuzz_register_000110(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx,  uint objectAddressIdx, address initialOwner) public //, bytes memory data
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            _types[objectTypeIdx % _types.length],
            EnumerableSet.at(_addresses, objectAddressIdx % EnumerableSet.length(_addresses)),
            initialOwner,
            ""
        );

        testFuzz_register(sender, info);
    }

    
    function testFuzz_register_000111(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx,  uint objectAddressIdx, uint initialOwnerIdx) public //, bytes memory data
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            _types[objectTypeIdx % _types.length],
            EnumerableSet.at(_addresses, objectAddressIdx % EnumerableSet.length(_addresses)),
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            ""
        );

        testFuzz_register(sender, info);
    }

    
    function testFuzz_register_001000(address sender, NftId nftId, uint parentIdx, ObjectType objectType, address objectAddress, address initialOwner) public //, bytes memory data
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            objectType,
            objectAddress,
            initialOwner,
            ""
        );

        testFuzz_register(sender, info);
    }

    
    function testFuzz_register_001001(address sender, NftId nftId, uint parentIdx, ObjectType objectType, address objectAddress, uint initialOwnerIdx) public //, bytes memory data
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            objectType,
            objectAddress,
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            ""
        );

        testFuzz_register(sender, info);
    }

    
    function testFuzz_register_001010(address sender, NftId nftId, uint parentIdx, ObjectType objectType, uint objectAddressIdx, address initialOwner) public //, bytes memory data
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            objectType,
            EnumerableSet.at(_addresses, objectAddressIdx % EnumerableSet.length(_addresses)),
            initialOwner,
            ""
        );

        testFuzz_register(sender, info);
    }

    
    function testFuzz_register_001011(address sender, NftId nftId, uint parentIdx, ObjectType objectType, uint objectAddressIdx, uint initialOwnerIdx) public //, bytes memory data
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            objectType,
            EnumerableSet.at(_addresses, objectAddressIdx % EnumerableSet.length(_addresses)),
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            ""
        );

        testFuzz_register(sender, info);
    }

    
    function testFuzz_register_001100(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, address objectAddress, address initialOwner) public //, bytes memory data
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            _types[objectTypeIdx % _types.length],
            objectAddress,
            initialOwner,
            ""
        );

        testFuzz_register(sender, info);
    }

    
    function testFuzz_register_001101(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, address objectAddress, uint initialOwnerIdx) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            _types[objectTypeIdx % _types.length],
            objectAddress,
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            ""
        );

        testFuzz_register(sender, info);
    }

    
    function testFuzz_register_001110(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, uint objectAddressIdx, address initialOwner) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            _types[objectTypeIdx % _types.length],
            EnumerableSet.at(_addresses, objectAddressIdx % EnumerableSet.length(_addresses)),
            initialOwner,
            ""
        );

        testFuzz_register(sender, info);
    }

    
    function testFuzz_register_001111(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, uint objectAddressIdx, uint initialOwnerIdx) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            _types[objectTypeIdx % _types.length],
            EnumerableSet.at(_addresses, objectAddressIdx % EnumerableSet.length(_addresses)),
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            ""
        );

        testFuzz_register(sender, info);
    }

    function testFuzz_register_zeroObjectAddress(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, address initialOwner) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            objectType,
            address(0),
            initialOwner,
            ""
        );

        testFuzz_register(sender, info);
    }

    function testFuzz_register_zeroObjectAddress_00001(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, uint initialOwnerIdx) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            objectType,
            address(0),
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            ""
        );

        testFuzz_register(sender, info);
    }

    function testFuzz_register_zeroObjectAddress_00010(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, address initialOwner) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            _types[objectTypeIdx % _types.length],
            address(0),
            initialOwner,
            ""
        );

        testFuzz_register(sender, info);
    }

    function testFuzz_register_zeroObjectAddress_00011(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, uint initialOwnerIdx) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            _types[objectTypeIdx % _types.length],
            address(0),
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            ""
        );

        testFuzz_register(sender, info);
    }

    function testFuzz_register_zeroObjectAddress_00100(address sender, NftId nftId, uint parentIdx, ObjectType objectType, address initialOwner) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            objectType,
            address(0),
            initialOwner,
            ""
        );

        testFuzz_register(sender, info);
    }

    function testFuzz_register_zeroObjectAddress_00101(address sender, NftId nftId, uint parentIdx, ObjectType objectType, uint initialOwnerIdx) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            objectType,
            address(0),
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            ""
        );

        testFuzz_register(sender, info);
    }

    function testFuzz_register_zeroObjectAddress_00110(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, address initialOwner) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            _types[objectTypeIdx % _types.length],
            address(0),
            initialOwner,
            ""
        );

        testFuzz_register(sender, info);
    }

    function testFuzz_register_zeroObjectAddress_00111(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, uint initialOwnerIdx) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            _types[objectTypeIdx % _types.length],
            address(0),
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            ""
        );

        testFuzz_register(sender, info);
    }

    
    function testFuzz_approve(address sender, NftId nftId, ObjectType objectType, ObjectType parentType) public
    {
        _startPrank(sender);

        _assert_approve_with_default_checks(nftId, objectType, parentType);

        _stopPrank();

        if(sender != registryOwner) {
            _startPrank(registryOwner);

            _assert_approve_with_default_checks(nftId, objectType, parentType);

            _stopPrank();
        }
    }

    
    function testFuzz_approve_0001(address sender, NftId nftId, ObjectType objectType, uint8 parentTypeIdx) public
    {
        testFuzz_approve(
            sender,
            nftId,
            objectType,
            _types[parentTypeIdx % _types.length]
        );
    }

    
    function testFuzz_approve_0010(address sender, NftId nftId, uint8 objectTypeIdx, ObjectType parentType) public
    {
        testFuzz_approve(
            sender,
            nftId,
            _types[objectTypeIdx % _types.length],
            parentType
        );
    }

    
    function testFuzz_approve_0011(address sender, NftId nftId, uint8 objectTypeIdx, uint8 parentTypeIdx) public
    {
        testFuzz_approve(
            sender,
            nftId,
            _types[objectTypeIdx % _types.length],
            _types[parentTypeIdx % _types.length]
        );
    }

    
    function testFuzz_approve_0100(address sender, uint nftIdIdx, ObjectType objectType, ObjectType parentType) public
    {
        testFuzz_approve(
            sender,
            toNftId(EnumerableSet.at(_nftIds, nftIdIdx % EnumerableSet.length(_nftIds))),
            objectType,
            parentType
        );        
    }

    
    function testFuzz_approve_0101(address sender, uint nftIdIdx, ObjectType objectType, uint8 parentTypeIdx) public
    {
        testFuzz_approve(
            sender,
            toNftId(EnumerableSet.at(_nftIds, nftIdIdx % EnumerableSet.length(_nftIds))),
            objectType,
            _types[parentTypeIdx % _types.length]
        );
    }

    
    function testFuzz_approve_0110(address sender, uint nftIdIdx, uint8 objectTypeIdx, ObjectType parentType) public
    {
        testFuzz_approve(
            sender,
            toNftId(EnumerableSet.at(_nftIds, nftIdIdx % EnumerableSet.length(_nftIds))),
            _types[objectTypeIdx % _types.length],
            parentType
        );
    }

    function testFuzz_approve_0111(address sender, uint nftIdIdx, uint8 objectTypeIdx, uint8 parentTypeIdx) public
    {
        testFuzz_approve(
            sender,
            toNftId(EnumerableSet.at(_nftIds, nftIdIdx % EnumerableSet.length(_nftIds))),
            _types[objectTypeIdx % _types.length],
            _types[parentTypeIdx % _types.length]
        );
    }
}

contract RegistryTestWithPreset is RegistryTest
{ 
    function setUp() public override
    {
        super.setUp();

        _startPrank(registryService);

        _register_all_types();

        _stopPrank();
    }

    function _register_all_types() internal
    {
        IRegistry.ObjectInfo memory info;

        console.log("Registering token\n");

        info.nftId = toNftId(randomNumber(type(uint96).max));
        info.parentNftId = _nftIdByType[REGISTRY()];
        info.objectType = TOKEN();
        info.objectAddress = address(uint160(randomNumber(11, type(uint160).max))); // not 0
        info.initialOwner = address(uint160(randomNumber(type(uint160).max)));

        assertTrue(_nftIdByType[TOKEN()] == zeroNftId(), "Test error: _nftIdByType[TOKEN()] overwrite");
        _nftIdByType[TOKEN()] = _assert_register(info, false, "");

        console.log("Registered token\n");
        console.log("Registering instance\n");

        info.nftId = toNftId(randomNumber(type(uint96).max));
        info.parentNftId = _nftIdByType[REGISTRY()];
        info.objectType = INSTANCE();
        info.objectAddress = address(uint160(randomNumber(11, type(uint160).max))); // not 0
        info.initialOwner = address(uint160(randomNumber(type(uint160).max)));

        assertTrue(_nftIdByType[INSTANCE()] == zeroNftId(), "Test error: _nftIdByType[INSTANCE()] overwrite");
        _nftIdByType[INSTANCE()] = _assert_register(info, false, "");

        console.log("Registered instance\n");
        console.log("Registering product\n");

        info.nftId = toNftId(randomNumber(type(uint96).max));
        info.parentNftId = _nftIdByType[INSTANCE()];
        info.objectType = PRODUCT();
        info.objectAddress = address(uint160(randomNumber(11, type(uint160).max))); // not 0
        info.initialOwner = address(uint160(randomNumber(type(uint160).max)));

        assertTrue(_nftIdByType[PRODUCT()] == zeroNftId(), "Test error: _nftIdByType[PRODUCT()] overwrite");
        _nftIdByType[PRODUCT()] = _assert_register(info, false, "");

        console.log("Registered product\n");
        console.log("Registering pool\n");

        info.nftId = toNftId(randomNumber(type(uint96).max));
        info.parentNftId = _nftIdByType[INSTANCE()];
        info.objectType = POOL();
        info.objectAddress = address(uint160(randomNumber(11, type(uint160).max))); // not 0
        info.initialOwner = address(uint160(randomNumber(type(uint160).max)));

        assertTrue(_nftIdByType[POOL()] == zeroNftId(), "Test error: _nftIdByType[POOL()] overwrite");
        _nftIdByType[POOL()] = _assert_register(info, false, "");

        console.log("Registered pool\n");
        console.log("Registering oracle\n");

        info.nftId = toNftId(randomNumber(type(uint96).max));
        info.parentNftId = _nftIdByType[INSTANCE()];
        info.objectType = ORACLE();
        info.objectAddress = address(uint160(randomNumber(11, type(uint160).max))); // not 0
        info.initialOwner = address(uint160(randomNumber(type(uint160).max)));

        assertTrue(_nftIdByType[ORACLE()] == zeroNftId(), "Test error: _nftIdByType[ORACLE()] overwrite");
        _nftIdByType[ORACLE()] = _assert_register(info, false, "");

        console.log("Registered oracle\n");
        console.log("Registering distribution\n");

        info.nftId = toNftId(randomNumber(type(uint96).max));
        info.parentNftId = _nftIdByType[INSTANCE()];
        info.objectType = DISTRIBUTION();
        info.objectAddress = address(uint160(randomNumber(11, type(uint160).max))); // not 0
        info.initialOwner = address(uint160(randomNumber(type(uint160).max)));

        assertTrue(_nftIdByType[DISTRIBUTION()] == zeroNftId(), "Test error: _nftIdByType[DISTRIBUTION()] overwrite");
        _nftIdByType[DISTRIBUTION()] = _assert_register(info, false, "");

        console.log("Registered distribution\n");
        console.log("Registering policy\n");

        info.nftId = toNftId(randomNumber(type(uint96).max));
        info.parentNftId = _nftIdByType[PRODUCT()];
        info.objectType = POLICY();
        info.objectAddress = address(0);
        info.initialOwner = address(uint160(randomNumber(type(uint160).max)));

        assertTrue(_nftIdByType[POLICY()] == zeroNftId(), "Test error: _nftIdByType[POLICY()] overwrite");
        _nftIdByType[POLICY()] = _assert_register(info, false, "");     

        console.log("Registered policy\n");
        console.log("Registering bundle\n");   

        info.nftId = toNftId(randomNumber(type(uint96).max));
        info.parentNftId = _nftIdByType[POOL()];
        info.objectType = BUNDLE();
        info.objectAddress = address(0);
        info.initialOwner = address(uint160(randomNumber(type(uint160).max)));

        assertTrue(_nftIdByType[BUNDLE()] == zeroNftId(), "Test error: _nftIdByType[BUNDLE()] overwrite");
        _nftIdByType[BUNDLE()] = _assert_register(info, false, "");   

        console.log("Registered bundle\n");
        console.log("Registering stake\n");

        info.nftId = toNftId(randomNumber(type(uint96).max));
        info.parentNftId = _nftIdByType[POOL()];
        info.objectType = STAKE();
        info.objectAddress = address(0);
        info.initialOwner = address(uint160(randomNumber(type(uint160).max)));

        assertTrue(_nftIdByType[STAKE()] == zeroNftId(), "Test error: _nftIdByType[STAKE()] overwrite");
        _nftIdByType[STAKE()] = _assert_register(info, false, "");  

        console.log("Registered stake\n");
    }
}
