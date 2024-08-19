// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {BasicProductAuthorization} from "../../product/BasicProductAuthorization.sol";
import {IAccess} from "../../authorization/IAccess.sol";
import {PUBLIC_ROLE} from "../../type/RoleId.sol";
import {SimpleProduct} from "./SimpleProduct.sol";

contract SimpleProductAuthorization
    is BasicProductAuthorization
{
    constructor(string memory componentName)
        BasicProductAuthorization(componentName)
    {}

    function _setupTargetAuthorizations()
        internal
        virtual override
    {
        super._setupTargetAuthorizations();

        // authorize public role (open access to any account, only allows to lock target)
        IAccess.FunctionInfo[] storage functions;
        functions = _authorizeForTarget(getMainTargetName(), PUBLIC_ROLE());
        _authorize(functions, SimpleProduct.approveTokenHandler.selector, "approveTokenHandler");
        _authorize(functions, SimpleProduct.setWallet.selector, "setWallet");
    }
}