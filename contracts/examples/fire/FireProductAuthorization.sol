// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {BasicProductAuthorization} from "../../product/BasicProductAuthorization.sol";
import {FireProduct} from "./FireProduct.sol";
import {IAccess} from "../../../contracts/authorization/IAccess.sol";
import {PUBLIC_ROLE} from "../../../contracts/type/RoleId.sol";


contract FireProductAuthorization
    is BasicProductAuthorization
{

    constructor(string memory poolName)
        BasicProductAuthorization(poolName)
    {}

    function _setupTargetAuthorizations()
        internal
        virtual override
    {
        super._setupTargetAuthorizations();
        IAccess.FunctionInfo[] storage functions;

        // authorize public role (open access to any account, only allows to lock target)
        functions = _authorizeForTarget(getTargetName(), PUBLIC_ROLE());
        _authorize(functions, FireProduct.createApplication.selector, "createApplication");
    }

}

