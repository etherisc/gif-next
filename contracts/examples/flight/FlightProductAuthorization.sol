// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccess} from "../../../contracts/authorization/IAccess.sol";

import {AccessAdminLib} from "../../authorization/AccessAdminLib.sol";
import {BasicProductAuthorization} from "../../product/BasicProductAuthorization.sol";
import {FlightProduct} from "./FlightProduct.sol";
import {ORACLE} from "../../../contracts/type/ObjectType.sol";
import {RoleId, ADMIN_ROLE, PUBLIC_ROLE} from "../../../contracts/type/RoleId.sol";


contract FlightProductAuthorization
    is BasicProductAuthorization
{

    uint64 public constant STATISTICS_PROVIDER_ROLE_IDX = 1; // 1st custom role for flight product
    string public constant STATISTICS_PROVIDER_ROLE_NAME = "StatisticsProviderRole";
    RoleId public STATISTICS_PROVIDER_ROLE;


    constructor(string memory productName)
        BasicProductAuthorization(productName)
    { }


    function _setupRoles()
        internal
        override
    {
        STATISTICS_PROVIDER_ROLE = AccessAdminLib.getCustomRoleId(STATISTICS_PROVIDER_ROLE_IDX);

        _addRole(
            STATISTICS_PROVIDER_ROLE,
            AccessAdminLib.roleInfo(
                ADMIN_ROLE(),
                TargetType.Custom,
                1, // max member count special case: instance nft owner is sole role owner
                STATISTICS_PROVIDER_ROLE_NAME));
    }


    function _setupTargetAuthorizations()
        internal
        virtual override
    {
        super._setupTargetAuthorizations();
        IAccess.FunctionInfo[] storage functions;

        // authorize oracle service
        functions = _authorizeForTarget(getMainTargetName(), getServiceRole(ORACLE()));
        _authorize(functions, FlightProduct.flightStatusCallback.selector, "flightStatusCallback");

        // authorize statistics provider role 
        functions = _authorizeForTarget(getMainTargetName(), STATISTICS_PROVIDER_ROLE);
        _authorize(functions, FlightProduct.createPolicyWithPermit.selector, "createPolicyWithPermit");

        // authorize public role (additional authz via onlyOwner)
        functions = _authorizeForTarget(getMainTargetName(), PUBLIC_ROLE());
        _authorize(functions, FlightProduct.resendRequest.selector, "resendRequest");
        _authorize(functions, FlightProduct.processPayoutsAndClosePolicies.selector, "processPayoutsAndClosePolicies");
        _authorize(functions, FlightProduct.setConstants.selector, "setConstants");
        _authorize(functions, FlightProduct.setTestMode.selector, "setTestMode");
        _authorize(functions, FlightProduct.setDefaultBundle.selector, "setDefaultBundle");
        _authorize(functions, FlightProduct.approveTokenHandler.selector, "approveTokenHandler");
        _authorize(functions, FlightProduct.setLocked.selector, "setLocked");
        _authorize(functions, FlightProduct.setWallet.selector, "setWallet");
    }
}

