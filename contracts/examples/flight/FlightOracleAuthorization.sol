

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccess} from "../../../contracts/authorization/IAccess.sol";

import {AccessAdminLib} from "../../authorization/AccessAdminLib.sol";
import {BasicOracleAuthorization} from "../../oracle/BasicOracleAuthorization.sol";
import {FlightOracle} from "./FlightOracle.sol";
import {RoleId, ADMIN_ROLE} from "../../../contracts/type/RoleId.sol";

contract FlightOracleAuthorization
    is BasicOracleAuthorization
{

    uint64 public constant STATUS_PROVIDER_ROLE_IDX = 2; // 2nd custom role for flight oracle
    string public constant STATUS_PROVIDER_ROLE_NAME = "StatusProviderRole";
    RoleId public STATUS_PROVIDER_ROLE;

    constructor(string memory oracleName, string memory commitHash)
        BasicOracleAuthorization(oracleName, commitHash)
    {  }


    function _setupRoles()
        internal
        override
    {
        STATUS_PROVIDER_ROLE = AccessAdminLib.getCustomRoleId(STATUS_PROVIDER_ROLE_IDX);

        _addRole(
            STATUS_PROVIDER_ROLE,
            AccessAdminLib.roleInfo(
                ADMIN_ROLE(),
                TargetType.Custom,
                1, // max member count special case: instance nft owner is sole role owner
                STATUS_PROVIDER_ROLE_NAME));
    }


    function _setupTargetAuthorizations()
        internal
        virtual override
    {
        super._setupTargetAuthorizations();
        IAccess.FunctionInfo[] storage functions;

        functions = _authorizeForTarget(getMainTargetName(), STATUS_PROVIDER_ROLE);
        _authorize(functions, FlightOracle.respondWithFlightStatus.selector, "respondWithFlightStatus");
    }
}

