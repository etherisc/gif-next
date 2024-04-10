// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {Key32} from "../types/Key32.sol";
import {NftId} from "../types/NftId.sol";
import {ClaimId} from "../types/ClaimId.sol";
import {DistributorType} from "../types/DistributorType.sol";
import {PayoutId} from "../types/PayoutId.sol";
import {ObjectType, BUNDLE, DISTRIBUTION, INSTANCE, POLICY, POOL, PRODUCT, DISTRIBUTOR} from "../types/ObjectType.sol";
import {ReferralId} from "../types/Referral.sol";
import {RiskId} from "../types/RiskId.sol";
import {INSTANCE_OWNER_ROLE} from "../types/RoleId.sol";
import {StateId} from "../types/StateId.sol";
import {VersionPart, VersionPartLib} from "../types/Version.sol";

import {Registerable} from "../shared/Registerable.sol";

import {IRegistry} from "../registry/IRegistry.sol";

import {IInstance} from "./IInstance.sol";
import {InstanceReader} from "./InstanceReader.sol";
import {InstanceAccessManager} from "./InstanceAccessManager.sol";
import {BundleManager} from "./BundleManager.sol";

import {KeyValueStore} from "./base/KeyValueStore.sol";

import {IBundle} from "./module/IBundle.sol";
import {IComponents} from "./module/IComponents.sol";
import {IDistribution} from "./module/IDistribution.sol";
import {IPolicy} from "./module/IPolicy.sol";
import {IRisk} from "./module/IRisk.sol";
import {ISetup} from "./module/ISetup.sol";

import {VersionPart, VersionPartLib} from "../types/Version.sol";

