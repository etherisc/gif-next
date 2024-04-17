// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {FoundryRandom} from "foundry-random/FoundryRandom.sol";


import {Test, Vm, console} from "../../lib/forge-std/src/Test.sol";
import {NftId, toNftId, zeroNftId} from "../../contracts/type/NftId.sol";
import {VersionPart, VersionPartLib } from "../../contracts/type/Version.sol";
import {Timestamp, TimestampLib} from "../../contracts/type/Timestamp.sol";
import {Blocknumber, BlocknumberLib} from "../../contracts/type/Blocknumber.sol";
import {ObjectType, toObjectType, ObjectTypeLib, zeroObjectType, TOKEN} from "../../contracts/type/ObjectType.sol";

import {ERC165, IERC165} from "../../contracts/shared/ERC165.sol";

import {RegistryAccessManager} from "../../contracts/registry/RegistryAccessManager.sol";
import {ReleaseManager} from "../../contracts/registry/ReleaseManager.sol";
import {RegistryServiceManager} from "../../contracts/registry/RegistryServiceManager.sol";
import {IRegistryService} from "../../contracts/registry/IRegistryService.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";

import {IService} from "../../contracts/shared/IService.sol";

import {IRegisterable} from "../../contracts/shared/IRegisterable.sol";

import {Dip} from "../mock/Dip.sol";
import {ServiceMock} from "../mock/ServiceMock.sol";
import {RegisterableMock} from "../mock/RegisterableMock.sol";


// Helper functions to test IRegistry.ObjectInfo structs 
function eqObjectInfo(IRegistry.ObjectInfo memory a, IRegistry.ObjectInfo memory b) pure returns (bool isSame) {
    return (
        (a.nftId == b.nftId) &&
        (a.parentNftId == b.parentNftId) &&
        (a.objectType == b.objectType) &&
        (a.objectAddress == b.objectAddress) &&
        (a.initialOwner == b.initialOwner) &&
        (a.data.length == b.data.length) &&
        keccak256(a.data) == keccak256(b.data)
    );
}

function zeroObjectInfo() pure returns (IRegistry.ObjectInfo memory) {
    return (
        IRegistry.ObjectInfo(
            zeroNftId(),
            zeroNftId(),
            zeroObjectType(),
            false,
            address(0),
            address(0),
            bytes("")
        )
    );
}

function toBool(uint256 uintVal) pure returns (bool boolVal)
{
    assembly {
        boolVal := uintVal
    }
}

