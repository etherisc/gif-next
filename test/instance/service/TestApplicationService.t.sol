// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {console} from "../../../lib/forge-std/src/Script.sol";
import {GifTest} from "../../base/GifTest.sol";
import {NftId, toNftId, NftIdLib} from "../../../contracts/type/NftId.sol";
import {PRODUCT_OWNER_ROLE, POOL_OWNER_ROLE, DISTRIBUTION_OWNER_ROLE} from "../../../contracts/type/RoleId.sol";
import {Pool} from "../../../contracts/pool/Pool.sol";
import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";
import {IRegistry} from "../../../contracts/registry/IRegistry.sol";
import {ISetup} from "../../../contracts/instance/module/ISetup.sol";
import {Fee, FeeLib} from "../../../contracts/type/Fee.sol";
import {UFixedLib} from "../../../contracts/type/UFixed.sol";
import {ComponentService} from "../../../contracts/shared/ComponentService.sol";
import {DistributorType} from "../../../contracts/type/DistributorType.sol";
import {ReferralId, ReferralLib} from "../../../contracts/type/Referral.sol";
import {AmountLib} from "../../../contracts/type/Amount.sol";
import {RiskId, RiskIdLib} from "../../../contracts/type/RiskId.sol";
import {SecondsLib} from "../../../contracts/type/Seconds.sol";
import {SimpleProduct} from "../../mock/SimpleProduct.sol";
import {SimpleDistribution} from "../../mock/SimpleDistribution.sol";
import {SimplePool} from "../../mock/SimplePool.sol";
import {TimestampLib} from "../../../contracts/type/Timestamp.sol";

contract TestApplicationService is GifTest {
    using NftIdLib for NftId;

}