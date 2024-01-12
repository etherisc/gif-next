// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import { FoundryRandom } from "foundry-random/FoundryRandom.sol";


import {Test, Vm, console} from "../../lib/forge-std/src/Test.sol";
import {Version, VersionPart, VersionLib} from "../../contracts/types/Version.sol";
import {NftId, toNftId, zeroNftId} from "../../contracts/types/NftId.sol";
import {Timestamp, TimestampLib} from "../../contracts/types/Timestamp.sol";
import {Blocknumber, BlocknumberLib} from "../../contracts/types/Blocknumber.sol";
import {ObjectType, toObjectType, ObjectTypeLib, zeroObjectType, SERVICE} from "../../contracts/types/ObjectType.sol";

import {ERC165, IERC165} from "../../contracts/shared/ERC165.sol";

import {IVersionable} from "../../contracts/shared/IVersionable.sol";
import {IRegisterable} from "../../contracts/shared/IRegisterable.sol";
import {IService} from "../../contracts/shared/IService.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {IRegistryService} from "../../contracts/registry/IRegistryService.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {RegistryServiceManager} from "../../contracts/registry/RegistryServiceManager.sol";

import {ServiceMock} from "../mock/ServiceMock.sol";
import {RegisterableMock} from "../mock/RegisterableMock.sol";
import {DIP} from "../mock/Dip.sol";


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

    address public registryOwner = makeAddr("registryOwner");
    address public outsider = makeAddr("outsider");
    address public EOA = makeAddr("EOA");
    address public invalidAddress = makeAddr("invalidAddress");

    RegistryServiceManager public registryServiceManager;
    AccessManager accessManager;
    RegistryService public registryService;
    IRegistry public registry;

    NftId public registryNftId;
    NftId public registryServiceNftId;

    address public contractWithoutIERC165 = address(new DIP());
    address public erc165 = address(new ERC165()); 

    RegisterableMock public registerableOwnedByRegistryOwner;

    function setUp() public virtual
    {
        vm.startPrank(registryOwner);
        accessManager = new AccessManager(registryOwner);
        registryServiceManager = new RegistryServiceManager(address(accessManager));
        registryService = registryServiceManager.getRegistryService();
        registry = registryServiceManager.getRegistry();

        registryServiceNftId = registry.getNftId(address(registryService));
        registryNftId = registry.getNftId(address(registry));

        registerableOwnedByRegistryOwner = new RegisterableMock(
            address(registry), 
            registryNftId, 
            toObjectType(randomNumber(type(uint8).max)),
            toBool(randomNumber(1)),
            address(uint160(randomNumber(type(uint160).max))),
            ""
        ); 

        vm.stopPrank();
    }

    function _assert_registered_contract(
        address registerable, 
        IRegistry.ObjectInfo memory infoFromRegistryService, 
        bytes memory dataFromRegistryService) 
        public
    {
        IRegistry.ObjectInfo memory infoFromRegistry = registry.getObjectInfo(infoFromRegistryService.nftId);

        (
            IRegistry.ObjectInfo memory infoFromRegisterable,
            bytes memory dataFromRegisterable
        ) = IRegisterable(registerable).getInitialInfo();

        infoFromRegisterable.objectAddress = address(registerable);

        assertTrue(eqObjectInfo(infoFromRegistry, infoFromRegistryService), 
            "Info from registry is different from info in registry service");
        assertTrue(eqObjectInfo(infoFromRegistry, infoFromRegisterable), 
            "Info from registry is different from info in registerable");
        assertEq(dataFromRegistryService, dataFromRegisterable, 
            "Data from registry service is different from data in registerable");
    }

    /*function _assert_registryServiceGetters(address owner, address implementation, Version version, uint64 initializedVersion, uint256 versionsCount) internal
    {
        _assert_versionableGetters(implementation, version, initializedVersion, versionsCount);
        _assert_registerableGetters(IRegistry.ObjectInfo(
            registryServiceNftId, 
            registryNftId, 
            SERVICE(),
            address(registryService),
            owner,
            ""));

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