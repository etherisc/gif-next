// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Test, Vm, console} from "../../lib/forge-std/src/Test.sol";
import {VersionLib, Version, VersionPart} from "../../contracts/type/Version.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {ObjectType, ObjectTypeLib, toObjectType, zeroObjectType, PROTOCOL, REGISTRY, TOKEN, SERVICE, INSTANCE, PRODUCT, POOL, ORACLE, DISTRIBUTION, BUNDLE, POLICY, STAKE} from "../../contracts/type/ObjectType.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {RegistryTestBase} from "./RegistryTestBase.sol";
import {RegistryTestBaseWithPreset} from "./RegistryTestBaseWithPreset.sol";

contract RegisterServiceFuzzTest is RegistryTestBase 
{
    function testFuzz_registerService(address sender, IRegistry.ObjectInfo memory info, VersionPart version, ObjectType domain) public
    {
        _registerService_testFunction(sender, info, version, domain);
    }

    // nftId - always random
    // parentNftId - random
    // objectType - random
    // isInterceptor - always random
    // objectAddress - random
    // initialOwner - set of addresses (actors + registered + initial owners)
    function testFuzz_registerService_0000001(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, address objectAddress, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            objectType,
            isInterceptor,
            objectAddress,
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            data
        );

        _registerService_testFunction(sender, info, version, domain);
    }


    function testFuzz_registerService_0000010(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, uint objectAddressIdx, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            objectType,
            isInterceptor,
            EnumerableSet.at(_addresses, objectAddressIdx % EnumerableSet.length(_addresses)),
            initialOwner,
            data
        );

        _registerService_testFunction(sender, info, version, domain);
    }

    
    function testFuzz_registerService_0000011(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            objectType,
            isInterceptor,
            EnumerableSet.at(_addresses, objectAddressIdx % EnumerableSet.length(_addresses)),
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            data
        );

        _registerService_testFunction(sender, info, version, domain);
    }

    
    function testFuzz_registerService_0001000(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, bool isInterceptor, address objectAddress, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public 
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            _types[objectTypeIdx % _types.length],
            isInterceptor,
            objectAddress,
            initialOwner,
            data
        );

        _registerService_testFunction(sender, info, version, domain);
    }

    
    function testFuzz_registerService_0001001(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, bool isInterceptor, address objectAddress, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            _types[objectTypeIdx % _types.length],
            isInterceptor,
            objectAddress,
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            data
        );

        _registerService_testFunction(sender, info, version, domain);
    }

    
    function testFuzz_registerService_0001010(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, bool isInterceptor,  uint objectAddressIdx, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public 
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            _types[objectTypeIdx % _types.length],
            isInterceptor,
            EnumerableSet.at(_addresses, objectAddressIdx % EnumerableSet.length(_addresses)),
            initialOwner,
            data
        );

        _registerService_testFunction(sender, info, version, domain);
    }

    
    function testFuzz_registerService_0001011(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, bool isInterceptor,  uint objectAddressIdx, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public 
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            _types[objectTypeIdx % _types.length],
            isInterceptor,
            EnumerableSet.at(_addresses, objectAddressIdx % EnumerableSet.length(_addresses)),
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            data
        );

        _registerService_testFunction(sender, info, version, domain);
    }

    
    function testFuzz_registerService_0010000(address sender, NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, address objectAddress, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            NftIdLib.toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            objectType,
            isInterceptor,
            objectAddress,
            initialOwner,
            data
        );

        _registerService_testFunction(sender, info, version, domain);
    }

    
    function testFuzz_registerService_0010001(address sender, NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, address objectAddress, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            NftIdLib.toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            objectType,
            isInterceptor,
            objectAddress,
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            data
        );

        _registerService_testFunction(sender, info, version, domain);
    }

    
    function testFuzz_registerService_0010010(address sender, NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, uint objectAddressIdx, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            NftIdLib.toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            objectType,
            isInterceptor,
            EnumerableSet.at(_addresses, objectAddressIdx % EnumerableSet.length(_addresses)),
            initialOwner,
            data
        );

        _registerService_testFunction(sender, info, version, domain);
    }

    
    function testFuzz_registerService_0010011(address sender, NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public 
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            NftIdLib.toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            objectType,
            isInterceptor,
            EnumerableSet.at(_addresses, objectAddressIdx % EnumerableSet.length(_addresses)),
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            data
        );

        _registerService_testFunction(sender, info, version, domain);
    }

    
    function testFuzz_registerService_0011000(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, address objectAddress, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public 
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            NftIdLib.toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            _types[objectTypeIdx % _types.length],
            isInterceptor,
            objectAddress,
            initialOwner,
            data
        );

        _registerService_testFunction(sender, info, version, domain);
    }

    
    function testFuzz_registerService_0011001(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, address objectAddress, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            NftIdLib.toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            _types[objectTypeIdx % _types.length],
            isInterceptor,
            objectAddress,
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            data
        );

        _registerService_testFunction(sender, info, version, domain);
    }

    
    function testFuzz_registerService_0011010(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, uint objectAddressIdx, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            NftIdLib.toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            _types[objectTypeIdx % _types.length],
            isInterceptor,
            EnumerableSet.at(_addresses, objectAddressIdx % EnumerableSet.length(_addresses)),
            initialOwner,
            data
        );

        _registerService_testFunction(sender, info, version, domain);
    }

    
    function testFuzz_registerService_0011011(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            NftIdLib.toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            _types[objectTypeIdx % _types.length],
            isInterceptor,
            EnumerableSet.at(_addresses, objectAddressIdx % EnumerableSet.length(_addresses)),
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            data
        );

        _registerService_testFunction(sender, info, version, domain);
    }

    function testFuzz_registerService_withValidType(address sender, NftId nftId, NftId parentNftId, bool isInterceptor, address objectAddress, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            SERVICE(),
            isInterceptor,
            objectAddress,
            initialOwner,
            data
        );

        _registerService_testFunction(sender, info, version, domain);
    }

    function testFuzz_registerService_withValidType_00001(address sender, NftId nftId, NftId parentNftId, bool isInterceptor, address objectAddress, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            SERVICE(),
            isInterceptor,
            objectAddress,
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            data
        );

        _registerService_testFunction(sender, info, version, domain);
    }

    function testFuzz_registerService_withValidType_00010(address sender, NftId nftId, NftId parentNftId, bool isInterceptor, uint objectAddressIdx, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            SERVICE(),
            isInterceptor,
            EnumerableSet.at(_addresses, objectAddressIdx % EnumerableSet.length(_addresses)),
            initialOwner,
            data
        );

        _registerService_testFunction(sender, info, version, domain);
    }

    function testFuzz_registerService_withValidType_00011(address sender, NftId nftId, NftId parentNftId, bool isInterceptor, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            SERVICE(),
            isInterceptor,
            EnumerableSet.at(_addresses, objectAddressIdx % EnumerableSet.length(_addresses)),
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            data
        );

        _registerService_testFunction(sender, info, version, domain);
    }

    function testFuzz_registerService_withValidType_00100(address sender, NftId nftId, uint parentIdx, bool isInterceptor, address objectAddress, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            NftIdLib.toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            SERVICE(),
            isInterceptor,
            objectAddress,
            initialOwner,
            data
        );

        _registerService_testFunction(sender, info, version, domain);
    }

    function testFuzz_registerService_withValidType_00101(address sender, NftId nftId, uint parentIdx, bool isInterceptor, address objectAddress, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            NftIdLib.toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            SERVICE(),
            isInterceptor,
            objectAddress,
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            data
        );

        _registerService_testFunction(sender, info, version, domain);
    }

    function testFuzz_registerService_withValidType_00110(address sender, NftId nftId, uint parentIdx, bool isInterceptor, uint objectAddressIdx, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            NftIdLib.toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            SERVICE(),
            isInterceptor,
            EnumerableSet.at(_addresses, objectAddressIdx % EnumerableSet.length(_addresses)),
            initialOwner,
            data
        );

        _registerService_testFunction(sender, info, version, domain);
    }

    function testFuzz_registerService_withValidType_00111(address sender, NftId nftId, uint parentIdx, bool isInterceptor, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            NftIdLib.toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            SERVICE(),
            isInterceptor,
            EnumerableSet.at(_addresses, objectAddressIdx % EnumerableSet.length(_addresses)),
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            data
        );

        _registerService_testFunction(sender, info, version, domain);
    }

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
            address(info_2.initialOwner) != address(0) &&
            !(version.toInt() == VERSION.toInt() && domain.toInt() == REGISTRY().toInt()) && // already registered service
            domain.gtz()
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

        info_1.parentNftId = registryNftId;
        info_1.objectType = SERVICE();
        info_1.isInterceptor = false;

        info_2.parentNftId = registryNftId;
        info_2.objectType = SERVICE();
        info_2.isInterceptor = false;

        _startPrank(address(releaseManager));

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

    function testFuzz_registerService_00P1000(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, address objectAddress, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            _nftIdByType[_types[parentIdx % _types.length]],
            _types[objectTypeIdx % _types.length],
            isInterceptor,
            objectAddress,
            initialOwner,
            data
        );

        _registerService_testFunction(sender, info, version, domain);
    }

    function testFuzz_registerService_withValidType_00P011(address sender, NftId nftId, uint parentIdx, bool isInterceptor, address objectAddress, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            _nftIdByType[_types[parentIdx % _types.length]],
            SERVICE(),
            isInterceptor,
            objectAddress,
            initialOwner,
            data
        );

        _registerService_testFunction(sender, info, version, domain);
    }
}