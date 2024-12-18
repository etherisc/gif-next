// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccess} from "../../../contracts/authorization/IAccess.sol";

import {AccessAdminLib} from "../../authorization/AccessAdminLib.sol";
import {BasicProductAuthorization} from "../../product/BasicProductAuthorization.sol";
import {CropProduct} from "./CropProduct.sol";
import {RoleId, ADMIN_ROLE, PUBLIC_ROLE} from "../../../contracts/type/RoleId.sol";


contract CropProductAuthorization
    is BasicProductAuthorization
{

    uint64 public constant PRODUCT_OPERATOR_ROLE_IDX = 1; // 1st custom role for flight product
    string public constant PRODUCT_OPERATOR_ROLE_NAME = "ProductOperatorRole";
    // solhint-disable-next-line var-name-mixedcase
    RoleId public PRODUCT_OPERATOR_ROLE;


    constructor(string memory productName)
        BasicProductAuthorization(productName)
    { }


    function _setupRoles()
        internal
        override
    {
        PRODUCT_OPERATOR_ROLE = AccessAdminLib.getCustomRoleId(PRODUCT_OPERATOR_ROLE_IDX);

        _addRole(
            PRODUCT_OPERATOR_ROLE,
            AccessAdminLib.roleInfo(
                ADMIN_ROLE(),
                TargetType.Custom,
                1, // max member count special case: instance nft owner is sole role owner
                PRODUCT_OPERATOR_ROLE_NAME));
    }


    function _setupTargetAuthorizations()
        internal
        virtual override
    {
        super._setupTargetAuthorizations();
        IAccess.FunctionInfo[] storage functions;

        // authorize product operator role 
        functions = _authorizeForTarget(getMainTargetName(), PRODUCT_OPERATOR_ROLE);
        _authorize(functions, CropProduct.createSeason.selector, "createSeason");
        _authorize(functions, CropProduct.createLocation.selector, "createLocation");
        _authorize(functions, CropProduct.createCrop.selector, "createCrop");
        _authorize(functions, CropProduct.createRisk.selector, "createRisk");
        _authorize(functions, CropProduct.createPolicy.selector, "createPolicy");

        // authorize public role (additional authz via onlyOwner)
        functions = _authorizeForTarget(getMainTargetName(), PUBLIC_ROLE());
        _authorize(functions, CropProduct.processPayoutsAndClosePolicies.selector, "processPayoutsAndClosePolicies");
        _authorize(functions, CropProduct.setDefaultBundle.selector, "setDefaultBundle");
        _authorize(functions, CropProduct.setConstants.selector, "setConstants");
        _authorize(functions, CropProduct.approveTokenHandler.selector, "approveTokenHandler");
        _authorize(functions, CropProduct.setLocked.selector, "setLocked");
        _authorize(functions, CropProduct.setWallet.selector, "setWallet");
    }
}

