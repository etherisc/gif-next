// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin5/contracts/access/Ownable.sol";

import {Test, Vm, console} from "../lib/forge-std/src/Test.sol";
import {blockTimestamp} from "../contracts/types/Timestamp.sol";
import {blockBlocknumber} from "../contracts/types/Blocknumber.sol";
import {VersionLib, Version} from "../contracts/types/Version.sol";
import {NftId, toNftId, zeroNftId} from "../contracts/types/NftId.sol";
import {ObjectType, zeroObjectType, PROTOCOL, REGISTRY, TOKEN, SERVICE, INSTANCE, PRODUCT, POOL, DISTRIBUTION, BUNDLE, POLICY} from "../contracts/types/ObjectType.sol";

import {IVersionable} from "../contracts/shared/IVersionable.sol";
import {IRegisterable} from "../contracts/shared/IRegisterable.sol";
import {ProxyDeployer} from "../contracts/shared/Proxy.sol";
import {ChainNft} from "../contracts/registry/ChainNft.sol";

import {IRegistry} from "../contracts/registry/IRegistry.sol";
import {Registry} from "../contracts/registry/Registry.sol";
import {RegistryV02} from "./mock/RegistryV02.sol";
import {RegistryV03} from "./mock/RegistryV03.sol";

import {TestService} from "../contracts/test/TestService.sol";

// Helper functions to test IRegistry.ObjectInfo structs 
function eqObjectInfo(IRegistry.ObjectInfo memory a, IRegistry.ObjectInfo memory b) pure returns (bool isSame) {
    return (
        (a.nftId == b.nftId) &&
        (a.parentNftId == b.parentNftId) &&
        (a.objectType == b.objectType) &&
        (a.objectAddress == b.objectAddress) &&
        (a.initialOwner == b.initialOwner) /*&&
        (a.data == b.data)*/
    );
}

function zeroObjectInfo() pure returns (IRegistry.ObjectInfo memory) {
    return (
        IRegistry.ObjectInfo(
            zeroNftId(),
            zeroNftId(),
            zeroObjectType(),
            address(0),
            address(0),
            bytes("")
        )
    );
}


