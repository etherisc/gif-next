// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {console} from "../../lib/forge-std/src/Script.sol";

import {Registry} from "../../contracts/registry/Registry.sol";
import {Instance} from "../../contracts/instance/Instance.sol";

contract DeployInstance {

    function run(Registry registry) external virtual returns (Instance instance) {
        instance = new Instance(
            address(registry), 
            registry.getNftId());
        instance.register();

        console.log("instance deployed at", address(instance));
    }
}