

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccess} from "../../../contracts/authorization/IAccess.sol";

import {BasicPoolAuthorization} from "../../pool/BasicPoolAuthorization.sol";
import {FlightPool} from "./FlightPool.sol";
import {PUBLIC_ROLE} from "../../../contracts/type/RoleId.sol";

contract FlightPoolAuthorization
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

        // authorize public role (also protected by onlyOwner)
        functions = _authorizeForTarget(getMainTargetName(), PUBLIC_ROLE());

        // only owner
        _authorize(functions, FlightPool.createBundle.selector, "createBundle");
        _authorize(functions, FlightPool.approveTokenHandler.selector, "approveTokenHandler");
        _authorize(functions, FlightPool.setWallet.selector, "setWallet");
    }
}

