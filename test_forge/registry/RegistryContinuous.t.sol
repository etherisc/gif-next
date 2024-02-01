// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Test, Vm, console} from "../../lib/forge-std/src/Test.sol";
import {VersionLib, Version, VersionPart} from "../../contracts/types/Version.sol";
import {NftId, toNftId, zeroNftId} from "../../contracts/types/NftId.sol";
import {ObjectType, ObjectTypeLib, toObjectType, zeroObjectType, PROTOCOL, REGISTRY, TOKEN, SERVICE, INSTANCE, PRODUCT, POOL, ORACLE, DISTRIBUTION, BUNDLE, POLICY, STAKE} from "../../contracts/types/ObjectType.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {RegistryTestBase, toBool} from "./RegistryTestBase.sol";
import {RegistryTestBaseWithPreset} from "./RegistryTestBaseWithPreset.sol";

contract Registry_Continous_Tests is RegistryTestBase 
{
    uint constant ITTERATIONS = 150;

    // nftId - always random
    // parenNftId - random
    // objectType random
    // objectAddress - random
    // isInterseptor - always random
    // initialOwner - random
    function test_continuous_register_000000() public
    {
        _startPrank(address(registryService));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            _assert_register_with_default_checks(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    toNftId(randomNumber(type(uint96).max)),
                    toObjectType(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    address(uint160(randomNumber(type(uint160).max))),
                    address(uint160(randomNumber(type(uint160).max))),
                    abi.encode(_nextServiceName(), VersionLib.toVersionPart(GIF_VERSION))                  
                )
            );
        }

        // solhint-disable no-console
        console.log("Registered nfts count %s", EnumerableSet.length(_nftIds) - 1);
        console.log("Registered services count %s\n", _servicesCount);
        // solhint-enable

        _stopPrank();
    }

    // initialOwner - from address set
    function test_continuous_register_000001() public
    {
        _startPrank(address(registryService));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            _assert_register_with_default_checks(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    toNftId(randomNumber(type(uint96).max)),
                    toObjectType(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    address(uint160(randomNumber(type(uint160).max))),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    abi.encode(_nextServiceName(), VersionLib.toVersionPart(GIF_VERSION))                  
                )
            );
        }

        // solhint-disable no-console
        console.log("Registered nfts count %s", EnumerableSet.length(_nftIds) - 1);
        console.log("Registered services count %s\n", _servicesCount);
        // solhint-enable

        _stopPrank();
    }

    function test_continuous_register_000010() public
    {
        _startPrank(address(registryService));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            _assert_register_with_default_checks(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    toNftId(randomNumber(type(uint96).max)),
                    toObjectType(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    address(uint160(randomNumber(type(uint160).max))),
                    abi.encode(_nextServiceName(), VersionLib.toVersionPart(GIF_VERSION))                  
                )
            );
        }

        // solhint-disable no-console
        console.log("Registered nfts count %s", EnumerableSet.length(_nftIds) - 1);
        console.log("Registered services count %s\n", _servicesCount);
        // solhint-enable

        _stopPrank();
    }

    function test_continuous_register_000011() public
    {
        _startPrank(address(registryService));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            _assert_register_with_default_checks(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    toNftId(randomNumber(type(uint96).max)),
                    toObjectType(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    abi.encode(_nextServiceName(), VersionLib.toVersionPart(GIF_VERSION))                  
                )
            );
        }

        // solhint-disable no-console
        console.log("Registered nfts count %s", EnumerableSet.length(_nftIds) - 1);
        console.log("Registered services count %s\n", _servicesCount);
        // solhint-enable

        _stopPrank();
    }

    function test_continuous_register_001000() public
    {
        _startPrank(address(registryService));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            _assert_register_with_default_checks(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    toNftId(randomNumber(type(uint96).max)),
                    _types[randomNumber(type(uint8).max) % _types.length],
                    toBool(randomNumber(1)),
                    address(uint160(randomNumber(type(uint160).max))),
                    address(uint160(randomNumber(type(uint160).max))),
                    abi.encode(_nextServiceName(), VersionLib.toVersionPart(GIF_VERSION))                  
                )
            );
        }

        // solhint-disable no-console
        console.log("Registered nfts count %s", EnumerableSet.length(_nftIds) - 1);
        console.log("Registered services count %s\n", _servicesCount);
        // solhint-enable

        _stopPrank();
    }

    function test_continuous_register_001001() public
    {
        _startPrank(address(registryService));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            _assert_register_with_default_checks(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    toNftId(randomNumber(type(uint96).max)),
                    _types[randomNumber(type(uint8).max) % _types.length],
                    toBool(randomNumber(1)),
                    address(uint160(randomNumber(type(uint160).max))),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    abi.encode(_nextServiceName(), VersionLib.toVersionPart(GIF_VERSION))                  
                )
            );
        }

        // solhint-disable no-console
        console.log("Registered nfts count %s", EnumerableSet.length(_nftIds) - 1);
        console.log("Registered services count %s\n", _servicesCount);
        // solhint-enable

        _stopPrank();
    }

    function test_continuous_register_001010() public
    {
        _startPrank(address(registryService));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            _assert_register_with_default_checks(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    toNftId(randomNumber(type(uint96).max)),
                    _types[randomNumber(type(uint8).max) % _types.length],
                    toBool(randomNumber(1)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    address(uint160(randomNumber(type(uint160).max))),
                    abi.encode(_nextServiceName(), VersionLib.toVersionPart(GIF_VERSION))                  
                )
            );
        }

        // solhint-disable no-console
        console.log("Registered nfts count %s", EnumerableSet.length(_nftIds) - 1);
        console.log("Registered services count %s\n", _servicesCount);
        // solhint-enable

        _stopPrank();
    }

    function test_continuous_register_001011() public
    {
        _startPrank(address(registryService));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            _assert_register_with_default_checks(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    toNftId(randomNumber(type(uint96).max)),
                    _types[randomNumber(type(uint8).max) % _types.length],
                    toBool(randomNumber(1)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    abi.encode(_nextServiceName(), VersionLib.toVersionPart(GIF_VERSION))                  
                )
            );
        }

        // solhint-disable no-console
        console.log("Registered nfts count %s", EnumerableSet.length(_nftIds) - 1);
        console.log("Registered services count %s\n", _servicesCount);
        // solhint-enable

        _stopPrank();
    }

    function test_continuous_register_010000() public
    {
        _startPrank(address(registryService));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            _assert_register_with_default_checks(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    toNftId(EnumerableSet.at(_nftIds, randomNumber(type(uint256).max) % EnumerableSet.length(_nftIds))),
                    toObjectType(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    address(uint160(randomNumber(type(uint160).max))),
                    address(uint160(randomNumber(type(uint160).max))),
                    abi.encode(_nextServiceName(), VersionLib.toVersionPart(GIF_VERSION))                  
                )
            );
        }

        // solhint-disable no-console
        console.log("Registered nfts count %s", EnumerableSet.length(_nftIds) - 1);
        console.log("Registered services count %s\n", _servicesCount);
        // solhint-enable

        _stopPrank();
    }

    function test_continuous_register_010001() public
    {
        _startPrank(address(registryService));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            _assert_register_with_default_checks(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    toNftId(EnumerableSet.at(_nftIds, randomNumber(type(uint256).max) % EnumerableSet.length(_nftIds))),
                    toObjectType(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    address(uint160(randomNumber(type(uint160).max))),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    abi.encode(_nextServiceName(), VersionLib.toVersionPart(GIF_VERSION))                  
                )
            );
        }

        // solhint-disable no-console
        console.log("Registered nfts count %s", EnumerableSet.length(_nftIds) - 1);
        console.log("Registered services count %s\n", _servicesCount);
        // solhint-enable

        _stopPrank();
    }
    
    function test_continuous_register_010010() public
    {
        _startPrank(address(registryService));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            _assert_register_with_default_checks(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    toNftId(EnumerableSet.at(_nftIds, randomNumber(type(uint256).max) % EnumerableSet.length(_nftIds))),
                    toObjectType(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    address(uint160(randomNumber(type(uint160).max))),
                    abi.encode(_nextServiceName(), VersionLib.toVersionPart(GIF_VERSION))                  
                )
            );
        }

        // solhint-disable no-console
        console.log("Registered nfts count %s", EnumerableSet.length(_nftIds) - 1);
        console.log("Registered services count %s\n", _servicesCount);
        // solhint-enable

        _stopPrank();
    }

    function test_continuous_register_010011() public
    {
        _startPrank(address(registryService));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            _assert_register_with_default_checks(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    toNftId(EnumerableSet.at(_nftIds, randomNumber(type(uint256).max) % EnumerableSet.length(_nftIds))),
                    toObjectType(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    abi.encode(_nextServiceName(), VersionLib.toVersionPart(GIF_VERSION))                  
                )
            );
        }

        // solhint-disable no-console
        console.log("Registered nfts count %s", EnumerableSet.length(_nftIds) - 1);
        console.log("Registered services count %s\n", _servicesCount);
        // solhint-enable

        _stopPrank();
    }

    function test_continuous_register_011000() public
    {
        _startPrank(address(registryService));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            _assert_register_with_default_checks(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    toNftId(EnumerableSet.at(_nftIds, randomNumber(type(uint256).max) % EnumerableSet.length(_nftIds))),
                    _types[randomNumber(type(uint8).max) % _types.length],
                    toBool(randomNumber(1)),
                    address(uint160(randomNumber(type(uint160).max))),
                    address(uint160(randomNumber(type(uint160).max))),
                    abi.encode(_nextServiceName(), VersionLib.toVersionPart(GIF_VERSION))                  
                )
            );
        }

        // solhint-disable no-console
        console.log("Registered nfts count %s", EnumerableSet.length(_nftIds) - 1);
        console.log("Registered services count %s\n", _servicesCount);
        // solhint-enable

        _stopPrank();
    }

    function test_continuous_register_011001() public
    {
        _startPrank(address(registryService));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            _assert_register_with_default_checks(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    toNftId(EnumerableSet.at(_nftIds, randomNumber(type(uint256).max) % EnumerableSet.length(_nftIds))),
                    _types[randomNumber(type(uint8).max) % _types.length],
                    toBool(randomNumber(1)),
                    address(uint160(randomNumber(type(uint160).max))),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    abi.encode(_nextServiceName(), VersionLib.toVersionPart(GIF_VERSION))                  
                )
            );
        }

        // solhint-disable no-console
        console.log("Registered nfts count %s", EnumerableSet.length(_nftIds) - 1);
        console.log("Registered services count %s\n", _servicesCount);
        // solhint-enable

        _stopPrank();
    }

    function test_continuous_register_011010() public
    {
        _startPrank(address(registryService));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            _assert_register_with_default_checks(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    toNftId(EnumerableSet.at(_nftIds, randomNumber(type(uint256).max) % EnumerableSet.length(_nftIds))),
                    _types[randomNumber(type(uint8).max) % _types.length],
                    toBool(randomNumber(1)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    address(uint160(randomNumber(type(uint160).max))),
                    abi.encode(_nextServiceName(), VersionLib.toVersionPart(GIF_VERSION))                  
                )
            );
        }

        // solhint-disable no-console
        console.log("Registered nfts count %s", EnumerableSet.length(_nftIds) - 1);
        console.log("Registered services count %s\n", _servicesCount);
        // solhint-enable

        _stopPrank();
    }

    function test_continuous_register_011011() public
    {
        _startPrank(address(registryService));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            _assert_register_with_default_checks(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    toNftId(EnumerableSet.at(_nftIds, randomNumber(type(uint256).max) % EnumerableSet.length(_nftIds))),
                    _types[randomNumber(type(uint8).max) % _types.length],
                    toBool(randomNumber(1)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    abi.encode(_nextServiceName(), VersionLib.toVersionPart(GIF_VERSION))                  
                )
            );
        }

        // solhint-disable no-console
        console.log("Registered nfts count %s", EnumerableSet.length(_nftIds) - 1);
        console.log("Registered services count %s\n", _servicesCount);
        // solhint-enable

        _stopPrank();
    }
    // TODO refactor
    /*function test_continuous_register_ServiceNewVersion() public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            zeroNftId(), // any nftId
            registryNftId,
            SERVICE(),
            false, // isInterceptor
            address(uint160(randomNumber(type(uint160).max))),
            outsider, // initialOwner, any address capable to receive nft
            ""
        );  

        string memory serviceName = "SomeTestName";

        // TODO refactor
        // services may only be registered for major version == registry.getMajorVersionMax()
        // before servies can be registered for next major version registry.setMajorVersionMax needs to be called to increase major version max

        uint256 testVersionMax = type(uint8).max / 4; // because of `out of gas` error
        uint256 majorVersion = registry.getMajorVersion().toInt();

        while(majorVersion < testVersionMax)
        {
            while(EnumerableSet.contains(_registeredAddresses, info.objectAddress)) 
            {// guarantee objectAddress is fresh
                info.objectAddress = address(uint160(info.objectAddress) + 1);
            }
            // try register incredibly new version 
            info.data = abi.encode(serviceName, VersionLib.toVersionPart(type(uint8).max - majorVersion));

            _startPrank(address(registryService));

            _assert_register(
                info, 
                true, // expectRevert
                abi.encodeWithSelector(
                    IRegistry.InvalidServiceVersion.selector, 
                    VersionLib.toVersionPart(type(uint8).max - majorVersion))
            );

            // try register next version 
            info.data = abi.encode(serviceName, VersionLib.toVersionPart(majorVersion + 1));

            _assert_register(
                info, 
                true, // expectRevert
                abi.encodeWithSelector(
                    IRegistry.InvalidServiceVersion.selector, 
                    VersionLib.toVersionPart(majorVersion + 1))
            );

            info.data = abi.encode(serviceName, VersionLib.toVersionPart(majorVersion - 1));

            // try to register previous version
            _assert_register(
                info, 
                true, // expectRevert
                abi.encodeWithSelector(
                    IRegistry.InvalidServiceVersion.selector, 
                    VersionLib.toVersionPart(majorVersion - 1))
            );

            // register with current GIF major version 
            info.data = abi.encode(serviceName, VersionLib.toVersionPart(majorVersion));

            _assert_register(info, false, "");

            _stopPrank();
            _startPrank(registryOwner);

            // increase GIF major version
            majorVersion++;
            registry.setMajorVersion(VersionLib.toVersionPart(majorVersion));
            

            _stopPrank();
        }

        // solhint-disable no-console
        console.log("Registered nfts count %s", EnumerableSet.length(_nftIds) - 1);
        console.log("Registered services count %s\n", _servicesCount);
        // solhint-enable

        _stopPrank();
    }*/
}

