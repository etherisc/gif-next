// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Test, Vm, console} from "../../lib/forge-std/src/Test.sol";
import {VersionLib, Version, VersionPart} from "../../contracts/types/Version.sol";
import {NftId, toNftId, zeroNftId} from "../../contracts/types/NftId.sol";
import {ObjectType, ObjectTypeLib, toObjectType, zeroObjectType, PROTOCOL, REGISTRY, TOKEN, SERVICE, INSTANCE, PRODUCT, POOL, ORACLE, DISTRIBUTION, BUNDLE, POLICY, STAKE} from "../../contracts/types/ObjectType.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {RegistryTestBase} from "./RegistryTestBase.sol";

contract Registry_Concrete_Tests is RegistryTestBase {

    // previously failing cases 
    function test_register_specificCases() public
    {
        bytes memory data = abi.encode("TestService", VersionLib.toVersionPart(GIF_VERSION));

        _startPrank(0xb6F322D9421ae42BBbB5CC277CE23Dbb08b3aC1f);

        _assert_register_with_default_checks(
            IRegistry.ObjectInfo(
                toNftId(16158753772191290777002328881),
                toNftId(193),
                toObjectType(160),
                false, // isInterceptor
                0x9c538400FeC769e651E6552221C88A29660f0DE5,
                0x643A203932303038363435323830353333323539,
                ""                
            )
        );

        _stopPrank();
        _startPrank(address(registryService));

        // parentNftId == _chainNft.mint() && objectAddress == initialOwner
        _assert_register_with_default_checks(
            IRegistry.ObjectInfo(
                toNftId(3471),
                toNftId(43133705),
                toObjectType(128),
                false, // isInterceptor
                0x6AB133Ce3481A06313b4e0B1bb810BCD670853a4,
                0x6AB133Ce3481A06313b4e0B1bb810BCD670853a4,
                ""              
            )
        );

        // precompile address as owner
        _assert_register_with_default_checks(
            IRegistry.ObjectInfo(
                toNftId(76658180398758015949026343204),
                toNftId(17762988911415987093326017078),
                toObjectType(21),
                false, // isInterceptor
                0x85Cf4Fe71daF5271f8a5C1D4E6BB4bc91f792e27,
                0x0000000000000000000000000000000000000008,
                ""            
            )
        );

        // initialOwner is cheat codes contract address
        _assert_register_with_default_checks(
            IRegistry.ObjectInfo(
                toNftId(15842010466351085404296329522),
                toNftId(16017),
                toObjectType(19),
                false, // isInterceptor
                0x0C168C3a4589B65fFf12444A0c88125a416927DD,
                0x7109709ECfa91a80626fF3989D68f67F5b1DD12D,
                ""        
            )
        );

        _assert_register_with_default_checks(
            IRegistry.ObjectInfo(
                toNftId(0),
                toNftId(162),
                toObjectType(0),
                false, // isInterceptor
                0x733A203078373333613230333037383337333333,
                0x4e59b44847b379578588920cA78FbF26c0B4956C,
                ""        
            )
        );

        _assert_register_with_default_checks(
            IRegistry.ObjectInfo(
                toNftId(133133705),
                registryNftId,
                SERVICE(),
                false, // isInterceptor
                0x0000000000000000000000000000000000000001,
                0x6AB133Ce3481A06313b4e0B1bb810BCD670853a4,
                abi.encode("asasas", VersionLib.toVersionPart(GIF_VERSION))
            )
        );

        _stopPrank();
        _startPrank(0x0000000000000000000000000000000042966C69);

        _assert_register_with_default_checks(
            IRegistry.ObjectInfo(
                toNftId(22045),
                toNftId(EnumerableSet.at(_nftIds, 2620112370 % EnumerableSet.length(_nftIds))),
                _types[199 % _types.length],
                false, // isInterceptor
                address(0),
                0x7109709ECfa91a80626fF3989D68f67F5b1DD12D,
                ""        
            )
        );

        _stopPrank();
        _startPrank(0x000000000000000000000000000000000000185e);

        _assert_register_with_default_checks(
            IRegistry.ObjectInfo(
                toNftId(5764),
                toNftId(EnumerableSet.at(_nftIds, 1794 % EnumerableSet.length(_nftIds))),
                _types[167 % _types.length],
                false,
                address(0),
                0x7109709ECfa91a80626fF3989D68f67F5b1DD12D,
                ""        
            )
        );

        _stopPrank();
        
    }

    function test_registryOwnerNftTransfer() public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            zeroNftId(), // any nftId
            registryNftId,
            SERVICE(),
            false,
            address(uint160(randomNumber(type(uint160).max))),
            outsider, // any address capable to receive nft
            abi.encode("NewService", VersionLib.toVersionPart(GIF_VERSION))
        );

        while(EnumerableSet.contains(_registeredAddresses, info.objectAddress)) 
        {// guarantee objectAddress is fresh
            info.objectAddress = address(uint160(info.objectAddress) + 1);
        }

        bytes memory reason_NotRegistryService = abi.encodeWithSelector(IRegistry.NotRegistryService.selector);
        bytes memory reason_NotOwner = abi.encodeWithSelector(IRegistry.NotOwner.selector);

        // outsider can not register and approve 
        _startPrank(outsider);

        _assert_register(info, true, reason_NotRegistryService);

        _stopPrank();

        // registryOwner can approve only
        _startPrank(registryOwner);

        _assert_register(info, true, reason_NotRegistryService);

        chainNft.safeTransferFrom(registryOwner, outsider, registryNftId.toInt());

        // registryOwner is not owner anymore, can not register and approve
        _assert_register(info, true, reason_NotRegistryService);

        _stopPrank();

        // registryService can only register
        _startPrank(address(registryService));

        _assert_register(info, false, "");

        _stopPrank();

        // outsider is new owner, can approve only
        _startPrank(outsider);

        _assert_register(info, true, reason_NotRegistryService);

        _stopPrank();
    }

    function test_register_ServiceWithZeroMajorVersion() public
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

        while(EnumerableSet.contains(_registeredAddresses, info.objectAddress)) 
        {// guarantee objectAddress is fresh
            info.objectAddress = address(uint160(info.objectAddress) + 1);
        }

        _startPrank(address(registryService));

        for(uint8 majorVersion = 0; majorVersion < GIF_VERSION; majorVersion++)
        {
            info.data = abi.encode("SomeTestName", VersionLib.toVersionPart(majorVersion));
            _assert_register(info, true, abi.encodeWithSelector(IRegistry.InvalidServiceVersion.selector, VersionLib.toVersionPart(majorVersion)));
        }

        _stopPrank();
    }
}

