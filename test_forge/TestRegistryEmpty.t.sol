// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import "../lib/forge-std/src/Test.sol";
import {console} from "../lib/forge-std/src/Script.sol";

import {DeployRegistry} from "../scripts/DeployRegistry.s.sol";

import {Registry} from "../contracts/registry/Registry.sol";

contract TestRegistryEmpty is Test {

    Registry registry;
    address registryOwner = makeAddr("registryOwner");
    
    function setUp() external {
        DeployRegistry dr = new DeployRegistry();
        registry = dr.run();
    }

    function testRegistryEmptyCount() public {
        assertEq(registry.getObjectCount(), 0, "getObjectCount not 0");
    }
}
