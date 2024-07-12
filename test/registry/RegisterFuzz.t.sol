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

contract RegisterFuzzTest is RegistryTestBase 
{
    using EnumerableSet for EnumerableSet.UintSet;

    function testFuzz_register_00000000(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, bytes32 salt, address initialOwner, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            objectType,
            isInterceptor,
            address(0), // uses created with salt and random isInterceptor
            initialOwner,
            data
        );

        register_testFunction(sender, info, salt);
    }

    // sender - random
    // nftId - always random
    // parentNftId - random
    // objectType - random
    // isInterceptor - random
    // salt - always random
    // initialOwner - set of addresses (actors + registered + initial owners)
    // data - always random
    function testFuzz_register_00000010(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, bytes32 salt, uint initialOwnerIdx, bytes memory data) public
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

        register_testFunction(sender, info, salt);
    }

    // sender - random
    // nftId - always random
    // parentNftId - random
    // objectType - random
    // objectAddress - from addresses set (actors + registered + initial owners), not interceptor
    // initialOwner - random
    // data - always random
    // if objectAddress is from address set -> set isInterceptor to false
    function testFuzz_register_0000100(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, uint objectAddressIdx, address initialOwner, bytes memory data) public
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

        register_testFunction(sender, info);
    }

    
    function testFuzz_register_0000110(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data) public
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

        register_testFunction(sender, info);
    }

    
    function testFuzz_register_00010000(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, bool isInterceptor, bytes32 salt, address initialOwner, bytes memory data) public 
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

        register_testFunction(sender, info, salt);
    }

    
    function testFuzz_register_00010010(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, bool isInterceptor, bytes32 salt, uint initialOwnerIdx, bytes memory data) public
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

        register_testFunction(sender, info, salt);
    }

    
    function testFuzz_register_0001100(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, uint objectAddressIdx, address initialOwner, bytes memory data) public 
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

        register_testFunction(sender, info);
    }

    
    function testFuzz_register_0001110(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data) public 
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

        register_testFunction(sender, info);
    }

    
    function testFuzz_register_00100000(address sender, NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, bytes32 salt, address initialOwner, bytes memory data) public
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

        register_testFunction(sender, info, salt);
    }

    
    function testFuzz_register_00100010(address sender, NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, bytes32 salt, uint initialOwnerIdx, bytes memory data) public
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

        register_testFunction(sender, info, salt);
    }

    
    function testFuzz_register_0010100(address sender, NftId nftId, uint parentIdx, ObjectType objectType, uint objectAddressIdx, address initialOwner, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            _getNftIdAtIndex(parentIdx),
            objectType,
            false, // isInterceptor
            _getAddressAtIndex(objectAddressIdx),
            initialOwner,
            data
        );

        register_testFunction(sender, info);

    }

    
    function testFuzz_register_0010110(address sender, NftId nftId, uint parentIdx, ObjectType objectType, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data) public 
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            _getNftIdAtIndex(parentIdx),
            objectType,
            false, // isInterceptor
            _getAddressAtIndex(objectAddressIdx),
            _getAddressAtIndex(initialOwnerIdx),
            data
        );

        register_testFunction(sender, info);
    }

    
    function testFuzz_register_00110000(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, bytes32 salt, address initialOwner, bytes memory data) public 
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

        register_testFunction(sender, info, salt);
    }

    
    function testFuzz_register_00110010(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, bytes32 salt, uint initialOwnerIdx, bytes memory data) public
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

        register_testFunction(sender, info, salt);
    }

    
    function testFuzz_register_0011100(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, uint objectAddressIdx, address initialOwner, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            _getNftIdAtIndex(parentIdx),
            _getObjectTypeAtIndex(objectTypeIdx),
            false, // isInterceptor
            _getAddressAtIndex(objectAddressIdx),
            initialOwner,
            data
        );

        register_testFunction(sender, info);
    }

    
    function testFuzz_register_0011110(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            _getNftIdAtIndex(parentIdx),
            _getObjectTypeAtIndex(objectTypeIdx),
            false, // isInterceptor
            _getAddressAtIndex(objectAddressIdx),
            _getAddressAtIndex(initialOwnerIdx),
            data
        );

        register_testFunction(sender, info);
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

        register_testFunction(sender, info);
    }

    function testFuzz_register_withZeroObjectAddress_0000010(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, uint initialOwnerIdx, bytes memory data) public
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

        register_testFunction(sender, info);
    }

    function testFuzz_register_withZeroObjectAddress_0001000(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, bool isInterceptor, address initialOwner, bytes memory data) public
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

        register_testFunction(sender, info);
    }

    function testFuzz_register_withZeroObjectAddress_0001010(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, bool isInterceptor, uint initialOwnerIdx, bytes memory data) public
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

        register_testFunction(sender, info);
    }

    function testFuzz_register_withZeroObjectAddress_0010000(address sender, NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, address initialOwner, bytes memory data) public
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

        register_testFunction(sender, info);
    }

    function testFuzz_register_withZeroObjectAddress_0010010(address sender, NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, uint initialOwnerIdx, bytes memory data) public
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

        register_testFunction(sender, info);
    }

    function testFuzz_register_withZeroObjectAddress_00110(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, address initialOwner, bytes memory data) public
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

        register_testFunction(sender, info);
    }

    function testFuzz_register_withZeroObjectAddress_00111(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, uint initialOwnerIdx, bytes memory data) public
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

        register_testFunction(sender, info);
    }

    function testFuzz_register_withValidSender_0000000(NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, bytes32 salt, address initialOwner, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            objectType,
            isInterceptor,
            address(0), // uses created with salt and random interceptor
            initialOwner,
            data
        );

        register_testFunction(address(registryServiceMock), info, salt);
    }

    // nftId - always random
    // parentNftId - random
    // objectType - random
    // isInterceptor - random
    // salt - always random
    // initialOwner - set of addresses (actors + registered + initial owners)
    // data - always random
    function testFuzz_register_withValidSender_0000010(NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, bytes32 salt, uint initialOwnerIdx, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            objectType,
            isInterceptor,
            address(0), // uses created with salt and random interceptor
            _getAddressAtIndex(initialOwnerIdx),
            data
        );

        register_testFunction(address(registryServiceMock), info, salt);
    }

    function testFuzz_register_withValidSender_000100(NftId nftId, NftId parentNftId, ObjectType objectType, uint objectAddressIdx, address initialOwner, bytes memory data) public
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

        register_testFunction(address(registryServiceMock), info);
    }

    function testFuzz_register_withValidSender_000110(NftId nftId, NftId parentNftId, ObjectType objectType, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data) public
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

        register_testFunction(address(registryServiceMock), info);
    }

    function testFuzz_register_withValidSender_0010000(NftId nftId, NftId parentNftId, uint objectTypeIdx, bool isInterceptor, bytes32 salt, address initialOwner, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            _getObjectTypeAtIndex(objectTypeIdx),
            isInterceptor,
            address(0), // uses created with salt and random interceptor
            initialOwner,
            data
        );

        register_testFunction(address(registryServiceMock), info, salt);
    }

    function testFuzz_register_withValidSender_0010010(NftId nftId, NftId parentNftId, uint objectTypeIdx, bool isInterceptor, bytes32 salt, uint initialOwnerIdx, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            _getObjectTypeAtIndex(objectTypeIdx),
            isInterceptor,
            address(0), // uses created with salt and random interceptor
            _getAddressAtIndex(initialOwnerIdx),
            data
        );

        register_testFunction(address(registryServiceMock), info, salt);
    }

    function testFuzz_register_withValidSender_00110(NftId nftId, NftId parentNftId, uint objectTypeIdx, uint objectAddressIdx, address initialOwner, bytes memory data) public
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

        register_testFunction(address(registryServiceMock), info);
    }

    function testFuzz_register_withValidSender_00111(NftId nftId, NftId parentNftId, uint objectTypeIdx, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data) public
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

        register_testFunction(address(registryServiceMock), info);
    }

    function testFuzz_register_withValidSender_0100000(NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, bytes32 salt, address initialOwner, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            _getNftIdAtIndex(parentIdx),
            objectType,
            isInterceptor,
            address(0), // uses created with salt and random interceptor
            initialOwner,
            data
        );

        register_testFunction(address(registryServiceMock), info, salt);
    }

    function testFuzz_register_withValidSender_0100010(NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, bytes32 salt, uint initialOwnerIdx, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            _getNftIdAtIndex(parentIdx),
            objectType,
            isInterceptor,
            address(0), // uses created with salt and random interceptor
            _getAddressAtIndex(initialOwnerIdx),
            data
        );

        register_testFunction(address(registryServiceMock), info, salt);
    }

    function testFuzz_register_withValidSender_010100(NftId nftId, uint parentIdx, ObjectType objectType, uint objectAddressIdx, address initialOwner, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            _getNftIdAtIndex(parentIdx),
            objectType,
            false, // isInterceptor
            _getAddressAtIndex(objectAddressIdx),
            initialOwner,
            data
        );

        register_testFunction(address(registryServiceMock), info);
    }

    function testFuzz_register_withValidSender_010110(NftId nftId, uint parentIdx, ObjectType objectType, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            _getNftIdAtIndex(parentIdx),
            objectType,
            false, // isInterceptor
            _getAddressAtIndex(objectAddressIdx),
            _getAddressAtIndex(initialOwnerIdx),
            data
        );

        register_testFunction(address(registryServiceMock), info);
    }

    function testFuzz_register_withValidSender_0110000(NftId nftId, uint parentIdx, uint objectTypeIdx, bool isInterceptor, bytes32 salt, address initialOwner, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            _getNftIdAtIndex(parentIdx),
            _getObjectTypeAtIndex(objectTypeIdx),
            isInterceptor,
            address(0), // uses created with salt and random interceptor
            initialOwner,
            data
        );

        register_testFunction(address(registryServiceMock), info, salt);
    }

    function testFuzz_register_withValidSender_0110010(NftId nftId, uint parentIdx, uint objectTypeIdx, bool isInterceptor, bytes32 salt, uint initialOwnerIdx, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            _getNftIdAtIndex(parentIdx),
            _getObjectTypeAtIndex(objectTypeIdx),
            isInterceptor,
            address(0), // uses created with salt and random interceptor
            _getAddressAtIndex(initialOwnerIdx),
            data
        );

        register_testFunction(address(registryServiceMock), info, salt);
    }

    function testFuzz_register_withValidSender_011100(NftId nftId, uint parentIdx, uint objectTypeIdx, uint objectAddressIdx, address initialOwner, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            _getNftIdAtIndex(parentIdx),
            _getObjectTypeAtIndex(objectTypeIdx),
            false, // isInterceptor
            _getAddressAtIndex(objectAddressIdx),
            initialOwner,
            data
        );

        register_testFunction(address(registryServiceMock), info);
    }

    function testFuzz_register_withValidSender_011110(NftId nftId, uint parentIdx, uint objectTypeIdx, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            _getNftIdAtIndex(parentIdx),
            _getObjectTypeAtIndex(objectTypeIdx),
            false, // isInterceptor
            _getAddressAtIndex(objectAddressIdx),
            _getAddressAtIndex(initialOwnerIdx),
            data
        );

        register_testFunction(address(registryServiceMock), info);
    }

    function testFuzz_register_withValidSenderAndZeroObjectAddress_000000(NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, address initialOwner, bytes memory data) public
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

        register_testFunction(address(registryServiceMock), info);
    }

    function testFuzz_register_withValidSenderAndZeroObjectAddress_000010(NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, uint initialOwnerIdx, bytes memory data) public
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

        register_testFunction(address(registryServiceMock), info);
    }

    function testFuzz_register_withValidSenderAndZeroObjectAddress_001000(NftId nftId, NftId parentNftId, uint8 objectTypeIdx, bool isInterceptor, address initialOwner, bytes memory data) public
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

        register_testFunction(address(registryServiceMock), info);
    }

    function testFuzz_register_withValidSenderAndZeroObjectAddress_001010(NftId nftId, NftId parentNftId, uint8 objectTypeIdx, bool isInterceptor, uint initialOwnerIdx, bytes memory data) public
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

        register_testFunction(address(registryServiceMock), info);
    }

    function testFuzz_register_withValidSenderAndZeroObjectAddress_010000(NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, address initialOwner, bytes memory data) public
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

        register_testFunction(address(registryServiceMock), info);
    }

    function testFuzz_register_withValidSenderAndZeroObjectAddress_010010(NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, uint initialOwnerIdx, bytes memory data) public
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

        register_testFunction(address(registryServiceMock), info);
    }

    function testFuzz_register_withValidSenderAndZeroObjectAddress_011000(NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, address initialOwner, bytes memory data) public
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

        register_testFunction(address(registryServiceMock), info);
    }

    function testFuzz_register_withValidSenderAndZeroObjectAddress_011010(NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, uint initialOwnerIdx, bytes memory data) public
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

        register_testFunction(address(registryServiceMock), info);
    }

}
contract RegisterFuzzTestL1 is RegisterFuzzTest
{
    function setUp() public virtual override {
        vm.chainId(1);
        super.setUp();
    }
}

