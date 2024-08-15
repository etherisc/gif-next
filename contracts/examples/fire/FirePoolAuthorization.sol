

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {BasicPoolAuthorization} from "../../pool/BasicPoolAuthorization.sol";
import {FirePool} from "./FirePool.sol";
import {IAccess} from "../../../contracts/authorization/IAccess.sol";
import {PUBLIC_ROLE} from "../../../contracts/type/RoleId.sol";

contract FirePoolAuthorization
    is BasicPoolAuthorization
{

    constructor(string memory poolName)
        BasicPoolAuthorization(poolName)
    {}


    function _setupTargetAuthorizations()
        internal
        virtual override
    {
        super._setupTargetAuthorizations();
        IAccess.FunctionInfo[] storage functions;

        // authorize public role (open access to any account, only allows to lock target)
        functions = _authorizeForTarget(getTargetName(), PUBLIC_ROLE());
        // TODO: FirePool.createBundle must require a custom role (e.g. INVESTOR) instead of PUBLIC_ROLE
        _authorize(functions, FirePool.approveTokenHandler.selector, "approveTokenHandler");
        _authorize(functions, FirePool.createBundle.selector, "createBundle");
    }

}

