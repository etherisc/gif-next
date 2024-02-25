// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ShortString, ShortStrings} from "@openzeppelin/contracts/utils/ShortStrings.sol";

import {IAccess} from "./module/IAccess.sol";
import {IBundle} from "./module/IBundle.sol";
import {IPolicy} from "./module/IPolicy.sol";
import {IRisk} from "./module/IRisk.sol";
import {ISetup} from "./module/ISetup.sol";
import {Key32, KeyId, Key32Lib} from "../types/Key32.sol";
import {KeyValueStore} from "./base/KeyValueStore.sol";
import {IInstance} from "./IInstance.sol";
import {InstanceReader} from "./InstanceReader.sol";
import {BundleManager} from "./BundleManager.sol";
import {NftId} from "../types/NftId.sol";
import {NumberId} from "../types/NumberId.sol";
import {ObjectType, BUNDLE, DISTRIBUTION, INSTANCE, POLICY, POOL, ROLE, PRODUCT, TARGET} from "../types/ObjectType.sol";
import {RiskId, RiskIdLib} from "../types/RiskId.sol";
import {RoleId, RoleIdLib} from "../types/RoleId.sol";
import {StateId, ACTIVE} from "../types/StateId.sol";
import {ERC165} from "../shared/ERC165.sol";
import {Registerable} from "../shared/Registerable.sol";
import {ComponentOwnerService} from "./service/ComponentOwnerService.sol";
import {IComponentOwnerService} from "./service/IComponentOwnerService.sol";
import {IDistributionService} from "./service/IDistributionService.sol";
import {IPoolService} from "./service/IPoolService.sol";
import {IProductService} from "./service/IProductService.sol";
import {VersionPart} from "../types/Version.sol";
import {IInstanceBase} from "./IInstanceBase.sol";

contract InstanceBase is
    IInstanceBase,
    KeyValueStore,
    Registerable
{


}
