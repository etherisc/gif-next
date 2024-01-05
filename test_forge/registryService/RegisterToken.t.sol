// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, Vm, console} from "../../lib/forge-std/src/Test.sol";
import {VersionLib, Version, VersionPart} from "../../contracts/types/Version.sol";
import {NftId, toNftId, zeroNftId} from "../../contracts/types/NftId.sol";
import {ObjectType, ObjectTypeLib, TOKEN} from "../../contracts/types/ObjectType.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {IRegistryService} from "../../contracts/registry/IRegistryService.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";

import {RegistryServiceTestBase} from "./RegistryServiceTestBase.sol";

contract RegisterTokenTest is RegistryServiceTestBase {

    function test_callByOutsider() public
    {
        vm.prank(outsider);

        vm.expectRevert(abi.encodeWithSelector(RegistryService.NotRegistryOwner.selector)); 

        registryService.registerToken(address(contractWithoutIERC165));  
    }

    function test_selfRegistration() public
    {
        vm.prank(registryOwner);

        vm.expectRevert(abi.encodeWithSelector(RegistryService.SelfRegistration.selector));

        registryService.registerToken(registryOwner);        
    }

    function test_withEOA() public
    {
        vm.startPrank(registryOwner);

        vm.expectRevert(abi.encodeWithSelector(RegistryService.NotToken.selector));

        registryService.registerToken(EOA);

        vm.stopPrank();
    }

    function test_contractWithoutIERC165() public
    {
        vm.prank(registryOwner);

        NftId nftId = registryService.registerToken(address(contractWithoutIERC165));

        IRegistry.ObjectInfo memory info = registry.getObjectInfo(nftId);

        assertEq(registry.getNftId(address(contractWithoutIERC165)).toInt(), nftId.toInt(), "NftId of token registered is different");
        assertEq(info.objectType.toInt(), TOKEN().toInt(), "Type of token registered is not TOKEN");
        assertEq(info.objectAddress, address(contractWithoutIERC165), "Address of token registered is different");
        assertEq(info.initialOwner, NFT_LOCK_ADDRESS, "Initial owner of the token is different");
    }

    function test_withIERC165() public
    {
        vm.prank(registryOwner);

        NftId nftId = registryService.registerToken(address(erc165));

        IRegistry.ObjectInfo memory info = registry.getObjectInfo(nftId);

        assertEq(registry.getNftId(address(erc165)).toInt(), nftId.toInt(), "NftId of token registered is different");
        assertEq(info.objectType.toInt(), TOKEN().toInt(), "Type of token registered is not TOKEN");
        assertEq(info.objectAddress, address(erc165), "Address of token registered is different");
        assertEq(info.initialOwner, NFT_LOCK_ADDRESS, "Initial owner of the token is different");
    }

    function test_withIRegisterable() public
    {
        vm.prank(registryOwner);

        vm.expectRevert(abi.encodeWithSelector(RegistryService.NotToken.selector));

        registryService.registerToken(address(registerableOwnedByRegistryOwner));        
    }
}