contract RegistryWithPreset_Continuous_Tests is RegistryTestBaseWithPreset, Registry_Continous_Tests
{
    function setUp() public virtual override(RegistryTestBaseWithPreset, RegistryTestBase)
    {
        RegistryTestBaseWithPreset.setUp();
    }

    // nftId - always random
    // parentNftId - from preset,
    // types - from types set
    // isInterceptor - always random
    // objectAddress - random
    // initialOwner - random
    function test_continuous_register_0P1000() public
    {
        _startPrank(address(registryService));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {

            _assert_register_with_default_checks(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    _nftIdByType[_types[randomNumber(type(uint256).max) % _types.length]],
                    _types[randomNumber(type(uint8).max) % _types.length],
                    toBool(randomNumber(1)),
                    address(uint160(randomNumber(type(uint160).max))),
                    address(uint160(randomNumber(type(uint160).max))),
                    abi.encode(_nextServiceName(), VersionLib.toVersionPart(GIF_VERSION))                  
                )
            );
        }

        // solhint-disable no-console
        console.log("Registered nfts count %s", EnumerableSet.length(_nftIds) - 1);
        console.log("Registered services count %s\n", _servicesCount);
        // solhint-enable

        _stopPrank();
    }

    function test_continuous_register_0P1011() public
    {
        _startPrank(address(registryService));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {

            _assert_register_with_default_checks(
                IRegistry.ObjectInfo(
                    toNftId(randomNumber(type(uint96).max)),
                    _nftIdByType[_types[randomNumber(type(uint256).max) % _types.length]],
                    _types[randomNumber(type(uint8).max) % _types.length],
                    toBool(randomNumber(1)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    abi.encode(_nextServiceName(), VersionLib.toVersionPart(GIF_VERSION))                  
                )
            );
        }

        // solhint-disable no-console
        console.log("Registered nfts count %s", EnumerableSet.length(_nftIds) - 1);
        console.log("Registered services count %s\n", _servicesCount);
        // solhint-enable

        _stopPrank();
    }

}
