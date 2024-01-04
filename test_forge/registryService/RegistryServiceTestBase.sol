// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin5/contracts/access/Ownable.sol";
import {IERC721Errors} from "@openzeppelin5/contracts/interfaces/draft-IERC6093.sol";
import {IERC20Metadata} from "@openzeppelin5/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { FoundryRandom } from "foundry-random/FoundryRandom.sol";


import {Test, Vm, console} from "../../lib/forge-std/src/Test.sol";
import {NftId, toNftId, zeroNftId} from "../../contracts/types/NftId.sol";
import {Timestamp, TimestampLib} from "../../contracts/types/Timestamp.sol";
import {Blocknumber, BlocknumberLib} from "../../contracts/types/Blocknumber.sol";
import {ObjectType, toObjectType, ObjectTypeLib, zeroObjectType, PROTOCOL, REGISTRY, TOKEN, SERVICE, INSTANCE, PRODUCT, POOL, ORACLE, DISTRIBUTION, BUNDLE, POLICY, STAKE} from "../../contracts/types/ObjectType.sol";

import {ERC165, IERC165} from "../../contracts/shared/ERC165.sol";

import {IRegisterable} from "../../contracts/shared/IRegisterable.sol";
import {IService} from "../../contracts/instance/base/IService.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {IRegistryService} from "../../contracts/registry/IRegistryService.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {RegistryServiceManager} from "../../contracts/registry/RegistryServiceManager.sol";

import {ServiceMock} from "../mock/ServiceMock.sol";
import {RegisterableMock} from "../mock/RegisterableMock.sol";
import {DIP} from "../mock/DIP.sol";


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

    address public constant NFT_LOCK_ADDRESS = address(0x1); // TOKEN nfts are minted for

    address public registryOwner = makeAddr("registryOwner");
    address public outsider = makeAddr("outsider");
    address public EOA = makeAddr("EOA");
    address public invalidAddress = makeAddr("invalidAddress");

    RegistryServiceManager public registryServiceManager;
    RegistryService public registryService;
    IRegistry public registry;

    NftId public registryNftId;
    NftId public registryServiceNftId;

    address public contractWithoutIERC165 = address(new DIP());
    address public erc165 = address(new ERC165()); 

    RegisterableMock public registerableOwnedByRegistryOwner;
    RegisterableMock public registerableOwnedByOutsider;

    function setUp() public virtual
    {
        vm.startPrank(registryOwner);
        registryServiceManager = new RegistryServiceManager();

        registryService = registryServiceManager.getRegistryService();
        registry = registryServiceManager.getRegistry();
        registryServiceNftId = registry.getNftId(address(registryService));

        registryNftId = registry.getNftId(address(registry));

        registerableOwnedByRegistryOwner = new RegisterableMock(
            address(registry), 
            registryNftId, 
            toObjectType(randomNumber(type(uint96).max)),
            toBool(randomNumber(1)),
            address(uint160(randomNumber(type(uint160).max))),
            ""
        ); 

        vm.stopPrank();
        vm.startPrank(outsider);

        registerableOwnedByOutsider = new RegisterableMock(
            address(registry), 
            registryNftId, 
            toObjectType(randomNumber(type(uint96).max)),
            toBool(randomNumber(1)),
            address(uint160(randomNumber(type(uint160).max))),
            ""
        ); 

        vm.stopPrank();
    }

    /*function _checkRegistryServiceGetters(address registryService, address implementation, Version version, uint64 initializedVersion, uint256 versionsCount)
    {
        _assert_versionable_getters(IVersionable(registryService), implementation, version, initializedVersion, versionsCount);
        _assert_registerable_getters(IRegisterable(registryService), registryService.getRegistry());

        //IService
        assertTrue(Strings.equal(registryService.getName(), "RegistryService"), "getName() returned unexpected value");
        (VersionPart majorVersion, , ) = VersionLib.toVersionParts(version);
        assertEq(registryService.getMajorVersion(), majorVersion, "getMajorVersion() returned unexpected value" );
    }

    function _assert_versionable_getters(IVersionable versionable, address implementation, Version version, uint64 initializedVersion, uint256 versionsCount) internal
    {
        console.log("Checking all IVersionable getters\n");

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
    function _assert_registerable_getters(IRegisterable registerable, address registry) internal
    {
        console.log("Checking all IRegisterable getters\n");

        assertEq(address(registerable.getRegistry()), address(registry), "getRegistry() returned unxpected value");
        // TODO global registry case
        assertEq(registerable.getNftId().toInt(), registryNftId.toInt(), "getNftId() returned unxpected value #1");
        assertNotEq(registerable.getNftId().toInt(), protocolNftId.toInt(), "getNftId() returned unexpected value #2");
        assertNotEq(registerable.getNftId().toInt(), globalRegistryNftId.toInt(), "getNftId() returned unexpected value #3");        

        (IRegistry.ObjectInfo memory initialInfo, bytes memory initialData) = registerable.getInitialInfo();
        assertEq(initialInfo.nftId.toInt(), registryNftId.toInt(), "getInitialInfo().nftId returned unexpected value");
        assertEq(initialInfo.parentNftId.toInt(), globalRegistryNftId.toInt(), "getInitialInfo().parentNftId returned unexpected value");
        assertEq(initialInfo.objectType.toInt(), REGISTRY().toInt(), "getInitialInfo().objectType returned unexpected value");
        assertEq(initialInfo.objectAddress, address(registry), "getInitialInfo().objectAddress returned unexpected value");
        assertEq(initialInfo.initialOwner, registryOwner, "getInitialInfo().initialOwner returned unexpected value");
        assertTrue(initialInfo.data.length == 0, "getInitialInfo().data returned unexpected value");       
    }*/
}