contract RegistryServiceTestBase is Test, FoundryRandom {

    address public constant NFT_LOCK_ADDRESS = address(0x1);

    address public registryOwner = makeAddr("registryOwner");// owns all services
    address public outsider = makeAddr("outsider");
    address public EOA = makeAddr("EOA");

    RegistryAccessManager accessManager;
    ReleaseManager releaseManager;
    RegistryServiceManager public registryServiceManager;
    RegistryService public registryService;
    IRegistry public registry;

    NftId public registryNftId;
    NftId public registryServiceNftId;

    IService componentOwnerService;

    address public contractWithoutIERC165 = address(new Dip());
    address public erc165 = address(new ERC165()); 

    RegisterableMock public registerableOwnedByRegistryOwner;

    function setUp() public virtual
    {
        vm.startPrank(registryOwner);

        _deployRegistryServiceAndRegistry();

        _deployAndRegisterServices();

        registerableOwnedByRegistryOwner = new RegisterableMock(
            zeroNftId(), 
            registryNftId, 
            toObjectType(randomNumber(type(uint8).max)),
            toBool(randomNumber(1)),
            registryOwner, 
            ""
        );

        vm.stopPrank();
    }

    function _deployRegistryServiceAndRegistry() internal
    {
        accessManager = new RegistryAccessManager(registryOwner);

        releaseManager = new ReleaseManager(
            accessManager,
            VersionPartLib.toVersionPart(3));

        registry = IRegistry(releaseManager.getRegistryAddress());
        registryNftId = registry.getNftId(address(registry));

        registryServiceManager = new RegistryServiceManager(
            accessManager.authority(),
            address(registry)
        );        
        
        registryService = registryServiceManager.getRegistryService();

        address tokenRegistry;
        accessManager.initialize(address(releaseManager), tokenRegistry);

        releaseManager.createNextRelease();

        registryServiceNftId = registry.getNftId(address(registryService));

        // registryServiceManager.linkToNftOwnable(address(registry));// links to registry service
    }

    function _deployAndRegisterServices() internal
    {
        releaseManager.registerService(componentOwnerService);
    }

    function _assert_registered_token(address token, NftId nftIdFromRegistryService) internal
    {
        IRegistry.ObjectInfo memory info = registry.getObjectInfo(token);

        assertEq(info.nftId.toInt(), nftIdFromRegistryService.toInt(), "NftId of token registered is different");
        assertEq(info.parentNftId.toInt(), registryNftId.toInt(), "Parent of token registered is not registry");
        assertEq(info.objectType.toInt(), TOKEN().toInt(), "Type of token registered is not TOKEN");
        assertEq(info.objectAddress, token, "Address of token registered is different");
        assertEq(info.initialOwner, NFT_LOCK_ADDRESS, "Initial owner of the token is different");
    }

    function _assert_registered_contract(
        address registeredContract, 
        IRegistry.ObjectInfo memory infoFromRegistryService, 
        bytes memory dataFromRegistryService) 
        internal
    {
        IRegistry.ObjectInfo memory infoFromRegistry = registry.getObjectInfo(registeredContract);
        IRegistry.ObjectInfo memory infoFromRegisterable = IRegisterable(registeredContract).getInitialInfo();

        infoFromRegisterable.nftId = infoFromRegistry.nftId; // initial value is random
        infoFromRegisterable.objectAddress = registeredContract;// registry enforces objectAddress 

        assertTrue(eqObjectInfo(infoFromRegistry, infoFromRegistryService), 
            "Info from registry is different from info in registry service");
        assertTrue(eqObjectInfo(infoFromRegistry, infoFromRegisterable), 
            "Info from registry is different from info in registered contract");
    }

    function _assert_registered_object(IRegistry.ObjectInfo memory objectInfo) internal 
    {
        IRegistry.ObjectInfo memory infoFromRegistry = registry.getObjectInfo(objectInfo.nftId);

        assertEq(infoFromRegistry.objectAddress, address(0), "Object has non zero address");
        assertTrue(eqObjectInfo(infoFromRegistry, objectInfo), 
            "Info from registry is different from object info");
    }

    /*function _checkRegistryServiceGetters(address implementation, Version version, uint64 initializedVersion, uint256 versionsCount) internal
    {
        _assert_versionable_getters(IVersionable(registryService), implementation, version, initializedVersion, versionsCount);
        _assert_registerable_getters(IRegisterable(registryService), registryService.getRegistry());
        _assert_nftownable_getters(INftOwnable(registryService));

        //IService
        assertTrue(Strings.equal(registryService.getName(), "RegistryService"), "getName() returned unexpected value");
        (VersionPart majorVersion, , ) = VersionLib.toVersionParts(version);
        assertEq(registryService.getMajorVersion(), majorVersion, "getMajorVersion() returned unexpected value" );
    }

    function _assert_versionableGetters(address implementation, Version version, uint64 initializedVersion, uint256 versionsCount) internal
    {
        IVersionable versionable = IVersionable(address(registryService));

        assertNotEq(address(versionable), address(0), "test parameter error: versionable address is zero");
        assertNotEq(implementation, address(0), "test parameter error: implementation address is zero");
        assertNotEq(version.toInt(), 0, "test parameter error: version is zero");
        assertNotEq(initializedVersion, 0, "test parameter error: initialized version is zero");
        assertNotEq(versionsCount, 0, "test parameter error: version count is zero");

        
        assertEq(versionable.getVersion().toInt(), version.toInt(), "getVersion() returned unxpected value");
        assertEq(versionable.getVersion(versionsCount - 1).toInt(), version.toInt(), "getVersion(versionsCount - 1) returned unxpected value");
        assertTrue(versionable.isInitialized(version), "isInitialized(version) returned unxpected value");
        assertEq(versionable.getInitializedVersion(), initializedVersion, "getInitializedVersion() returned unxpected value");
        assertEq(versionable.getVersionCount(), versionsCount, "getVersionCount() returned unxpected value");
        
        IVersionable.VersionInfo memory versionInfo = versionable.getVersionInfo(version);
        assertEq(versionInfo.version.toInt(), version.toInt(), "getVersionInfo(version).version returned unxpected value");
        assertEq(versionInfo.implementation, implementation, "getVersionInfo(version).implementation returned unxpected value");
        assertEq(versionInfo.activatedBy, registryOwner, "getVersionInfo(version).activatedBy returned unxpected value");
        assertEq(TimestampLib.toInt(versionInfo.activatedAt), TimestampLib.toInt(blockTimestamp()), "getVersionInfo(version).activatedAt returned unxpected value");
        assertEq(BlocknumberLib.toInt(versionInfo.activatedIn), BlocknumberLib.toInt(blockBlocknumber()), "getVersionInfo(version).activatedIn returned unxpected value");        
    }
    function _assert_registerableGetters(IRegistry.ObjectInfo info) internal
    {
        IRegisterable registerable = IRegisterable(address(registryService));

        assertEq(address(registerable.getRegistry()), address(registry), "getRegistry() returned unxpected value");
        // TODO global registry case
        assertEq(registerable.getNftId().toInt(), info.nftId.toInt(), "getNftId() returned unxpected value #1");

        (IRegistry.ObjectInfo memory infoFromRegisterable, bytes memory dataFromRegisterable) = registerable.getInitialInfo();
        IRegistry.ObjectInfo infoFromRegistry = registry.getObjectInfo(registryServiceNftId);
        
        assertTrue(eqObjectInfo(info, infoFromRegisterable), "getInitialInfo() returned unexpected value");
        assertTrue(eqObjectInfo(infoFromRegistry, infoFromRegisterable), "getInitialInfo() returned unexpected value");
    }*/
}