contract RegisterFuzzTestL2 is RegisterFuzzTest
{
    function setUp() public virtual override {
        vm.chainId(_getRandomChainId());
        super.setUp();
    }
}





contract RegisterWithPresetFuzzTest is RegistryTestBaseWithPreset, RegisterFuzzTest
{
    function setUp() public virtual override(RegistryTestBaseWithPreset, RegistryTestBase)
    {
        RegistryTestBaseWithPreset.setUp();
    }

    function testFuzz_register_00P10000(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, bytes32 salt, address initialOwner, bytes memory data) public
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

        register_testFunction(sender, info, salt);
    }

    function testFuzz_register_withZeroObjectAddress_00P1000(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, address initialOwner, bytes memory data) public
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

        register_testFunction(sender, info);
    }

    function testFuzz_register_withValidSenderAndZeroObjectAddress_0P1000(NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, address initialOwner, bytes memory data) public
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

        register_testFunction(address(registryServiceMock), info);
    }
}
contract RegisterWithPresetFuzzTestL1 is RegisterWithPresetFuzzTest
{
    function setUp() public virtual override {
        vm.chainId(1);
        super.setUp();
    }
}

contract RegisterWithPresetFuzzTestL2 is RegisterWithPresetFuzzTest
{
    function setUp() public virtual override {
        vm.chainId(_getRandomChainId());
        super.setUp();
    }
}
