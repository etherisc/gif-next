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

contract RegisterRegistryContinuousTest is RegistryTestBase 
{
    uint constant ITTERATIONS = 150;

    function test_continuous_registerRegistry_0000_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            registerRegistry_testFunction(
                address(uint160(randomNumber(type(uint160).max))), // sender
                NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
                uint64(randomNumber(type(uint64).max)), // chainId
                address(uint160(randomNumber(type(uint160).max))) // registryAddress
            );
        }
    }
    // note: each itteration will fail because of 0 chainId, running this test in order to reach all possible reverts during continuous tests
    function test_continuous_registerRegistry_withValidSenerAndZeroRegistryChainId_00_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            registerRegistry_testFunction(
                gifAdmin,
                NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
                0, // chainId
                address(uint160(randomNumber(type(uint160).max))) // registryAddress
            );
        }
    }

    function test_continuous_registerRegistry_withValidSender_000_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            registerRegistry_testFunction(
                gifAdmin,
                NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
                uint64(randomNumber(type(uint64).max)), // chainId
                address(uint160(randomNumber(type(uint160).max))) // registryAddress
            );
        }
    }

    function test_continuous_registerRegistry_withValidSender_001_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            registerRegistry_testFunction(
                gifAdmin,
                NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
                uint64(randomNumber(type(uint64).max)), // chainId
                _getAddressAtIndex(randomNumber(type(uint256).max)) // registryAddress
            );
        }
    }

    function test_continuous_registerRegistry_withValidSender_010_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            registerRegistry_testFunction(
                gifAdmin,
                NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
                _getChainIdAtIndex(randomNumber(type(uint256).max)), // chainId
                address(uint160(randomNumber(type(uint160).max))) // registryAddress
            );
        }
    }

    function test_continuous_registerRegistry_withValidSender_011_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            registerRegistry_testFunction(
                gifAdmin,
                NftIdLib.toNftId(randomNumber(type(uint96).max)), // nftId
                _getChainIdAtIndex(randomNumber(type(uint256).max)), // chainId
                _getAddressAtIndex(randomNumber(type(uint256).max)) // registryAddress
            );
        }
    }

    function test_continuous_registerRegistry_withValidSender_100_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            registerRegistry_testFunction(
                gifAdmin,
                _getNftIdAtIndex(randomNumber(type(uint256).max)), // nftId
                uint64(randomNumber(type(uint64).max)), // chainId
                address(uint160(randomNumber(type(uint160).max))) // registryAddress
            );
        }
    }

    function test_continuous_registerRegistry_withValidSender_101_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            registerRegistry_testFunction(
                gifAdmin,
                _getNftIdAtIndex(randomNumber(type(uint256).max)), // nftId
                uint64(randomNumber(type(uint64).max)), // chainId
                _getAddressAtIndex(randomNumber(type(uint256).max)) // registryAddress
            );
        }
    }

    function test_continuous_registerRegistry_withValidSender_110_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            registerRegistry_testFunction(
                gifAdmin,
                _getNftIdAtIndex(randomNumber(type(uint256).max)), // nftId
                _getChainIdAtIndex(randomNumber(type(uint256).max)), // chainId
                address(uint160(randomNumber(type(uint160).max))) // registryAddress
            );
        }
    }

    function test_continuous_registerRegistry_withValidSender_111_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            registerRegistry_testFunction(
                gifAdmin,
                _getNftIdAtIndex(randomNumber(type(uint256).max)), // nftId
                _getChainIdAtIndex(randomNumber(type(uint256).max)), // chainId
                _getAddressAtIndex(randomNumber(type(uint256).max)) // registryAddress
            );
        }
    }
}

contract RegisterRegistryContinuousTestL1 is RegisterRegistryContinuousTest
{
    function setUp() public virtual override {
        vm.chainId(1);
        super.setUp();
    }
}

contract RegisterRegistryContinuousTestL2 is RegisterRegistryContinuousTest
{
    function setUp() public virtual override {
        vm.chainId(_getRandomChainId());
        super.setUp();
    }
}





contract RegisterRegistryWithPresetContinousTest is RegistryTestBaseWithPreset, RegisterRegistryContinuousTest
{
    function setUp() public virtual override(RegistryTestBase, RegistryTestBaseWithPreset)
    {
        RegistryTestBaseWithPreset.setUp();
    }
}

contract RegisterRegistryWithPresetContinousTestL1 is RegisterRegistryWithPresetContinousTest
{
    function setUp() public virtual override {
        vm.chainId(1);
        super.setUp();
    }
}

contract RegisterRegistryWithPresetContinousTestL2 is RegisterRegistryWithPresetContinousTest
{
    function setUp() public virtual override {
        vm.chainId(_getRandomChainId());
        super.setUp();
    }
}