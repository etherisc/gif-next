// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ClaimId} from "../types/ClaimId.sol";
import {DistributorType} from "../types/DistributorType.sol";
import {PayoutId} from "../types/PayoutId.sol";
import {ClaimId} from "../types/ClaimId.sol";
import {DistributorType} from "../types/DistributorType.sol";
import {PayoutId} from "../types/PayoutId.sol";
import {NftId} from "../types/NftId.sol";
import {StateId} from "../types/StateId.sol";
import {ReferralId} from "../types/Referral.sol";
import {ReferralId} from "../types/Referral.sol";
import {RiskId} from "../types/RiskId.sol";
import {VersionPart} from "../types/Version.sol";
import {Key32} from "../types/Key32.sol";
import {RoleId} from "../types/RoleId.sol";

import {IRegisterable} from "../shared/IRegisterable.sol";

import {ITransferInterceptor} from "../registry/ITransferInterceptor.sol";

import {InstanceAccessManager} from "./InstanceAccessManager.sol";
import {BundleManager} from "./BundleManager.sol";
import {InstanceReader} from "./InstanceReader.sol";
import {InstanceStore} from "./InstanceStore.sol";

import {IKeyValueStore} from "./base/IKeyValueStore.sol";

import {IAccess} from "./module/IAccess.sol";

import {IBundleService} from "./service/IBundleService.sol";
import {IDistributionService} from "./service/IDistributionService.sol";
import {IPolicyService} from "./service/IPolicyService.sol";
import {IPoolService} from "./service/IPoolService.sol";
import {IProductService} from "./service/IProductService.sol";
import {IPolicyService} from "./service/IPolicyService.sol";
import {IBundleService} from "./service/IBundleService.sol";



interface IInstance is 
    IRegisterable, 
    ITransferInterceptor, 
    IAccessManaged
{
    error ErrorInstanceInstanceAccessManagerZero();
    error ErrorInstanceInstanceAccessManagerAlreadySet(address instanceAccessManager);
    error ErrorInstanceInstanceAccessManagerAuthorityMismatch(address instanceAuthority);

    error ErrorInstanceBundleManagerAlreadySet(address instanceBundleManager);
    error ErrorInstanceBundleManagerInstanceMismatch(address instance);
    error ErrorInstanceBundleManagerAuthorityMismatch(address instanceAuthority);

    error ErrorInstanceInstanceReaderInstanceMismatch(address instanceAuthority);

    error ErrorInstanceInstanceStoreAlreadySet(address instanceStore);
    error ErrorInstanceInstanceStoreAuthorityMismatch(address instanceAuthority);

    function createRole(string memory roleName, string memory adminName) external returns (RoleId roleId, RoleId admin);
    function grantRole(RoleId roleId, address account) external;
    function revokeRole(RoleId roleId, address account) external;

    function createTarget(address target, string memory name) external;
    function setTargetFunctionRole(string memory targetName, bytes4[] calldata selectors, RoleId roleId) external;
    function setTargetLocked(address target, bool locked) external;

    function getDistributionService() external view returns (IDistributionService);
    function getProductService() external view returns (IProductService);
    function getPoolService() external view returns (IPoolService);
    function getPolicyService() external view returns (IPolicyService);
    function getBundleService() external view returns (IBundleService);

    function getMajorVersion() external pure returns (VersionPart majorVersion);
    function getInstanceReader() external view returns (InstanceReader);
    function getBundleManager() external view returns (BundleManager);
    function getInstanceAccessManager() external view returns (InstanceAccessManager);
    function getInstanceStore() external view returns (InstanceStore);
}