contract RegistryTest is Test {
    // TODO printing this addresses as NaN ....why??
    // TODO proxy owner and registry owner are the same...
    address public proxyOwner = makeAddr("proxyOwner");
    address public outsider = makeAddr("outsider");// MUST != registryOwner
    address public registryOwner = makeAddr("registryOwner");

    ProxyDeployer public proxy;
    IVersionable public versionable;
    IRegisterable public registerable;
    ChainNft public chainNft;
    IRegistry public registry;
    address public registryAddress;
    NftId public registryNftId;
    NftId public protocolNftId = toNftId(1101);
    NftId public globalRegistryNftId = toNftId(1201);
    IRegistry.ObjectInfo public protocolInfo;
    IRegistry.ObjectInfo public globalRegistryInfo;




    // mock -> stack to deep
    NftId public unknownNftId = toNftId(1234567890);
    NftId public tokenNftId;
    NftId public serviceNftId;
    NftId public instanceNftId;
    NftId public productNftId;
    NftId public poolNftId;
    NftId public distributionNftId;
    NftId public policyNftId;
    NftId public bundleNftId;
    address public serviceAddress = address(12);
    address public tokenAddress = address(13);// MUST > 10 because of precompiles
    address public instanceAddress = address(14);
    address public productAddress = address(15);
    address public poolAddress = address(16);
    address public distributionAddress = address(17);
    address public policyAddress = address(18);// TODO must be 0
    address public bundleAddress = address(19);// TODO must be 0


    // TODO add setup function, initialize vars there?

    function _deployRegistry(address implementation) internal
    {
        proxy = new ProxyDeployer();

        assertTrue(address(proxy) > address(0), "proxy deployer address is zero");
        // solhint-disable-next-line
        console.log("proxy deployer address", address(proxy));

        bytes memory initializationData = bytes("");
        versionable = proxy.deploy(implementation, initializationData);

        registryAddress = address(versionable);

        registry = IRegistry(registryAddress);
        registerable = IRegisterable(registryAddress);

        assertTrue(registryAddress > address(0), "registry address is zero");
        // solhint-disable-next-line
        //console.log("registry address", registryAddress);

        registryNftId = registry.getNftId(registryAddress);

        address chainNftAddress = address(registry.getChainNft());
        chainNft = ChainNft(chainNftAddress);
        
        assertTrue(chainNftAddress > address(0), "chain nft address is zero");
        // solhint-disable-next-line
        //console.log("chain nft address", chainNftAddress);

        protocolNftId = toNftId( chainNft.PROTOCOL_NFT_ID() );
        globalRegistryNftId = toNftId( chainNft.GLOBAL_REGISTRY_ID() );

        assertTrue(protocolNftId != globalRegistryNftId, "protocol nft id is equal to global registry nft id");

        protocolInfo = IRegistry.ObjectInfo(
                protocolNftId,
                zeroNftId(),
                PROTOCOL(),
                address(0),
                registryOwner,
                ""
        );

        // TODO global registry address if registry under test is global / not global registry
        globalRegistryInfo = block.chainid == 1 ? 
            zeroObjectInfo() :
            IRegistry.ObjectInfo(
                    globalRegistryNftId,
                    protocolNftId,
                    REGISTRY(),
                    address(0),
                    registryOwner,
                    "" 
            );

        // solhint-disable-next-line
        console.log("registry proxy address", registryAddress);
    }

    function _upgradeRegistry(address implementation) internal
    {
        bytes memory upgradeData =  bytes("");
        proxy.upgrade(implementation, upgradeData);
    }
    // use only with freshly initialized/upgraded registry
    // TODO add "registry is global registry" case...
    function _checkRegistryGetters(address implementation, Version version, uint64 initializedVersion, uint256 versionsCount) internal
    {
        assertTrue(versionsCount > 0, "test parameter error: version count zero");

        //console.log("testing registry getters");

        // IVersionable
        assertTrue(address(versionable) != address(0), "versionable address is zero");
        assertTrue(versionable.getVersion() == version, "getVersion() returned unxpected value");
        assertTrue(versionable.getVersion(versionsCount - 1) == version, "getVersion(versionsCount - 1) returned unxpected value");
        assertTrue(versionable.isInitialized(version), "isInitialized(version) returned unxpected value");
        assertTrue(versionable.getInitializedVersion() == initializedVersion, "getInitializedVersion() returned unxpected value");
        assertTrue(versionable.getVersionCount() == versionsCount, "getVersionCount() returned unxpected value");
        
        IVersionable.VersionInfo memory versionInfo = versionable.getVersionInfo(version);
        assertTrue(versionInfo.version == version, "getVersionInfo(version).version returned unxpected value");
        assertTrue(versionInfo.implementation == implementation, "getVersionInfo(version).implementation returned unxpected value");
        assertTrue(versionInfo.activatedBy == registryOwner, "getVersionInfo(version).activatedBy returned unxpected value");
        assertTrue(versionInfo.activatedAt == blockTimestamp(), "getVersionInfo(version).activatedAt returned unxpected value");
        assertTrue(versionInfo.activatedIn == blockBlocknumber(), "getVersionInfo(version).activatedIn returned unxpected value");

        // IRegisterable
        assertTrue(registerable.getRegistry() == registry, "getRegistry() returned unxpected value");
        // TODO global registry case
        assertTrue(registerable.getNftId() == registryNftId, "getNftId() returned unxpected value #1");
        assertTrue(registerable.getNftId() != protocolNftId, "getNftId() returned unexpected value #2");
        assertTrue(registerable.getNftId() != globalRegistryNftId, "getNftId() returned unexpected value #3");        

        (IRegistry.ObjectInfo memory initialInfo, bytes memory initialData) = registerable.getInitialInfo();
        assertTrue(initialInfo.nftId == registryNftId, "getInitialInfo().nftId returned unexpected value");
        assertTrue(initialInfo.parentNftId == globalRegistryNftId, "getInitialInfo().parentNftId returned unexpected value");
        assertTrue(initialInfo.objectType == REGISTRY(), "getInitialInfo().objectType returned unexpected value");
        assertTrue(initialInfo.objectAddress == address(registry), "getInitialInfo().objectAddress returned unexpected value");
        assertTrue(initialInfo.initialOwner == registryOwner, "getInitialInfo().initialOwner returned unexpected value");
        //assertTrue(initialInfo.data == bytes(""), "getInitialInfo().data returned unexpected value");
        //assertTrue(initialData == bytes(""), "getInitialInfo() returned unxpected initialData");

        // IRegistry
        _assert_allowance_all_types(registryNftId, PROTOCOL(), false);
        _assert_allowance_all_types(registryNftId, REGISTRY(), false);
        _assert_allowance_all_types(registryNftId, SERVICE(), false);
        _assert_allowance_all_types(registryNftId, TOKEN(), false);
        _assert_allowance_all_types(registryNftId, INSTANCE(), false);
        _assert_allowance_all_types(registryNftId, PRODUCT(), false);
        _assert_allowance_all_types(registryNftId, POOL(), false);
        _assert_allowance_all_types(registryNftId, DISTRIBUTION(), false);
        _assert_allowance_all_types(registryNftId, POLICY(), false);
        _assert_allowance_all_types(registryNftId, BUNDLE(), false);

        _assert_allowance_all_types(protocolNftId, PROTOCOL(), false);
        _assert_allowance_all_types(protocolNftId, REGISTRY(), false);
        _assert_allowance_all_types(protocolNftId, SERVICE(), false);
        _assert_allowance_all_types(protocolNftId, TOKEN(), false);
        _assert_allowance_all_types(protocolNftId, INSTANCE(), false);
        _assert_allowance_all_types(protocolNftId, PRODUCT(), false);
        _assert_allowance_all_types(protocolNftId, POOL(), false);
        _assert_allowance_all_types(protocolNftId, DISTRIBUTION(), false);
        _assert_allowance_all_types(protocolNftId, POLICY(), false);
        _assert_allowance_all_types(protocolNftId, BUNDLE(), false);

        _assert_allowance_all_types(globalRegistryNftId, PROTOCOL(), false);
        _assert_allowance_all_types(globalRegistryNftId, REGISTRY(), false);
        _assert_allowance_all_types(globalRegistryNftId, SERVICE(), false);
        _assert_allowance_all_types(globalRegistryNftId, TOKEN(), false);
        _assert_allowance_all_types(globalRegistryNftId, INSTANCE(), false);
        _assert_allowance_all_types(globalRegistryNftId, PRODUCT(), false);
        _assert_allowance_all_types(globalRegistryNftId, POOL(), false);
        _assert_allowance_all_types(globalRegistryNftId, DISTRIBUTION(), false);
        _assert_allowance_all_types(globalRegistryNftId, POLICY(), false);
        _assert_allowance_all_types(globalRegistryNftId, BUNDLE(), false);

        _assert_allowance_all_types(unknownNftId, PROTOCOL(), false);
        _assert_allowance_all_types(unknownNftId, REGISTRY(), false);
        _assert_allowance_all_types(unknownNftId, SERVICE(), false);
        _assert_allowance_all_types(unknownNftId, TOKEN(), false);
        _assert_allowance_all_types(unknownNftId, INSTANCE(), false);
        _assert_allowance_all_types(unknownNftId, PRODUCT(), false);
        _assert_allowance_all_types(unknownNftId, POOL(), false);
        _assert_allowance_all_types(unknownNftId, DISTRIBUTION(), false);
        _assert_allowance_all_types(unknownNftId, POLICY(), false);
        _assert_allowance_all_types(unknownNftId, BUNDLE(), false);

        _assert_allowance_all_types(zeroNftId(), PROTOCOL(), false);
        _assert_allowance_all_types(zeroNftId(), REGISTRY(), false);
        _assert_allowance_all_types(zeroNftId(), SERVICE(), false);
        _assert_allowance_all_types(zeroNftId(), TOKEN(), false);
        _assert_allowance_all_types(zeroNftId(), INSTANCE(), false);
        _assert_allowance_all_types(zeroNftId(), PRODUCT(), false);
        _assert_allowance_all_types(zeroNftId(), POOL(), false);
        _assert_allowance_all_types(zeroNftId(), DISTRIBUTION(), false);
        _assert_allowance_all_types(zeroNftId(), POLICY(), false);
        _assert_allowance_all_types(zeroNftId(), BUNDLE(), false);

        assertTrue(registry.getObjectCount() == 3, "getObjectCount() returned unexpected value");

        assertTrue(registry.getNftId(registryAddress) == registryNftId, "getNftId(registryAddress) returned unexpected value");
        assertTrue(registry.getNftId( address(0) ) == zeroNftId(), "getNftId(0) returned unexpected value");

        //assertTrue(registry.getName(registryNftId) == string(""), "getName(registryNftId) returned unexpected value");

        assertTrue(registry.ownerOf(registryAddress) == registryOwner, "ownerOf(registryAddress) returned unexpected value");
        assertTrue(registry.ownerOf(registryNftId) == registryOwner, "ownerOf(registryNftId) returned unexpected value");
        assertTrue(registry.ownerOf(protocolNftId) == registryOwner, "ownerOf(protocolNftId) returned unexpected value");
        assertTrue(registry.ownerOf(globalRegistryNftId) == registryOwner, "ownerOf(globalRegistryNftId) returned unexpected value");
        vm.expectRevert();//"ERC721NonexistentToken(0)"
        assertTrue(registry.ownerOf( zeroNftId() ) == address(0), "ownerOf(zeroNftId) returned unexpected value");

        assertTrue(eqObjectInfo( registry.getObjectInfo(registryAddress), initialInfo ), "getObjectInfo(registryAddress) returned unexpected value");
        assertTrue(eqObjectInfo( registry.getObjectInfo( address(0) ), zeroObjectInfo() ), "getObjectInfo(0) returned unexpected value");

        assertTrue(eqObjectInfo( registry.getObjectInfo(registryNftId), initialInfo ), "getObjectInfo(registryNftId) returned unexpected value");
        assertTrue(eqObjectInfo( registry.getObjectInfo( zeroNftId() ), zeroObjectInfo() ), "getObjectInfo(zeroNftId) returned unexpected value");

        assertTrue(eqObjectInfo( registry.getObjectInfo(protocolNftId), protocolInfo ), "getObjectInfo(protocolNftId) returned unexpected value");
        assertTrue(eqObjectInfo( registry.getObjectInfo(globalRegistryNftId), globalRegistryInfo ), "getObjectInfo(globalRegistryNftId) returned unexpected value");

        assertTrue(registry.isRegistered(registryNftId), "isRegistered(registryNftId) returned unexpected value");
        assertTrue(registry.isRegistered(protocolNftId), "isRegistered(protocolNftId) returned unexpected value");
        assertTrue(registry.isRegistered(globalRegistryNftId), "isRegistered(globalRegistryNftId) returned unexpected value");
        assertFalse(registry.isRegistered( zeroNftId() ), "isRegistered(zeroNftId) returned unexpected value");

        assertTrue(registry.isRegistered(registryAddress), "isRegistered(registryAddress) returned unexpected value");
        assertFalse(registry.isRegistered( address(0) ), "isRegistered(0) returned unexpected value");

        //getServiceAddress(string memory serviceName, VersionPart majorVersion)

        assertTrue(registry.getProtocolOwner() == registryOwner, "getProtocolOwner() returned unexpected value");

        //getChainNft()
    }


    // gas cost of initialize: 3020886 -> 2796869 
    // deployment size 22288 -> 24096
    function test_RegistryV01Deploy() public 
    {
        vm.startPrank(registryOwner);

        Registry implemetationV01 = new Registry();
        _deployRegistry(address(implemetationV01));

        vm.stopPrank();

        _checkRegistryGetters(
            address(implemetationV01), 
            VersionLib.toVersion(1,0,0), 
            1,//uint64 initializedVersion
            1 //uint256 versionsCount
        );

        Registry registryV01 = Registry(registryAddress); 

        /* solhint-disable */
        console.log("registry deployed at", registryAddress);
        console.log("registry nft[int]", registryV01.getNftId().toInt()); 
        console.log("registry version[int]", registryV01.getVersion().toInt());
        console.log("registry initialized version[int]", registryV01.getInitializedVersion());
        console.log("registry version count is", registryV01.getVersionCount());
        console.log("registry NFT deployed at", address(registryV01.getChainNft()));
        /* solhint-enable */ 
    }  

    // gas cost of initialize: 3020886 -> 2796869  
    // deployment size 22300 -> 24096
    function test_RegistryV02Deploy() public
    {
        vm.startPrank(registryOwner);

        Registry implemetationV02 = new RegistryV02();
        _deployRegistry(address(implemetationV02));

        vm.stopPrank();

        _checkRegistryGetters(
            address(implemetationV02), 
            VersionLib.toVersion(1,1,0), 
            1,//uint64 initializedVersion
            1 //uint256 versionsCount
        ); 

        RegistryV02 registryV02 = RegistryV02(registryAddress);       

        /* solhint-disable */
        console.log("registry deployed at", registryAddress);
        console.log("registry nft[int]", registryV02.getNftId().toInt()); 
        console.log("registry version[int]", registryV02.getVersion().toInt());
        console.log("registry initialized version[int]", registryV02.getInitializedVersion());
        console.log("registry version count is", registryV02.getVersionCount());
        console.log("registry NFT deployed at", address(registryV02.getChainNft()));
        /* solhint-enable */ 
    }

    // gas cost of initialize: 3043002  
    // deployment size 22366 
    function test_RegistryV03Deploy() public
    {
        vm.startPrank(registryOwner);

        Registry implemetationV03 = new RegistryV03();
        _deployRegistry(address(implemetationV03));

        vm.stopPrank();

        _checkRegistryGetters(
            address(implemetationV03), 
            VersionLib.toVersion(1,2,0), 
            1,//uint64 initializedVersion
            1 //uint256 versionsCount
        );   

        // check new function(s)
        RegistryV03 registryV03 = RegistryV03(registryAddress);
        uint v3data = registryV03.getDataV3();
        assertEq(v3data, type(uint).max, "unxpected value of initialized V3 variable");

        /* solhint-disable */
        console.log("registry deployed at", registryAddress);
        console.log("registry nft[int]", registryV03.getNftId().toInt()); 
        console.log("registry version[int]", registryV03.getVersion().toInt());
        console.log("registry initialized version[int]", registryV03.getInitializedVersion());
        console.log("registry version count is", registryV03.getVersionCount());
        console.log("registry NFT deployed at", address(registryV03.getChainNft()));
        /* solhint-enable */ 
    }

    function test_RegistryV01DeployAndUpgradeToV02() public
    {
        test_RegistryV01Deploy();

        // upgrade
        vm.startPrank(registryOwner);

        RegistryV02 implemetationV02 = new RegistryV02();
        _upgradeRegistry(address(implemetationV02));

        vm.stopPrank();

        _checkRegistryGetters(
            address(implemetationV02), 
            VersionLib.toVersion(1,1,0), 
            VersionLib.toUint64( VersionLib.toVersion(1,1,0) ),//uint64 initializedVersion
            2 //uint256 versionsCount
        );  

        Registry registryV02 = RegistryV02(registryAddress);

        /* solhint-disable */
        console.log("after upgrade to V02, registry nft[int]", registryV02.getNftId().toInt()); 
        console.log("after upgrade to V02, registry version[int]", registryV02.getVersion().toInt());
        console.log("after upgrade to V02, registry initialized version[int]", registryV02.getInitializedVersion());
        console.log("after upgrade to V02, registry version count is", registryV02.getVersionCount());
        console.log("after upgrade to V02, registry NFT deployed at", address(registryV02.getChainNft()));
        /* solhint-enable */ 
    }
    
    function test_RegistryV01DeployAndUpgradeToV03() public
    {
        test_RegistryV01DeployAndUpgradeToV02();

        // upgrade
        vm.startPrank(registryOwner);

        RegistryV03 implemetationV03 = new RegistryV03();
        _upgradeRegistry(address(implemetationV03));

        vm.stopPrank();

        _checkRegistryGetters(
            address(implemetationV03), 
            VersionLib.toVersion(1,2,0), 
            VersionLib.toUint64( VersionLib.toVersion(1,2,0) ),//uint64 initializedVersion
            3 //uint256 versionsCount
        );

        // check new function(s) 
        RegistryV03 registryV03 = RegistryV03(registryAddress);
        uint v3data = registryV03.getDataV3();

        assertTrue(v3data == type(uint).max, "getDataV3 returned unxpected value");

        /* solhint-disable */
        console.log("after upgrade to V03, registry nft[int]", registryV03.getNftId().toInt()); 
        console.log("after upgrade to V03, registry version[int]", registryV03.getVersion().toInt());
        console.log("after upgrade to V03, registry initialized version[int]", registryV03.getInitializedVersion());
        console.log("after upgrade to V03, registry version count is", registryV03.getVersionCount());
        console.log("after upgrade to V03, registry NFT deployed at", address(registryV03.getChainNft()));
        /* solhint-enable */ 
    }

    function _assert_allowance_all_types(NftId nftId, ObjectType objectType, bool assertTrue_) internal
    {
        assertFalse(registry.allowance(nftId, objectType, zeroObjectType()), "allowance(nftId, objectType, ZERO_TYPE) returned unexpected value");
        assertFalse(registry.allowance(nftId, objectType, PROTOCOL()), "allowance(nftId, objectType, PROTOCOL) returned unexpected value");

        if(assertTrue_) 
        {
            assertTrue(registry.allowance(nftId, objectType, REGISTRY()), "allowance(nftId, objectType, REGISTRY) returned unexpected value");
            assertTrue(registry.allowance(nftId, objectType, SERVICE()), "allowance(nftId, objectType, SERVICE) returned unexpected value");
            assertTrue(registry.allowance(nftId, objectType, TOKEN()), "allowance(nftId, objectType, TOKEN) returned unexpected value");
            assertTrue(registry.allowance(nftId, objectType, INSTANCE()), "allowance(nftId, objectType, INSTANCE) returned unexpected value");
            assertTrue(registry.allowance(nftId, objectType, PRODUCT()), "allowance(nftId, objectType, PRODUCT) returned unexpected value");
            assertTrue(registry.allowance(nftId, objectType, POOL()), "allowance(nftId, objectType, POOL) returned unexpected value");
            assertTrue(registry.allowance(nftId, objectType, POLICY()), "allowance(nftId, objectType, POLICY) returned unexpected value");
            assertTrue(registry.allowance(nftId, objectType, BUNDLE()), "allowance(nftId, objectType, BUNDLE) returned unexpected value"); 
        } 
        else
        {
            assertFalse(registry.allowance(nftId, objectType, REGISTRY()), "allowance(nftId, objectType, REGISTRY) returned unexpected value");
            assertFalse(registry.allowance(nftId, objectType, SERVICE()), "allowance(nftId, objectType, SERVICE) returned unexpected value");
            assertFalse(registry.allowance(nftId, objectType, TOKEN()), "allowance(nftId, objectType, TOKEN) returned unexpected value");
            assertFalse(registry.allowance(nftId, objectType, INSTANCE()), "allowance(nftId, objectType, INSTANCE) returned unexpected value");
            assertFalse(registry.allowance(nftId, objectType, PRODUCT()), "allowance(nftId, objectType, PRODUCT) returned unexpected value");
            assertFalse(registry.allowance(nftId, objectType, POOL()), "allowance(nftId, objectType, POOL) returned unexpected value");
            assertFalse(registry.allowance(nftId, objectType, POLICY()), "allowance(nftId, objectType, POLICY) returned unexpected value");
            assertFalse(registry.allowance(nftId, objectType, BUNDLE()), "allowance(nftId, objectType, BUNDLE) returned unexpected value");  
        }      
    }

    function _assert_allowance_all_types(NftId nftId, ObjectType objectType, ObjectType assertTrueType) internal
    {
        assertFalse(registry.allowance(nftId, objectType, zeroObjectType()), "allowance(nftId, objectType, ZERO_TYPE) returned unexpected value");
        assertFalse(registry.allowance(nftId, objectType, PROTOCOL()), "allowance(nftId, objectType, PROTOCOL) returned unexpected value");
        
        assertTrueType == REGISTRY() ?
        assertTrue(registry.allowance(nftId, objectType, REGISTRY()), "allowance(nftId, objectType, REGISTRY) returned unexpected value"):
        assertFalse(registry.allowance(nftId, objectType, REGISTRY()), "allowance(nftId, objectType, REGISTRY) returned unexpected value");

        assertTrueType == SERVICE() ?
        assertTrue(registry.allowance(nftId, objectType, SERVICE()), "allowance(nftId, objectType, SERVICE) returned unexpected value"):
        assertFalse(registry.allowance(nftId, objectType, SERVICE()), "allowance(nftId, objectType, SERVICE) returned unexpected value");

        assertTrueType == TOKEN() ?
        assertTrue(registry.allowance(nftId, objectType, TOKEN()), "allowance(nftId, objectType, TOKEN) returned unexpected value"):
        assertFalse(registry.allowance(nftId, objectType, TOKEN()), "allowance(nftId, objectType, TOKEN) returned unexpected value");

        assertTrueType == INSTANCE() ?
        assertTrue(registry.allowance(nftId, objectType, INSTANCE()), "allowance(nftId, objectType, INSTANCE) returned unexpected value"):
        assertFalse(registry.allowance(nftId, objectType, INSTANCE()), "allowance(nftId, objectType, INSTANCE) returned unexpected value");

        assertTrueType == PRODUCT() ?
        assertTrue(registry.allowance(nftId, objectType, PRODUCT()), "allowance(nftId, objectType, PRODUCT) returned unexpected value"):
        assertFalse(registry.allowance(nftId, objectType, PRODUCT()), "allowance(nftId, objectType, PRODUCT) returned unexpected value");

        assertTrueType == POOL() ?
        assertTrue(registry.allowance(nftId, objectType, POOL()), "allowance(nftId, objectType, POOL) returned unexpected value"):
        assertFalse(registry.allowance(nftId, objectType, POOL()), "allowance(nftId, objectType, POOL) returned unexpected value");

        assertTrueType == POLICY() ?
        assertTrue(registry.allowance(nftId, objectType, POLICY()), "allowance(nftId, objectType, POLICY) returned unexpected value"):
        assertFalse(registry.allowance(nftId, objectType, POLICY()), "allowance(nftId, objectType, POLICY) returned unexpected value");

        assertTrueType == BUNDLE() ?
        assertTrue(registry.allowance(nftId, objectType, BUNDLE()), "allowance(nftId, objectType, BUNDLE) returned unexpected value"):
        assertFalse(registry.allowance(nftId, objectType, BUNDLE()), "allowance(nftId, objectType, BUNDLE) returned unexpected value");  
    }
    // TODO check for revert msg. 
    // TODO add revert msg. as arg 
    // TODO add vm.expectEmit() with events
    function _approve_all_types(NftId nftId, bool expectRevert) internal
    {
        _assert_allowance_all_types(nftId, PROTOCOL(), false); // expectTrue
        _assert_allowance_all_types(nftId, REGISTRY(), false);
        _assert_allowance_all_types(nftId, SERVICE(), false);
        _assert_allowance_all_types(nftId, TOKEN(), false);
        _assert_allowance_all_types(nftId, INSTANCE(), false);
        _assert_allowance_all_types(nftId, PRODUCT(), false);
        _assert_allowance_all_types(nftId, POOL(), false);
        _assert_allowance_all_types(nftId, DISTRIBUTION(), false);
        _assert_allowance_all_types(nftId, POLICY(), false);
        _assert_allowance_all_types(nftId, BUNDLE(), false);

        console.log("approving PROTOCOL type");

        vm.expectRevert();
        registry.approve(nftId, PROTOCOL(), PROTOCOL());
        vm.expectRevert();
        registry.approve(nftId, PROTOCOL(), REGISTRY());
        vm.expectRevert();
        registry.approve(nftId, PROTOCOL(), TOKEN());
        vm.expectRevert();
        registry.approve(nftId, PROTOCOL(), SERVICE());
        vm.expectRevert();
        registry.approve(nftId, PROTOCOL(), INSTANCE());
        vm.expectRevert();
        registry.approve(nftId, PROTOCOL(), PRODUCT());
        vm.expectRevert();
        registry.approve(nftId, PROTOCOL(), POOL());
        vm.expectRevert();
        registry.approve(nftId, PROTOCOL(), DISTRIBUTION());
        vm.expectRevert();
        registry.approve(nftId, PROTOCOL(), POLICY());
        vm.expectRevert();
        registry.approve(nftId, PROTOCOL(), BUNDLE());

        console.log("approving REGISTRY type");

        vm.expectRevert();
        registry.approve(nftId, REGISTRY(), PROTOCOL());
        vm.expectRevert();
        registry.approve(nftId, REGISTRY(), REGISTRY());
        vm.expectRevert();
        registry.approve(nftId, REGISTRY(), TOKEN());
        vm.expectRevert();
        registry.approve(nftId, REGISTRY(), SERVICE());
        vm.expectRevert();
        registry.approve(nftId, REGISTRY(), INSTANCE());
        vm.expectRevert();
        registry.approve(nftId, REGISTRY(), PRODUCT());
        vm.expectRevert();
        registry.approve(nftId, REGISTRY(), POOL());
        vm.expectRevert();
        registry.approve(nftId, REGISTRY(), DISTRIBUTION());
        vm.expectRevert();
        registry.approve(nftId, REGISTRY(), POLICY());
        vm.expectRevert();
        registry.approve(nftId, REGISTRY(), BUNDLE());

        console.log("approving SERVICE type");

        vm.expectRevert();
        registry.approve(nftId, SERVICE(), PROTOCOL());
        vm.expectRevert();
        registry.approve(nftId, SERVICE(), TOKEN());
        vm.expectRevert();
        registry.approve(nftId, SERVICE(), SERVICE());
        vm.expectRevert();
        registry.approve(nftId, SERVICE(), INSTANCE());
        vm.expectRevert();
        registry.approve(nftId, SERVICE(), PRODUCT());
        vm.expectRevert();
        registry.approve(nftId, SERVICE(), POOL());
        vm.expectRevert();
        registry.approve(nftId, SERVICE(), DISTRIBUTION());
        vm.expectRevert();
        registry.approve(nftId, SERVICE(), POLICY());
        vm.expectRevert();
        registry.approve(nftId, SERVICE(), BUNDLE());

        if(expectRevert) {
            vm.expectRevert();
            registry.approve(nftId, SERVICE(), REGISTRY());
        } else {
            //vm.expectEmit( address(registry) );
            //emit Registry.Approval(nftId, SERVICE());// TODO make public or what???
            registry.approve(nftId, SERVICE(), REGISTRY());

            _assert_allowance_all_types(nftId, PROTOCOL(), false); // expectTrue
            _assert_allowance_all_types(nftId, REGISTRY(), false);
            _assert_allowance_all_types(nftId, SERVICE(), REGISTRY());
            _assert_allowance_all_types(nftId, TOKEN(), false);
            _assert_allowance_all_types(nftId, INSTANCE(), false);
            _assert_allowance_all_types(nftId, PRODUCT(), false);
            _assert_allowance_all_types(nftId, POOL(), false);
            _assert_allowance_all_types(nftId, DISTRIBUTION(), false);
            _assert_allowance_all_types(nftId, POLICY(), false);
            _assert_allowance_all_types(nftId, BUNDLE(), false);
        }

        console.log("approving TOKEN type");

        vm.expectRevert();
        registry.approve(nftId, TOKEN(), PROTOCOL());
        vm.expectRevert();
        registry.approve(nftId, TOKEN(), TOKEN());
        vm.expectRevert();
        registry.approve(nftId, TOKEN(), SERVICE());
        vm.expectRevert();
        registry.approve(nftId, TOKEN(), INSTANCE());
        vm.expectRevert();
        registry.approve(nftId, TOKEN(), PRODUCT());
        vm.expectRevert();
        registry.approve(nftId, TOKEN(), POOL());
        vm.expectRevert();
        registry.approve(nftId, TOKEN(), DISTRIBUTION());
        vm.expectRevert();
        registry.approve(nftId, TOKEN(), POLICY());
        vm.expectRevert();
        registry.approve(nftId, TOKEN(), BUNDLE());

        if(expectRevert) {
            vm.expectRevert();
            registry.approve(nftId, TOKEN(), REGISTRY());
        } else {
            registry.approve(nftId, TOKEN(), REGISTRY());

            _assert_allowance_all_types(nftId, PROTOCOL(), false); // expectTrue
            _assert_allowance_all_types(nftId, REGISTRY(), false);
            _assert_allowance_all_types(nftId, SERVICE(), REGISTRY());
            _assert_allowance_all_types(nftId, TOKEN(), REGISTRY());
            _assert_allowance_all_types(nftId, INSTANCE(), false);
            _assert_allowance_all_types(nftId, PRODUCT(), false);
            _assert_allowance_all_types(nftId, POOL(), false);
            _assert_allowance_all_types(nftId, DISTRIBUTION(), false);
            _assert_allowance_all_types(nftId, POLICY(), false);
            _assert_allowance_all_types(nftId, BUNDLE(), false);
        }

        console.log("approving INSTANCE type");

        vm.expectRevert();
        registry.approve(nftId, INSTANCE(), PROTOCOL());
        vm.expectRevert();
        registry.approve(nftId, INSTANCE(), TOKEN());
        vm.expectRevert();
        registry.approve(nftId, INSTANCE(), SERVICE());
        vm.expectRevert();
        registry.approve(nftId, INSTANCE(), INSTANCE());
        vm.expectRevert();
        registry.approve(nftId, INSTANCE(), PRODUCT());
        vm.expectRevert();
        registry.approve(nftId, INSTANCE(), POOL());
        vm.expectRevert();
        registry.approve(nftId, INSTANCE(), DISTRIBUTION());
        vm.expectRevert();
        registry.approve(nftId, INSTANCE(), POLICY());
        vm.expectRevert();
        registry.approve(nftId, INSTANCE(), BUNDLE());

        if(expectRevert) {
            vm.expectRevert();
            registry.approve(nftId, INSTANCE(), REGISTRY());
        } else {
            registry.approve(nftId, INSTANCE(), REGISTRY());

            _assert_allowance_all_types(nftId, PROTOCOL(), false); // expectTrue
            _assert_allowance_all_types(nftId, REGISTRY(), false);
            _assert_allowance_all_types(nftId, SERVICE(), REGISTRY());
            _assert_allowance_all_types(nftId, TOKEN(), REGISTRY());
            _assert_allowance_all_types(nftId, INSTANCE(), REGISTRY());
            _assert_allowance_all_types(nftId, PRODUCT(), false);
            _assert_allowance_all_types(nftId, POOL(), false);
            _assert_allowance_all_types(nftId, DISTRIBUTION(), false);
            _assert_allowance_all_types(nftId, POLICY(), false);
            _assert_allowance_all_types(nftId, BUNDLE(), false);
        }

        console.log("approving PRODUCT type");

        vm.expectRevert();
        registry.approve(nftId, PRODUCT(), PROTOCOL());
        vm.expectRevert();
        registry.approve(nftId, PRODUCT(), REGISTRY());
        vm.expectRevert();
        registry.approve(nftId, PRODUCT(), TOKEN());
        vm.expectRevert();
        registry.approve(nftId, PRODUCT(), SERVICE());
        vm.expectRevert();
        registry.approve(nftId, PRODUCT(), PRODUCT());
        vm.expectRevert();
        registry.approve(nftId, PRODUCT(), POOL());
        vm.expectRevert();
        registry.approve(nftId, PRODUCT(), DISTRIBUTION());
        vm.expectRevert();
        registry.approve(nftId, PRODUCT(), POLICY());
        vm.expectRevert();
        registry.approve(nftId, PRODUCT(), BUNDLE());

        if(expectRevert) {
            vm.expectRevert();
            registry.approve(nftId, PRODUCT(), INSTANCE());
        } else {
            registry.approve(nftId, PRODUCT(), INSTANCE());

            _assert_allowance_all_types(nftId, PROTOCOL(), false); // expectTrue
            _assert_allowance_all_types(nftId, REGISTRY(), false);
            _assert_allowance_all_types(nftId, SERVICE(), REGISTRY());
            _assert_allowance_all_types(nftId, TOKEN(), REGISTRY());
            _assert_allowance_all_types(nftId, INSTANCE(), REGISTRY());
            _assert_allowance_all_types(nftId, PRODUCT(), INSTANCE());
            _assert_allowance_all_types(nftId, POOL(), false);
            _assert_allowance_all_types(nftId, DISTRIBUTION(), false);
            _assert_allowance_all_types(nftId, POLICY(), false);
            _assert_allowance_all_types(nftId, BUNDLE(), false);
        } 

        console.log("approving POOL type");

        vm.expectRevert();
        registry.approve(nftId, POOL(), PROTOCOL());
        vm.expectRevert();
        registry.approve(nftId, POOL(), REGISTRY());
        vm.expectRevert();
        registry.approve(nftId, POOL(), TOKEN());
        vm.expectRevert();
        registry.approve(nftId, POOL(), SERVICE());
        vm.expectRevert();
        registry.approve(nftId, POOL(), PRODUCT());
        vm.expectRevert();
        registry.approve(nftId, POOL(), POOL());
        vm.expectRevert();
        registry.approve(nftId, POOL(), DISTRIBUTION());
        vm.expectRevert();
        registry.approve(nftId, POOL(), POLICY());
        vm.expectRevert();
        registry.approve(nftId, POOL(), BUNDLE());

        if(expectRevert) {
            vm.expectRevert();
            registry.approve(nftId, POOL(), INSTANCE());
        } else {
            registry.approve(nftId, POOL(), INSTANCE());

            _assert_allowance_all_types(nftId, PROTOCOL(), false); // expectTrue
            _assert_allowance_all_types(nftId, REGISTRY(), false);
            _assert_allowance_all_types(nftId, SERVICE(), REGISTRY());
            _assert_allowance_all_types(nftId, TOKEN(), REGISTRY());
            _assert_allowance_all_types(nftId, INSTANCE(), REGISTRY());
            _assert_allowance_all_types(nftId, PRODUCT(), INSTANCE());
            _assert_allowance_all_types(nftId, POOL(), INSTANCE());
            _assert_allowance_all_types(nftId, DISTRIBUTION(), false);
            _assert_allowance_all_types(nftId, POLICY(), false);
            _assert_allowance_all_types(nftId, BUNDLE(), false);
        }

        console.log("approving DISTRIBUTION type");

        vm.expectRevert();
        registry.approve(nftId, DISTRIBUTION(), PROTOCOL());
        vm.expectRevert();
        registry.approve(nftId, DISTRIBUTION(), REGISTRY());
        vm.expectRevert();
        registry.approve(nftId, DISTRIBUTION(), TOKEN());
        vm.expectRevert();
        registry.approve(nftId, DISTRIBUTION(), SERVICE());
        vm.expectRevert();
        registry.approve(nftId, DISTRIBUTION(), PRODUCT());
        vm.expectRevert();
        registry.approve(nftId, DISTRIBUTION(), POOL());
        vm.expectRevert();
        registry.approve(nftId, DISTRIBUTION(), DISTRIBUTION());
        vm.expectRevert();
        registry.approve(nftId, DISTRIBUTION(), POLICY());
        vm.expectRevert();
        registry.approve(nftId, DISTRIBUTION(), BUNDLE());

        if(expectRevert) {
            vm.expectRevert();
            registry.approve(nftId, DISTRIBUTION(), INSTANCE());
        } else {
            registry.approve(nftId, DISTRIBUTION(), INSTANCE());

            _assert_allowance_all_types(nftId, PROTOCOL(), false); // expectTrue
            _assert_allowance_all_types(nftId, REGISTRY(), false);
            _assert_allowance_all_types(nftId, SERVICE(), REGISTRY());
            _assert_allowance_all_types(nftId, TOKEN(), REGISTRY());
            _assert_allowance_all_types(nftId, INSTANCE(), REGISTRY());
            _assert_allowance_all_types(nftId, PRODUCT(), INSTANCE());
            _assert_allowance_all_types(nftId, POOL(), INSTANCE());
            _assert_allowance_all_types(nftId, DISTRIBUTION(), INSTANCE());
            _assert_allowance_all_types(nftId, POLICY(), false);
            _assert_allowance_all_types(nftId, BUNDLE(), false);
        }

        console.log("approving POLICY type");

        vm.expectRevert();
        registry.approve(nftId, POLICY(), PROTOCOL());
        vm.expectRevert();
        registry.approve(nftId, POLICY(), REGISTRY());
        vm.expectRevert();
        registry.approve(nftId, POLICY(), TOKEN());
        vm.expectRevert();
        registry.approve(nftId, POLICY(), SERVICE());
        vm.expectRevert();
        registry.approve(nftId, POLICY(), INSTANCE());
        vm.expectRevert();
        registry.approve(nftId, POLICY(), POOL());
        vm.expectRevert();
        registry.approve(nftId, POLICY(), DISTRIBUTION());
        vm.expectRevert();
        registry.approve(nftId, POLICY(), POLICY());
        vm.expectRevert();
        registry.approve(nftId, POLICY(), BUNDLE());

        if(expectRevert) {
            vm.expectRevert();
            registry.approve(nftId, POLICY(), PRODUCT());
        } else {
            registry.approve(nftId, POLICY(), PRODUCT());

            _assert_allowance_all_types(nftId, PROTOCOL(), false); // expectTrue
            _assert_allowance_all_types(nftId, REGISTRY(), false);
            _assert_allowance_all_types(nftId, SERVICE(), REGISTRY());
            _assert_allowance_all_types(nftId, TOKEN(), REGISTRY());
            _assert_allowance_all_types(nftId, INSTANCE(), REGISTRY());
            _assert_allowance_all_types(nftId, PRODUCT(), INSTANCE());
            _assert_allowance_all_types(nftId, POOL(), INSTANCE());
            _assert_allowance_all_types(nftId, DISTRIBUTION(), INSTANCE());
            _assert_allowance_all_types(nftId, POLICY(), PRODUCT());
            _assert_allowance_all_types(nftId, BUNDLE(), false);
        }

        console.log("approving BUNDLE type");

        vm.expectRevert();
        registry.approve(nftId, BUNDLE(), PROTOCOL());
        vm.expectRevert();
        registry.approve(nftId, BUNDLE(), REGISTRY());
        vm.expectRevert();
        registry.approve(nftId, BUNDLE(), TOKEN());
        vm.expectRevert();
        registry.approve(nftId, BUNDLE(), SERVICE());
        vm.expectRevert();
        registry.approve(nftId, BUNDLE(), INSTANCE());
        vm.expectRevert();
        registry.approve(nftId, BUNDLE(), PRODUCT());
        vm.expectRevert();
        registry.approve(nftId, BUNDLE(), DISTRIBUTION());
        vm.expectRevert();
        registry.approve(nftId, BUNDLE(), POLICY());
        vm.expectRevert();
        registry.approve(nftId, BUNDLE(), BUNDLE());

        if(expectRevert) {
            vm.expectRevert();
            registry.approve(nftId, BUNDLE(), POOL());
        } else {
            registry.approve(nftId, BUNDLE(), POOL());

            _assert_allowance_all_types(nftId, PROTOCOL(), false); // expectTrue
            _assert_allowance_all_types(nftId, REGISTRY(), false);
            _assert_allowance_all_types(nftId, SERVICE(), REGISTRY());
            _assert_allowance_all_types(nftId, TOKEN(), REGISTRY());
            _assert_allowance_all_types(nftId, INSTANCE(), REGISTRY());
            _assert_allowance_all_types(nftId, PRODUCT(), INSTANCE());
            _assert_allowance_all_types(nftId, POOL(), INSTANCE());
            _assert_allowance_all_types(nftId, DISTRIBUTION(), INSTANCE());
            _assert_allowance_all_types(nftId, POLICY(), PRODUCT());
            _assert_allowance_all_types(nftId, BUNDLE(), POOL());
        }
    }

    //function test_approve_zeroNftId()
    //function test_approve_unknownNftId()
    //function test_approve_registryNftId()
    //function test_approve_registredObjects()
    function test_approve() public
    {
        test_RegistryV01Deploy();

        TestService service = new TestService(address(registry), registryNftId, registryOwner);
        serviceAddress = address(service);

        assertTrue( eqObjectInfo(registry.getObjectInfo(unknownNftId), zeroObjectInfo()) );
        assertTrue( eqObjectInfo(registry.getObjectInfo(address(service)), zeroObjectInfo()) );

        vm.startPrank(outsider);
        console.log("test approving `%s` nft id for all types by outsider:%s", zeroNftId().toInt(), outsider);
        _approve_all_types(zeroNftId(), true);// NOT_OWNER
        console.log("test approving `%s` (unknown nft id) for all types by outsider:%s", unknownNftId.toInt(), outsider);
        _approve_all_types(unknownNftId, true);// NOT_OWNER
        console.log("test approving `%s` (registry nft id) for all types by outsider:%s", registryNftId.toInt(), outsider);
        _approve_all_types(registryNftId, true);// NOT_OWNER

        vm.stopPrank();
        vm.startPrank(serviceAddress);
        // NOT_OWNER
        console.log("test approving `%s` nft id for all types by unregistered service:%s", zeroNftId().toInt(), serviceAddress);
        _approve_all_types(zeroNftId(), true);// NOT_OWNER
        console.log("test approving `%s` (unknown nft id) for all types by unregistered service:%s", unknownNftId.toInt(), serviceAddress);
        _approve_all_types(unknownNftId, true);// NOT_OWNER
        console.log("test approving `%s` (registry nft id) for all types by unregistered service:%s", registryNftId.toInt(), serviceAddress);
        _approve_all_types(registryNftId, true);// NOT_OWNER

        vm.stopPrank();
        vm.startPrank(registryOwner);
        // NOT_REGISTERED
        console.log("test approving `%s` nft id for all types by registry owner:%s", zeroNftId().toInt(), registryOwner);
        _approve_all_types(zeroNftId(), true);// NOT_REGISTERED
        console.log("test approving `%s` (unknown nft id) for all types by registry owner:%s", unknownNftId.toInt(), registryOwner);
        _approve_all_types(unknownNftId, true);// NOT_REGISTERED
        console.log("test approving `%s` (registry nft id) for all types by registry owner:%s", registryNftId.toInt(), serviceAddress);
        _approve_all_types(registryNftId, true); // SELF_APROVAL

        //_register_all_types(registryOwner, false);

        console.log("Registering all contract types");

        tokenNftId = registry.register(IRegistry.ObjectInfo(
            zeroNftId(),
            registryNftId,
            TOKEN(),
            tokenAddress,
            registryOwner,
            ""
        ));

        serviceNftId = registry.register(IRegistry.ObjectInfo(
            zeroNftId(),
            registryNftId,
            SERVICE(),
            serviceAddress,
            registryOwner,
            ""
        ));

        instanceNftId = registry.register(IRegistry.ObjectInfo(
            zeroNftId(),
            registryNftId,
            INSTANCE(),
            instanceAddress,
            registryOwner,
            ""
        ));

        productNftId = registry.register(IRegistry.ObjectInfo(
            zeroNftId(),
            instanceNftId,
            PRODUCT(),
            productAddress,
            registryOwner,
            ""
        ));

        poolNftId = registry.register(IRegistry.ObjectInfo(
            zeroNftId(),
            instanceNftId,
            POOL(),
            poolAddress,
            registryOwner,
            ""
        ));

        distributionNftId = registry.register(IRegistry.ObjectInfo(
            zeroNftId(),
            instanceNftId,
            DISTRIBUTION(),
            distributionAddress,
            registryOwner,
            ""
        ));

        // TODO do not test register here -> use registerFrom() fro BUNDLE and POLICY
        /*vm.expectRevert(); //ZERO_ADDRESS
        policyNftId = registry.register(IRegistry.ObjectInfo(
            zeroNftId(),
            productNftId,
            POLICY(),
            address(0),
            registryOwner,
            ""
        ));

        vm.expectRevert(); //ZERO_ADDRESS
        bundleNftId = registry.register(IRegistry.ObjectInfo(
            zeroNftId(),
            poolNftId,
            BUNDLE(),
            address(0),
            registryOwner,
            ""
        ));*/

        console.log("test approving `%s` (registered service nft id) for all types by registry owner:%s", serviceNftId.toInt(), registryOwner);
        _approve_all_types(serviceNftId, false); // OK
        console.log("test approving `%s` (registered token nft id) for all types by registry owner:%s", tokenNftId.toInt(), registryOwner);
        _approve_all_types(tokenNftId, true); // NOT_SERVICE
        console.log("test approving `%s` (registered instance nft id) for all types by registry owner:%s", instanceNftId.toInt(), registryOwner);
        _approve_all_types(instanceNftId, true); // NOT_SERVICE
        console.log("test approving `%s` (registered product nft id) for all types by registry owner:%s", productNftId.toInt(), registryOwner);
        _approve_all_types(productNftId, true); // NOT_SERVICE
        console.log("test approving `%s` (registered pool nft id) for all types by registry owner:%s", poolNftId.toInt(), registryOwner);
        _approve_all_types(poolNftId, true); // NOT_SERVICE
        console.log("test approving `%s` (registered distribution nft id) for all types by registry owner:%s", distributionNftId.toInt(), registryOwner);
        _approve_all_types(distributionNftId, true); // NOT_SERVICE
        // TODO 
        //_approve_all_types(policyNftId, true); // registred policy // NOT_SERVICE
        //_approve_all_types(policyNftId, true); // registred bundle // NOT_SERVICE

        vm.stopPrank();
    }
}