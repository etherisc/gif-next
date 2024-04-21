// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Test, Vm, console} from "../../lib/forge-std/src/Test.sol";
import {VersionLib, Version, VersionPart} from "../../contracts/type/Version.sol";
import {NftId, toNftId, zeroNftId} from "../../contracts/type/NftId.sol";
import {ObjectType, ObjectTypeLib, toObjectType, zeroObjectType, PROTOCOL, REGISTRY, TOKEN, SERVICE, INSTANCE, PRODUCT, POOL, ORACLE, DISTRIBUTION, BUNDLE, POLICY, STAKE} from "../../contracts/type/ObjectType.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {RegistryTestBase} from "./RegistryTestBase.sol";
import {RegistryTestBaseWithPreset} from "./RegistryTestBaseWithPreset.sol";

contract RegisterServiceFuzzTest is RegistryTestBase 
{
    function testFuzz_registerService(address sender, IRegistry.ObjectInfo memory info, VersionPart version, ObjectType domain) public
    {
        vm.assume(
            info.initialOwner != 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D && // gives error (Invalid data) only during fuzzing when minting nft to foundry's cheatcodes contract
            info.initialOwner != 0x4e59b44847b379578588920cA78FbF26c0B4956C // Deterministic Deployment Proxy, on nft transfer callback tries Create2Deployer::create2()
        );

        // TODO register contracts with IInterceptor interface support
        info.isInterceptor = false;
        // release manager guarantees
        info.objectType = SERVICE();

        _startPrank(sender);

        _assert_registerService_withChecks(info, version, domain);

        _stopPrank();

        if(sender != address(releaseManager)) {
            _startPrank(address(releaseManager));

            _assert_registerService_withChecks(info, version ,domain);

            _stopPrank();
        }
    }

    // nftId - always random
    // parentNftId - random
    // objectType - random
    // isInterceptor - always random
    // objectAddress - random
    // initialOwner - set of addresses (actors + registered + initial owners)
    function testFuzz_registerService_000000100(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, address objectAddress, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
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

        testFuzz_registerService(sender, info, version, domain);
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

        testFuzz_registerService(sender, info, version, domain);
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

        testFuzz_registerService(sender, info, version, domain);
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

        testFuzz_registerService(sender, info, version, domain);
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

        testFuzz_registerService(sender, info, version, domain);
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

        testFuzz_registerService(sender, info, version, domain);
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

        testFuzz_registerService(sender, info, version, domain);
    }

    
    function testFuzz_registerService_0010000(address sender, NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, address objectAddress, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            objectType,
            isInterceptor,
            objectAddress,
            initialOwner,
            data
        );

        testFuzz_registerService(sender, info, version, domain);
    }

    
    function testFuzz_registerService_0010001(address sender, NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, address objectAddress, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            objectType,
            isInterceptor,
            objectAddress,
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            data
        );

        testFuzz_registerService(sender, info, version, domain);
    }

    
    function testFuzz_registerService_0010010(address sender, NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, uint objectAddressIdx, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            objectType,
            isInterceptor,
            EnumerableSet.at(_addresses, objectAddressIdx % EnumerableSet.length(_addresses)),
            initialOwner,
            data
        );

        testFuzz_registerService(sender, info, version, domain);
    }

    
    function testFuzz_registerService_0010011(address sender, NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public 
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            objectType,
            isInterceptor,
            EnumerableSet.at(_addresses, objectAddressIdx % EnumerableSet.length(_addresses)),
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            data
        );

        testFuzz_registerService(sender, info, version, domain);
    }

    
    function testFuzz_registerService_0011000(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, address objectAddress, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public 
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            _types[objectTypeIdx % _types.length],
            isInterceptor,
            objectAddress,
            initialOwner,
            data
        );

        testFuzz_registerService(sender, info, version, domain);
    }

    
    function testFuzz_registerService_0011001(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, address objectAddress, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            _types[objectTypeIdx % _types.length],
            isInterceptor,
            objectAddress,
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            data
        );

        testFuzz_registerService(sender, info, version, domain);
    }

    
    function testFuzz_registerService_0011010(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, uint objectAddressIdx, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            _types[objectTypeIdx % _types.length],
            isInterceptor,
            EnumerableSet.at(_addresses, objectAddressIdx % EnumerableSet.length(_addresses)),
            initialOwner,
            data
        );

        testFuzz_registerService(sender, info, version, domain);
    }

    
    function testFuzz_registerService_0011011(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, uint objectAddressIdx, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            _types[objectTypeIdx % _types.length],
            isInterceptor,
            EnumerableSet.at(_addresses, objectAddressIdx % EnumerableSet.length(_addresses)),
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            data
        );

        testFuzz_registerService(sender, info, version, domain);
    }
