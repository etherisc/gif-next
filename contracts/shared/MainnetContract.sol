// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

contract MainnetContract
{
    error ErrorDeploymentContractForMainnetOnly();

    uint constant public MAINNET_CHAIN_ID = 1;

    constructor() {
        if(block.chainid != MAINNET_CHAIN_ID) {
            revert ErrorDeploymentContractForMainnetOnly();
        }
    }
}