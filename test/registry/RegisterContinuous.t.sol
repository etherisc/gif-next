// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Test, Vm, console} from "../../lib/forge-std/src/Test.sol";
import {VersionLib, Version, VersionPart} from "../../contracts/type/Version.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {ObjectType, ObjectTypeLib, toObjectType, zeroObjectType, PROTOCOL, REGISTRY, TOKEN, SERVICE, INSTANCE, PRODUCT, POOL, ORACLE, DISTRIBUTION, BUNDLE, POLICY, STAKE} from "../../contracts/type/ObjectType.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {RegistryTestBase} from "./RegistryTestBase.sol";
import {RegistryTestBaseWithPreset} from "./RegistryTestBaseWithPreset.sol";

contract RegisterContinousTest is RegistryTestBase 
{
    uint constant ITTERATIONS = 150;

    function test_continuous_register(IRegistry.ObjectInfo memory info) public
    {
        vm.assume(
            info.initialOwner != 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D && // gives error (Invalid data) only during fuzzing when minting nft to foundry's cheatcodes contract
            info.initialOwner != 0x4e59b44847b379578588920cA78FbF26c0B4956C // Deterministic Deployment Proxy, on nft transfer callback tries Create2Deployer::create2()
        );

        // TODO register contracts with IInterceptor interface support
        info.isInterceptor = false;

        _assert_register_withChecks(info);
    }

    // nftId - always random
    // parenNftId - random
    // objectType random
    // objectAddress - random
    // isInterseptor - always random
    // initialOwner - random
    function test_continuous_register_000000() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_register(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    toNftId(randomNumber(type(uint96).max)),
                    toObjectType(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    address(uint160(randomNumber(type(uint160).max))),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                  
                )
            );
        }

        _stopPrank();
    }

    // initialOwner - from address set
    function test_continuous_register_000001() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_register(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    toNftId(randomNumber(type(uint96).max)),
                    toObjectType(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    address(uint160(randomNumber(type(uint160).max))),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    ""                  
                )
            );
        }

        _stopPrank();
    }

    function test_continuous_register_000010() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_register(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    toNftId(randomNumber(type(uint96).max)),
                    toObjectType(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                  
                )
            );
        }

        _stopPrank();
    }

    function test_continuous_register_000011() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_register(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    toNftId(randomNumber(type(uint96).max)),
                    toObjectType(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    ""                  
                )
            );
        }

        _stopPrank();
    }

    function test_continuous_register_001000() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_register(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    toNftId(randomNumber(type(uint96).max)),
                    _types[randomNumber(type(uint8).max) % _types.length],
                    toBool(randomNumber(1)),
                    address(uint160(randomNumber(type(uint160).max))),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                  
                )
            );
        }

        _stopPrank();
    }

    function test_continuous_register_001001() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_register(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    toNftId(randomNumber(type(uint96).max)),
                    _types[randomNumber(type(uint8).max) % _types.length],
                    toBool(randomNumber(1)),
                    address(uint160(randomNumber(type(uint160).max))),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    ""                  
                )
            );
        }

        _stopPrank();
    }

    function test_continuous_register_001010() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_register(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    toNftId(randomNumber(type(uint96).max)),
                    _types[randomNumber(type(uint8).max) % _types.length],
                    toBool(randomNumber(1)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                  
                )
            );
        }

        _stopPrank();
    }

    function test_continuous_register_001011() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_register(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    toNftId(randomNumber(type(uint96).max)),
                    _types[randomNumber(type(uint8).max) % _types.length],
                    toBool(randomNumber(1)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    ""                  
                )
            );
        }

        _stopPrank();
    }

    function test_continuous_register_010000() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_register(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    toNftId(EnumerableSet.at(_nftIds, randomNumber(type(uint256).max) % EnumerableSet.length(_nftIds))),
                    toObjectType(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    address(uint160(randomNumber(type(uint160).max))),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                  
                )
            );
        }

        _stopPrank();
    }

    function test_continuous_register_010001() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_register(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    toNftId(EnumerableSet.at(_nftIds, randomNumber(type(uint256).max) % EnumerableSet.length(_nftIds))),
                    toObjectType(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    address(uint160(randomNumber(type(uint160).max))),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    ""                  
                )
            );
        }

        _stopPrank();
    }
    
    function test_continuous_register_010010() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_register(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    toNftId(EnumerableSet.at(_nftIds, randomNumber(type(uint256).max) % EnumerableSet.length(_nftIds))),
                    toObjectType(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                
                )
            );
        }

        _stopPrank();
    }

    function test_continuous_register_010011() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_register(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    toNftId(EnumerableSet.at(_nftIds, randomNumber(type(uint256).max) % EnumerableSet.length(_nftIds))),
                    toObjectType(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    ""                
                )
            );
        }

        _stopPrank();
    }

    function test_continuous_register_011000() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_register(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    toNftId(EnumerableSet.at(_nftIds, randomNumber(type(uint256).max) % EnumerableSet.length(_nftIds))),
                    _types[randomNumber(type(uint8).max) % _types.length],
                    toBool(randomNumber(1)),
                    address(uint160(randomNumber(type(uint160).max))),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                  
                )
            );
        }

        _stopPrank();
    }

    function test_continuous_register_011001() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_register(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    toNftId(EnumerableSet.at(_nftIds, randomNumber(type(uint256).max) % EnumerableSet.length(_nftIds))),
                    _types[randomNumber(type(uint8).max) % _types.length],
                    toBool(randomNumber(1)),
                    address(uint160(randomNumber(type(uint160).max))),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    ""                  
                )
            );
        }

        _stopPrank();
    }

    function test_continuous_register_011010() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_register(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    toNftId(EnumerableSet.at(_nftIds, randomNumber(type(uint256).max) % EnumerableSet.length(_nftIds))),
                    _types[randomNumber(type(uint8).max) % _types.length],
                    toBool(randomNumber(1)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""           
                )
            );
        }

        _stopPrank();
    }

    function test_continuous_register_011011() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_register(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    toNftId(EnumerableSet.at(_nftIds, randomNumber(type(uint256).max) % EnumerableSet.length(_nftIds))),
                    _types[randomNumber(type(uint8).max) % _types.length],
                    toBool(randomNumber(1)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    ""                  
                )
            );
        }

        _stopPrank();
    }
}

contract RegisterWithPresetContinuousTest is RegistryTestBaseWithPreset, RegisterContinousTest
{
    function setUp() public virtual override(RegistryTestBaseWithPreset, RegistryTestBase)
    {
        RegistryTestBaseWithPreset.setUp();
    }

// TODO refactor

    // nftId - always random
    // parentNftId - from preset,
    // types - from types set
    // isInterceptor - always random
    // objectAddress - random
    // initialOwner - random
    function test_continuous_register_0P1000() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {

            test_continuous_register(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    _nftIdByType[_types[randomNumber(type(uint256).max) % _types.length]],
                    _types[randomNumber(type(uint8).max) % _types.length],
                    toBool(randomNumber(1)),
                    address(uint160(randomNumber(type(uint160).max))),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                  
                )
            );
        }

        _stopPrank();
    }

    function test_continuous_register_0P1011() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {

            test_continuous_register(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    _nftIdByType[_types[randomNumber(type(uint256).max) % _types.length]],
                    _types[randomNumber(type(uint8).max) % _types.length],
                    toBool(randomNumber(1)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    ""                  
                )
            );
        }

        _stopPrank();
    }

}