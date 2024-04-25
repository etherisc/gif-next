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

contract RegisterServiceContinousTests is RegistryTestBase 
{
    uint constant ITTERATIONS = 150;

    function test_continuous_registerService(IRegistry.ObjectInfo memory info, VersionPart version, ObjectType domain) public
    {
        vm.assume(
            info.initialOwner != 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D && // gives error (Invalid data) only during fuzzing when minting nft to foundry's cheatcodes contract
            info.initialOwner != 0x4e59b44847b379578588920cA78FbF26c0B4956C // Deterministic Deployment Proxy, on nft transfer callback tries Create2Deployer::create2()
        );

        // TODO register contracts with IInterceptor interface support
        info.isInterceptor = false;
        // release manager guarantees
        info.objectType = SERVICE();


        _assert_registerService_withChecks(info, version, domain);
    }

    // nftId - always random
    // parenNftId - random
    // objectType random
    // objectAddress - random
    // isInterseptor - always random
    // initialOwner - random
    function test_continuous_registerService_000000() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerService(
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    toObjectType(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    address(uint160(randomNumber(type(uint160).max))),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                  
                ),
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                toObjectType(randomNumber(type(uint8).max))
            );
        }

        _stopPrank();
    }

    // initialOwner - from address set
    function test_continuous_registerService_000001() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerService(
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    toObjectType(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    address(uint160(randomNumber(type(uint160).max))),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    ""                  
                ),
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                toObjectType(randomNumber(type(uint8).max))
            );
        }

        _stopPrank();
    }

    function test_continuous_registerService_000010() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerService(
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    toObjectType(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                  
                ),
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                toObjectType(randomNumber(type(uint8).max))
            );
        }

        _stopPrank();
    }

    function test_continuous_registerService_000011() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerService(
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    toObjectType(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    ""                  
                ),
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                toObjectType(randomNumber(type(uint8).max))
            );
        }

        _stopPrank();
    }

    function test_continuous_registerService_001000() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerService(
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _types[randomNumber(type(uint8).max) % _types.length],
                    toBool(randomNumber(1)),
                    address(uint160(randomNumber(type(uint160).max))),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                  
                ),
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                toObjectType(randomNumber(type(uint8).max))
            );
        }

        _stopPrank();
    }

    function test_continuous_registerService_001001() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerService(
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _types[randomNumber(type(uint8).max) % _types.length],
                    toBool(randomNumber(1)),
                    address(uint160(randomNumber(type(uint160).max))),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    ""                  
                ),
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                toObjectType(randomNumber(type(uint8).max))
            );
        }

        _stopPrank();
    }

    function test_continuous_registerService_001010() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerService(
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _types[randomNumber(type(uint8).max) % _types.length],
                    toBool(randomNumber(1)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                  
                ),
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                toObjectType(randomNumber(type(uint8).max))
            );
        }

        _stopPrank();
    }

    function test_continuous_registerService_001011() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerService(
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _types[randomNumber(type(uint8).max) % _types.length],
                    toBool(randomNumber(1)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    ""                  
                ),
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                toObjectType(randomNumber(type(uint8).max))
            );
        }

        _stopPrank();
    }

    function test_continuous_registerService_010000() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerService(
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(EnumerableSet.at(_nftIds, randomNumber(type(uint256).max) % EnumerableSet.length(_nftIds))),
                    toObjectType(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    address(uint160(randomNumber(type(uint160).max))),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                  
                ),
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                toObjectType(randomNumber(type(uint8).max))
            );
        }

        _stopPrank();
    }

    function test_continuous_registerService_010001() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerService(
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(EnumerableSet.at(_nftIds, randomNumber(type(uint256).max) % EnumerableSet.length(_nftIds))),
                    toObjectType(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    address(uint160(randomNumber(type(uint160).max))),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    ""                  
                ),
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                toObjectType(randomNumber(type(uint8).max))
            );
        }

        _stopPrank();
    }
    
    function test_continuous_registerService_010010() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerService(
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(EnumerableSet.at(_nftIds, randomNumber(type(uint256).max) % EnumerableSet.length(_nftIds))),
                    toObjectType(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                
                ),
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                toObjectType(randomNumber(type(uint8).max))
            );
        }

        _stopPrank();
    }

    function test_continuous_registerService_010011() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerService(
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(EnumerableSet.at(_nftIds, randomNumber(type(uint256).max) % EnumerableSet.length(_nftIds))),
                    toObjectType(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    ""                
                ),
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                toObjectType(randomNumber(type(uint8).max))
            );
        }

        _stopPrank();
    }

    function test_continuous_registerService_011000() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerService(
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(EnumerableSet.at(_nftIds, randomNumber(type(uint256).max) % EnumerableSet.length(_nftIds))),
                    _types[randomNumber(type(uint8).max) % _types.length],
                    toBool(randomNumber(1)),
                    address(uint160(randomNumber(type(uint160).max))),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                  
                ),
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                toObjectType(randomNumber(type(uint8).max))
            );
        }

        _stopPrank();
    }

    function test_continuous_registerService_011001() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerService(
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(EnumerableSet.at(_nftIds, randomNumber(type(uint256).max) % EnumerableSet.length(_nftIds))),
                    _types[randomNumber(type(uint8).max) % _types.length],
                    toBool(randomNumber(1)),
                    address(uint160(randomNumber(type(uint160).max))),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    ""                  
                ),
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                toObjectType(randomNumber(type(uint8).max))
            );
        }

        _stopPrank();
    }

    function test_continuous_registerService_011010() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerService(
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(EnumerableSet.at(_nftIds, randomNumber(type(uint256).max) % EnumerableSet.length(_nftIds))),
                    _types[randomNumber(type(uint8).max) % _types.length],
                    toBool(randomNumber(1)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""           
                ),
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                toObjectType(randomNumber(type(uint8).max))
            );
        }

        _stopPrank();
    }

    function test_continuous_registerService_011011() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerService(
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(EnumerableSet.at(_nftIds, randomNumber(type(uint256).max) % EnumerableSet.length(_nftIds))),
                    _types[randomNumber(type(uint8).max) % _types.length],
                    toBool(randomNumber(1)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    ""                  
                ),
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                toObjectType(randomNumber(type(uint8).max))
            );
        }

        _stopPrank();
    }

