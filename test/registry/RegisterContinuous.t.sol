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

contract RegisterContinousTest is RegistryTestBase 
{
    uint constant ITTERATIONS = 150;

    function test_continuous_register(address sender, IRegistry.ObjectInfo memory info) public
    {
        if(
            info.initialOwner == 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D || // gives error (Invalid data) only during fuzzing when minting nft to foundry's cheatcodes contract
            info.initialOwner == 0x4e59b44847b379578588920cA78FbF26c0B4956C // Deterministic Deployment Proxy, on nft transfer callback tries Create2Deployer::create2()
        )
        {
            info.initialOwner = address(uint160(uint160(info.initialOwner) + 1));
        }

        register_testFunction(sender, info);
    }

    function test_continuous_register(address sender, IRegistry.ObjectInfo memory info, bytes32 salt) public
    {
        if(
            info.initialOwner == 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D || // gives error (Invalid data) only during fuzzing when minting nft to foundry's cheatcodes contract
            info.initialOwner == 0x4e59b44847b379578588920cA78FbF26c0B4956C // Deterministic Deployment Proxy, on nft transfer callback tries Create2Deployer::create2()
        )
        {
            info.initialOwner = address(uint160(uint160(info.initialOwner) + 1));
        }

        register_testFunction(sender, info, salt);
    }

    // nftId - always random
    // parenNftId - random
    // objectType random
    // isInterceptor - always random
    // initialOwner - random
    // salt - always random
    function test_continuous_register_000000() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_register(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    ObjectTypeLib.toObjectType(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    address(0),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                  
                ),
                bytes32(randomNumber(type(uint256).max))
            );
        }
    }
    // nftId - always random
    // parenNftId - random
    // objectType random
    // isInterceptor - always random
    // initialOwner - from address set
    // salt - always random
    function test_continuous_register_000010() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_register(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    ObjectTypeLib.toObjectType(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    address(0), // mock will be created
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    ""                  
                ),
                bytes32(randomNumber(type(uint256).max))
            );
        }
    }

    // nftId - always random
    // parenNftId - random
    // objectType random
    // objectAddress - from address set
    // initialOwner - random
    function test_continuous_register_00010() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_register(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    ObjectTypeLib.toObjectType(randomNumber(type(uint8).max)),
                    false, // isInterceptor
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                  
                )
            );
        }
    }

    function test_continuous_register_00011() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_register(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    ObjectTypeLib.toObjectType(randomNumber(type(uint8).max)),
                    false, // isInterceptor
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    ""                  
                )
            );
        }
    }

    function test_continuous_register_001000() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_register(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getObjectTypeAtIndex(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    address(0), // mock will be created
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                  
                ),
                bytes32(randomNumber(type(uint256).max))
            );
        }
    }

    function test_continuous_register_001010() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_register(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getObjectTypeAtIndex(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    address(0), // mock will be created
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    ""                  
                ),
                bytes32(randomNumber(type(uint256).max))
            );
        }
    }

    function test_continuous_register_00110() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_register(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getObjectTypeAtIndex(randomNumber(type(uint8).max)),
                    false, // isInterceptor
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                  
                )
            );
        }
    }

    function test_continuous_register_00111() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_register(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getObjectTypeAtIndex(randomNumber(type(uint8).max)),
                    false, // isInterceptor
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    ""                  
                )
            );
        }
    }

    function test_continuous_register_010000() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_register(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getNftIdAtIndex(randomNumber(type(uint256).max)),
                    ObjectTypeLib.toObjectType(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    address(0), // mock will be created
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                  
                ),
                bytes32(randomNumber(type(uint256).max))
            );
        }
    }

    function test_continuous_register_010010() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_register(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getNftIdAtIndex(randomNumber(type(uint256).max)),
                    ObjectTypeLib.toObjectType(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    address(0),
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    ""                  
                ),
                bytes32(randomNumber(type(uint256).max))
            );
        }
    }
    
    function test_continuous_register_01010() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_register(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getNftIdAtIndex(randomNumber(type(uint256).max)),
                    ObjectTypeLib.toObjectType(randomNumber(type(uint8).max)),
                    false, // isInterceptor
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                
                )
            );
        }
    }

    function test_continuous_register_01011() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_register(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getNftIdAtIndex(randomNumber(type(uint256).max)),
                    ObjectTypeLib.toObjectType(randomNumber(type(uint8).max)),
                    false, // isInterceptor
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    ""                
                )
            );
        }
    }

    function test_continuous_register_011000() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_register(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getNftIdAtIndex(randomNumber(type(uint256).max)),
                    _getObjectTypeAtIndex(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    address(0),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                  
                ),
                bytes32(randomNumber(type(uint256).max))
            );
        }
    }

    function test_continuous_register_011010() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_register(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getNftIdAtIndex(randomNumber(type(uint256).max)),
                    _getObjectTypeAtIndex(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    address(0),
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    ""                  
                ),
                bytes32(randomNumber(type(uint256).max))
            );
        }
    }

    function test_continuous_register_01110() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_register(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getNftIdAtIndex(randomNumber(type(uint256).max)),
                    _getObjectTypeAtIndex(randomNumber(type(uint8).max)),
                    false, // isInterceptor
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""           
                )
            );
        }
    }

    function test_continuous_register_01111() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_register(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getNftIdAtIndex(randomNumber(type(uint256).max)),
                    _getObjectTypeAtIndex(randomNumber(type(uint8).max)),
                    false, // isInterceptor
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    ""                  
                )
            );
        }
    }
}

contract RegisterWithPresetContinuousTest is RegistryTestBaseWithPreset, RegisterContinousTest
{
    function setUp() public virtual override(RegistryTestBaseWithPreset, RegistryTestBase)
    {
        RegistryTestBaseWithPreset.setUp();
    }

    // nftId - always random
    // parentNftId - from preset,
    // types - from types set
    // isInterceptor - always random
    // initialOwner - random
    // salt - always random
    function test_continuous_register_0P1000() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_register(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _nftIdByType[randomNumber(_nftIdByType.length - 1)],
                    _getObjectTypeAtIndex(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    address(0),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                  
                ),
                bytes32(randomNumber(type(uint256).max))
            );
        }
    }

    function test_continuous_register_0P111() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_register(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _nftIdByType[randomNumber(_nftIdByType.length - 1)],
                    _getObjectTypeAtIndex(randomNumber(type(uint8).max)),
                    false, // isInterceptor
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    ""                  
                )
            );
        }
    }
}