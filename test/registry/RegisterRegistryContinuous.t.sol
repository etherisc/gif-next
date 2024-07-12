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

contract RegisterRegistryContinousTest is RegistryTestBase 
{
    uint constant ITTERATIONS = 150;

    function test_continuous_registerRegistry_withValidSender_000() public
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

    function test_continuous_registerRegistry_withValidSender_001() public
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

    function test_continuous_registerRegistry_withValidSender_010() public
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

    function test_continuous_registerRegistry_withValidSender_011() public
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

    function test_continuous_registerRegistry_withValidSender_100() public
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

    function test_continuous_registerRegistry_withValidSender_101() public
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

    function test_continuous_registerRegistry_withValidSender_110() public
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

    function test_continuous_registerRegistry_withValidSender_111() public
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

contract RegisterRegistryContinousTestL1 is RegisterRegistryContinousTest
{
    uint64 chainId;

    function setUp() public virtual override {
        vm.chainId(1);
        super.setUp();
    }
}

contract RegisterRegistryContinousTestL2 is RegisterRegistryContinousTest
{
    uint64 chainId;

    function setUp() public virtual override {
        vm.chainId(_getRandomChainId());
        super.setUp();
    }
}





contract RegisterRegistryWithPresetContinousTest is RegistryTestBaseWithPreset, RegisterRegistryContinousTest
{
    function setUp() public virtual override(RegistryTestBase, RegistryTestBaseWithPreset)
    {
        RegistryTestBaseWithPreset.setUp();
    }
}

contract RegisterRegistryWithPresetContinousTestL1 is RegisterRegistryWithPresetContinousTest
{
    uint64 chainId;

    function setUp() public virtual override {
        vm.chainId(1);
        super.setUp();
    }
}

contract RegisterRegistryWithPresetContinousTestL2 is RegisterRegistryWithPresetContinousTest
{
    uint64 chainId;

    function setUp() public virtual override {
        vm.chainId(_getRandomChainId());
        super.setUp();
    }
}