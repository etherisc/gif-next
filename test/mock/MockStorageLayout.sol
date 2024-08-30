// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccess} from "../../contracts/authorization/IAccess.sol";
import {IBundle} from "../../contracts/instance/module/IBundle.sol";
import {IComponents} from "../../contracts/instance/module/IComponents.sol";
import {IDistribution} from "../../contracts/instance/module/IDistribution.sol";
import {IOracle} from "../../contracts/oracle/IOracle.sol";
import {IPolicy} from "../../contracts/instance/module/IPolicy.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {IRelease} from "../../contracts/registry/IRelease.sol";
import {IRisk} from "../../contracts/instance/module/IRisk.sol";
import {TokenRegistry} from "../../contracts/registry/TokenRegistry.sol";

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

    IAccess.RoleInfo private _roleInfo;
    IAccess.TargetInfo private _targetInfo;
    IAccess.FunctionInfo private _functionInfo;
    IAccess.RoleNameInfo private _roleNameInfo;
    IAccess.TargeNameInfo private _targetNameInfo;

    IOracle.RequestInfo private _requestInfo;

    IRelease.ReleaseInfo private _releaseInfo;

    TokenRegistry.TokenInfo private _tokenInfo;
}
