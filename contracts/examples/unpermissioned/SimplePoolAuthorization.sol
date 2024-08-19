// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {BasicPoolAuthorization} from "../../pool/BasicPoolAuthorization.sol";
import {IAccess} from "../../authorization/IAccess.sol";
import {PUBLIC_ROLE} from "../../type/RoleId.sol";
import {SimplePool} from "./SimplePool.sol";

contract SimplePoolAuthorization
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

        // authorize public role (open access to any account, only allows to lock target)
        IAccess.FunctionInfo[] storage functions;
        functions = _authorizeForTarget(getMainTargetName(), PUBLIC_ROLE());
        _authorize(functions, SimplePool.approveTokenHandler.selector, "approveTokenHandler");
        _authorize(functions, SimplePool.setWallet.selector, "setWallet");
    }
}