/*
    function testFuzz_registerService_withZeroAddress(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
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

        testFuzz_registerService(sender, info, version, domain);
    }

    function testFuzz_registerService_withZeroAddress_00001(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
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

        testFuzz_registerService(sender, info, version, domain);
    }

    function testFuzz_registerService_withZeroAddress_00010(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, bool isInterceptor, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
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

        testFuzz_registerService(sender, info, version, domain);
    }

    function testFuzz_registerService_withZeroAddress_00011(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, bool isInterceptor, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
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

        testFuzz_registerService(sender, info, version, domain);
    }

    function testFuzz_registerService_withZeroAddress_00100(address sender, NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            objectType,
            isInterceptor,
            address(0),
            initialOwner,
            data
        );

        testFuzz_registerService(sender, info, version, domain);
    }

    function testFuzz_registerService_withZeroAddress_00101(address sender, NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            objectType,
            isInterceptor,
            address(0),
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            data
        );

        testFuzz_registerService(sender, info, version, domain);
    }

    function testFuzz_registerService_withZeroAddress_00110(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, address initialOwner, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            _types[objectTypeIdx % _types.length],
            isInterceptor,
            address(0),
            initialOwner,
            data
        );

        testFuzz_registerService(sender, info, version, domain);
    }

    function testFuzz_registerService_withZeroAddress_00111(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, uint initialOwnerIdx, bytes memory data, VersionPart version, ObjectType domain) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            _types[objectTypeIdx % _types.length],
            isInterceptor,
            address(0),
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            data
        );

        testFuzz_registerService(sender, info, version, domain);
    }
*/
    function testFuzz_registerService_withDuplicateVersonAndDomain(
        NftId serviceNftId_1,
        bool isInterceptor_1,
        address serviceAddress_1,
        address serviceOwner_1,
        bytes memory data_1,
        NftId serviceNftId_2,
        address serviceAddress_2,
        address serviceOwner_2,
        bytes memory data_2,
        VersionPart version, 
        ObjectType domain
    ) public
    {
        vm.assume(
            serviceAddress_1 != serviceAddress_2 &&
            serviceAddress_1 != address(0) &&
            serviceAddress_2 != address(0) &&
            address(serviceOwner_1).codehash == 0 && // can receive nft
            address(serviceOwner_2).codehash == 0 &&
            address(serviceOwner_1) != address(0) &&
            address(serviceOwner_2) != address(0) &&
            !EnumerableSet.contains(_registeredAddresses, serviceAddress_1) &&
            !EnumerableSet.contains(_registeredAddresses, serviceAddress_2) &&
            !EnumerableSet.contains(_registeredAddresses, serviceOwner_1) &&
            !EnumerableSet.contains(_registeredAddresses, serviceOwner_2) &&
            domain.gtz()
        );

        IRegistry.ObjectInfo memory info_1 = IRegistry.ObjectInfo(
            serviceNftId_1,
            registryNftId,
            SERVICE(),
            false, //test.isInterceptor_1 // TODO make random
            serviceAddress_1,// not zero and not registered
            serviceOwner_1, // initialOwner, any address capable to receive nft
            data_1
        );

        IRegistry.ObjectInfo memory info_2 = IRegistry.ObjectInfo(
            serviceNftId_2,
            registryNftId,
            SERVICE(),
            false, //test.isInterceptor_2 // TODO make random
            serviceAddress_2,// not zero and not registered
            serviceOwner_2, // initialOwner, any address capable to receive nft
            data_2
        );

        _startPrank(address(releaseManager));

        _assert_registerService(info_1, version, domain, false, "");

        _assert_registerService(
            info_2,
            version,
            domain,
            true, 
            abi.encodeWithSelector(
                IRegistry.ErrorRegistryDomainAlreadyRegistered.selector,
                serviceAddress_2,
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
}