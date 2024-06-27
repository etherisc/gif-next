// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {GIF_ADMIN_ROLE} from "../type/RoleId.sol";

import {IGlobalRegistry} from "./IGlobalRegistry.sol";
import {RegistryAdmin} from "./RegistryAdmin.sol";
import {MainnetContract} from "../shared/MainnetContract.sol";


contract GlobalRegistryAdmin is
    MainnetContract,
    RegistryAdmin
{
    error ErrorGlobalRegistryAdminDeploymentNotOnMainnet();

    constructor() RegistryAdmin() 
    { 
        if(block.chainid != 1) {
            revert ErrorGlobalRegistryAdminDeploymentNotOnMainnet();
        }
    }

    function _setupRegistry()
        internal
        override
        onlyInitializing()
    {
        super._setupRegistry();

        // global registry function authorization for gif admin role
        FunctionInfo[] memory functions;
        functions = new FunctionInfo[](1);
        functions[0] = toFunction(IGlobalRegistry.registerChainRegistry.selector, "registerChainRegistry");

        _authorizeTargetFunctions(_registry, GIF_ADMIN_ROLE(), functions);
    }
}