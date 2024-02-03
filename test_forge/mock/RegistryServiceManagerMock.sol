// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Registry} from "../../contracts/registry/Registry.sol";
import {RegistryServiceManager} from "../../contracts/registry/RegistryServiceManager.sol";
import {RegistryServiceHarness} from "../registryService/RegistryServiceHarness.sol";


contract RegistryServiceManagerMock is RegistryServiceManager
{
    constructor(address initialAuthority, address registry)
        RegistryServiceManager(initialAuthority, registry)
    {
        bytes memory emptyUpgradeData;

        upgrade(
            address(new RegistryServiceHarness()),
            emptyUpgradeData
        );
    }
}
