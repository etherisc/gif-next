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

contract RegisterWithCustomTypeContinuousTest is RegistryTestBase 
{
    uint constant ITTERATIONS = 150;

    function test_continuous_registerWithCustomType(address sender, IRegistry.ObjectInfo memory info) public
    {
        if(
            info.initialOwner == 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D || // gives error (Invalid data) only during fuzzing when minting nft to foundry's cheatcodes contract
            info.initialOwner == 0x4e59b44847b379578588920cA78FbF26c0B4956C // Deterministic Deployment Proxy, on nft transfer callback tries Create2Deployer::create2()
        )
        {
            info.initialOwner = address(uint160(uint160(info.initialOwner) + 1));
        }

        registerWithCustomType_testFunction(sender, info);
    }

    function test_continuous_registerWithCustomType(address sender, IRegistry.ObjectInfo memory info, bytes32 salt) public
    {
        if(
            info.initialOwner == 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D || // gives error (Invalid data) only during fuzzing when minting nft to foundry's cheatcodes contract
            info.initialOwner == 0x4e59b44847b379578588920cA78FbF26c0B4956C // Deterministic Deployment Proxy, on nft transfer callback tries Create2Deployer::create2()
        )
        {
            info.initialOwner = address(uint160(uint160(info.initialOwner) + 1));
        }

        registerWithCustomType_testFunction(sender, info, salt);
    }

    // nftId - always random
    // parenNftId - random
    // objectType random
    // isInterceptor - always random
    // initialOwner - random
    // salt - always random
    function test_continuous_registerWithCustomType_withValidSender_000000_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerWithCustomType(
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
    function test_continuous_registerWithCustomType_withValidSender_000010_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerWithCustomType(
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
    function test_continuous_registerWithCustomType_withValidSender_00010_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerWithCustomType(
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

    function test_continuous_registerWithCustomType_withValidSender_00011_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerWithCustomType(
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

    function test_continuous_registerWithCustomType_withValidSender_001000_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerWithCustomType(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getObjectTypeAtIndex(randomNumber(type(uint256).max)),
                    toBool(randomNumber(1)),
                    address(0), // mock will be created
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                  
                ),
                bytes32(randomNumber(type(uint256).max))
            );
        }
    }

    function test_continuous_registerWithCustomType_withValidSender_001010_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerWithCustomType(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getObjectTypeAtIndex(randomNumber(type(uint256).max)),
                    toBool(randomNumber(1)),
                    address(0), // mock will be created
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    ""                  
                ),
                bytes32(randomNumber(type(uint256).max))
            );
        }
    }

    function test_continuous_registerWithCustomType_withValidSender_00110_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerWithCustomType(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getObjectTypeAtIndex(randomNumber(type(uint256).max)),
                    false, // isInterceptor
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                  
                )
            );
        }
    }

    function test_continuous_registerWithCustomType_withValidSender_00111_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerWithCustomType(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getObjectTypeAtIndex(randomNumber(type(uint256).max)),
                    false, // isInterceptor
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    ""                  
                )
            );
        }
    }

    function test_continuous_registerWithCustomType_withValidSender_010000_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerWithCustomType(
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

    function test_continuous_registerWithCustomType_withValidSender_010010_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerWithCustomType(
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
    
    function test_continuous_registerWithCustomType_withValidSender_01010_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerWithCustomType(
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

    function test_continuous_registerWithCustomType_withValidSender_01011_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerWithCustomType(
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

    function test_continuous_registerWithCustomType_withValidSender_011000_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerWithCustomType(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getNftIdAtIndex(randomNumber(type(uint256).max)),
                    _getObjectTypeAtIndex(randomNumber(type(uint256).max)),
                    toBool(randomNumber(1)),
                    address(0),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                  
                ),
                bytes32(randomNumber(type(uint256).max))
            );
        }
    }

    function test_continuous_registerWithCustomType_withValidSender_011010_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerWithCustomType(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getNftIdAtIndex(randomNumber(type(uint256).max)),
                    _getObjectTypeAtIndex(randomNumber(type(uint256).max)),
                    toBool(randomNumber(1)),
                    address(0),
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    ""                  
                ),
                bytes32(randomNumber(type(uint256).max))
            );
        }
    }

    function test_continuous_registerWithCustomType_withValidSender_01110_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerWithCustomType(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getNftIdAtIndex(randomNumber(type(uint256).max)),
                    _getObjectTypeAtIndex(randomNumber(type(uint256).max)),
                    false, // isInterceptor
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""           
                )
            );
        }
    }

    function test_continuous_registerWithCustomType_withValidSender_01111_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerWithCustomType(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getNftIdAtIndex(randomNumber(type(uint256).max)),
                    _getObjectTypeAtIndex(randomNumber(type(uint256).max)),
                    false, // isInterceptor
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    ""                  
                )
            );
        }
    }

    function test_continuous_registerWithCustomType_withValidSenderAndZeroObjectAddress_00000_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerWithCustomType(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    ObjectTypeLib.toObjectType(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    address(0),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                  
                )
            );
        }
    }

    function test_continuous_registerWithCustomType_withValidSenderAndZeroObjectAddress_00001_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerWithCustomType(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    ObjectTypeLib.toObjectType(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    address(0),
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    ""                  
                )
            );
        }
    }

    function test_continuous_registerWithCustomType_withValidSenderAndZeroObjectAddress_00100_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerWithCustomType(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getObjectTypeAtIndex(randomNumber(type(uint256).max)),
                    toBool(randomNumber(1)),
                    address(0),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                  
                )
            );
        }
    }

    function test_continuous_registerWithCustomType_withValidSenderAndZeroObjectAddress_00101_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerWithCustomType(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getObjectTypeAtIndex(randomNumber(type(uint256).max)),
                    toBool(randomNumber(1)),
                    address(0),
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    ""                  
                )
            );
        }
    }

    function test_continuous_registerWithCustomType_withValidSenderAndZeroObjectAddress_01000_longRunning() public
    {
        for(uint idx = 0; idx < 100; idx++)
        {
            test_continuous_registerWithCustomType(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getNftIdAtIndex(randomNumber(type(uint256).max)),
                    ObjectTypeLib.toObjectType(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    address(0),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                  
                )
            );
        }
    }

    function test_continuous_registerWithCustomType_withValidSenderAndZeroObjectAddress_01001_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerWithCustomType(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getNftIdAtIndex(randomNumber(type(uint256).max)),
                    ObjectTypeLib.toObjectType(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    address(0),
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    ""                  
                )
            );
        }
    }

    function test_continuous_registerWithCustomType_withValidSenderAndZeroObjectAddress_01100_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerWithCustomType(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getNftIdAtIndex(randomNumber(type(uint256).max)),
                    _getObjectTypeAtIndex(randomNumber(type(uint256).max)),
                    toBool(randomNumber(1)),
                    address(0),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                  
                )
            );
        }
    }

    function test_continuous_registerWithCustomType_withValidSenderAndZeroObjectAddress_01101_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerWithCustomType(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getNftIdAtIndex(randomNumber(type(uint256).max)),
                    _getObjectTypeAtIndex(randomNumber(type(uint256).max)),
                    toBool(randomNumber(1)),
                    address(0),
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    ""                  
                )
            );
        }
    }
}

