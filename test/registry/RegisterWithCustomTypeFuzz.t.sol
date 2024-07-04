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

contract RegisterWithCustomTypeFuzzTest is RegistryTestBase 
{    
    function testFuzz_registerWithCustomType(address sender, IRegistry.ObjectInfo memory info, bytes32 salt) public
    {
        registerWithCustomType_testFunction(sender, info, salt);
    }

    // sender - random
    // nftId - always random
    // parentNftId - random
    // objectType - random
    // isInterceptor - random
    // salt - always random
    // initialOwner - set of addresses (actors + registered + initial owners)
    // data - always random
    function testFuzz_registerWithCustomType_00000010(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, bytes32 salt, uint initialOwnerIdx, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            objectType,
            isInterceptor,
            address(0),
            _getAddressAtIndex(initialOwnerIdx),
            data
        );

        registerWithCustomType_testFunction(sender, info, salt);
    }

    // sender - random
    // nftId - always random
    // parentNftId - random
    // objectType - random
    // objectAddress - from addresses set (actors + registered + initial owners)
    // initialOwner - random
    // data - always random
    // if objectAddress is from address set -> set isInterceptor to false
    function testFuzz_registerWithCustomType_0000100(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, uint objectAddressIdx, address initialOwner, bytes memory data) public
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

        registerWithCustomType_testFunction(sender, info);
    }

    
    function testFuzz_registerWithCustomType_0000110(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data) public
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

        registerWithCustomType_testFunction(sender, info);
    }

    
    function testFuzz_registerWithCustomType_00010000(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, bool isInterceptor, bytes32 salt, address initialOwner, bytes memory data) public 
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            _getObjectTypeAtIndex(objectTypeIdx),
            isInterceptor,
            address(0),
            initialOwner,
            data
        );

        registerWithCustomType_testFunction(sender, info, salt);
    }

    
    function testFuzz_registerWithCustomType_00010010(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, bool isInterceptor, bytes32 salt, uint initialOwnerIdx, bytes memory data) public
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

        registerWithCustomType_testFunction(sender, info, salt);
    }

    
    function testFuzz_registerWithCustomType_0001100(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, uint objectAddressIdx, address initialOwner, bytes memory data) public 
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            _getObjectTypeAtIndex(objectTypeIdx),
            false, // isInterceptor
            _getAddressAtIndex(objectAddressIdx),
            initialOwner,
            data
        );

        registerWithCustomType_testFunction(sender, info);
    }

    
    function testFuzz_registerWithCustomType_0001110(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data) public 
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            _getObjectTypeAtIndex(objectTypeIdx),
            false, // isInterceptor
            _getAddressAtIndex(objectAddressIdx),
            _getAddressAtIndex(initialOwnerIdx),
            data
        );

        registerWithCustomType_testFunction(sender, info);
    }

    
    function testFuzz_registerWithCustomType_00100000(address sender, NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, bytes32 salt, address initialOwner, bytes memory data) public
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

        registerWithCustomType_testFunction(sender, info, salt);
    }

    
    function testFuzz_registerWithCustomType_00100010(address sender, NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, bytes32 salt, uint initialOwnerIdx, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            NftIdLib.toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            objectType,
            isInterceptor,
            address(0),
            _getAddressAtIndex(initialOwnerIdx),
            data
        );

        registerWithCustomType_testFunction(sender, info, salt);
    }

    
    function testFuzz_registerWithCustomType_0010100(address sender, NftId nftId, uint parentIdx, ObjectType objectType, uint objectAddressIdx, address initialOwner, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            NftIdLib.toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            objectType,
            false, // isInterceptor
            _getAddressAtIndex(objectAddressIdx),
            initialOwner,
            data
        );

        registerWithCustomType_testFunction(sender, info);
    }

    
    function testFuzz_registerWithCustomType_0010110(address sender, NftId nftId, uint parentIdx, ObjectType objectType, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data) public 
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            NftIdLib.toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            objectType,
            false, // isInterceptor
            _getAddressAtIndex(objectAddressIdx),
            _getAddressAtIndex(initialOwnerIdx),
            data
        );

        registerWithCustomType_testFunction(sender, info);
    }

    
    function testFuzz_registerWithCustomType_00110000(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, bytes32 salt, address initialOwner, bytes memory data) public 
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            NftIdLib.toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            _getObjectTypeAtIndex(objectTypeIdx),
            isInterceptor,
            address(0),
            initialOwner,
            data
        );

        registerWithCustomType_testFunction(sender, info, salt);
    }

    
    function testFuzz_registerWithCustomType_00110010(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, bytes32 salt, uint initialOwnerIdx, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            NftIdLib.toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            _getObjectTypeAtIndex(objectTypeIdx),
            isInterceptor,
            address(0),
            _getAddressAtIndex(initialOwnerIdx),
            data
        );

        registerWithCustomType_testFunction(sender, info, salt);
    }

    
    function testFuzz_registerWithCustomType_0011100(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, uint objectAddressIdx, address initialOwner, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            NftIdLib.toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            _getObjectTypeAtIndex(objectTypeIdx),
            false, // isInterceptor
            _getAddressAtIndex(objectAddressIdx),
            initialOwner,
            data
        );

        registerWithCustomType_testFunction(sender, info);
    }

    
    function testFuzz_registerWithCustomType_0011110(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            NftIdLib.toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            _getObjectTypeAtIndex(objectTypeIdx),
            false, // isInterceptor
            _getAddressAtIndex(objectAddressIdx),
            _getAddressAtIndex(initialOwnerIdx),
            data
        );

        registerWithCustomType_testFunction(sender, info);
    }

    function testFuzz_registerWithCustomType_withZeroObjectAddress(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, address initialOwner, bytes memory data) public
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

        registerWithCustomType_testFunction(sender, info);
    }

    function testFuzz_registerWithCustomType_withZeroObjectAddress_0000010(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, uint initialOwnerIdx, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            objectType,
            isInterceptor,
            address(0),
            _getAddressAtIndex(initialOwnerIdx),
            data
        );

        registerWithCustomType_testFunction(sender, info);
    }

    function testFuzz_registerWithCustomType_withZeroObjectAddress_0001000(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, bool isInterceptor, address initialOwner, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            _getObjectTypeAtIndex(objectTypeIdx),
            isInterceptor,
            address(0),
            initialOwner,
            data
        );

        registerWithCustomType_testFunction(sender, info);
    }

    function testFuzz_registerWithCustomType_withZeroObjectAddress_0001010(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, bool isInterceptor, uint initialOwnerIdx, bytes memory data) public
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

        registerWithCustomType_testFunction(sender, info);
    }

    function testFuzz_registerWithCustomType_withZeroObjectAddress_0010000(address sender, NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, address initialOwner, bytes memory data) public
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

        registerWithCustomType_testFunction(sender, info);
    }

    function testFuzz_registerWithCustomType_withZeroObjectAddress_0010010(address sender, NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, uint initialOwnerIdx, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            NftIdLib.toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            objectType,
            isInterceptor,
            address(0),
            _getAddressAtIndex(initialOwnerIdx),
            data
        );

        registerWithCustomType_testFunction(sender, info);
    }

    function testFuzz_registerWithCustomType_withZeroObjectAddress_00110(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, address initialOwner, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            NftIdLib.toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            _getObjectTypeAtIndex(objectTypeIdx),
            isInterceptor,
            address(0),
            initialOwner,
            data
        );

        registerWithCustomType_testFunction(sender, info);
    }

    function testFuzz_registerWithCustomType_withZeroObjectAddress_00111(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, uint initialOwnerIdx, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            NftIdLib.toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            _getObjectTypeAtIndex(objectTypeIdx),
            isInterceptor,
            address(0),
            _getAddressAtIndex(initialOwnerIdx),
            data
        );

        registerWithCustomType_testFunction(sender, info);
    }
}

contract RegisterWithPresetFuzzTest is RegistryTestBaseWithPreset, RegisterWithCustomTypeFuzzTest
{
    function setUp() public virtual override(RegistryTestBaseWithPreset, RegistryTestBase)
    {
        RegistryTestBaseWithPreset.setUp();
    }

    function testFuzz_registerWithCustomType_00P1000(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, bytes32 salt, address initialOwner, bytes memory data) public
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

        registerWithCustomType_testFunction(sender, info, salt);
    }

    function testFuzz_registerWithCustomType_withZeroObjectAddress_00P100(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, address initialOwner, bytes memory data) public
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

        registerWithCustomType_testFunction(sender, info);
    }
}
