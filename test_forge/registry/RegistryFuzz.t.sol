// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin5/contracts/utils/structs/EnumerableSet.sol";

import {Test, Vm, console} from "../../lib/forge-std/src/Test.sol";
import {VersionLib, Version, VersionPart} from "../../contracts/types/Version.sol";
import {NftId, toNftId, zeroNftId} from "../../contracts/types/NftId.sol";
import {ObjectType, ObjectTypeLib, toObjectType, zeroObjectType, PROTOCOL, REGISTRY, TOKEN, SERVICE, INSTANCE, PRODUCT, POOL, ORACLE, DISTRIBUTION, BUNDLE, POLICY, STAKE} from "../../contracts/types/ObjectType.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {RegistryTestBase} from "./RegistryTestBase.sol";
import {RegistryTestBaseWithPreset} from "./RegistryTestBaseWithPreset.sol";

contract Registry_Fuzz_Tests is RegistryTestBase 
{    
    function testFuzz_register(address sender, IRegistry.ObjectInfo memory info) public
    {
        vm.assume(
            info.initialOwner != 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D && // gives error (Invalid data) only during fuzzing when minting nft to foundry's cheatcodes contract
            info.initialOwner != 0x4e59b44847b379578588920cA78FbF26c0B4956C // Deterministic Deployment Proxy, on nft transfer tries Create2Deployer::create2()
        );

        // fuzz serviceName?
        if(info.objectType == SERVICE()) {
            info.data = abi.encode("SomeTestService", VersionLib.toVersionPart(GIF_VERSION));
        } else {
            info.data = "";
        }

        _startPrank(sender);

        _assert_register_with_default_checks(info); // NotRegistryService

        _stopPrank();

        if(sender != address(registryService)) {
            _startPrank(address(registryService));

            _assert_register_with_default_checks(info);

            _stopPrank();
        }
    }

    // nftId - always random
    // parentNftId - random
    // objectType - random
    // isInterceptor - always random
    // objectAddress - random
    // initialOwner - set of addresses (actors + registered + initial owners)
    function testFuzz_register_0000001(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, address objectAddress, uint initialOwnerIdx) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            objectType,
            isInterceptor,
            objectAddress,
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            ""
        );

        testFuzz_register(sender, info);
    }

    
    function testFuzz_register_0000010(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, uint objectAddressIdx, address initialOwner) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            objectType,
            isInterceptor,
            EnumerableSet.at(_addresses, objectAddressIdx % EnumerableSet.length(_addresses)),
            initialOwner,
            ""
        );

        testFuzz_register(sender, info);
    }

    
    function testFuzz_register_0000011(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, uint objectAddressIdx, uint initialOwnerIdx) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            objectType,
            isInterceptor,
            EnumerableSet.at(_addresses, objectAddressIdx % EnumerableSet.length(_addresses)),
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            ""
        );

        testFuzz_register(sender, info);
    }

    
    function testFuzz_register_0001000(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, bool isInterceptor, address objectAddress, address initialOwner) public 
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            _types[objectTypeIdx % _types.length],
            isInterceptor,
            objectAddress,
            initialOwner,
            ""
        );

        testFuzz_register(sender, info);
    }

    
    function testFuzz_register_0001001(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, bool isInterceptor, address objectAddress, uint initialOwnerIdx) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            _types[objectTypeIdx % _types.length],
            isInterceptor,
            objectAddress,
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            ""
        );

        testFuzz_register(sender, info);
    }

    
    function testFuzz_register_0001010(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, bool isInterceptor,  uint objectAddressIdx, address initialOwner) public 
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            _types[objectTypeIdx % _types.length],
            isInterceptor,
            EnumerableSet.at(_addresses, objectAddressIdx % EnumerableSet.length(_addresses)),
            initialOwner,
            ""
        );

        testFuzz_register(sender, info);
    }

    
    function testFuzz_register_0001011(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, bool isInterceptor,  uint objectAddressIdx, uint initialOwnerIdx) public 
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            _types[objectTypeIdx % _types.length],
            isInterceptor,
            EnumerableSet.at(_addresses, objectAddressIdx % EnumerableSet.length(_addresses)),
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            ""
        );

        testFuzz_register(sender, info);
    }

    
    function testFuzz_register_0010000(address sender, NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, address objectAddress, address initialOwner) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            objectType,
            isInterceptor,
            objectAddress,
            initialOwner,
            ""
        );

        testFuzz_register(sender, info);
    }

    
    function testFuzz_register_0010001(address sender, NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, address objectAddress, uint initialOwnerIdx) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            objectType,
            isInterceptor,
            objectAddress,
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            ""
        );

        testFuzz_register(sender, info);
    }

    
    function testFuzz_register_0010010(address sender, NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, uint objectAddressIdx, address initialOwner) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            objectType,
            isInterceptor,
            EnumerableSet.at(_addresses, objectAddressIdx % EnumerableSet.length(_addresses)),
            initialOwner,
            ""
        );

        testFuzz_register(sender, info);
    }

    
    function testFuzz_register_0010011(address sender, NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, uint objectAddressIdx, uint initialOwnerIdx) public 
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            objectType,
            isInterceptor,
            EnumerableSet.at(_addresses, objectAddressIdx % EnumerableSet.length(_addresses)),
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            ""
        );

        testFuzz_register(sender, info);
    }

    
    function testFuzz_register_0011000(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, address objectAddress, address initialOwner) public 
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            _types[objectTypeIdx % _types.length],
            isInterceptor,
            objectAddress,
            initialOwner,
            ""
        );

        testFuzz_register(sender, info);
    }

    
    function testFuzz_register_0011001(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, address objectAddress, uint initialOwnerIdx) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            _types[objectTypeIdx % _types.length],
            isInterceptor,
            objectAddress,
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            ""
        );

        testFuzz_register(sender, info);
    }

    
    function testFuzz_register_0011010(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, uint objectAddressIdx, address initialOwner) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            _types[objectTypeIdx % _types.length],
            isInterceptor,
            EnumerableSet.at(_addresses, objectAddressIdx % EnumerableSet.length(_addresses)),
            initialOwner,
            ""
        );

        testFuzz_register(sender, info);
    }

    
    function testFuzz_register_0011011(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, uint objectAddressIdx, uint initialOwnerIdx) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            _types[objectTypeIdx % _types.length],
            isInterceptor,
            EnumerableSet.at(_addresses, objectAddressIdx % EnumerableSet.length(_addresses)),
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            ""
        );

        testFuzz_register(sender, info);
    }

    function testFuzz_register_zeroObjectAddress(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, address initialOwner) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            objectType,
            isInterceptor,
            address(0),
            initialOwner,
            ""
        );

        testFuzz_register(sender, info);
    }

    function testFuzz_register_zeroObjectAddress_00001(address sender, NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, uint initialOwnerIdx) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            objectType,
            isInterceptor,
            address(0),
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            ""
        );

        testFuzz_register(sender, info);
    }

    function testFuzz_register_zeroObjectAddress_00010(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, bool isInterceptor, address initialOwner) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            _types[objectTypeIdx % _types.length],
            isInterceptor,
            address(0),
            initialOwner,
            ""
        );

        testFuzz_register(sender, info);
    }

    function testFuzz_register_zeroObjectAddress_00011(address sender, NftId nftId, NftId parentNftId, uint8 objectTypeIdx, bool isInterceptor, uint initialOwnerIdx) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            parentNftId,
            _types[objectTypeIdx % _types.length],
            isInterceptor,
            address(0),
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            ""
        );

        testFuzz_register(sender, info);
    }

    function testFuzz_register_zeroObjectAddress_00100(address sender, NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, address initialOwner) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            objectType,
            isInterceptor,
            address(0),
            initialOwner,
            ""
        );

        testFuzz_register(sender, info);
    }

    function testFuzz_register_zeroObjectAddress_00101(address sender, NftId nftId, uint parentIdx, ObjectType objectType, bool isInterceptor, uint initialOwnerIdx) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            objectType,
            isInterceptor,
            address(0),
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            ""
        );

        testFuzz_register(sender, info);
    }

    function testFuzz_register_zeroObjectAddress_00110(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, address initialOwner) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            _types[objectTypeIdx % _types.length],
            isInterceptor,
            address(0),
            initialOwner,
            ""
        );

        testFuzz_register(sender, info);
    }

    function testFuzz_register_zeroObjectAddress_00111(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, uint initialOwnerIdx) public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            nftId,
            toNftId(EnumerableSet.at(_nftIds, parentIdx % EnumerableSet.length(_nftIds))),
            _types[objectTypeIdx % _types.length],
            isInterceptor,
            address(0),
            EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            ""
        );

        testFuzz_register(sender, info);
    }

    function testFuzz_register_Service(bool isInterceptor, address serviceAddress, string memory serviceName, VersionPart majorVersion) public
    {
        vm.assume(
            serviceAddress != address(0) &&
            EnumerableSet.contains(_registeredAddresses, serviceAddress) == false
        );

        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            zeroNftId(), // any nftId
            registryNftId,
            SERVICE(),
            isInterceptor,
            serviceAddress,// not zero and not registered
            outsider, // initialOwner, any address capable to receive nft
            abi.encode(serviceName, majorVersion)
        );  

        _startPrank(address(registryService));

        if(majorVersion.toInt() != GIF_VERSION) {   
            _assert_register(info, true, abi.encodeWithSelector(Registry.InvalidServiceVersion.selector, majorVersion));    
        }

        info.data = abi.encode(serviceName, VersionLib.toVersionPart(GIF_VERSION));

        _assert_register(info, false, "");

        _stopPrank();
    }

    function testFuzz_register_ServiceWithDuplicateName(bool isInterceptor, address serviceAddress, address serviceAddress_2, string memory serviceName) public
    {
        vm.assume(
            serviceAddress != address(0) &&
            serviceAddress != serviceAddress_2 &&
            EnumerableSet.contains(_registeredAddresses, serviceAddress) == false &&
            serviceAddress_2 != address(0) && 
            EnumerableSet.contains(_registeredAddresses, serviceAddress_2) == false
        );

        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            zeroNftId(), // any nftId
            registryNftId,
            SERVICE(),
            isInterceptor,
            serviceAddress,// not zero and not registered
            outsider, // initialOwner, any address capable to receive nft
            abi.encode(serviceName, VersionLib.toVersionPart(GIF_VERSION))
        );  

        _startPrank(address(registryService));

        _assert_register(info, false, "");

        info.objectAddress = serviceAddress_2;

        _assert_register(info, true, abi.encodeWithSelector(Registry.ServiceNameAlreadyRegistered.selector, serviceName, VersionLib.toVersionPart(GIF_VERSION)));

        info.data = abi.encode(serviceName, VersionLib.toVersionPart(255));

        _assert_register(info, true, abi.encodeWithSelector(Registry.InvalidServiceVersion.selector, VersionLib.toVersionPart(255)));

        info.data = abi.encode(serviceName, VersionLib.toVersionPart(GIF_VERSION + 1));

        _assert_register(info, false, "");

        _stopPrank();
    }

    function testFuzz_approve(address sender, NftId nftId, ObjectType objectType, ObjectType parentType) public
    {
        _startPrank(sender);

        _assert_approve_with_default_checks(nftId, objectType, parentType);

        _stopPrank();

        if(sender != registryOwner) {
            _startPrank(registryOwner);

            _assert_approve_with_default_checks(nftId, objectType, parentType);

            _stopPrank();
        }
    }

    
    function testFuzz_approve_0001(address sender, NftId nftId, ObjectType objectType, uint8 parentTypeIdx) public
    {
        testFuzz_approve(
            sender,
            nftId,
            objectType,
            _types[parentTypeIdx % _types.length]
        );
    }

    
    function testFuzz_approve_0010(address sender, NftId nftId, uint8 objectTypeIdx, ObjectType parentType) public
    {
        testFuzz_approve(
            sender,
            nftId,
            _types[objectTypeIdx % _types.length],
            parentType
        );
    }

    
    function testFuzz_approve_0011(address sender, NftId nftId, uint8 objectTypeIdx, uint8 parentTypeIdx) public
    {
        testFuzz_approve(
            sender,
            nftId,
            _types[objectTypeIdx % _types.length],
            _types[parentTypeIdx % _types.length]
        );
    }

    
    function testFuzz_approve_0100(address sender, uint nftIdIdx, ObjectType objectType, ObjectType parentType) public
    {
        testFuzz_approve(
            sender,
            toNftId(EnumerableSet.at(_nftIds, nftIdIdx % EnumerableSet.length(_nftIds))),
            objectType,
            parentType
        );        
    }

    
    function testFuzz_approve_0101(address sender, uint nftIdIdx, ObjectType objectType, uint8 parentTypeIdx) public
    {
        testFuzz_approve(
            sender,
            toNftId(EnumerableSet.at(_nftIds, nftIdIdx % EnumerableSet.length(_nftIds))),
            objectType,
            _types[parentTypeIdx % _types.length]
        );
    }

    
    function testFuzz_approve_0110(address sender, uint nftIdIdx, uint8 objectTypeIdx, ObjectType parentType) public
    {
        testFuzz_approve(
            sender,
            toNftId(EnumerableSet.at(_nftIds, nftIdIdx % EnumerableSet.length(_nftIds))),
            _types[objectTypeIdx % _types.length],
            parentType
        );
    }

    function testFuzz_approve_0111(address sender, uint nftIdIdx, uint8 objectTypeIdx, uint8 parentTypeIdx) public
    {
        testFuzz_approve(
            sender,
            toNftId(EnumerableSet.at(_nftIds, nftIdIdx % EnumerableSet.length(_nftIds))),
            _types[objectTypeIdx % _types.length],
            _types[parentTypeIdx % _types.length]
        );
    }

    // ALL FAILING FUZZ TESTS CASES ARE FOUND HERE 

    /*Failing tests:
    Encountered 1 failing test in test_forge/registry/Registry_fuzz.t.sol:Registry_Fuzz_Tests
    [FAIL. Reason: Call reverted as expected, but without data Counterexample: calldata=0x0x32648697000000000000000000000000000000000000000000000000000000003173bdd1000000000000000000000000000000000000000030353932450000000000000020202020202020206e667449643a203232353438353733363034303100000000000000000000000000000000000000000000000000000000000000000000009c00000000000000000000000000000000000000000000000000000000000000003b90f78db5f492600602dfe401cdad28ce22523859eeb9b27173a9222de601180000000000000000000000004e59b44847b379578588920ca78fbf26c0b4956c, 
    args=[0x000000000000000000000000000000003173BDd1, 14919623642062839888920707072 [1.491e28], 14530771982722032368798786749386477409287618435051978159066943806936604213248 [1.453e76], 156, false, 26942592595603077380690895395975204362362406466373062908592538621806708654360 [2.694e76], 0x4e59b44847b379578588920cA78FbF26c0B4956C]] 
    testFuzz_register_0010010(address,uint96,uint256,uint8,bool,uint256,address) (runs: 3113, μ: 219408, ~: 132348)
    */
    /* Deterministic Deployment Proxy
    function test_register_FuzzCase_1() public
    {
        testFuzz_register_0010010(
            0x000000000000000000000000000000003173BDd1,
            toNftId(14919623642062839888920707072),
            14530771982722032368798786749386477409287618435051978159066943806936604213248,
            toObjectType(156),
            false,
            26942592595603077380690895395975204362362406466373062908592538621806708654360,
            0x4e59b44847b379578588920cA78FbF26c0B4956C
        );
    }*/


}

contract RegistryWithPreset_Fuzz_Tests is RegistryTestBaseWithPreset, Registry_Fuzz_Tests
{
    function setUp() public virtual override(RegistryTestBaseWithPreset, RegistryTestBase)
    {
        RegistryTestBaseWithPreset.setUp();
    }
}
