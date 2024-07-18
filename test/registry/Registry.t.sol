// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

import {Test, Vm, console} from "../../lib/forge-std/src/Test.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {RegistryTestBase} from "./RegistryTestBase.sol";
import {RegistryTestBaseWithPreset} from "./RegistryTestBaseWithPreset.sol";

contract RegistryTest 
{
/*
    testRegistry_deployChainRegistryAtGlobalRegistryAddress() public
    {
        uint64 chainId;

        do {
            chainId = uint64(randomNumber(type(uint64).max));
        } while (chainId <= 1);

        // calculate global registry address
        bytes32 salt = bytes32(randomNumber(type(uint256).max));
        address globalRegistryAdderss = Create2.computeAddress(
            salt,
            type(Registry).creationCode.hash
            address(createX)
        );

        // deploy on mainnet
        vm.chainId(1);

        RegistryAdmin registryAdminMainnet = new RegistryAdmin{salt: salt}();

        Registry globalRegistry = createX.deployCreate2AndInit(
            type(Registry).creationCode,
            abi.encodeWithSelector(Registry.initialize, address(registryAdminMainnet), globalRegistryAddress),
            0//Values memory values
        );

        // deploy on random chain id
        // TODO will it allow to register to the same address after vm.chainId was changed ???
        // TODO in case if deployed with "create1" will the nonce be changed with after vm.chainId was changed ???
        vm.chainId(chainId);

        RegistryAdmin registryAdmin = new RegistryAdmin{salt: salt}();

        Registry chainRegistry = createX.deployCreate2AndInit(
            type(Registry).creationCode,
            abi.encodeWithSelector(Registry.initialize, address(registryAdminMainnet), globalRegistryAddress),
            0//Values memory values
        );

        assertTrue(address(registryAdminMainnet) == address(registryAdmin), "RegistryAdmin address mismatch");
        assertTrue(address(globalRegistry) == address(chainRegistry), "Global registry address mismatch");
    }
    */
}