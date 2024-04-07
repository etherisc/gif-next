// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {console} from "../../../lib/forge-std/src/Script.sol";
import {TestGifBase} from "../../base/TestGifBase.sol";
import {NftId, toNftId, NftIdLib} from "../../../contracts/types/NftId.sol";
import {PRODUCT_OWNER_ROLE, POOL_OWNER_ROLE, DISTRIBUTION_OWNER_ROLE} from "../../../contracts/types/RoleId.sol";
import {Pool} from "../../../contracts/components/Pool.sol";
import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";
import {IRegistry} from "../../../contracts/registry/IRegistry.sol";
import {ISetup} from "../../../contracts/instance/module/ISetup.sol";
import {Fee, FeeLib} from "../../../contracts/types/Fee.sol";
import {UFixedLib} from "../../../contracts/types/UFixed.sol";
import {ComponentService} from "../../../contracts/instance/base/ComponentService.sol";
import {DistributorType} from "../../../contracts/types/DistributorType.sol";
import {ReferralId, ReferralLib} from "../../../contracts/types/Referral.sol";
import {RiskId, RiskIdLib} from "../../../contracts/types/RiskId.sol";
import {SecondsLib} from "../../../contracts/types/Seconds.sol";
import {SimpleProduct} from "../../mock/SimpleProduct.sol";
import {SimpleDistribution} from "../../mock/SimpleDistribution.sol";
import {SimplePool} from "../../mock/SimplePool.sol";
import {TimestampLib} from "../../../contracts/types/Timestamp.sol";

contract TestApplicationService is TestGifBase {
    using NftIdLib for NftId;

}