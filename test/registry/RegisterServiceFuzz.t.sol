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
    function testFuzz_registerService(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, bytes32 salt, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            objectType,
            isInterceptor,
            address(0), // mock will be created
            initialOwner,
            data
        );

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

    function testFuzz_registerService_withValidSender_000000000(NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, bytes32 salt, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
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

        registerService_testFunction(address(core.releaseRegistry), info, version, domain, salt);
    }

    function testFuzz_registerService_withValidSender_000001000(NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, bytes32 salt, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
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

        registerService_testFunction(address(core.releaseRegistry), info, version, domain, salt);
    }

    function testFuzz_registerService_withValidSender_00010000(NftId nftId, NftId parentNftId, ObjectType objectType, uint objectAddressIdx, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            objectType,
            false,
            _getAddressAtIndex(objectAddressIdx),
            initialOwner,
            data
        );

        registerService_testFunction(address(core.releaseRegistry), info, version, domain);
    }

    function testFuzz_registerService_withValidSender_00011000(NftId nftId, NftId parentNftId, ObjectType objectType, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            objectType,
            false,
            _getAddressAtIndex(objectAddressIdx),
            _getAddressAtIndex(initialOwnerIdx),
            data
        );

        registerService_testFunction(address(core.releaseRegistry), info, version, domain);
    }

    function testFuzz_registerService_withValidSender_001000000(NftId nftId, NftId parentNftId, uint objectTypeIdx, bool isInterceptor, bytes32 salt, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
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

        registerService_testFunction(address(core.releaseRegistry), info, version, domain, salt);
    }

    function testFuzz_registerService_withValidSender_001001000(NftId nftId, NftId parentNftId, uint objectTypeIdx, bool isInterceptor, bytes32 salt, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
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

        registerService_testFunction(address(core.releaseRegistry), info, version, domain, salt);
    }

    function testFuzz_registerService_withValidSender_00110000(NftId nftId, NftId parentNftId, uint objectTypeIdx, uint objectAddressIdx, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
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

        registerService_testFunction(address(core.releaseRegistry), info, version, domain);
    }

    function testFuzz_registerService_withValidSender_00111000(NftId nftId, NftId parentNftId, uint objectTypeIdx, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
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

        registerService_testFunction(address(core.releaseRegistry), info, version, domain);
    }

    function testFuzz_registerService_withValidSender_010000000(NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, bytes32 salt, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
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

        registerService_testFunction(address(core.releaseRegistry), info, version, domain, salt);
    }

    function testFuzz_registerService_withValidSender_010001000(NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, bytes32 salt, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
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

        registerService_testFunction(address(core.releaseRegistry), info, version, domain, salt);
    }

    function testFuzz_registerService_withValidSender_01010000(NftId nftId, uint parentIdx, ObjectType objectType, uint objectAddressIdx, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
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

        registerService_testFunction(address(core.releaseRegistry), info, version, domain);
    }

    function testFuzz_registerService_withValidSender_01011000(NftId nftId, uint parentIdx, ObjectType objectType, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
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

        registerService_testFunction(address(core.releaseRegistry), info, version, domain);
    }

    function testFuzz_registerService_withValidSender_011000000(NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, bytes32 salt, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
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

        registerService_testFunction(address(core.releaseRegistry), info, version, domain, salt);
    }

    function testFuzz_registerService_withValidSender_011001000(NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, bytes32 salt, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
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

        registerService_testFunction(address(core.releaseRegistry), info, version, domain, salt);
    }

    function testFuzz_registerService_withValidSender_01110000(NftId nftId, uint parentIdx, uint8 objectTypeIdx, uint objectAddressIdx, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
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

        registerService_testFunction(address(core.releaseRegistry), info, version, domain);
    }

    function testFuzz_registerService_withValidSender_01111000(NftId nftId, uint parentIdx, uint8 objectTypeIdx, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
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

        registerService_testFunction(address(core.releaseRegistry), info, version, domain);
    }

    function testFuzz_registerService_withValidObjectType_000000000(address sender, NftId nftId, NftId parentNftId, bool isInterceptor, bytes32 salt, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
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

    function testFuzz_registerService_withValidObjectType_000001000(address sender, NftId nftId, NftId parentNftId, bool isInterceptor, bytes32 salt, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
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

    function testFuzz_registerService_withValidObjectType_00010000(address sender, NftId nftId, NftId parentNftId, uint objectAddressIdx, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
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

    function testFuzz_registerService_withValidObjectType_00011000(address sender, NftId nftId, NftId parentNftId, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
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

    function testFuzz_registerService_withValidObjectType_001000000(address sender, NftId nftId, uint parentIdx, bool isInterceptor, bytes32 salt, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
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

    function testFuzz_registerService_withValidObjectType_001001000(address sender, NftId nftId, uint parentIdx, bool isInterceptor, bytes32 salt, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
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

    function testFuzz_registerService_withValidObjectType_00110000(address sender, NftId nftId, uint parentIdx, uint objectAddressIdx, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
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

    function testFuzz_registerService_withValidObjectType_00111000(address sender, NftId nftId, uint parentIdx, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
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

    function testFuzz_registerService_withValidSenderAndValidObjectType_00000000(NftId nftId, NftId parentNftId, bool isInterceptor, bytes32 salt, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
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

        registerService_testFunction(address(core.releaseRegistry), info, version, domain, salt);
    }

    function testFuzz_registerService_withValidSenderAndValidObjectType_00001000(NftId nftId, NftId parentNftId, bool isInterceptor, bytes32 salt, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
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

        registerService_testFunction(address(core.releaseRegistry), info, version, domain, salt);
    }

    function testFuzz_registerService_withValidSenderAndValidObjectType_0010000(NftId nftId, NftId parentNftId, uint objectAddressIdx, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
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

        registerService_testFunction(address(core.releaseRegistry), info, version, domain);
    }

    function testFuzz_registerService_withValidSenderAndValidObjectType_0011000(NftId nftId, NftId parentNftId, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
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

        registerService_testFunction(address(core.releaseRegistry), info, version, domain);
    }

    function testFuzz_registerService_withValidSenderAndValidObjectType_01000000(NftId nftId, uint parentIdx, bool isInterceptor, bytes32 salt, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
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

        registerService_testFunction(address(core.releaseRegistry), info, version, domain, salt);
    }

    function testFuzz_registerService_withValidSenderAndValidObjectType_01001000(NftId nftId, uint parentIdx, bool isInterceptor, bytes32 salt, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
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

        registerService_testFunction(address(core.releaseRegistry), info, version, domain, salt);
    }

    function testFuzz_registerService_withValidSenderAndValidObjectType_0110000(NftId nftId, uint parentIdx, uint objectAddressIdx, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
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

        registerService_testFunction(address(core.releaseRegistry), info, version, domain);
    }

    function testFuzz_registerService_withValidSenderAndValidObjectType_0111000(NftId nftId, uint parentIdx, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
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

        registerService_testFunction(address(core.releaseRegistry), info, version, domain);
    }


    // TODO rename and fix, current implementation fails frequently with error message below
    // [FAIL. Reason: The `vm.assume` cheatcode rejected too many inputs (100 allowed)] 
    function testFuzz_registerService_withDuplicateVersionAndDomain(
        NftId nftId_1,
        address objectAddress_1, 
        address initialOwner_1,
        bytes memory data_1,
        NftId nftId_2,
        address objectAddress_2, 
        address initialOwner_2,
        bytes memory data_2,
        VersionPart version, 
        ObjectType domain
    ) 
        public
    {
        vm.assume(
            initialOwner_1 != address(0) &&
            initialOwner_2 != address(0) &&
            initialOwner_1.code.length == 0 && 
            initialOwner_2.code.length == 0 &&
            !EnumerableSet.contains(_registeredAddresses, objectAddress_1) &&
            !EnumerableSet.contains(_registeredAddresses, objectAddress_2) &&
            objectAddress_1 != address(0) &&
            objectAddress_2 != address(0) &&
            objectAddress_1 != objectAddress_2
        );

        IRegistry.ObjectInfo memory info_1 = IRegistry.ObjectInfo(
            nftId_1,
            registryNftId,
            SERVICE(),
            false,
            objectAddress_1,
            initialOwner_1,
            data_1
        );

        IRegistry.ObjectInfo memory info_2 = IRegistry.ObjectInfo(
            nftId_2,
            registryNftId,
            SERVICE(),
            false,
            objectAddress_2,
            initialOwner_2,
            data_2
        );

        while(domain.eqz() || domain.toInt() == REGISTRY().toInt()) { // already registered service domain
            domain = ObjectTypeLib.toObjectType(domain.toInt() + 1);
        }

        while(version.toInt() <= VERSION.toInt()) { // already registered service version
            version = VersionLib.toVersionPart(version.toInt() + 1);
        }

        _startPrank(address(core.releaseRegistry));

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

contract RegisterServiceFuzzTestL1 is RegisterServiceFuzzTest
{
    function setUp() public virtual override {
        vm.chainId(1);
        super.setUp();
    }
}

contract RegisterServiceFuzzTestL2 is RegisterServiceFuzzTest
{
    function setUp() public virtual override {
        vm.chainId(_getRandomChainId());
        super.setUp();
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

    function testFuzz_registerService_withValidObjectType_00P000000(address sender, NftId nftId, uint parentIdx, bool isInterceptor, bytes32 salt, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
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

    function tetsFuzz_registerService_withValidSenderAndValidObjectType_0P000000(NftId nftId, uint parentIdx, bool isInterceptor, bytes32 salt, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
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

        registerService_testFunction(address(core.releaseRegistry), info, version, domain, salt);
    }
}

contract RegisterServiceWithPresetFuzzTestL1 is RegisterServiceWithPresetFuzzTest
{
    function setUp() public virtual override {
        vm.chainId(1);
        super.setUp();
    }
}

contract RegisterServiceWithPresetFuzzTestL2 is RegisterServiceWithPresetFuzzTest
{
    function setUp() public virtual override {
        vm.chainId(_getRandomChainId());
        super.setUp();
    }
}