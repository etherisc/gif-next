// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Test, Vm, console} from "../../lib/forge-std/src/Test.sol";
import {VersionLib, Version, VersionPart} from "../../contracts/type/Version.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {ObjectType, ObjectTypeLib, PROTOCOL, REGISTRY, SERVICE, INSTANCE, PRODUCT, POOL, ORACLE, DISTRIBUTION, BUNDLE, POLICY, STAKE} from "../../contracts/type/ObjectType.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {RegistryTestBase} from "./RegistryTestBase.sol";
import {RegistryTestBaseWithPreset} from "./RegistryTestBaseWithPreset.sol";

contract RegisterServiceFuzzTest is RegistryTestBase 
{
    function testFuzz_registerService(address sender, IRegistry.ObjectInfo memory info, VersionPart version, ObjectType domain, bytes32 salt) public
    {
        registerService_testFunction(sender, info, version, domain, salt);
    }

    // nftId - always random
    // parentNftId - random
    // objectType - random
    // isInterceptor - always random
    // salt - random
    // initialOwner - set of addresses (actors + registered + initial owners)
    // data - random
    // version - random
    // domain - random
    function testFuzz_registerService_0000001000(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, bytes32 salt, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            objectType,
            isInterceptor,
            address(0), // mock will be created
            _getAddressAtIndex(initialOwnerIdx),
            data
        );

        registerService_testFunction(sender, info, version, domain, salt);
    }

    // nftId - always random
    // parentNftId - random
    // objectType - random
    // objectAddress - from address set
    // initialOwner - random
    // data - random
    // version - random
    // domain - random
    function testFuzz_registerService_000010000(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, uint objectAddressIdx, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            objectType,
            false, // isInterceptor
            _getAddressAtIndex(objectAddressIdx),
            initialOwner,
            data
        );

        registerService_testFunction(sender, info, version, domain);
    }

    
    function testFuzz_registerService_000011000(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            objectType,
            false, // isInterceptor
            _getAddressAtIndex(objectAddressIdx),
            _getAddressAtIndex(initialOwnerIdx),
            data
        );

        registerService_testFunction(sender, info, version, domain);
    }

    
    function testFuzz_registerService_0001000000(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, bool isInterceptor, bytes32 salt, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public 
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            _getObjectTypeAtIndex(objectTypeIdx),
            isInterceptor,
            address(0), // mock will be created
            initialOwner,
            data
        );

        registerService_testFunction(sender, info, version, domain, salt);
    }

    
    function testFuzz_registerService_0001001000(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, bool isInterceptor, bytes32 salt, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            _getObjectTypeAtIndex(objectTypeIdx),
            isInterceptor,
            address(0),
            _getAddressAtIndex(initialOwnerIdx),
            data
        );

        registerService_testFunction(sender, info, version, domain, salt);
    }

    
    function testFuzz_registerService_000110000(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx,  uint objectAddressIdx, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public 
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            _getObjectTypeAtIndex(objectTypeIdx),
            false,
            _getAddressAtIndex(objectAddressIdx),
            initialOwner,
            data
        );

        registerService_testFunction(sender, info, version, domain);
    }

    
    function testFuzz_registerService_000111000(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx,  uint objectAddressIdx, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public 
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            _getObjectTypeAtIndex(objectTypeIdx),
            false,
            _getAddressAtIndex(objectAddressIdx),
            _getAddressAtIndex(initialOwnerIdx),
            data
        );

        registerService_testFunction(sender, info, version, domain);
    }

    
    function testFuzz_registerService_0010000000(address sender, NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, bytes32 salt, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            _getNftIdAtIndex(parentIdx),
            objectType,
            isInterceptor,
            address(0),
            initialOwner,
            data
        );

        registerService_testFunction(sender, info, version, domain, salt);
    }

    
    function testFuzz_registerService_0010001000(address sender, NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, bytes32 salt, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            _getNftIdAtIndex(parentIdx),
            objectType,
            isInterceptor,
            address(0),
            _getAddressAtIndex(initialOwnerIdx),
            data
        );

        registerService_testFunction(sender, info, version, domain, salt);
    }

    
    function testFuzz_registerService_001010000(address sender, NftId nftId, uint parentIdx, ObjectType objectType, uint objectAddressIdx, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            _getNftIdAtIndex(parentIdx),
            objectType,
            false,
            _getAddressAtIndex(objectAddressIdx),
            initialOwner,
            data
        );

        registerService_testFunction(sender, info, version, domain);
    }

    
    function testFuzz_registerService_001011000(address sender, NftId nftId, uint parentIdx, ObjectType objectType, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public 
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            _getNftIdAtIndex(parentIdx),
            objectType,
            false,
            _getAddressAtIndex(objectAddressIdx),
            _getAddressAtIndex(initialOwnerIdx),
            data
        );

        registerService_testFunction(sender, info, version, domain);
    }

    
    function testFuzz_registerService_0011000000(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, bytes32 salt, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public 
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            _getNftIdAtIndex(parentIdx),
            _getObjectTypeAtIndex(objectTypeIdx),
            isInterceptor,
            address(0),
            initialOwner,
            data
        );

        registerService_testFunction(sender, info, version, domain, salt);
    }

    
    function testFuzz_registerService_0011001000(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, bytes32 salt, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            _getNftIdAtIndex(parentIdx),
            _getObjectTypeAtIndex(objectTypeIdx),
            isInterceptor,
            address(0),
            _getAddressAtIndex(initialOwnerIdx),
            data
        );

        registerService_testFunction(sender, info, version, domain, salt);
    }

    
    function testFuzz_registerService_001110000(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, uint objectAddressIdx, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            _getNftIdAtIndex(parentIdx),
            _getObjectTypeAtIndex(objectTypeIdx),
            false,
            _getAddressAtIndex(objectAddressIdx),
            initialOwner,
            data
        );

        registerService_testFunction(sender, info, version, domain);
    }

    
    function testFuzz_registerService_001111000(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            _getNftIdAtIndex(parentIdx),
            _getObjectTypeAtIndex(objectTypeIdx),
            false,
            _getAddressAtIndex(objectAddressIdx),
            _getAddressAtIndex(initialOwnerIdx),
            data
        );

        registerService_testFunction(sender, info, version, domain);
    }

    function testFuzz_registerService_withValidType(address sender, NftId nftId, NftId parentNftId, bool isInterceptor, bytes32 salt, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            SERVICE(),
            isInterceptor,
            address(0),
            initialOwner,
            data
        );

        registerService_testFunction(sender, info, version, domain, salt);
    }

    function testFuzz_registerService_withValidType_000001000(address sender, NftId nftId, NftId parentNftId, bool isInterceptor, bytes32 salt, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            SERVICE(),
            isInterceptor,
            address(0),
            _getAddressAtIndex(initialOwnerIdx),
            data
        );

        registerService_testFunction(sender, info, version, domain, salt);
    }

    function testFuzz_registerService_withValidType_00010000(address sender, NftId nftId, NftId parentNftId, uint objectAddressIdx, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            SERVICE(),
            false,
            _getAddressAtIndex(objectAddressIdx),
            initialOwner,
            data
        );

        registerService_testFunction(sender, info, version, domain);
    }

    function testFuzz_registerService_withValidType_00011000(address sender, NftId nftId, NftId parentNftId, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            SERVICE(),
            false,
            _getAddressAtIndex(objectAddressIdx),
            _getAddressAtIndex(initialOwnerIdx),
            data
        );

        registerService_testFunction(sender, info, version, domain);
    }

    function testFuzz_registerService_withValidType_001000000(address sender, NftId nftId, uint parentIdx, bool isInterceptor, bytes32 salt, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            _getNftIdAtIndex(parentIdx),
            SERVICE(),
            isInterceptor,
            address(0),
            initialOwner,
            data
        );

        registerService_testFunction(sender, info, version, domain, salt);
    }

    function testFuzz_registerService_withValidType_001001000(address sender, NftId nftId, uint parentIdx, bool isInterceptor, bytes32 salt, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            _getNftIdAtIndex(parentIdx),
            SERVICE(),
            isInterceptor,
            address(0),
            _getAddressAtIndex(initialOwnerIdx),
            data
        );

        registerService_testFunction(sender, info, version, domain, salt);
    }

    function testFuzz_registerService_withValidType_00110000(address sender, NftId nftId, uint parentIdx, uint objectAddressIdx, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            _getNftIdAtIndex(parentIdx),
            SERVICE(),
            false,
            _getAddressAtIndex(objectAddressIdx),
            initialOwner,
            data
        );

        registerService_testFunction(sender, info, version, domain);
    }

    function testFuzz_registerService_withValidType_00111000(address sender, NftId nftId, uint parentIdx, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            _getNftIdAtIndex(parentIdx),
            SERVICE(),
            false,
            _getAddressAtIndex(objectAddressIdx),
            _getAddressAtIndex(initialOwnerIdx),
            data
        );

        registerService_testFunction(sender, info, version, domain);
    }

    // TODO rename and fix, current implementation fails frequently with error message below
    // [FAIL. Reason: The `vm.assume` cheatcode rejected too many inputs (100 allowed)] 
    function testFuzz_registerService_withDuplicateVersionAndDomain(
        IRegistry.ObjectInfo memory info_1,
        IRegistry.ObjectInfo memory info_2,
        VersionPart version, 
        ObjectType domain
    ) 
        public
    {
        vm.assume(
            info_1.objectAddress != info_2.objectAddress &&
            info_1.objectAddress != address(0) &&
            info_2.objectAddress != address(0) &&
            address(info_1.initialOwner).codehash == 0 && // can receive nft
            address(info_2.initialOwner).codehash == 0 &&
            address(info_1.initialOwner) != address(0) &&
            address(info_2.initialOwner) != address(0)
        );

        while(EnumerableSet.contains(_registeredAddresses, info_1.objectAddress)) {
            info_1.objectAddress = address((uint160(info_1.objectAddress) + 1));
        }

        while(EnumerableSet.contains(_registeredAddresses, info_1.initialOwner)) {
            info_1.initialOwner = address((uint160(info_1.initialOwner) + 1));
        }

        while(EnumerableSet.contains(_registeredAddresses, info_2.objectAddress)) {
            info_2.objectAddress = address((uint160(info_2.objectAddress) + 1));
        }

        while(EnumerableSet.contains(_registeredAddresses, info_2.initialOwner)) {
            info_2.initialOwner = address((uint160(info_2.initialOwner) + 1));
        }

        while(domain.eqz() || domain.toInt() == REGISTRY().toInt()) { // already registered service domain
            domain = ObjectTypeLib.toObjectType(domain.toInt() + 1);
        }

        while(version.toInt() <= VERSION.toInt()) { // already registered service version
            version = VersionLib.toVersionPart(version.toInt() + 1);
        }

        info_1.parentNftId = registryNftId;
        info_1.objectType = SERVICE();
        info_1.isInterceptor = false;

        info_2.parentNftId = registryNftId;
        info_2.objectType = SERVICE();
        info_2.isInterceptor = false;

        _startPrank(address(releaseRegistry));

        _assert_registerService(info_1, version, domain, false, "");

        _assert_registerService(
            info_2,
            version,
            domain,
            true, 
            abi.encodeWithSelector(
                IRegistry.ErrorRegistryDomainAlreadyRegistered.selector,
                info_2.objectAddress,
                version,
                domain)
        );

        _stopPrank();
    }
}

