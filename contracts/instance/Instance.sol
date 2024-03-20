// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {Key32, KeyId, Key32Lib} from "../types/Key32.sol";
import {NftId} from "../types/NftId.sol";
import {ClaimId} from "../types/ClaimId.sol";
import {NumberId} from "../types/NumberId.sol";
import {ObjectType, BUNDLE, DISTRIBUTION, INSTANCE, POLICY, POOL, ROLE, PRODUCT, TARGET, COMPONENT, DISTRIBUTOR, DISTRIBUTOR_TYPE} from "../types/ObjectType.sol";
import {RiskId, RiskIdLib} from "../types/RiskId.sol";
import {RoleId, RoleIdLib, INSTANCE_ROLE, INSTANCE_OWNER_ROLE} from "../types/RoleId.sol";
import {StateId, ACTIVE} from "../types/StateId.sol";
import {TimestampLib} from "../types/Timestamp.sol";
import {VersionPart, VersionPartLib} from "../types/Version.sol";

import {ERC165} from "../shared/ERC165.sol";
import {Registerable} from "../shared/Registerable.sol";

import {IRegistry} from "../registry/IRegistry.sol";

import {IInstance} from "./IInstance.sol";
import {InstanceReader} from "./InstanceReader.sol";
import {InstanceAccessManager} from "./InstanceAccessManager.sol";
import {BundleManager} from "./BundleManager.sol";

import {KeyValueStore} from "./base/KeyValueStore.sol";

import {IAccess} from "./module/IAccess.sol";
import {IBundle} from "./module/IBundle.sol";
import {IDistribution} from "./module/IDistribution.sol";
import {IPolicy} from "./module/IPolicy.sol";
import {IRisk} from "./module/IRisk.sol";
import {ISetup} from "./module/ISetup.sol";

