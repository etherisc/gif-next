// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import "../lib/forge-std/src/Test.sol";
import {console} from "../lib/forge-std/src/Script.sol";

import {DeployRegistry} from "../scripts/DeployRegistry.s.sol";
import {DeployInstance} from "../scripts/DeployInstance.s.sol";

import {Registry} from "../contracts/registry/Registry.sol";
import {Instance} from "../contracts/instance/Instance.sol";

contract TestInstanceEmpty is Test {

    Registry registry;
    Instance instance;
    address instanceOwner = makeAddr("instanceOwner");
    
    function setUp() external {
        DeployRegistry dr = new DeployRegistry();
        registry = dr.run();

        DeployInstance di = new DeployInstance();
        instance = di.run(registry, instanceOwner);
    }

    function testRegistryCount() public {
        assertEq(registry.getObjectCount(), 1, "getObjectCount not 1");
    }

    function testRegistryNftId() public {
        uint256 nftId = registry.getNftId(address(instance));
        assertEq(nftId, 1, "getNftId not 1");
        assertEq(nftId, instance.getNftId(), "registry and instance nft id differ");
    }

    function testInstanceOwner() public {
        uint256 instanceId = registry.getNftId(address(instance));
        assertEq(registry.getOwner(instanceId), instanceOwner, "unexpected instance owner");
    }
}
