// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {VersionLib, VersionPart, VersionPartLib} from "../../contracts/type/Version.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {ObjectType, ObjectTypeLib, SERVICE} from "../../contracts/type/ObjectType.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";

import {RegistryTestBase} from "./RegistryTestBase.sol";
import {RegistryTestBaseWithPreset} from "./RegistryTestBaseWithPreset.sol";
import {RegisterServiceFuzzTest} from "./RegisterServiceFuzz.t.sol";

contract RegisterServiceConcreteTest is RegistryTestBase {

    // previously failing cases 
    function test_registeService_specificCase_1() public
    {
        _startPrank(0x8Ae8b867cAa4B9ee8ee24323D8b809b692507e54);

        _assert_registerService_withChecks(
            IRegistry.ObjectInfo(
                NftIdLib.toNftId(10017),
                NftIdLib.toNftId(353073667),
                ObjectTypeLib.toObjectType(35),
                false, // isInterceptor
                address(2072),
                address(162012514),
                ""                
            ),
            VersionLib.toVersionPart(22),
            ObjectTypeLib.toObjectType(244)
        );

        _stopPrank();
    }

    function test_registeService_specificCase_2() public
    {
        _startPrank(0x8Ae8b867cAa4B9ee8ee24323D8b809b692507e54);

        _assert_registerService_withChecks(
            IRegistry.ObjectInfo(
                NftIdLib.toNftId(10017),
                NftIdLib.toNftId(353073667),
                ObjectTypeLib.toObjectType(35),
                false, // isInterceptor
                address(0),
                address(2072),
                ""                
            ),
            VersionLib.toVersionPart(98),
            ObjectTypeLib.toObjectType(22)
        );

        _stopPrank();
    }

    function test_registeService_specificCase_3() public
    {
        _startPrank(0x8Ae8b867cAa4B9ee8ee24323D8b809b692507e54);

        _assert_registerService_withChecks(
            IRegistry.ObjectInfo(
                NftIdLib.toNftId(7505),
                NftIdLib.toNftId(11674931516840186165219379815826254658548193973),
                ObjectTypeLib.toObjectType(173),
                false, // isInterceptor
                address(7148),
                address(0x00000000000000000000000000000000000000000000000000000000fdd9ec7e),
                ""                
            ),
            VersionLib.toVersionPart(172),
            ObjectTypeLib.toObjectType(185)
        );

        _stopPrank();
    }

    function test_registeService_specificCase_4() public
    {
        _startPrank(0x8Ae8b867cAa4B9ee8ee24323D8b809b692507e54);

        _assert_registerService_withChecks(
            IRegistry.ObjectInfo(
                NftIdLib.toNftId(12537),
                NftIdLib.toNftId(6191),
                ObjectTypeLib.toObjectType(100),
                false, // isInterceptor
                address(16382),
                address(0x0000000000000000000000000000000000000000000000000000000000002181),
                ""                
            ),
            VersionLib.toVersionPart(178),
            ObjectTypeLib.toObjectType(44)
        );

        _stopPrank();
    }

    function test_registeService_specificCase_5() public
    {
        _startPrank(0x8Ae8b867cAa4B9ee8ee24323D8b809b692507e54);

        _assert_registerService_withChecks(
            IRegistry.ObjectInfo(
                NftIdLib.toNftId(3590),
                NftIdLib.toNftId(158),
                ObjectTypeLib.toObjectType(220),
                false, // isInterceptor
                address(0x0000000000000000000000000000000000001eF1),
                address(0x000000000000000000000000000000000000000000000000000000000000441c),
                ""                
            ),
            VersionLib.toVersionPart(63),
            ObjectTypeLib.toObjectType(99)
        );

        _stopPrank();
    }

    function test_registerService_specificCases_6() public
    {
        // args=[0x0000000000000000000000000000000000001262, 11159 [1.115e4], 2099035519 [2.099e9], 148, true, 0x000000000000000000000000000000007e273289, 804448731 [8.044e8], 0x00000000000000000000000000000000000000000000000000000000000026a3, 115, 250]] 
        // testFuzz_registerService_0011001(address,uint96,uint256,uint8,bool,address,uint256,bytes,uint8,uint8) (runs: 2, μ: 73578, ~: 73578)

        _startPrank(address(core.releaseRegistry));

        _assert_registerService_withChecks(IRegistry.ObjectInfo(
            NftIdLib.toNftId(11159),
            NftIdLib.toNftId(EnumerableSet.at(_nftIds, 2099035519 % EnumerableSet.length(_nftIds))),
            SERVICE(),//_types[148 % _types.length],
            false,
            address(0x000000000000000000000000000000007e273289),
            EnumerableSet.at(_addresses, 804448731 % EnumerableSet.length(_addresses)),
            "0x00000000000000000000000000000000000000000000000000000000000026a3"),
            VersionLib.toVersionPart(115),
            ObjectTypeLib.toObjectType(250)
        );

        _stopPrank();
    }
    
    function test_registerService_specificCases_7() public
    {
        //args=[0x0000000000000000000000000000000000000000, 0, 3, 45, false, 0x0000000000000000000000000000000000000001, 0x0000000000000000000000000000000000000001, 0x]] 
        //testFuzz_register_0010000(address,uint96,uint256,uint8,bool,address,address,bytes)

        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            NftIdLib.toNftId(14642),
            NftIdLib.toNftId(43133705),
            SERVICE(),
            false,
            address(0x00000000000000000000000000000000000034dD),
            EnumerableSet.at(_addresses, 7194 % EnumerableSet.length(_addresses)),// address(uint160(uint(7194))),//EnumerableSet.at(_addresses, initialOwnerIdx % EnumerableSet.length(_addresses)),
            "0x000000000000000000000000000000000000000000000000000000000000285d"
        );

        VersionPart version = VersionLib.toVersionPart(115);
        ObjectType domain = ObjectTypeLib.toObjectType(250);
        address sender = address(0x000000000000000000000000000000005FA4428e);

        registerService_testFunction(sender, info, version, domain);
    }

    function test_registerService_specificCases_8() public
    {
        // args=[0x4Dc593023536B7b8c4f254893f3bCA460c45EF8B, ObjectInfo({ nftId: 27734615690662410822268275 [2.773e25], parentNftId: 915066191401421401 [9.15e17], objectType: 0, isInterceptor: true, objectAddress: 0x24E9ffB8B924aA3d30e8F701Cd33f15C871cC8AC, initialOwner: 0xB3d21d1a92C4d65A6b878facf5dB1fB422199394, data: 0x0a24f63bcf984404134eb0867bed5c4b0a1675ba2da124de18a0897e460b5c22b635957e19b24af75a006242e9aeff5144f9cc9ec2f04a17278dafa058e2086f3d1e9ca393607a2b6632ec055e3db2 }), 8, 254]]
        // testFuzz_registerService(address sender, IRegistry.ObjectInfo memory info, VersionPart version, ObjectType domain)

        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            NftIdLib.toNftId(27734615690662410822268275),
            NftIdLib.toNftId(915066191401421401),
            ObjectTypeLib.toObjectType(0),
            true,
            address(0x24E9ffB8B924aA3d30e8F701Cd33f15C871cC8AC),
            address(0xB3d21d1a92C4d65A6b878facf5dB1fB422199394),
            "0x0a24f63bcf984404134eb0867bed5c4b0a1675ba2da124de18a0897e460b5c22b635957e19b24af75a006242e9aeff5144f9cc9ec2f04a17278dafa058e2086f3d1e9ca393607a2b6632ec055e3db2"
        );

        VersionPart version = VersionLib.toVersionPart(8);
        ObjectType domain = ObjectTypeLib.toObjectType(254);
        address sender = address(0x4Dc593023536B7b8c4f254893f3bCA460c45EF8B);

        registerService_testFunction(sender, info, version, domain);
    }

    function test_registerService_withDuplicateVersionAndDomain_specificCase() public
    {
        // args=[ObjectInfo({ nftId: 58320260334610590964687536414 [5.832e28], parentNftId: 23060 [2.306e4], objectType: 7, isInterceptor: false, objectAddress: 0x35EEEF71D74d608fe53AB0d76CF84F261a2B81E5, initialOwner: 0x000000000000000000000000000000001641c88f, data: 0x0000000000000000000000000000000000000000000000000000000000000f7b }), ObjectInfo({ nftId: 129, parentNftId: 1148, objectType: 181, isInterceptor: true, objectAddress: 0x0000000000000000000000000000000000001C12, initialOwner: 0x00000000000000000000000000000000000017c5, data: 0x000000000000000000000000000000000000000000000000000000002255341b }), 224, 27]] 
        // testFuzz_registerService_withDuplicateVersionAndDomain((uint96,uint96,uint8,bool,address,address,bytes),(uint96,uint96,uint8,bool,address,address,bytes),uint8,uint8)


        // TODO use this parameters
        // args=[17933918450742370540801522842 [1.793e28], 0x8e66961A6eFe5853ef595cC12A1f3e1b1d961EfE, 0x0000000000000000000000000000000000000000000000000000000000002c4a, 14677 [1.467e4], 0x000000000000000000000000000000000000160f, 0x0000000000000000000000000000000000000000000000000000000000003fee, 70, 250]] 


        IRegistry.ObjectInfo memory info_1 = IRegistry.ObjectInfo(
            NftIdLib.toNftId(58320260334610590964687536414),
            NftIdLib.toNftId(23060),
            ObjectTypeLib.toObjectType(7),
            false,
            address(0x35eeeF71d74d608fE53Ab0d76cf84F261a2b81E6),
            address(0x000000000000000000000000000000001641c88f),
            "0x0000000000000000000000000000000000000000000000000000000000000f7b"
        );

        IRegistry.ObjectInfo memory info_2 = IRegistry.ObjectInfo(
            NftIdLib.toNftId(129),
            NftIdLib.toNftId(1148),
            ObjectTypeLib.toObjectType(181),
            true,
            address(0x0000000000000000000000000000000000001C12),
            address(0x00000000000000000000000000000000000017c5),
            "0x000000000000000000000000000000000000000000000000000000002255341b"
        );

        VersionPart version = VersionLib.toVersionPart(224);
        ObjectType domain = ObjectTypeLib.toObjectType(27);


        info_1.parentNftId = registryNftId;
        info_1.objectType = SERVICE();
        info_1.isInterceptor = false;

        info_2.parentNftId = registryNftId;
        info_2.objectType = SERVICE();
        info_2.isInterceptor = false;


        _startPrank(address(core.releaseRegistry));

        _assert_registerService(info_1, version, domain, false, "");

        _assert_registerService(
            info_2,
            version,
            domain,
            true, 
            abi.encodeWithSelector(
                IRegistry.ErrorRegistryDomainAlreadyRegistered.selector,
                info_2.objectAddress,
                version,
                domain)
        );

        _stopPrank();

    }

    function test_registerService_withRegisteredChainRegistryAddress() public
    {
        uint64 chainId = _getNotRegisteredRandomChainId();
        address chainRegistryAddress = _getRandomNotRegisteredAddress();
        NftId chainRegistryNftId = NftIdLib.toNftId(core.chainNft.calculateTokenId(core.registry.REGISTRY_TOKEN_SEQUENCE_ID(), chainId));

        // register chain registry
        _startPrank(gifAdmin);

        _assert_registerRegistry(
            chainRegistryNftId,
            chainId,
            chainRegistryAddress,
            false,
            ""
        );

        _stopPrank();

        // register service
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            NftIdLib.toNftId(randomNumber(type(uint96).max)),
            registryNftId,
            SERVICE(),
            false, // isInterceptor
            chainRegistryAddress,
            _getRandomNotRegisteredAddress(),
            "0xd65a6b878facf5db1fb422199394c9190a24f63bcf984404134eb0867bed5c4b0a1675ba2da124de18a0897e460b5c22b635957e19b24af75a006242e9aeff5144f9cc9ec2f04a17278dafa058"
        );

        VersionPart version = VersionLib.toVersionPart(13);
        ObjectType domain = ObjectTypeLib.toObjectType(8);

        _startPrank(address(core.releaseRegistry));

        _assert_registerService(
            info, 
            version, 
            domain,
            true,
            abi.encodeWithSelector(
                IRegistry.ErrorRegistryContractAlreadyRegistered.selector,
                chainRegistryAddress
            )
        );

        _stopPrank();
    }

    // TODO move to release manager tests
    /*function test_register_ServiceWithZeroMajorVersion() public
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

        _startPrank(address(registryServiceMock));

        for(uint8 majorVersion = 0; majorVersion < GIF_VERSION; majorVersion++)
        {
            info.data = abi.encode("SomeTestName", VersionLib.toVersionPart(majorVersion));
            _assert_register(info, true, abi.encodeWithSelector(IRegistry.InvalidServiceVersion.selector, VersionLib.toVersionPart(majorVersion)));
        }

        _stopPrank();
    }*/
}
contract RegisterServiceConcreteTestL1 is RegisterServiceConcreteTest
{
    function setUp() public virtual override {
        vm.chainId(1);
        super.setUp();
    }
}

