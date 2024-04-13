// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Registry} from "../../contracts/registry/Registry.sol";
import {RegistryServiceManager} from "../../contracts/registry/RegistryServiceManager.sol";
import {RegistryServiceHarness} from "../registryService/RegistryServiceHarness.sol";
import {RegistryServiceMockWithSimpleConfig} from "./RegistryServiceMock.sol";


contract RegistryServiceManagerMockWithHarness is RegistryServiceManager
{
    constructor(address initialAuthority, address registry, bytes32 salt)
        RegistryServiceManager(initialAuthority, registry, salt)
    {
        bytes memory emptyUpgradeData;

        upgrade(
            address(new RegistryServiceHarness()),
            emptyUpgradeData
        );
    }
}


contract RegistryServiceManagerMockWithConfig is RegistryServiceManager
{
    constructor(address initialAuthority, address registry, bytes32 salt)
        RegistryServiceManager(initialAuthority, registry, salt)
    {
        bytes memory emptyUpgradeData;

        upgrade(
            address(new RegistryServiceMockWithSimpleConfig()),
            emptyUpgradeData
        );
    }
}