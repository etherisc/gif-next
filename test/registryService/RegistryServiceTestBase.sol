// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {FoundryRandom} from "foundry-random/FoundryRandom.sol";


import {Vm, console} from "../../lib/forge-std/src/Test.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {VersionPart, VersionPartLib } from "../../contracts/type/Version.sol";
import {Timestamp, TimestampLib} from "../../contracts/type/Timestamp.sol";
import {Blocknumber, BlocknumberLib} from "../../contracts/type/Blocknumber.sol";
import {ObjectType, toObjectType, ObjectTypeLib, zeroObjectType, TOKEN} from "../../contracts/type/ObjectType.sol";
import {RoleId} from "../../contracts/type/RoleId.sol";

import {ERC165, IERC165} from "../../contracts/shared/ERC165.sol";

import {RegistryAdmin} from "../../contracts/registry/RegistryAdmin.sol";
import {ReleaseManager} from "../../contracts/registry/ReleaseManager.sol";
import {RegistryServiceManager} from "../../contracts/registry/RegistryServiceManager.sol";
import {IRegistryService} from "../../contracts/registry/IRegistryService.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";

import {IService} from "../../contracts/shared/IService.sol";

import {IRegisterable} from "../../contracts/shared/IRegisterable.sol";

import {Dip} from "../../contracts/mock/Dip.sol";
import {ServiceMock} from "../mock/ServiceMock.sol";
import {RegisterableMock} from "../mock/RegisterableMock.sol";

import {RegistryTestBase} from "../registry/RegistryTestBase.sol";
import {GifTest} from "../base/GifTest.sol";
import {RegistryServiceTestConfig} from "./RegistryServiceTestConfig.sol";


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
            NftIdLib.zero(),
            NftIdLib.zero(),
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

contract RegistryServiceTestBase is GifTest, FoundryRandom {

    address public EOA = makeAddr("EOA");

    NftId public registryServiceNftId;

    IService componentOwnerService;

    address public contractWithoutIERC165 = address(new Dip());
    address public erc165 = address(new ERC165()); 

    function _deployRegistryService() internal
    {
        //bytes32 salt = "0x1111";

        RegistryServiceTestConfig config = new RegistryServiceTestConfig(
            releaseManager,
            type(RegistryServiceManager).creationCode,
            type(RegistryService).creationCode, 
            registryOwner,
            VersionPartLib.toVersionPart(3),
            "0x1111");//salt);

        (
            address[] memory serviceAddresses,
            string[] memory serviceNames,
            RoleId[][] memory serviceRoles,
            string[][] memory serviceRoleNames,
            RoleId[][] memory functionRoles,
            string[][] memory functionRoleNames,
            bytes4[][][] memory selectors
        ) = config.getConfig();

        releaseManager.createNextRelease();

        (
            address releaseAccessManager,
            VersionPart releaseVersion,
            bytes32 releaseSalt
        ) = releaseManager.prepareNextRelease(
            serviceAddresses, 
            serviceNames, 
            serviceRoles, 
            serviceRoleNames,
            functionRoles,
            functionRoleNames,
            selectors, 
            "0x1111");//salt);

        registryServiceManager = new RegistryServiceManager{salt: releaseSalt}(
            releaseAccessManager,
            registryAddress,
            releaseSalt);
        registryService = registryServiceManager.getRegistryService();
        releaseManager.registerService(registryService);

        releaseManager.activateNextRelease();
        
        registryServiceManager.linkToProxy();
    }
/*
    function _deployAndRegisterServices() internal {
        releaseManager.registerService(componentOwnerService);
    }
*/
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

        eqObjectInfo(infoFromRegistry, infoFromRegistryService);
        eqObjectInfo(infoFromRegistry, infoFromRegisterable);
    }

    function _assert_registered_object(IRegistry.ObjectInfo memory objectInfo) internal 
    {
        IRegistry.ObjectInfo memory infoFromRegistry = registry.getObjectInfo(objectInfo.nftId);

        assertEq(infoFromRegistry.objectAddress, address(0), "Object has non zero address");
        eqObjectInfo(infoFromRegistry, objectInfo);
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