// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Registry} from "../../contracts/registry/Registry.sol";
import {RegistryServiceManager} from "../../contracts/registry/RegistryServiceManager.sol";
import {RegistryServiceHarness} from "../registryService/RegistryServiceHarness.sol";
import {RegistryServiceMock} from "./RegistryServiceMock.sol";

// TODO add service manager mock with service with configurable domain and version -> pure getVersion() and getDomain() prevents this
contract RegistryServiceManagerMock is RegistryServiceManager
{
    constructor(address initialAuthority, address registry, bytes32 salt)
        RegistryServiceManager(initialAuthority, registry, salt)
    {
        bytes memory emptyUpgradeData;

        upgrade(
            address(new RegistryServiceMock()),
            emptyUpgradeData
        );
    }
}


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