contract RegisterServiceConcreteTestL2 is RegisterServiceConcreteTest
{
    function setUp() public virtual override {
        vm.chainId(_getRandomChainId());
        super.setUp();
    }
}




contract RegisterServiceWithPresetConcreteTest is RegistryTestBaseWithPreset, RegisterServiceConcreteTest
{
    function setUp() public virtual override(RegistryTestBaseWithPreset, RegistryTestBase)
    {
        RegistryTestBaseWithPreset.setUp();
    }

    function test_registerService_specificCases_9() public
    {
        // args=[0x4Dc593023536B7b8c4f254893f3bCA460c45EF8B, 27734615690662410822268275 [2.773e25], 1120358745980813599 [1.12e18], true, 0x9f42f339A39F93e66782894Df2042c2b24E9FFB8, 0xB924Aa3d30e8F701cd33f15C871cC8aCB3d21D1a, 0xd65a6b878facf5db1fb422199394c9190a24f63bcf984404134eb0867bed5c4b0a1675ba2da124de18a0897e460b5c22b635957e19b24af75a006242e9aeff5144f9cc9ec2f04a17278dafa058, 13, 8]]
        // testFuzz_registerService_withValidType_00P011(address sender, NftId nftId, uint parentIdx, bool isInterceptor, address objectAddress, address initialOwner, bytes memory data, VersionPart version, ObjectType domain)

        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            NftIdLib.toNftId(27734615690662410822268275),
            _nftIdByType[1120358745980813599 % _nftIdByType.length],
            SERVICE(),
            true,
            address(0x9f42f339A39F93e66782894Df2042c2b24E9FFB8),
            address(0xB924Aa3d30e8F701cd33f15C871cC8aCB3d21D1a),
            "0xd65a6b878facf5db1fb422199394c9190a24f63bcf984404134eb0867bed5c4b0a1675ba2da124de18a0897e460b5c22b635957e19b24af75a006242e9aeff5144f9cc9ec2f04a17278dafa058"
        );

        VersionPart version = VersionLib.toVersionPart(13);
        ObjectType domain = ObjectTypeLib.toObjectType(8);
        address sender = address(0x4Dc593023536B7b8c4f254893f3bCA460c45EF8B);

        registerService_testFunction(sender, info, version, domain);
    }

}


contract RegisterServiceWithPresetConcreteTestL1 is RegisterServiceWithPresetConcreteTest
{
    function setUp() public virtual override {
        vm.chainId(1);
        super.setUp();
    }
}

contract RegisterServiceWithPresetConcreteTestL2 is RegisterServiceWithPresetConcreteTest
{
    function setUp() public virtual override {
        vm.chainId(_getRandomChainId());
        super.setUp();
    }
}