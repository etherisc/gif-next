// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin5/contracts/access/Ownable.sol";

import {Test, Vm, console} from "../lib/forge-std/src/Test.sol";
import {blockTimestamp} from "../contracts/types/Timestamp.sol";
import {blockBlocknumber} from "../contracts/types/Blocknumber.sol";
import {VersionLib, Version} from "../contracts/types/Version.sol";
import {NftId, toNftId} from "../contracts/types/NftId.sol";
import {REGISTRY, TOKEN, SERVICE} from "../contracts/types/ObjectType.sol";

import {IVersionable} from "../contracts/shared/IVersionable.sol";
import {IRegisterable} from "../contracts/shared/IRegisterable.sol";
import {ProxyDeployer} from "../contracts/shared/Proxy.sol";
import {ChainNft} from "../contracts/registry/ChainNft.sol";

import {IRegistry} from "../contracts/registry/IRegistry.sol";
import {Registry} from "../contracts/registry/Registry.sol";
import {RegistryV02} from "./mock/RegistryV02.sol";
import {RegistryV03} from "./mock/RegistryV03.sol";

contract RegistryTest is Test {

    address public proxyOwner = makeAddr("proxyOwner");
    address public outsider = makeAddr("outsider");
    address public registryOwner = makeAddr("registryOwner");

    ProxyDeployer public proxy;
    IVersionable public versionable;
    IRegisterable public registerable;
    IRegistry public registry;
    address public registryAddress;
    NftId public registryNftId;

    ChainNft public chainNft;

    function _deployRegistry(address implementation) internal
    {
        proxy = new ProxyDeployer();
        // solhint-disable-next-line
        console.log("proxy deployer address", address(proxy));

        bytes memory initializationData = abi.encode(registryOwner);
        versionable = proxy.deploy(implementation, initializationData);

        registryAddress = address(versionable);

        registry = IRegistry(registryAddress);
        registerable = IRegisterable(registryAddress);
        registryNftId = registry.getNftId(registryAddress);

        address chainNftAddress = address(registry.getChainNft());
        chainNft = ChainNft(chainNftAddress);

        // solhint-disable-next-line
        console.log("registry proxy address", registryAddress);
    }

    function _upgradeRegistry(address implementation) internal
    {
        bytes memory upgradeData = abi.encode(uint(0));
        proxy.upgrade(implementation, upgradeData);
    }

    function _checkRegistryGetters(IRegistry implementation, Version version, uint64 initializedVersion, uint256 versionsCount) internal
    {// TODO check for expected reverts
        assertTrue(versionsCount > 0, "version count zero");

        // Versionable
        assertTrue(address(versionable) != address(0), "versionable address is zero");
        assertTrue(versionable.getVersion() == version, "getVersion() returned unxpected value");
        assertTrue(versionable.getVersion(versionsCount - 1) == version, "getVersion(versionsCount - 1) returned unxpected value");//TODO `versionsCount - 1` into string
        assertTrue(versionable.isInitialized(version), "isInitialized(version) returned unxpected value");//TODO substitute version into string
        assertTrue(versionable.getInitializedVersion() == initializedVersion, "getInitializedVersion() returned unxpected value");
        assertTrue(versionable.getVersionCount() == versionsCount, "getVersionCount() returned unxpected value");
        
        IVersionable.VersionInfo memory versionInfo = versionable.getVersionInfo(version);
        assertTrue(versionInfo.version == version, "getVersionInfo(version).version returned unxpected value");//TODO substitute version into string
        assertTrue(versionInfo.implementation == address(implementation), "getVersionInfo(version).implementation returned unxpected value");
        assertTrue(versionInfo.activatedBy == registryOwner, "getVersionInfo(version).activatedBy returned unxpected value");
        assertTrue(versionInfo.activatedAt == blockTimestamp(), "getVersionInfo(version).activatedAt returned unxpected value");
        assertTrue(versionInfo.activatedIn == blockBlocknumber(), "getVersionInfo(version).activatedIn returned unxpected value");

        // ChainNft
        assertNotEq(chainNft.PROTOCOL_NFT_ID(), chainNft.GLOBAL_REGISTRY_ID(), "protocol nft id is equal to global registry nft id");

        // IRegisterable
        assertTrue(registerable.getRegistry() == registry, "getRegistry() returned unxpected value");
        assertTrue(registerable.getNftId() == registryNftId, "getNftId() returned unxpected value #1");
        assertTrue(registerable.getNftId() != toNftId( chainNft.PROTOCOL_NFT_ID() ), "getNftId() returned unexpected value #2");
        assertTrue(registerable.getNftId() != toNftId( chainNft.GLOBAL_REGISTRY_ID() ), "getNftId() returned unexpected value #3");        

        (IRegistry.ObjectInfo memory initialInfo, bytes memory initialData) = registerable.getInitialInfo();
        assertTrue(initialInfo.nftId == registryNftId, "getInitialInfo().nftId returned unexpected value");
        assertTrue(initialInfo.parentNftId == toNftId( chainNft.GLOBAL_REGISTRY_ID() ), "getInitialInfo().parentNftId returned unexpected value");
        assertTrue(initialInfo.objectType == REGISTRY(), "getInitialInfo().objectType returned unexpected value");
        assertTrue(initialInfo.objectAddress == address(registry), "getInitialInfo().objectAddress returned unexpected value");
        assertTrue(initialInfo.initialOwner == registryOwner, "getInitialInfo().initialOwner returned unexpected value");
        //assertTrue(initialInfo.data == bytes(""), "getInitialInfo().data returned unexpected value");
        //assertTrue(initialData == bytes(""), "getInitialInfo() returned unxpected initialData");

        // IRegistry
        assertTrue(registry.allowance(registryNftId, SERVICE()), "allowance(registryNftId, SERVICE()) returned unexpected value");
        assertTrue(registry.allowance(registryNftId, TOKEN()), "allowance(registryNftId, TOKEN()) returned unexpected value");
        assertTrue(registry.getObjectCount() == 3, "getObjectCount() returned unexpected value");
        assertTrue(registry.getNftId(registryAddress) == registryNftId, "getNftId(registryAddress) returned unexpected value");
        //assertTrue(registry.getName(registryNftId) == string(""), "getName(registryNftId) returned unexpected value");
        assertTrue(registry.ownerOf(registryAddress) == registryOwner, "ownerOf(registryAddress) returned unexpected value");
        assertTrue(registry.ownerOf(registryNftId) == registryOwner, "ownerOf(registryNftId) returned unexpected value");
        assertTrue(registry.ownerOf( toNftId( chainNft.PROTOCOL_NFT_ID() ) ) == registryOwner, "ownerOf(protocolNftId) returned unexpected value");
        assertTrue(registry.ownerOf( toNftId( chainNft.GLOBAL_REGISTRY_ID() ) ) == registryOwner, "ownerOf(globalRegistryNftId) returned unexpected value");

        IRegistry.ObjectInfo memory infoByAddress = registry.getObjectInfo(registryAddress);
        assertTrue(infoByAddress.nftId == registryNftId, "getObjectInfo(registryAddress).nftId returned unexpected value");
        assertTrue(infoByAddress.parentNftId == toNftId( chainNft.GLOBAL_REGISTRY_ID() ), "getObjectInfo(registryAddress).parentNftId returned unexpected value");
        assertTrue(infoByAddress.objectType == REGISTRY(), "getObjectInfo(registryAddress).objectType returned unexpected value");
        assertTrue(infoByAddress.objectAddress == registryAddress, "getObjectInfo(registryAddress).objectAddress returned unexpected value");
        assertTrue(infoByAddress.initialOwner == registryOwner, "getObjectInfo(registryAddress).initialOwner returned unexpected value");
        //assertTrue(infoByAddress.data == bytes(""), "getObjectInfo(registryAddress).data returned unexpected value");

        IRegistry.ObjectInfo memory infoByNftId = registry.getObjectInfo(registryNftId);
        assertTrue(infoByNftId.nftId == registryNftId, "getObjectInfo(registryNftId).nftId returned unexpected value");
        assertTrue(infoByNftId.parentNftId == toNftId( chainNft.GLOBAL_REGISTRY_ID() ), "getObjectInfo(registryNftId).parentNftId returned unexpected value");
        assertTrue(infoByNftId.objectType == REGISTRY(), "getObjectInfo(registryNftId).objectType returned unexpected value");
        assertTrue(infoByNftId.objectAddress == registryAddress, "getObjectInfo(registryNftId).objectAddress returned unexpected value");
        assertTrue(infoByNftId.initialOwner == registryOwner, "getObjectInfo(registryNftId).initialOwner returned unexpected value");
        //assertTrue(infoByNftId.data == bytes(""), "getObjectInfo(registryNftId).dara returned unexpected value");

        assertTrue(registry.isRegistered(registryNftId), "isRegistered(registryNftId) returned unexpected value");
        assertTrue(registry.isRegistered( toNftId( chainNft.PROTOCOL_NFT_ID() ) ), "isRegistered(protocolNftId) returned unexpected value");
        assertTrue(registry.isRegistered( toNftId( chainNft.GLOBAL_REGISTRY_ID() ) ), "isRegistered(globalRegistryNftId) returned unexpected value");
        assertTrue(registry.isRegistered(registryAddress), "isRegistered(registryAddress) returned unexpected value");
        //getServiceAddress(string memory serviceName, VersionPart majorVersion)
        assertTrue(registry.getProtocolOwner() == registryOwner, "getProtocolOwner() returned unexpected value");
        //getChainNft()
    }


    // gas cost of initialize: 3020886
    // deployment size 22288 
    function testRegistryV01Deploy() public 
    {
        vm.startPrank(registryOwner);

        Registry implemetationV01 = new Registry();
        _deployRegistry(address(implemetationV01));

        vm.stopPrank();

        _checkRegistryGetters(
            implemetationV01, 
            VersionLib.toVersion(1,0,0), 
            1,//uint64 initializedVersion
            1 //uint256 versionsCount
        );

        Registry registryV01 = Registry(registryAddress); 

        /* solhint-disable */
        console.log("registry deployed at", registryAddress);
        console.log("registry NFT[int]", registryV01.getNftId().toInt()); 
        console.log("registry version[int]", registryV01.getVersion().toInt());
        console.log("registry initialized version[int]", registryV01.getInitializedVersion());
        console.log("registry version count is", registryV01.getVersionCount());
        console.log("registry NFT deployed at", address(registryV01.getChainNft()));
        /* solhint-enable */ 
    }  

    // gas cost of initialize: 3020886  
    // deployment size 22300 
    function testRegistryV02Deploy() public
    {
        vm.startPrank(registryOwner);

        Registry implemetationV02 = new RegistryV02();
        _deployRegistry(address(implemetationV02));

        vm.stopPrank();

        _checkRegistryGetters(
            implemetationV02, 
            VersionLib.toVersion(1,1,0), 
            1,//uint64 initializedVersion
            1 //uint256 versionsCount
        ); 

        RegistryV02 registryV02 = RegistryV02(registryAddress);       

        /* solhint-disable */
        console.log("registry deployed at", registryAddress);
        console.log("registry NFT[int]", registryV02.getNftId().toInt()); 
        console.log("registry version[int]", registryV02.getVersion().toInt());
        console.log("registry initialized version[int]", registryV02.getInitializedVersion());
        console.log("registry version count is", registryV02.getVersionCount());
        console.log("registry NFT deployed at", address(registryV02.getChainNft()));
        /* solhint-enable */ 
    }

    // gas cost of initialize: 3043002  
    // deployment size 22366 
    function testRegistryV03Deploy() public
    {
        vm.startPrank(registryOwner);

        Registry implemetationV03 = new RegistryV03();
        _deployRegistry(address(implemetationV03));

        vm.stopPrank();

        _checkRegistryGetters(
            implemetationV03, 
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
        console.log("registry NFT[int]", registryV03.getNftId().toInt()); 
        console.log("registry version[int]", registryV03.getVersion().toInt());
        console.log("registry initialized version[int]", registryV03.getInitializedVersion());
        console.log("registry version count is", registryV03.getVersionCount());
        console.log("registry NFT deployed at", address(registryV03.getChainNft()));
        /* solhint-enable */ 
    }

    function testRegistryV01DeployAndUpgradeToV02() public
    {
        testRegistryV01Deploy();

        // upgrade
        vm.startPrank(registryOwner);

        RegistryV02 implemetationV02 = new RegistryV02();
        _upgradeRegistry(address(implemetationV02));

        vm.stopPrank();

        _checkRegistryGetters(
            implemetationV02, 
            VersionLib.toVersion(1,1,0), 
            VersionLib.toUint64( VersionLib.toVersion(1,1,0) ),//uint64 initializedVersion
            2 //uint256 versionsCount
        );  

        Registry registryV02 = RegistryV02(registryAddress);

        /* solhint-disable */
        console.log("after upgrade to V02, registry NFT[int]", registryV02.getNftId().toInt()); 
        console.log("after upgrade to V02, registry version[int]", registryV02.getVersion().toInt());
        console.log("after upgrade to V02, registry initialized version[int]", registryV02.getInitializedVersion());
        console.log("after upgrade to V02, registry version count is", registryV02.getVersionCount());
        console.log("after upgrade to V02, registry NFT deployed at", address(registryV02.getChainNft()));
        /* solhint-enable */ 
    }
    
    function testRegistryV01DeployAndUpgradeToV03() public
    {
        testRegistryV01DeployAndUpgradeToV02();

        // upgrade
        vm.startPrank(registryOwner);

        RegistryV03 implemetationV03 = new RegistryV03();
        _upgradeRegistry(address(implemetationV03));

        vm.stopPrank();

        _checkRegistryGetters(
            implemetationV03, 
            VersionLib.toVersion(1,2,0), 
            VersionLib.toUint64( VersionLib.toVersion(1,2,0) ),//uint64 initializedVersion
            3 //uint256 versionsCount
        );

        // check new function(s) 
        RegistryV03 registryV03 = RegistryV03(registryAddress);
        uint v3data = registryV03.getDataV3();

        assertTrue(v3data == type(uint).max, "getDataV3 returned unxpected value");

        /* solhint-disable */
        console.log("after upgrade to V03, registry NFT[int]", registryV03.getNftId().toInt()); 
        console.log("after upgrade to V03, registry version[int]", registryV03.getVersion().toInt());
        console.log("after upgrade to V03, registry initialized version[int]", registryV03.getInitializedVersion());
        console.log("after upgrade to V03, registry version count is", registryV03.getVersionCount());
        console.log("after upgrade to V03, registry NFT deployed at", address(registryV03.getChainNft()));
        /* solhint-enable */ 
    }
}