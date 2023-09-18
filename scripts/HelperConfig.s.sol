// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Script} from "../lib/forge-std/src/Script.sol";

// import mocks
import {DIP} from "../contracts/mock/Dip.sol";

contract HelperConfig is Script {

    struct NetworkConfig {
        address dipAddress;
    }

    NetworkConfig public activeNetworkConfig;


    constructor() {
        if (block.chainid == 1) {
            activeNetworkConfig = getMainnetConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }


    function getMainnetConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            // https://etherscan.io/address/0xc719d010b63e5bbf2c0551872cd5316ed26acd83
            dipAddress: 0xc719d010B63E5bbF2C0551872CD5316ED26AcD83
        });
    }


    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.dipAddress != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        DIP dip = new DIP();
        vm.stopBroadcast();

        return NetworkConfig({
            dipAddress: address(dip)
        });
    }
}