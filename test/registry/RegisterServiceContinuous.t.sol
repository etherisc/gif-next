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


contract RegisterServiceContinousTests is RegistryTestBase 
{
    uint constant ITTERATIONS = 150;

    function test_continuous_registerService(address sender, IRegistry.ObjectInfo memory info, VersionPart version, ObjectType domain) public
    {
        if(
            info.initialOwner == 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D || // gives error (Invalid data) only during fuzzing when minting nft to foundry's cheatcodes contract
            info.initialOwner == 0x4e59b44847b379578588920cA78FbF26c0B4956C // Deterministic Deployment Proxy, on nft transfer callback tries Create2Deployer::create2()
        )
        {
            info.initialOwner = address(uint160(uint160(info.initialOwner) + 1));
        }

        registerService_testFunction(sender, info, version, domain);
    }

    function test_continuous_registerService(address sender, IRegistry.ObjectInfo memory info, VersionPart version, ObjectType domain, bytes32 salt) public
    {
        if(
            info.initialOwner == 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D || // gives error (Invalid data) only during fuzzing when minting nft to foundry's cheatcodes contract
            info.initialOwner == 0x4e59b44847b379578588920cA78FbF26c0B4956C // Deterministic Deployment Proxy, on nft transfer callback tries Create2Deployer::create2()
        )
        {
            info.initialOwner = address(uint160(uint160(info.initialOwner) + 1));
        }

        registerService_testFunction(sender, info, version, domain, salt);
    }

    // nftId - always random
    // parenNftId - random
    // objectType random
    // objectAddress - random
    // isInterseptor - always random
    // initialOwner - random
    function test_continuous_registerService_00000000() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerService(
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
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                ObjectTypeLib.toObjectType(randomNumber(type(uint8).max)),
                bytes32(randomNumber(type(uint256).max))
            );
        }
    }

    // initialOwner - from address set
    function test_continuous_registerService_00001000() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerService(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    ObjectTypeLib.toObjectType(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    address(0),
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    ""                  
                ),
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                ObjectTypeLib.toObjectType(randomNumber(type(uint8).max)),
                bytes32(randomNumber(type(uint256).max))
            );
        }
    }

    function test_continuous_registerService_0001000() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerService(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    ObjectTypeLib.toObjectType(randomNumber(type(uint8).max)),
                    false,
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                  
                ),
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                ObjectTypeLib.toObjectType(randomNumber(type(uint8).max))
            );
        }
    }

    function test_continuous_registerService_0001100() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerService(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    ObjectTypeLib.toObjectType(randomNumber(type(uint8).max)),
                    false,
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    ""                  
                ),
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                ObjectTypeLib.toObjectType(randomNumber(type(uint8).max))
            );
        }
    }

    function test_continuous_registerService_00100000() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerService(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getObjectTypeAtIndex(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    address(0),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                  
                ),
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                ObjectTypeLib.toObjectType(randomNumber(type(uint8).max)),
                bytes32(randomNumber(type(uint256).max))
            );
        }
    }

    function test_continuous_registerService_00101000() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerService(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getObjectTypeAtIndex(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    address(0),
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    ""                  
                ),
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                ObjectTypeLib.toObjectType(randomNumber(type(uint8).max)),
                bytes32(randomNumber(type(uint256).max))
            );
        }
    }

    function test_continuous_registerService_0011000() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerService(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getObjectTypeAtIndex(randomNumber(type(uint8).max)),
                    false,
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                  
                ),
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                ObjectTypeLib.toObjectType(randomNumber(type(uint8).max))
            );
        }
    }

    function test_continuous_registerService_0011100() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerService(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getObjectTypeAtIndex(randomNumber(type(uint8).max)),
                    false,
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    ""                  
                ),
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                ObjectTypeLib.toObjectType(randomNumber(type(uint8).max))
            );
        }
    }
    
    function test_continuous_registerService_01000000() public
    {
        for(uint idx = 0; idx < 100; idx++)
        {
            test_continuous_registerService(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getNftIdAtIndex(randomNumber(type(uint256).max)),
                    ObjectTypeLib.toObjectType(randomNumber(type(uint8).max)),
                    toBool(randomNumber(1)),
                    address(0),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                  
                ),
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                ObjectTypeLib.toObjectType(randomNumber(type(uint8).max)),
                bytes32(randomNumber(type(uint256).max))
            );
        }
    }

    function test_continuous_registerService_01001000() public
    {
        for(uint idx = 0; idx < 100; idx++)
        {
            test_continuous_registerService(
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
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                ObjectTypeLib.toObjectType(randomNumber(type(uint8).max)),
                bytes32(randomNumber(type(uint256).max))
            );
        }
    }
    
    function test_continuous_registerService_0101000() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerService(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getNftIdAtIndex(randomNumber(type(uint256).max)),
                    ObjectTypeLib.toObjectType(randomNumber(type(uint8).max)),
                    false,
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""                
                ),
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                ObjectTypeLib.toObjectType(randomNumber(type(uint8).max))
            );
        }
    }

    function test_continuous_registerService_0101100() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerService(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getNftIdAtIndex(randomNumber(type(uint256).max)),
                    ObjectTypeLib.toObjectType(randomNumber(type(uint8).max)),
                    false,
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    ""                
                ),
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                ObjectTypeLib.toObjectType(randomNumber(type(uint8).max))
            );
        }
    }

    function test_continuous_registerService_01100000() public
    {
        for(uint idx = 0; idx < 100; idx++)
        {
            test_continuous_registerService(
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
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                ObjectTypeLib.toObjectType(randomNumber(type(uint8).max)),
                bytes32(randomNumber(type(uint256).max))
            );
        }
    }

    function test_continuous_registerService_01101000() public
    {
        for(uint idx = 0; idx < 100; idx++)
        {
            test_continuous_registerService(
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
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                ObjectTypeLib.toObjectType(randomNumber(type(uint8).max)),
                bytes32(randomNumber(type(uint256).max))
            );
        }
    }

    function test_continuous_registerService_0111000() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerService(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getNftIdAtIndex(randomNumber(type(uint256).max)),
                    _getObjectTypeAtIndex(randomNumber(type(uint8).max)),
                    false,
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    address(uint160(randomNumber(type(uint160).max))),
                    ""           
                ),
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                ObjectTypeLib.toObjectType(randomNumber(type(uint8).max))
            );
        }
    }

    function test_continuous_registerService_0111100() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {
            test_continuous_registerService(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _getNftIdAtIndex(randomNumber(type(uint256).max)),
                    _getObjectTypeAtIndex(randomNumber(type(uint8).max)),
                    false,
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    ""                  
                ),
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                ObjectTypeLib.toObjectType(randomNumber(type(uint8).max))
            );
        }
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

        ObjectType domain = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));

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
    // registerService accepts only one object - parent combinations
    function test_continuous_registerService_0P100000() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {

            test_continuous_registerService(
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
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                ObjectTypeLib.toObjectType(randomNumber(type(uint8).max)),
                bytes32(randomNumber(type(uint256).max))
            );
        }
    }

    function test_continuous_registerService_0P11100() public
    {
        for(uint idx = 0; idx < ITTERATIONS; idx++)
        {

            test_continuous_registerService(
                address(registryServiceMock),
                IRegistry.ObjectInfo(
                    NftIdLib.toNftId(randomNumber(type(uint96).max)),
                    _nftIdByType[randomNumber(_nftIdByType.length - 1)],
                    _getObjectTypeAtIndex(randomNumber(type(uint8).max)),
                    false,
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    _getAddressAtIndex(randomNumber(type(uint256).max)),
                    ""                  
                ),
                VersionLib.toVersionPart(randomNumber(type(uint8).max)),
                ObjectTypeLib.toObjectType(randomNumber(type(uint8).max))
            );
        }
    }
}