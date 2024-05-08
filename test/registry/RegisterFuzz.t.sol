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
        // solhint-disable no-console
        vm.assume(
            info.initialOwner != 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D && // gives error (Invalid data) only during fuzzing when minting nft to foundry's cheatcodes contract
            info.initialOwner != 0x4e59b44847b379578588920cA78FbF26c0B4956C // Deterministic Deployment Proxy, on nft transfer callback tries Create2Deployer::create2()
        );


        // TODO register contracts with IInterceptor interface support
        info.isInterceptor = false;

        _startPrank(sender);

        _assert_register_withChecks(info);

        _stopPrank();

        if(sender != address(registryServiceMock)) {
            _startPrank(address(registryServiceMock));

            _assert_register_withChecks(info);

            _stopPrank();
        }
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

        testFuzz_register(sender, info);
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

        testFuzz_register(sender, info);
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

        testFuzz_register(sender, info);
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

        testFuzz_register(sender, info);
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

        testFuzz_register(sender, info);
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

        testFuzz_register(sender, info);
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

        testFuzz_register(sender, info);
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

        testFuzz_register(sender, info);
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

        testFuzz_register(sender, info);
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

        testFuzz_register(sender, info);
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

        testFuzz_register(sender, info);
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

        testFuzz_register(sender, info);
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

        testFuzz_register(sender, info);
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

        testFuzz_register(sender, info);
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

        testFuzz_register(sender, info);
    }

    function testFuzz_register_zeroObjectAddress(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, address initialOwner, bytes memory data) public
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

        testFuzz_register(sender, info);
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

        testFuzz_register(sender, info);
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

        testFuzz_register(sender, info);
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

        testFuzz_register(sender, info);
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

        testFuzz_register(sender, info);
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

        testFuzz_register(sender, info);
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

        testFuzz_register(sender, info);
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

        testFuzz_register(sender, info);
    }

    // TODO cleanup or reactivate
//     function testFuzz_register_Service(bool isInterceptor, address serviceAddress, string memory serviceName, VersionPart majorVersion) public
//     {
//         vm.assume(
//             serviceAddress != address(0) &&
//             EnumerableSet.contains(_registeredAddresses, serviceAddress) == false
//         );

//         IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
//             NftIdLib.zero(), // any nftId
//             registryNftId,
//             SERVICE(),
//             isInterceptor,
//             serviceAddress,// not zero and not registered
//             outsider, // initialOwner, any address capable to receive nft
//             abi.encode(serviceName, majorVersion)
//         );  

//         _startPrank(address(registryService));

//         if(majorVersion.toInt() != GIF_VERSION) {   
//             _assert_register(info, true, abi.encodeWithSelector(IRegistry.InvalidServiceVersion.selector, majorVersion));    
//         }

//         info.data = abi.encode(serviceName, VersionLib.toVersionPart(GIF_VERSION));

//         _assert_register(info, false, "");

//         _stopPrank();
//     }

//     function testFuzz_register_ServiceWithDuplicateName(bool isInterceptor, address serviceAddress, address serviceAddress_2, string memory serviceName) public
//     {
//         vm.assume(
//             serviceAddress != address(0) &&
//             serviceAddress != serviceAddress_2 &&
//             EnumerableSet.contains(_registeredAddresses, serviceAddress) == false &&
//             serviceAddress_2 != address(0) && 
//             EnumerableSet.contains(_registeredAddresses, serviceAddress_2) == false
//         );

//         IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
//             NftIdLib.zero(), // any nftId
//             registryNftId,
//             SERVICE(),
//             isInterceptor,
//             serviceAddress,// not zero and not registered
//             outsider, // initialOwner, any address capable to receive nft
//             abi.encode(serviceName, VersionLib.toVersionPart(GIF_VERSION))
//         );  

//         _startPrank(address(registryService));

//         _assert_register(info, false, "");

//         info.objectAddress = serviceAddress_2;

//         _assert_register(info, true, abi.encodeWithSelector(IRegistry.ServiceAlreadyRegistered.selector, serviceName, VersionLib.toVersionPart(GIF_VERSION)));

//         // TODO remove or refactor registration attempts for invalid versions
//         // info.data = abi.encode(serviceName, VersionLib.toVersionPart(255));

//         // _assert_register(info, true, abi.encodeWithSelector(IRegistry.InvalidServiceVersion.selector, VersionLib.toVersionPart(255)));

//         // info.data = abi.encode(serviceName, VersionLib.toVersionPart(GIF_VERSION + 1));

//         // _assert_register(info, false, "");

//         _stopPrank();
//     }*/
}