contract RegisterWithCustomTypeContinuousTestL1 is RegisterWithCustomTypeContinuousTest
{
    function setUp() public virtual override {
        vm.chainId(1);
        super.setUp();
    }
}

contract RegisterWithCustomTypeContinuousTestL2 is RegisterWithCustomTypeContinuousTest
{
    function setUp() public virtual override {
        vm.chainId(_getRandomChainId());
        super.setUp();
    }
}



contract RegisterWithCustomTypeWithPresetContinuousTest is RegistryTestBaseWithPreset, RegisterWithCustomTypeContinuousTest
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
    function test_continuous_registerWithCustomType_withValidSender_0P1000_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerWithCustomType(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _nftIdByType[randomNumber(_nftIdByType.length - 1)],
                    _getObjectTypeAtIndex(randomNumber(type(uint256).max)),
                    toBool(randomNumber(1)),
                    address(0),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                  
                ),
                bytes32(randomNumber(type(uint256).max))
            );
        }
    }

    function test_continuous_registerWithCustomType_withValidSender_0P111_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerWithCustomType(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _nftIdByType[randomNumber(_nftIdByType.length - 1)],
                    _getObjectTypeAtIndex(randomNumber(type(uint256).max)),
                    false, // isInterceptor
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    ""                  
                )
            );
        }
    }

    function test_continuous_registerWithCustomType_withValidSenderAndZeroObjectAddress_0P100_longRunning() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerWithCustomType(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _nftIdByType[randomNumber(_nftIdByType.length - 1)],
                    _getObjectTypeAtIndex(randomNumber(type(uint256).max)),
                    toBool(randomNumber(1)),
                    address(0),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                  
                )
            );
        }
    }
}
contract RegisterWithCustomTypeWithPresetContinuousTestL1 is RegisterWithCustomTypeWithPresetContinuousTest
{
    function setUp() public virtual override {
        vm.chainId(1);
        super.setUp();
    }
}

contract RegisterWithCustomTypeWithPresetContinuousTestL2 is RegisterWithCustomTypeWithPresetContinuousTest
{
    function setUp() public virtual override {
        vm.chainId(_getRandomChainId());
        super.setUp();
    }
}