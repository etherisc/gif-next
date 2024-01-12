// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {RoleId, RoleIdLib, PRODUCT_OWNER_ROLE_NAME, PRODUCT_OWNER_ROLE, POOL_OWNER_ROLE_NAME, POOL_OWNER_ROLE} from "../../contracts/types/RoleId.sol";

contract TestRoleId {
    function getRole(uint256 roleNum) external pure returns (RoleId) { return RoleIdLib.toRoleId(roleNum); }

    function getProductOwnerRoleName() external pure returns (string memory) { return PRODUCT_OWNER_ROLE_NAME(); }
    function getProductOwnerRole() external pure returns (RoleId) { return PRODUCT_OWNER_ROLE(); } 

    function getPoolOwnerRoleName() external pure returns (string memory) { return POOL_OWNER_ROLE_NAME(); }
    function getPoolOwnerRole() external pure returns (RoleId) { return POOL_OWNER_ROLE(); } 
}
