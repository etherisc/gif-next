// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

import {Registry} from "../contracts/registry/Registry.sol";
import {Instance} from "../contracts/instance/Instance.sol";
import {ComponentOwnerService} from "../contracts/instance/component/ComponentModule.sol";

contract DeployInstance is Script {

    function run(
        Registry registry, 
        address instanceOwner
    ) external returns (Instance) {

        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = HelperConfig.NetworkConfig(helperConfig.activeNetworkConfig());
        address dipAddress = config.dipAddress;

        vm.startBroadcast();
        ComponentOwnerService cos = new ComponentOwnerService();
        Instance instance = new Instance(address(registry), address(cos));

        uint256 nftId = instance.register();
        registry.transfer(nftId, instanceOwner);
        vm.stopBroadcast();

        return instance;
    }

}