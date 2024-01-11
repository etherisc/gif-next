// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ComponentOwnerService} from "./service/ComponentOwnerService.sol";

interface IInstance is IERC165 {

    function getComponentOwnerService() external view returns (ComponentOwnerService);

}