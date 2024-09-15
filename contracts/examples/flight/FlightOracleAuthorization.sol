

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccess} from "../../../contracts/authorization/IAccess.sol";

import {BasicOracleAuthorization} from "../../oracle/BasicOracleAuthorization.sol";
import {FlightOracle} from "./FlightOracle.sol";
import {PUBLIC_ROLE} from "../../../contracts/type/RoleId.sol";

contract FlightOracleAuthorization
    is BasicOracleAuthorization
{

    constructor(string memory oracleName)
        BasicOracleAuthorization(oracleName)
    {}


    function _setupTargetAuthorizations()
        internal
        virtual override
    {
        super._setupTargetAuthorizations();
        IAccess.FunctionInfo[] storage functions;

        // TODO IMPORTANT must not be public role for prod!!!
        // authorize public role (also protected by onlyOwner)
        functions = _authorizeForTarget(getMainTargetName(), PUBLIC_ROLE());
        _authorize(functions, FlightOracle.respondWithFlightStatus.selector, "respondWithFlightStatus");
    }
}

