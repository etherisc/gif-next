// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

contract MainnetId
{
    uint constant public MAINNET_CHAIN_ID = 1;
}

contract MainnetContract is MainnetId
{
    error ErrorDeploymentContractForMainnetOnly();

    constructor() {
        if(block.chainid != MAINNET_CHAIN_ID) {
            revert ErrorDeploymentContractForMainnetOnly();
        }
    }
}

contract SidenetContract is MainnetId
{
    error ErrorDeploymentContractForSidenetOnly();

    constructor() {
        if(block.chainid == MAINNET_CHAIN_ID) {
            revert ErrorDeploymentContractForSidenetOnly();
        }
    }
}