contract RegisterServiceWithPresetFuzzTest is RegistryTestBaseWithPreset, RegisterServiceFuzzTest
{
    function setUp() public virtual override(RegistryTestBaseWithPreset, RegistryTestBase)
    {
        RegistryTestBaseWithPreset.setUp();
    }

    function testFuzz_RegisterService_00P1000000(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, bytes32 salt, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            _nftIdByType[parentIdx % _nftIdByType.length],
            _getObjectTypeAtIndex(objectTypeIdx),
            isInterceptor,
            address(0),
            initialOwner,
            data
        );

        registerService_testFunction(sender, info, version, domain, salt);
    }

    function testFuzz_registerService_withValidType_00P000000(address sender, NftId nftId, uint parentIdx, bool isInterceptor, bytes32 salt, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            _nftIdByType[parentIdx % _nftIdByType.length],
            SERVICE(),
            isInterceptor,
            address(0),
            initialOwner,
            data
        );

        registerService_testFunction(sender, info, version, domain, salt);
    }

    function test_getIndexFunctions() public
    {
        console.log("_addresses length", EnumerableSet.length(_addresses));
        console.log("_nftIds length", EnumerableSet.length(_nftIds));
        console.log("_types length", EnumerableSet.length(_types));
        for(uint i = 0; i < 3; i++)
        {
            console.log("address at index %s: %s", i, EnumerableSet.at(_addresses, i));
            console.log("nftId at index %s: %s", i, EnumerableSet.at(_nftIds, i));
            console.log("objectType at index %s: %s", i, EnumerableSet.at(_types, i));

            uint256 index = randomNumber(type(uint256).max);
            console.log("random index ", index);

            uint addressModIndex = index % EnumerableSet.length(_addresses);
            uint nftIdModIndex = index % EnumerableSet.length(_nftIds);
            uint objectTypeModIndex = index % EnumerableSet.length(_types);

            console.log("mod _addresses index:", addressModIndex);
            console.log("mod _nftIds index:", nftIdModIndex);
            console.log("mod _types index:", objectTypeModIndex);

            console.log("address at mod _addresses index:", EnumerableSet.at(_addresses, index % EnumerableSet.length(_addresses)));
            console.log("nftId at mod _nftIds index:", EnumerableSet.at(_nftIds, index % EnumerableSet.length(_nftIds)));
            console.log("objectType at mod _types index:", EnumerableSet.at(_types, index % EnumerableSet.length(_types)));

            console.log("get functions:");
            console.log("address ", _getAddressAtIndex(index));
            console.log("nftId ", _getNftIdAtIndex(index).toInt());
            console.log("objectType ", _getObjectTypeAtIndex(index).toInt());
            console.log("");
        }
    }
}