// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {BasicDistributionAuthorization} from "../../distribution/BasicDistributionAuthorization.sol";
import {IAccess} from "../../authorization/IAccess.sol";
import {PUBLIC_ROLE} from "../../type/RoleId.sol";
import {SimpleDistribution} from "./SimpleDistribution.sol";

contract SimpleDistributionAuthorization
    is BasicDistributionAuthorization
{
    constructor(string memory componentName)
        BasicDistributionAuthorization(componentName)
    {}

    function _setupTargetAuthorizations()
        internal
        virtual override
    {
        super._setupTargetAuthorizations();

        // authorize public role (open access to any account, only allows to lock target)
        IAccess.FunctionInfo[] storage functions;
        functions = _authorizeForTarget(getTargetName(), PUBLIC_ROLE());
        _authorize(functions, SimpleDistribution.approveTokenHandler.selector, "approveTokenHandler");
        _authorize(functions, SimpleDistribution.setWallet.selector, "setWallet");
    }
}