// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ComponentOwnerService} from "./service/ComponentOwnerService.sol";
import {ISetup} from "./module/ISetup.sol";
import {NftId} from "../types/NftId.sol";

interface IInstance is IERC165 {

    function getComponentOwnerService() external view returns (ComponentOwnerService);

    function createProductSetup(NftId productNftId, ISetup.ProductSetupInfo memory setup) external;
    function createDistributionSetup(NftId distributionNftId, ISetup.DistributionSetupInfo memory setup) external;
    function createPoolSetup(NftId distributionNftId, ISetup.PoolSetupInfo memory setup) external;

}