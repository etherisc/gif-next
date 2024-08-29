// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IBundle} from "../../contracts/instance/module/IBundle.sol";
import {IComponents} from "../../contracts/instance/module/IComponents.sol";
import {IDistribution} from "../../contracts/instance/module/IDistribution.sol";
import {IPolicy} from "../../contracts/instance/module/IPolicy.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {IRisk} from "../../contracts/instance/module/IRisk.sol";

contract MockStorageLayout {
    IRegistry.ObjectInfo private _objectInfo;
    
    IBundle.BundleInfo private _bundleInfo;

    IComponents.ComponentInfo private _componentInfo;
    IComponents.ProductInfo private _productInfo;
    IComponents.FeeInfo private _feeInfo;
    IComponents.PoolInfo private _poolInfo;
    
    IDistribution.DistributorTypeInfo private _distributorTypeInfo;
    IDistribution.DistributorInfo private _distributorInfo;
    IDistribution.ReferralInfo private _referralInfo;

    IPolicy.PremiumInfo private _premiumInfo;
    IPolicy.PolicyInfo private _policyInfo;
    IPolicy.ClaimInfo private _claimInfo;
    IPolicy.PayoutInfo private _payoutInfo;

    IRisk.RiskInfo private _riskInfo;
}
