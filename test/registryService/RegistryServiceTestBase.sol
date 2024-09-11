// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {FoundryRandom} from "foundry-random/FoundryRandom.sol";


import {Vm, console} from "../../lib/forge-std/src/Test.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {VersionPart, VersionPartLib } from "../../contracts/type/Version.sol";
import {Timestamp, TimestampLib} from "../../contracts/type/Timestamp.sol";
import {Blocknumber, BlocknumberLib} from "../../contracts/type/Blocknumber.sol";
import {ObjectType, ObjectTypeLib} from "../../contracts/type/ObjectType.sol";
import {RoleId} from "../../contracts/type/RoleId.sol";

import {InitializableERC165} from "../../contracts/shared/InitializableERC165.sol";
import {IService} from "../../contracts/shared/IService.sol";
import {IRegisterable} from "../../contracts/shared/IRegisterable.sol";

import {IAccessAdmin} from "../../contracts/authorization/IAccessAdmin.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {IRegistryService} from "../../contracts/registry/IRegistryService.sol";
import {RegistryAdmin} from "../../contracts/registry/RegistryAdmin.sol";
import {RegistryServiceManager} from "../../contracts/registry/RegistryServiceManager.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {ServiceAuthorizationV3} from "../../contracts/registry/ServiceAuthorizationV3.sol";

import {Dip} from "../../contracts/mock/Dip.sol";
import {ServiceMock} from "../mock/ServiceMock.sol";
import {RegisterableMock} from "../mock/RegisterableMock.sol";

import {RegistryTestBase} from "../registry/RegistryTestBase.sol";
import {GifTest} from "../base/GifTest.sol";



contract RegistryServiceTestBase is GifTest, FoundryRandom {

    address public EOA = makeAddr("EOA");

    IService componentOwnerService;

    address public contractWithoutIERC165 = address(new Dip());
    address public erc165 = address(new InitializableERC165()); 

    function _deployRegistryService() internal
    {
        bytes32 salt = "0x1111";

        releaseRegistry.createNextRelease();

        (
            IAccessAdmin releaseAdmin,
            VersionPart releaseVersion,
            bytes32 releaseSalt
        ) = releaseRegistry.prepareNextRelease(
            new ServiceAuthorizationV3("85b428cbb5185aee615d101c2554b0a58fb64810"),
            salt);

        registryServiceManager = new RegistryServiceManager{salt: releaseSalt}(
            releaseAdmin.authority(),
            registryAddress,
            releaseSalt);
        registryService = registryServiceManager.getRegistryService();
        releaseRegistry.registerService(registryService);

        releaseRegistry.activateNextRelease();
        
        registryServiceManager.linkToProxy();
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
}