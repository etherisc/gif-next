// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccess} from "../../contracts/authorization/IAccess.sol";

import {AccessAdminLib} from "../../contracts/authorization/AccessAdminLib.sol";
import {AccessManagedMock} from "../mock/AccessManagedMock.sol";
import {PUBLIC_ROLE} from "../../contracts/type/RoleId.sol";
import {RegistryAdmin} from "../../contracts/registry/RegistryAdmin.sol";
import {VersionPart} from "../../contracts/type/Version.sol";

contract RegistryAdminEx is RegistryAdmin {

    AccessManagedMock public accessManagedMock;

    function completeSetup(
        address registry,
        address authorization,
        VersionPart release,
        address gifAdmin, 
        address gifManager
    )
        public
        virtual override
    {
        super.completeSetup(
            registry, 
            authorization,
            release,
            gifAdmin, 
            gifManager);

        accessManagedMock = new AccessManagedMock(address(authority()));

        // create target for access managed mock
        _createTarget(
            address(accessManagedMock), 
            "AccessManagedMock", 
            IAccess.TargetType.Component,
            false); // don't check authority

        // grant permissions to public role for access managed mock
        FunctionInfo[] memory functions;
        functions = new FunctionInfo[](1);
        functions[0] = AccessAdminLib.toFunction(AccessManagedMock.increaseCounter1.selector, "increaseCounter1");
        _authorizeTargetFunctions(address(accessManagedMock), PUBLIC_ROLE(), functions, true, false);
    }
}