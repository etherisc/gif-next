// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {BundleManager} from "./BundleManager.sol";
import {InstanceReader} from "./InstanceReader.sol";

import {IComponentOwnerService} from "./service/IComponentOwnerService.sol";
import {IDistributionService} from "./service/IDistributionService.sol";
import {IPoolService} from "./service/IPoolService.sol";
import {IProductService} from "./service/IProductService.sol";
import {IBundle} from "./module/IBundle.sol";
import {ISetup} from "./module/ISetup.sol";
import {NftId} from "../types/NftId.sol";
import {StateId} from "../types/StateId.sol";
import {RiskId} from "../types/RiskId.sol";
import {IRisk} from "./module/IRisk.sol";
import {IPolicy} from "./module/IPolicy.sol";
import {IKeyValueStore} from "./base/IKeyValueStore.sol";

import {IRegisterable} from "../shared/IRegisterable.sol";


interface IInstanceBase is IRegisterable, IKeyValueStore {


}