import {IDistributionService} from "./service/IDistributionService.sol";
import {IPoolService} from "./service/IPoolService.sol";
import {IProductService} from "./service/IProductService.sol";
import {IPolicyService} from "./service/IPolicyService.sol";
import {IBundleService} from "./service/IBundleService.sol";

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
        __AccessManaged_init(authority);
        
        IRegistry registry = IRegistry(registryAddress);
        initializeRegisterable(registryAddress, registry.getNftId(), INSTANCE(), true, initialOwner, "");
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
    function createPoolSetup(NftId poolNftId, ISetup.PoolSetupInfo memory setup) external restricted() {
        create(_toNftKey32(poolNftId, POOL()), abi.encode(setup));
    }

    function updatePoolSetup(NftId poolNftId, ISetup.PoolSetupInfo memory setup, StateId newState) external restricted() {
        update(_toNftKey32(poolNftId, POOL()), abi.encode(setup), newState);
    }

    function updatePoolSetupState(NftId poolNftId, StateId newState) external restricted() {
        updateState(_toNftKey32(poolNftId, POOL()), newState);
    }

    //--- DistributorType -------------------------------------------------------//
    function createDistributorType(Key32 distributorKey, IDistribution.DistributorTypeInfo memory info) external restricted() {
        create(distributorKey, abi.encode(info));
    }

    function updateDistributorType(Key32 distributorKey, IDistribution.DistributorTypeInfo memory info, StateId newState) external restricted() {
        update(distributorKey, abi.encode(info), newState);
    }

    function updateDistributorTypeState(Key32 distributorKey, StateId newState) external restricted() {
        updateState(distributorKey, newState);
    }

    //--- Distributor -------------------------------------------------------//
    function createDistributor(NftId nftId, IDistribution.DistributorInfo memory info) external restricted() {
        create(toDistributorKey32(nftId), abi.encode(info));
    }

    function updateDistributor(NftId nftId, IDistribution.DistributorInfo memory info, StateId newState) external restricted() {
        update(toDistributorKey32(nftId), abi.encode(info), newState);
    }

    function updateDistributorState(NftId nftId, StateId newState) external restricted() {
        updateState(toDistributorKey32(nftId), newState);
    }

    //--- Referral ----------------------------------------------------------//
    function createReferral(Key32 referralKey, IDistribution.ReferralInfo memory referralInfo) external restricted() {
        create(referralKey, abi.encode(referralInfo));
    }

    function updateReferral(Key32 referralKey, IDistribution.ReferralInfo memory referralInfo, StateId newState) external restricted() {
        update(referralKey, abi.encode(referralInfo), newState);
    }

    function updateReferralState(Key32 referralKey, StateId newState) external restricted() {
        updateState(referralKey, newState);
    }

    //--- Bundle ------------------------------------------------------------//
    function createBundle(NftId bundleNftId, IBundle.BundleInfo memory bundle) external restricted() {
        create(toBundleKey32(bundleNftId), abi.encode(bundle));
    }

    function updateBundle(NftId bundleNftId, IBundle.BundleInfo memory bundle, StateId newState) external restricted() {
        update(toBundleKey32(bundleNftId), abi.encode(bundle), newState);
    }

    function updateBundleState(NftId bundleNftId, StateId newState) external restricted() {
        updateState(toBundleKey32(bundleNftId), newState);
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
        create(toPolicyKey32(applicationNftId), abi.encode(policy));
    }

    function updateApplication(NftId applicationNftId, IPolicy.PolicyInfo memory policy, StateId newState) external restricted() {
        update(toPolicyKey32(applicationNftId), abi.encode(policy), newState);
    }

    function updateApplicationState(NftId applicationNftId, StateId newState) external restricted() {
        updateState(toPolicyKey32(applicationNftId), newState);
    }

    //--- Policy ------------------------------------------------------------//
    function updatePolicy(NftId policyNftId, IPolicy.PolicyInfo memory policy, StateId newState) external restricted() {
        update(toPolicyKey32(policyNftId), abi.encode(policy), newState);
    }

    function updatePolicyState(NftId policyNftId, StateId newState) external restricted() {
        updateState(toPolicyKey32(policyNftId), newState);
    }

    //--- Claim -------------------------------------------------------------//
    function createClaim(NftId policyNftId, ClaimId claimId, IPolicy.ClaimInfo memory claim) external restricted() {
        create(toPolicyKey32(policyNftId), abi.encode(claim));
    }

    function updateClaim(NftId policyNftId, ClaimId claimId, IPolicy.ClaimInfo memory claim, StateId newState) external restricted() {
        update(toPolicyKey32(policyNftId), abi.encode(claim), newState);
    }

    function updateClaimState(NftId policyNftId, ClaimId claimId, StateId newState) external restricted() {
        updateState(toPolicyKey32(policyNftId), newState);
    }

    //--- Payout ------------------------------------------------------------//
    function createPayout(NftId policyNftId, NumberId payoutId, IPolicy.PayoutInfo memory payout) external restricted() {
        create(toPolicyKey32(policyNftId), abi.encode(payout));
    }

    function updatePayout(NftId policyNftId, NumberId payoutId, IPolicy.PayoutInfo memory payout, StateId newState) external restricted() {
        update(toPolicyKey32(policyNftId), abi.encode(payout), newState);
    }

    function updatePayoutState(NftId policyNftId, StateId newState) external restricted() {
        updateState(toPolicyKey32(policyNftId), newState);
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

    //--- internal view/pure functions --------------------------------------//
    function _toNftKey32(NftId nftId, ObjectType objectType) internal pure returns (Key32) {
        return nftId.toKey32(objectType);
    }

    function toBundleKey32(NftId bundleNftId) public pure returns (Key32) {
        return bundleNftId.toKey32(BUNDLE());
    }

    function toPolicyKey32(NftId policyNftId) public pure returns (Key32) {
        return policyNftId.toKey32(POLICY());
    }

    function toDistributionKey32(NftId distNftId) public pure returns (Key32) {
        return distNftId.toKey32(DISTRIBUTION());
    }

    function toDistributorTypeKey32(NftId distNftId) public pure returns (Key32) {
        return distNftId.toKey32(DISTRIBUTOR_TYPE());
    }

    function toDistributorKey32(NftId distNftId) public pure returns (Key32) {
        return distNftId.toKey32(DISTRIBUTOR());
    }
    
    function getDistributionService() external view returns (IDistributionService) {
        return IDistributionService(getRegistry().getServiceAddress(DISTRIBUTION(), VersionPart.wrap(3)));
    }

    function getProductService() external view returns (IProductService) {
        return IProductService(getRegistry().getServiceAddress(PRODUCT(), VersionPart.wrap(3)));
    }

    function getPoolService() external view returns (IPoolService) {
        return IPoolService(getRegistry().getServiceAddress(POOL(), VersionPart.wrap(3)));
    }

    function getPolicyService() external view returns (IPolicyService) {
        return IPolicyService(getRegistry().getServiceAddress(POLICY(), VersionPart.wrap(3)));
    }

    function getBundleService() external view returns (IBundleService) {
        return IBundleService(getRegistry().getServiceAddress(BUNDLE(), VersionPart.wrap(3)));
    }

    function setInstanceReader(InstanceReader instanceReader) external restricted() {
        require(instanceReader.getInstance() == Instance(this), "InstanceReader instance mismatch");
        _instanceReader = instanceReader;
    }

    function getMajorVersion() external pure returns (VersionPart majorVersion) {
        return VersionPartLib.toVersionPart(GIF_MAJOR_VERSION);
    }

    function getInstanceReader() external view returns (InstanceReader) {
        return _instanceReader;
    }
    
    function setBundleManager(BundleManager bundleManager) external restricted() {
        require(address(_bundleManager) == address(0), "BundleManager is set");
        require(bundleManager.getInstance() == Instance(this), "BundleManager instance mismatch");
        require(bundleManager.authority() == authority(), "BundleManager authority mismatch");
        _bundleManager = bundleManager;
    }

    function getBundleManager() external view returns (BundleManager) {
        return _bundleManager;
    }

    function setInstanceAccessManager(InstanceAccessManager accessManager) external restricted {
        require(address(_accessManager) == address(0), "InstanceAccessManager is set");
        require(accessManager.authority() == authority(), "InstanceAccessManager authority mismatch");  
        _accessManager = accessManager;      
    }

    function getInstanceAccessManager() external view returns (InstanceAccessManager) {
        return _accessManager;
    }
}