/* MOVE to release manager tests
    function test_continuous_registerServiceNewVersion() public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            NftIdLib.zero(), // any nftId
            registryNftId,
            SERVICE(),
            false, // isInterceptor
            address(uint160(randomNumber(type(uint160).max))),
            outsider, // initialOwner, any address capable to receive nft
            ""
        );  

        ObjectType domain = toObjectType(randomNumber(type(uint8).max));

        // TODO refactor
        // services may only be registered for major version == registry.getMajorVersionMax()
        // before servies can be registered for next major version registry.setMajorVersionMax needs to be called to increase major version max

        uint256 testVersionMax = type(uint8).max / 4; // because of `out of gas` error
        uint256 version = registry.getLatestVersion().toInt();

        while(version < testVersionMax)
        {
            while(EnumerableSet.contains(_registeredAddresses, info.objectAddress)) 
            {// guarantee objectAddress is fresh
                info.objectAddress = address(uint160(info.objectAddress) + 1);
            }

            _startPrank(address(registryServiceMock));

            _assert_registerService(
                info,
                VersionLib.toVersionPart(type(uint8).max - version),// try register incredibly new version 
                domain, 
                true, // expectRevert
                abi.encodeWithSelector(
                    IRegistry.InvalidServiceVersion.selector, 
                    VersionLib.toVersionPart(type(uint8).max - majorVersion))
            );


            _assert_registerService(
                info,
                VersionLib.toVersionPart(majorVersion + 1),// try register next version 
                domain,
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
    }
*/
}

contract RegisterServiceWithPresetContinuousTests is RegistryTestBaseWithPreset, RegisterServiceContinousTests
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
    function test_continuous_registerService_0P1000() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {

            test_continuous_registerService(
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _nftIdByType[_types[randomNumber(type(uint256).max) % _types.length]],
                    _types[randomNumber(type(uint8).max) % _types.length],
                    toBool(randomNumber(1)),
                    address(uint160(randomNumber(type(uint160).max))),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                  
                ),
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                toObjectType(randomNumber(type(uint8).max))
            );
        }

        _stopPrank();
    }

    function test_continuous_registerService_0P1011() public
    {
        _startPrank(address(registryServiceMock));

        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {

            test_continuous_registerService(
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _nftIdByType[_types[randomNumber(type(uint256).max) % _types.length]],
                    _types[randomNumber(type(uint8).max) % _types.length],
                    toBool(randomNumber(1)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    EnumerableSet.at(_addresses, randomNumber(type(uint256).max) % EnumerableSet.length(_addresses)),
                    ""                  
                ),
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                toObjectType(randomNumber(type(uint8).max))
            );
        }

        _stopPrank();
    }
}