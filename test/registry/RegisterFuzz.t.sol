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

contract RegisterFuzzTest is RegistryTestBase 
{    
    function testFuzz_register(address sender, IRegistry.ObjectInfo memory info) public
    {
        _register_testFunction(sender, info);
    }

    // nftId - always random
    // parentNftId - random
    // objectType - random
    // isInterceptor - always random
    // objectAddress - random
    // initialOwner - set of addresses (actors + registered + initial owners)
    function testFuzz_register_0000001(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, address objectAddress, uint initialOwnerIdx, bytes memory data) public
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

        _register_testFunction(sender, info);
    }

    
    function testFuzz_register_0000010(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, uint objectAddressIdx, address initialOwner, bytes memory data) public
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

        _register_testFunction(sender, info);
    }

    
    function testFuzz_register_0000011(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data) public
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

        _register_testFunction(sender, info);
    }

    
    function testFuzz_register_0001000(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, bool isInterceptor, address objectAddress, address initialOwner, bytes memory data) public 
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

        _register_testFunction(sender, info);
    }

    
    function testFuzz_register_0001001(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, bool isInterceptor, address objectAddress, uint initialOwnerIdx, bytes memory data) public
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

        _register_testFunction(sender, info);
    }

    
    function testFuzz_register_0001010(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, bool isInterceptor,  uint objectAddressIdx, address initialOwner, bytes memory data) public 
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

        _register_testFunction(sender, info);
    }

    
    function testFuzz_register_0001011(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, bool isInterceptor,  uint objectAddressIdx, uint initialOwnerIdx, bytes memory data) public 
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

        _register_testFunction(sender, info);
    }

    
    function testFuzz_register_0010000(address sender, NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, address objectAddress, address initialOwner, bytes memory data) public
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

        _register_testFunction(sender, info);
    }

    
    function testFuzz_register_0010001(address sender, NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, address objectAddress, uint initialOwnerIdx, bytes memory data) public
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

        _register_testFunction(sender, info);
    }

    
    function testFuzz_register_0010010(address sender, NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, uint objectAddressIdx, address initialOwner, bytes memory data) public
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

        _register_testFunction(sender, info);
    }

    
    function testFuzz_register_0010011(address sender, NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data) public 
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

        _register_testFunction(sender, info);
    }

    
    function testFuzz_register_0011000(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, address objectAddress, address initialOwner, bytes memory data) public 
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

        _register_testFunction(sender, info);
    }

    
    function testFuzz_register_0011001(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, address objectAddress, uint initialOwnerIdx, bytes memory data) public
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

        _register_testFunction(sender, info);
    }

    
    function testFuzz_register_0011010(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, uint objectAddressIdx, address initialOwner, bytes memory data) public
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

        _register_testFunction(sender, info);
    }

    
    function testFuzz_register_0011011(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data) public
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

        _register_testFunction(sender, info);
    }

    function testFuzz_register_withZeroObjectAddress(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, address initialOwner, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            objectType,
            isInterceptor,
            address(0),
            initialOwner,
            data
        );

        _register_testFunction(sender, info);
    }

    function testFuzz_register_withZeroObjectAddress_00001(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, uint initialOwnerIdx, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            objectType,
            isInterceptor,
            address(0),
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            data
        );

        _register_testFunction(sender, info);
    }

    function testFuzz_register_withZeroObjectAddress_00010(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, bool isInterceptor, address initialOwner, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            _types[objectTypeIdx % _types.length],
            isInterceptor,
            address(0),
            initialOwner,
            data
        );

        _register_testFunction(sender, info);
    }

    function testFuzz_register_withZeroObjectAddress_00011(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, bool isInterceptor, uint initialOwnerIdx, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            _types[objectTypeIdx % _types.length],
            isInterceptor,
            address(0),
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            data
        );

        _register_testFunction(sender, info);
    }

    function testFuzz_register_withZeroObjectAddress_00100(address sender, NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, address initialOwner, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            NftIdLib.toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            objectType,
            isInterceptor,
            address(0),
            initialOwner,
            data
        );

        _register_testFunction(sender, info);
    }

    function testFuzz_register_withZeroObjectAddress_00101(address sender, NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, uint initialOwnerIdx, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            NftIdLib.toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            objectType,
            isInterceptor,
            address(0),
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            data
        );

        _register_testFunction(sender, info);
    }

    function testFuzz_register_withZeroObjectAddress_00110(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, address initialOwner, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            NftIdLib.toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            _types[objectTypeIdx % _types.length],
            isInterceptor,
            address(0),
            initialOwner,
            data
        );

        _register_testFunction(sender, info);
    }

    function testFuzz_register_withZeroObjectAddress_00111(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, uint initialOwnerIdx, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            NftIdLib.toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            _types[objectTypeIdx % _types.length],
            isInterceptor,
            address(0),
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            data
        );

        _register_testFunction(sender, info);
    }
}

contract RegisterWithPresetFuzzTest is RegistryTestBaseWithPreset, RegisterFuzzTest
{
    function setUp() public virtual override(RegistryTestBaseWithPreset, RegistryTestBase)
    {
        RegistryTestBaseWithPreset.setUp();
    }

    function testFuzz_register_00P1000(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, address objectAddress, address initialOwner, bytes memory data) public
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

        _register_testFunction(sender, info);
    }

    function testFuzz_register_withZeroObjectAddress_00P100(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, address initialOwner, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            _nftIdByType[_types[parentIdx % _types.length]],
            _types[objectTypeIdx % _types.length],
            isInterceptor,
            address(0),
            initialOwner,
            data
        );

        _register_testFunction(sender, info);
    }
}
