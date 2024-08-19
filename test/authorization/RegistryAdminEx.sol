// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagedMock} from "../mock/AccessManagedMock.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {PUBLIC_ROLE} from "../../contracts/type/RoleId.sol";
import {RegistryAdmin} from "../../contracts/registry/RegistryAdmin.sol";

contract RegistryAdminEx is RegistryAdmin {

    AccessManagedMock public accessManagedMock;

    function completeSetup(
        IRegistry registry,
        address gifAdmin, 
        address gifManager
    )
        public
        virtual override
    {
        super.completeSetup(registry, gifAdmin, gifManager);

        accessManagedMock = new AccessManagedMock(address(authority()));

        // create target for access managed mock
        _createTarget(address(accessManagedMock), "AccessManagedMock", false, false);

        // grant permissions to public role for access managed mock
        FunctionInfo[] memory functions;
        functions = new FunctionInfo[](1);
        functions[0] = toFunction(AccessManagedMock.increaseCounter1.selector, "increaseCounter1");
        _authorizeTargetFunctions(address(accessManagedMock), PUBLIC_ROLE(), functions);
    }
}