contract Instance is
    IInstance,
    AccessManagedUpgradeable,
    Registerable,
    KeyValueStore
{

    uint256 public constant GIF_MAJOR_VERSION = 3;

    uint64 public constant ADMIN_ROLE = type(uint64).min;
    uint64 public constant PUBLIC_ROLE = type(uint64).max;
    uint64 public constant CUSTOM_ROLE_ID_MIN = 10000;

    uint32 public constant EXECUTION_DELAY = 0;

    bool private _initialized;

    InstanceAccessManager internal _accessManager;
    InstanceReader internal _instanceReader;
    BundleManager internal _bundleManager;

    modifier onlyChainNft() {
        if(msg.sender != getRegistry().getChainNftAddress()) {
            revert();
        }
        _;
    }

    function initialize(address authority, address registryAddress, address initialOwner) 
        public 
        initializer()
    {
        if(authority == address(0)) {
            revert ErrorInstanceInstanceAccessManagerZero();
        }

        __AccessManaged_init(authority);
        
        IRegistry registry = IRegistry(registryAddress);
        initializeRegisterable(registryAddress, registry.getNftId(), INSTANCE(), true, initialOwner, "");
        initializeLifecycle();

        registerInterface(type(IInstance).interfaceId);    
    }

    //--- ProductSetup ------------------------------------------------------//
    function createProductSetup(NftId productNftId, ISetup.ProductSetupInfo memory setup) external restricted() {
        create(_toNftKey32(productNftId, PRODUCT()), abi.encode(setup));
    }

    function updateProductSetup(NftId productNftId, ISetup.ProductSetupInfo memory setup, StateId newState) external restricted() {
        update(_toNftKey32(productNftId, PRODUCT()), abi.encode(setup), newState);
    }

    function updateProductSetupState(NftId productNftId, StateId newState) external restricted() {
        updateState(_toNftKey32(productNftId, PRODUCT()), newState);
    }

    //--- DistributionSetup ------------------------------------------------------//
    function createDistributionSetup(NftId distributionNftId, ISetup.DistributionSetupInfo memory setup) external restricted() {
        create(_toNftKey32(distributionNftId, DISTRIBUTION()), abi.encode(setup));
    }

    function updateDistributionSetup(NftId distributionNftId, ISetup.DistributionSetupInfo memory setup, StateId newState) external restricted() {
        update(_toNftKey32(distributionNftId, DISTRIBUTION()), abi.encode(setup), newState);
    }

    function updateDistributionSetupState(NftId distributionNftId, StateId newState) external restricted() {
        updateState(_toNftKey32(distributionNftId, DISTRIBUTION()), newState);
    }

    //--- PoolSetup ------------------------------------------------------//
    function createPoolSetup(NftId poolNftId, IComponents.ComponentInfo memory info) external restricted() {
        create(_toNftKey32(poolNftId, POOL()), abi.encode(info));
    }

    function updatePoolSetup(NftId poolNftId, IComponents.ComponentInfo memory info, StateId newState) external restricted() {
        update(_toNftKey32(poolNftId, POOL()), abi.encode(info), newState);
    }

    function updatePoolSetupState(NftId poolNftId, StateId newState) external restricted() {
        updateState(_toNftKey32(poolNftId, POOL()), newState);
    }

    //--- DistributorType -------------------------------------------------------//
    function createDistributorType(DistributorType distributorType, IDistribution.DistributorTypeInfo memory info) external restricted() {
        create(distributorType.toKey32(), abi.encode(info));
    }

    function updateDistributorType(DistributorType distributorType, IDistribution.DistributorTypeInfo memory info, StateId newState) external restricted() {
        update(distributorType.toKey32(), abi.encode(info), newState);
    }

    function updateDistributorTypeState(DistributorType distributorType, StateId newState) external restricted() {
        updateState(distributorType.toKey32(), newState);
    }

    //--- Distributor -------------------------------------------------------//
    function createDistributor(NftId distributorNftId, IDistribution.DistributorInfo memory info) external restricted() {
        create(_toNftKey32(distributorNftId, DISTRIBUTOR()), abi.encode(info));
    }

    function updateDistributor(NftId distributorNftId, IDistribution.DistributorInfo memory info, StateId newState) external restricted() {
        update(_toNftKey32(distributorNftId, DISTRIBUTOR()), abi.encode(info), newState);
    }

    function updateDistributorState(NftId distributorNftId, StateId newState) external restricted() {
        updateState(_toNftKey32(distributorNftId, DISTRIBUTOR()), newState);
    }

    //--- Referral ----------------------------------------------------------//
    function createReferral(ReferralId referralId, IDistribution.ReferralInfo memory referralInfo) external restricted() {
        create(referralId.toKey32(), abi.encode(referralInfo));
    }

    function updateReferral(ReferralId referralId, IDistribution.ReferralInfo memory referralInfo, StateId newState) external restricted() {
        update(referralId.toKey32(), abi.encode(referralInfo), newState);
    }

    function updateReferralState(ReferralId referralId, StateId newState) external restricted() {
        updateState(referralId.toKey32(), newState);
    }

    //--- Bundle ------------------------------------------------------------//
    function createBundle(NftId bundleNftId, IBundle.BundleInfo memory bundle) external restricted() {
        create(_toNftKey32(bundleNftId, BUNDLE()), abi.encode(bundle));
    }

    function updateBundle(NftId bundleNftId, IBundle.BundleInfo memory bundle, StateId newState) external restricted() {
        update(_toNftKey32(bundleNftId, BUNDLE()), abi.encode(bundle), newState);
    }

    function updateBundleState(NftId bundleNftId, StateId newState) external restricted() {
        updateState(_toNftKey32(bundleNftId, BUNDLE()), newState);
    }

    //--- Risk --------------------------------------------------------------//
    function createRisk(RiskId riskId, IRisk.RiskInfo memory risk) external restricted() {
        create(riskId.toKey32(), abi.encode(risk));
    }

    function updateRisk(RiskId riskId, IRisk.RiskInfo memory risk, StateId newState) external restricted() {
        update(riskId.toKey32(), abi.encode(risk), newState);
    }

    function updateRiskState(RiskId riskId, StateId newState) external restricted() {
        updateState(riskId.toKey32(), newState);
    }

    //--- Application (Policy) ----------------------------------------------//
    function createApplication(NftId applicationNftId, IPolicy.PolicyInfo memory policy) external restricted() {
        create(_toNftKey32(applicationNftId, POLICY()), abi.encode(policy));
    }

    function updateApplication(NftId applicationNftId, IPolicy.PolicyInfo memory policy, StateId newState) external restricted() {
        update(_toNftKey32(applicationNftId, POLICY()), abi.encode(policy), newState);
    }

    function updateApplicationState(NftId applicationNftId, StateId newState) external restricted() {
        updateState(_toNftKey32(applicationNftId, POLICY()), newState);
    }

    //--- Policy ------------------------------------------------------------//
    function updatePolicy(NftId policyNftId, IPolicy.PolicyInfo memory policy, StateId newState) external restricted() {
        update(_toNftKey32(policyNftId, POLICY()), abi.encode(policy), newState);
    }

    function updatePolicyClaims(NftId policyNftId, IPolicy.PolicyInfo memory policy, StateId newState) external restricted() {
        update(_toNftKey32(policyNftId, POLICY()), abi.encode(policy), newState);
    }

    function updatePolicyState(NftId policyNftId, StateId newState) external restricted() {
        updateState(_toNftKey32(policyNftId, POLICY()), newState);
    }

    //--- Claim -------------------------------------------------------------//
    function createClaim(NftId policyNftId, ClaimId claimId, IPolicy.ClaimInfo memory claim) external restricted() {
        create(_toClaimKey32(policyNftId, claimId), abi.encode(claim));
    }

    function updateClaim(NftId policyNftId, ClaimId claimId, IPolicy.ClaimInfo memory claim, StateId newState) external restricted() {
        update(_toClaimKey32(policyNftId, claimId), abi.encode(claim), newState);
    }

    function updateClaimState(NftId policyNftId, ClaimId claimId, StateId newState) external restricted() {
        updateState(_toClaimKey32(policyNftId, claimId), newState);
    }

    //--- Payout ------------------------------------------------------------//
    function createPayout(NftId policyNftId, PayoutId payoutId, IPolicy.PayoutInfo memory payout) external restricted() {
        create(_toPayoutKey32(policyNftId, payoutId), abi.encode(payout));
    }

    function updatePayout(NftId policyNftId, PayoutId payoutId, IPolicy.PayoutInfo memory payout, StateId newState) external restricted() {
        update(_toPayoutKey32(policyNftId, payoutId), abi.encode(payout), newState);
    }

    function updatePayoutState(NftId policyNftId, PayoutId payoutId, StateId newState) external restricted() {
        updateState(_toPayoutKey32(policyNftId, payoutId), newState);
    }

    //--- ITransferInterceptor ------------------------------------------------------------//
    function nftMint(address to, uint256 tokenId) external onlyChainNft {
        assert(_accessManager.roleMembers(INSTANCE_OWNER_ROLE()) == 0);// temp
        assert(_accessManager.grantRole(INSTANCE_OWNER_ROLE(), to) == true);
    }

    function nftTransferFrom(address from, address to, uint256 tokenId) external onlyChainNft {
        assert(_accessManager.revokeRole(INSTANCE_OWNER_ROLE(), from) == true);
        assert(_accessManager.grantRole(INSTANCE_OWNER_ROLE(), to) == true);
    }

    //--- initial setup functions -------------------------------------------//

    function setInstanceAccessManager(InstanceAccessManager accessManager) external restricted {
        if(address(_accessManager) != address(0)) {
            revert ErrorInstanceInstanceAccessManagerAlreadySet(address(_accessManager));
        }

        if(accessManager.authority() != authority()) {
            revert ErrorInstanceInstanceAccessManagerAuthorityMismatch(authority());
        }

        _accessManager = accessManager;      
    }

    function setBundleManager(BundleManager bundleManager) external restricted() {
        if(address(_bundleManager) != address(0)) {
            revert ErrorInstanceBundleManagerAlreadySet(address(_bundleManager));
        }

        if(bundleManager.getInstance() != Instance(this)) {
            revert ErrorInstanceBundleManagerInstanceMismatch(address(this));
        }

        if(bundleManager.authority() != authority()) {
            revert ErrorInstanceBundleManagerAuthorityMismatch(authority());
        }

        _bundleManager = bundleManager;
    }

    function setInstanceReader(InstanceReader instanceReader) external restricted() {
        if(instanceReader.getInstance() != Instance(this)) {
            revert ErrorInstanceInstanceReaderInstanceMismatch(address(this));
        }

        _instanceReader = instanceReader;
    }

    //--- external view functions -------------------------------------------//

    function getInstanceReader() external view returns (InstanceReader) {
        return _instanceReader;
    }

    function getBundleManager() external view returns (BundleManager) {
        return _bundleManager;
    }

    function getInstanceAccessManager() external view returns (InstanceAccessManager) {
        return _accessManager;
    }

    function getMajorVersion() external pure returns (VersionPart majorVersion) {
        return VersionPartLib.toVersionPart(GIF_MAJOR_VERSION);
    }

    //--- internal view/pure functions --------------------------------------//
    function _toNftKey32(NftId nftId, ObjectType objectType) private pure returns (Key32) {
        return nftId.toKey32(objectType);
    }

    function _toClaimKey32(NftId policyNftId, ClaimId claimId) private pure returns (Key32) {
        return claimId.toKey32(policyNftId);
    }

    function _toPayoutKey32(NftId policyNftId, PayoutId payoutId) private pure returns (Key32) {
        return payoutId.toKey32(policyNftId);
    }
}
