// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

import {Registry} from "../contracts/registry/Registry.sol";

contract DeployRegistry is Script {

    function run() external returns (Registry) {

        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = HelperConfig.NetworkConfig(helperConfig.activeNetworkConfig());
        address dipAddress = config.dipAddress;

        vm.startBroadcast();
        Registry registry = new Registry();
        vm.stopBroadcast();

        console.log("registry deployed at ", address(registry));

        return registry;
    }

}