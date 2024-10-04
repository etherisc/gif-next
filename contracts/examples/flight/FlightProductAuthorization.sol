// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccess} from "../../../contracts/authorization/IAccess.sol";

import {BasicProductAuthorization} from "../../product/BasicProductAuthorization.sol";
import {FlightProduct} from "./FlightProduct.sol";
import {ORACLE} from "../../../contracts/type/ObjectType.sol";
import {PUBLIC_ROLE} from "../../../contracts/type/RoleId.sol";


contract FlightProductAuthorization
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

        // authorize oracle service
        functions = _authorizeForTarget(getMainTargetName(), getServiceRole(ORACLE()));
        _authorize(functions, FlightProduct.flightStatusCallback.selector, "flightStatusCallback");

        // authorize public role (open access to any account, only allows to lock target)
        functions = _authorizeForTarget(getMainTargetName(), PUBLIC_ROLE());
        _authorize(functions, FlightProduct.createPolicy.selector, "createPolicy");
        _authorize(functions, FlightProduct.createPolicyWithPermit.selector, "createPolicyWithPermit");

        // TODO: only owner
        _authorize(functions, FlightProduct.processFlightStatus.selector, "processFlightStatus");
        _authorize(functions, FlightProduct.completeSetup.selector, "completeSetup");
        _authorize(functions, FlightProduct.setDefaultBundle.selector, "setDefaultBundle");
        _authorize(functions, FlightProduct.approveTokenHandler.selector, "approveTokenHandler");
        _authorize(functions, FlightProduct.setLocked.selector, "setLocked");
        _authorize(functions, FlightProduct.setWallet.selector, "setWallet");
    }
}
