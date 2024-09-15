// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IAccess} from "../authorization/IAccess.sol";
import {IBundle} from "../instance/module/IBundle.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IDistribution} from "../instance/module/IDistribution.sol";
import {IDistributionService} from "../distribution/IDistributionService.sol";
import {IInstance} from "./IInstance.sol";
import {IKeyValueStore} from "../shared/IKeyValueStore.sol";
import {IOracle} from "../oracle/IOracle.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IRisk} from "../instance/module/IRisk.sol";

import {AccessAdminLib} from "../authorization/AccessAdminLib.sol";
import {Amount} from "../type/Amount.sol";
import {BundleSet} from "./BundleSet.sol";
import {BUNDLE, COMPONENT, DISTRIBUTOR, DISTRIBUTION, FEE, PREMIUM, POLICY, POOL, PRODUCT} from "../type/ObjectType.sol";
import {ClaimId, ClaimIdLib} from "../type/ClaimId.sol";
import {DistributorType} from "../type/DistributorType.sol";
import {InstanceAdmin} from "./InstanceAdmin.sol";
import {InstanceStore} from "./InstanceStore.sol";
import {Key32} from "../type/Key32.sol";
import {NftId} from "../type/NftId.sol";
import {PayoutId, PayoutIdLib} from "../type/PayoutId.sol";
import {PolicyServiceLib} from "../product/PolicyServiceLib.sol";
import {ReferralId, ReferralStatus, ReferralLib} from "../type/Referral.sol";
import {RequestId} from "../type/RequestId.sol";
import {RiskId} from "../type/RiskId.sol";
import {RiskSet} from "./RiskSet.sol";
import {RoleId, INSTANCE_OWNER_ROLE} from "../type/RoleId.sol";
import {StateId} from "../type/StateId.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {UFixed, UFixedLib} from "../type/UFixed.sol";


/// @dev Central reader contract for a specific instance.
/// Provides reading functions for all instance data and related component data.
contract InstanceReader {

    error ErrorInstanceReaderAlreadyInitialized();
    error ErrorInstanceReaderInstanceAddressZero();

    bool private _initialized = false;

    IRegistry internal _registry;
    IInstance internal _instance;
    InstanceAdmin internal _instanceAdmin;

    InstanceStore internal _store;
    BundleSet internal _bundleSet;
    RiskSet internal _riskSet;
    IDistributionService internal _distributionService;

    /// @dev This initializer needs to be called from the instance itself.
    function initialize() public {
        if(_initialized) {
            revert ErrorInstanceReaderAlreadyInitialized();
        }

        initializeWithInstance(msg.sender);
    }


    /// @dev Initializer to upgrade instance reader via instance service
    function initializeWithInstance(address instanceAddress)
        public
    {
        if(_initialized) {
            revert ErrorInstanceReaderAlreadyInitialized();
        }

        _initialized = true;
        _instance = IInstance(instanceAddress);
        _instanceAdmin = _instance.getInstanceAdmin();
        _registry = _instance.getRegistry();

        _store = _instance.getInstanceStore();
        _bundleSet = _instance.getBundleSet();
        _riskSet = _instance.getRiskSet();
        _distributionService = IDistributionService(_registry.getServiceAddress(DISTRIBUTION(), _instance.getRelease()));
    }


    //--- instance functions ---------------------------------------------------------//

    /// @dev Returns the registry this instance is registered in.
    function getRegistry() public view returns (IRegistry registry) {
        return _registry;
    }


    /// @dev Returns the instance NFT ID.
    function getInstanceNftId() public view returns (NftId instanceNftid) {
        return _registry.getNftIdForAddress(address(_instance));
    }


    /// @dev Returns the instance contract.
    function getInstance() public view returns (IInstance instance) {
        return _instance;
    }


    //--- component functions ------------------------------------------------------//

    /// @dev Returns the number of registered components.
    /// Components may be products, distributions, oracles or pools.
    function components() public view returns (uint256 componentCount) {
        return _instanceAdmin.components();
    }


    /// @dev Returns the component info for the given component NFT ID.
    function getComponentInfo(NftId componentNftId) public view returns (IComponents.ComponentInfo memory info) {
        (bytes memory data, bool success) = _getData(_toComponentKey(componentNftId));
        if (success) { return abi.decode(data, (IComponents.ComponentInfo)); }
    }


    /// @dev Returns the registered token for the given component NFT ID.
    function getToken(NftId componentNftId) public view returns (IERC20Metadata token) {
        TokenHandler tokenHandler = getTokenHandler(componentNftId);
        if (address(tokenHandler) != address(0)) { return tokenHandler.TOKEN(); }
    }


    /// @dev Returns the current wallet address for the given component NFT ID.
    /// The wallet address is either the component's own address or any other wallet address specified by the component owner.
    /// The wallet holds the component's funds. Tokens collected by the component are transferred to the wallet and 
    /// Tokens distributed from the component are transferred from this wallet.
    function getWallet(NftId componentNftId) public view returns (address wallet) {
        TokenHandler tokenHandler = getTokenHandler(componentNftId);
        if (address(tokenHandler) != address(0)) { return tokenHandler.getWallet(); }
    }


    /// @dev Returns the token handler for the given component NFT ID.
    /// The token handler manages all transfers from/to the component's wallet.
    /// To allow a component to collect funds from an account, it has to create a corresponding allowance from the
    /// account to the address of the component's token handler.
    function getTokenHandler(NftId componentNftId) public view returns (TokenHandler tokenHandler) {
        (bytes memory data, bool success) = _getData(_toComponentKey(componentNftId));
        if (success) { return abi.decode(data, (IComponents.ComponentInfo)).tokenHandler; }
    }


    /// @dev Returns the current token balance amount for the given component NFT ID.
    /// The balance amount includes the fee amount.
    function getBalanceAmount(NftId targetNftId) external view returns (Amount) { 
        return _store.getBalanceAmount(targetNftId);
    }


    /// @dev Returns the current fee amount for the given NFT ID.
    /// The target NFT ID may reference a component, a distributor or a bundle.
    function getFeeAmount(NftId targetNftId) external view returns (Amount) { 
        return _store.getFeeAmount(targetNftId);
    }


    /// @dev Returns the currently locked amount for the given NFT ID.
    /// The target NFT ID may reference a pool or a bundle.
    function getLockedAmount(NftId targetNftId) external view returns (Amount) { 
        return _store.getLockedAmount(targetNftId);
    }

    //--- product functions ------------------------------------------------------//

    /// @dev Returns the number of registered products.
    function products() public view returns (uint256 productCount) {
        return _instance.products();
    }


    /// @dev Returns th product NFT ID for the given index.
    function getProduct(uint256 idx) public view returns (NftId productNftId) {
        return _instance.getProduct(idx);
    }


    /// @dev Returns the product info for the given product NFT ID.
    function getProductInfo(NftId productNftId) public view returns (IComponents.ProductInfo memory info) {
        (bytes memory data, bool success) = _getData(productNftId.toKey32(PRODUCT()));
        if (success) { return abi.decode(data, (IComponents.ProductInfo)); }
    }


    /// @dev Returns the current fee settings for the given product NFT ID.
    function getFeeInfo(NftId productNftId) public view returns (IComponents.FeeInfo memory feeInfo) {
        (bytes memory data, bool success) = _getData(productNftId.toKey32(FEE()));
        if (success) { return abi.decode(data, (IComponents.FeeInfo)); }
    }

    //--- risk functions ---------------------------------------------------------//

    /// @dev Returns the total number of registered risks for the specified product.
    function risks(NftId productNftId) public view returns (uint256 riskCount) {
        return _riskSet.risks(productNftId);
    }


    /// @dev Returns the number of active risks for the specified product.
    function activeRisks(NftId productNftId) public view returns (uint256 activeRiskCount) {
        return _riskSet.activeRisks(productNftId);
    }


    /// @dev Returns the risk ID for the given product NFT ID and (registered) risk index.
    function getRiskId(NftId productNftId, uint256 idx) public view returns (RiskId riskId) {
        return _riskSet.getRiskId(productNftId, idx);
    }


    /// @dev Returns the active risk ID for the given product NFT ID and (active) risk index.
    function getActiveRiskId(NftId productNftId, uint256 idx) public view returns (RiskId riskId) {
        return _riskSet.getActiveRiskId(productNftId, idx);
    }


    /// @dev Returns true if the specified risk exists for the given product NFT ID.
    function isProductRisk(NftId productNftId, RiskId riskId) public view returns (bool exists) {
        return _riskSet.hasRisk(productNftId, riskId);
    }


    /// @dev Returns the risk info for the given risk ID.
    function getRiskInfo(RiskId riskId) public view returns (IRisk.RiskInfo memory info) {
        (bytes memory data, bool success) = _getData(riskId.toKey32()); 
        if (success) { return abi.decode(data, (IRisk.RiskInfo)); }
    }


    /// @dev Returns the risk state for the given risk ID.
    function getRiskState(RiskId riskId) public view returns (StateId stateId) {
        return getState(riskId.toKey32());
    }


    //--- policy functions -------------------------------------------------------//

    /// @dev Returns the number of linked policies for the given risk ID.
    function policiesForRisk(RiskId riskId) public view returns (uint256 linkedPolicies) {
        return _riskSet.linkedPolicies(riskId);
    }


    /// @dev Returns the linked policy NFT ID for the given risk ID and index.
    function getPolicyForRisk(RiskId riskId, uint256 idx) public view returns (NftId linkedPolicyNftId) {
        return _riskSet.getLinkedPolicyNftId(riskId, idx);
    }

    /// @dev Returns the number of linked policies for the given bundle NFT ID.
    function policiesForBundle(NftId bundleNftId) public view returns (uint256 linkedPolicies) {
        return _bundleSet.activePolicies(bundleNftId);
    }


    /// @dev Returns the linked policy NFT ID for the given risk ID and index.
    function getPolicyForBundle(NftId bundleNftId, uint256 idx) public view returns (NftId linkedPolicyNftId) {
        return _bundleSet.getActivePolicy(bundleNftId, idx);
    }


    /// @dev Returns the info for the given policy NFT ID.
    function getPolicyInfo(NftId policyNftId) public view returns (IPolicy.PolicyInfo memory info) {
        (bytes memory data, bool success) = _getData(_toPolicyKey(policyNftId));
        if (success) { return abi.decode(data, (IPolicy.PolicyInfo)); }
    }


    /// @dev Returns the state for the given policy NFT ID.
    function getPolicyState(NftId policyNftId) public view returns (StateId state) {
        return getState(_toPolicyKey(policyNftId));
    }


    /// @dev Returns true iff policy is active.
    function policyIsActive(NftId policyNftId) public view returns (bool isCloseable) {
        return PolicyServiceLib.policyIsActive(this, policyNftId);
    }

    //--- claim functions -------------------------------------------------------//

    /// @dev Returns the number of claims for the given policy NFT ID.
    function claims(NftId policyNftId) public view returns (uint16 claimCount) {
        return getPolicyInfo(policyNftId).claimsCount;
    }


    /// @dev Returns the claim ID for the given policy NFT ID and index.
    function getClaimId(uint256 idx) public pure returns (ClaimId claimId) {
        return ClaimIdLib.toClaimId(idx + 1);
    }


    /// @dev Returns the claim info for the given policy NFT ID and claim ID.
    function getClaimInfo(NftId policyNftId, ClaimId claimId) public view returns (IPolicy.ClaimInfo memory info) {
        (bytes memory data, bool success) = _getData(claimId.toKey32(policyNftId));
        if (success) {
            return abi.decode(data, (IPolicy.ClaimInfo));
        }
    }


    /// @dev Returns the current claim state for the given policy NFT ID and claim ID.
    function getClaimState(NftId policyNftId, ClaimId claimId) public view returns (StateId state) {
        return getState(claimId.toKey32(policyNftId));
    }


    /// @dev Returns the remaining claimable amount for the given policy NFT ID.
    /// The remaining claimable amount is the difference between the sum insured amount and total approved claim amounts so far.
    function getRemainingClaimableAmount(NftId policyNftId)
        public view returns (Amount remainingClaimableAmount) {
        IPolicy.PolicyInfo memory info = getPolicyInfo(policyNftId);
        return info.sumInsuredAmount - info.claimAmount;
    }

    //--- payout functions -------------------------------------------------------//

    /// @dev Returns the number of payouts for the given policy NFT ID and claim ID.
    function payouts(NftId policyNftId, ClaimId claimId) public view returns (uint24 payoutCount) {
        return getClaimInfo(policyNftId, claimId).payoutsCount;
    }


    /// @dev Returns the payout ID for the given claim ID and index.
    function getPayoutId(ClaimId claimId, uint24 idx) public pure returns (PayoutId payoutId) {
        return PayoutIdLib.toPayoutId(claimId, idx + 1);
    }


    /// @dev Returns the payout info for the given policy NFT ID and payout ID.
    function getPayoutInfo(NftId policyNftId, PayoutId payoutId) public view returns (IPolicy.PayoutInfo memory info) {
        (bytes memory data, bool success) = _getData(payoutId.toKey32(policyNftId));
        if (success) { return abi.decode(data, (IPolicy.PayoutInfo)); }
    }


    /// @dev Returns the payout state for the given policy NFT ID and payout ID.
    function getPayoutState(NftId policyNftId, PayoutId payoutId) public view returns (StateId state) {
        return getState(payoutId.toKey32(policyNftId));
    }

    //--- premium functions -------------------------------------------------------//

    /// @dev Returns the premium info for the given policy NFT ID.
    function getPremiumInfo(NftId policyNftId) public view returns (IPolicy.PremiumInfo memory info) {
        (bytes memory data, bool success) = _getData(_toPremiumKey(policyNftId));
        if (success) { return abi.decode(data, (IPolicy.PremiumInfo)); }
    }


    /// @dev Returns the premium state for the given policy NFT ID.
    function getPremiumState(NftId policyNftId) public view returns (StateId state) {
        return getState(_toPremiumKey(policyNftId));
    }

    //--- oracle functions ---------------------------------------------------------//

    /// @dev Returns the request info for the given oracle request ID.
    function getRequestInfo(RequestId requestId) public view returns (IOracle.RequestInfo memory requestInfo) {
        (bytes memory data, bool success) = _getData(requestId.toKey32());
        if (success) { return abi.decode(data, (IOracle.RequestInfo)); }
    }

    /// @dev Returns the request info for the given oracle request ID.
    function getRequestState(RequestId requestId) public view returns (StateId state) {
        return getState(requestId.toKey32());
    }

    //--- pool functions -----------------------------------------------------------//

    /// @dev Returns the pool info for the given pool NFT ID.
    function getPoolInfo(NftId poolNftId) public view returns (IComponents.PoolInfo memory info) {
        (bytes memory data, bool success) = _getData(poolNftId.toKey32(POOL()));
        if (success) { return abi.decode(data, (IComponents.PoolInfo)); }
    }

    //--- bundle functions -------------------------------------------------------//

    /// @dev Returns the total number of registered bundles for the given pool.
    function bundles(NftId poolNftId) public view returns (uint256 bundleCount) {
        return _bundleSet.bundles(poolNftId);
    }


    /// @dev Returns the number of active bundles for the given pool.
    function activeBundles(NftId poolNftId) public view returns (uint256 bundleCount) {
        return _bundleSet.activeBundles(poolNftId);
    }


    /// @dev Returns the bunde NFT ID for the given pool and index.
    function getBundleNftId(NftId poolNftId, uint256 idx) public view returns (NftId bundleNftId) {
        return _bundleSet.getBundleNftId(poolNftId, idx);
    }


    /// @dev Returns the active bunde NFT ID for the given pool and index.
    function getActiveBundleNftId(NftId poolNftId, uint256 idx) public view returns (NftId bundleNftId) {
        return _bundleSet.getActiveBundleNftId(poolNftId, idx);
    }


    /// @dev Returns the bundle info for the given bundle NFT ID.
    function getBundleInfo(NftId bundleNftId) public view  returns (IBundle.BundleInfo memory info) {
        (bytes memory data, bool success) = _getData(_toBundleKey(bundleNftId));
        if (success) { return abi.decode(data, (IBundle.BundleInfo)); }
    }


    /// @dev Returns the bundle state for the given bundle NFT ID.
    function getBundleState(NftId bundleNftId) public view returns (StateId state) {
        return getState(_toBundleKey(bundleNftId));
    }

    //--- distribution functions -------------------------------------------------------//

    function getDistributorTypeInfo(DistributorType distributorType) public view returns (IDistribution.DistributorTypeInfo memory info) {
        (bytes memory data, bool success) = _getData(distributorType.toKey32());
        if (success) { return abi.decode(data, (IDistribution.DistributorTypeInfo)); }
    }


    function getDistributorInfo(NftId distributorNftId) public view returns (IDistribution.DistributorInfo memory info) {
        (bytes memory data, bool success) = _getData(distributorNftId.toKey32(DISTRIBUTOR()));
        if (success) { return abi.decode(data, (IDistribution.DistributorInfo)); }
    }


    //--- referral functions -------------------------------------------------------//

    function toReferralId(NftId distributionNftId, string memory referralCode) public pure returns (ReferralId referralId) {
        return ReferralLib.toReferralId(distributionNftId, referralCode);      
    }


    function isReferralValid(NftId distributionNftId, ReferralId referralId) external view returns (bool isValid) {
        return _distributionService.referralIsValid(distributionNftId, referralId);
    }


    function getReferralInfo(ReferralId referralId) public view returns (IDistribution.ReferralInfo memory info) {
        (bytes memory data, bool success) = _getData(referralId.toKey32());
        if (success) { return abi.decode(data, (IDistribution.ReferralInfo)); }
    }


    function getDiscountPercentage(ReferralId referralId)
        public
        view
        returns (
            UFixed discountPercentage, 
            ReferralStatus status
        )
    {
        return IDistributionService(
            _registry.getServiceAddress(
                DISTRIBUTION(),
                _instance.getRelease())).getDiscountPercentage(
                    this, // instance reader
                    referralId);
    }

    //--- authorization functions -------------------------------------------------------//

    /// @dev Returns the number of defined roles.
    function roles() public view returns (uint256) {
        return _instanceAdmin.roles();
    }


    /// @dev Returns the role ID for the given index.
    function getRoleId(uint256 idx) public view returns (RoleId roleId) {
        return _instanceAdmin.getRoleId(uint64(idx));
    }


    /// @dev Returns the role ID for the instance owner role.
    /// This role may be used as a "root" admin role for other custom roles defined for this instance.
    function getInstanceOwnerRole() public pure returns (RoleId roleId) {
        return INSTANCE_OWNER_ROLE();
    }


    /// @dev Returns the role info for the given role ID.
    function getRoleInfo(RoleId roleId) public view returns (IAccess.RoleInfo memory roleInfo) { 
        return _instanceAdmin.getRoleInfo(roleId);
    }


    /// @dev Returns true iff the provided role ID is defined for this instance.
    function roleExists(RoleId roleId) public view returns (bool exists) {
        return _instanceAdmin.roleExists(roleId);
    }


    /// @dev Returns true iff the provided role ID represents a custom role ID.
    function isRoleCustom(RoleId roleId) public view returns (bool isCustom) {
        return _instanceAdmin.isRoleCustom(roleId);
    }


    /// @dev Returns true iff the provided role ID is active.
    function isRoleActive(RoleId roleId) public view returns (bool isActive) {
        return _instanceAdmin.isRoleActive(roleId);
    }


    /// @dev Returns the number of members (accounts) for the given role ID.
    function roleMembers(RoleId roleId) public view returns (uint256 numberOfMembers) {
        return _instanceAdmin.roleMembers(roleId);
    }


    /// @dev Returns the member (account address) for the given role ID and index.
    function getRoleMember(RoleId roleId, uint256 idx) public view returns (address account) {
        return _instanceAdmin.getRoleMember(roleId, idx);
    }


    /// @dev Returns true iff the given account is a member of the specified role ID.
    function isRoleMember(RoleId roleId, address account) public view returns (bool isMember) {
        return _instanceAdmin.isRoleMember(roleId, account);
    }


    /// @dev Returns true iff the given account is an admin of the specified role ID.
    /// Role admins may grant and revoke the role to other accounts.
    function isRoleAdmin(RoleId roleId, address account) public view returns (bool isMember) {
        return _instanceAdmin.isRoleAdmin(roleId, account);
    }


    /// @dev Returns the number of targets (contracts) defined for this instance.
    function targets() public view returns (uint256 targetCount) {
        return _instanceAdmin.targets();
    }


    /// @dev Returns the target address for the given index.
    function getTargetAddress(uint256 idx) public view returns (address target) {
        return _instanceAdmin.getTargetAddress(idx);
    }


    /// @dev Returns the target info for the given target address.
    function getTargetInfo(address target) public view returns (IAccess.TargetInfo memory targetInfo) {
        return _instanceAdmin.getTargetInfo(target);
    }


    /// @dev Returns true iff the given target is defined for this instance.
    function targetExists(address target) public view returns (bool exists) {
        return _instanceAdmin.targetExists(target);
    }


    /// @dev Returns true iff the given target is locked.
    function isLocked(address target) public view returns (bool) {
        return _instanceAdmin.isTargetLocked(target);
    }


    /// @dev Returns the number of authorized functions for the given target.
    function authorizedFunctions(address target) external view returns (uint256 numberOfFunctions) {
        return _instanceAdmin.authorizedFunctions(target);
    }


    /// @dev Returns the authorized function info for the given target and index.
    function getAuthorizedFunction(address target, uint256 idx) external view returns (IAccess.FunctionInfo memory func, RoleId roleId) {
        return _instanceAdmin.getAuthorizedFunction(target, idx);
    }


    /// @dev Returns a function info for the given function signature and function name.
    /// The function signature must not be zero and the function name must not be empty.
    function toFunction(bytes4 signature, string memory name) public view returns (IAccess.FunctionInfo memory) {
        return AccessAdminLib.toFunction(signature, name);
    }

    //--- low level function ----------------------------------------------------//

    function getInstanceAdmin() external view returns (InstanceAdmin instanceAdmin) {
        return _instanceAdmin;
    }

    function getInstanceStore() external view returns (IKeyValueStore store) {
        return _store;
    }


    function getBundleSet() external view returns (BundleSet bundleSet) {
        return _bundleSet;
    }


    function getRiskSet() external view returns (RiskSet riskSet) {
        return _riskSet;
    }


    function getMetadata(Key32 key) public view returns (IKeyValueStore.Metadata memory metadata) {
        return _store.getMetadata(key);
    }


    function getState(Key32 key) public view returns (StateId state) {
        return _store.getState(key);
    }


    function toUFixed(uint256 value, int8 exp) public pure returns (UFixed) {
        return UFixedLib.toUFixed(value, exp);
    }


    function toInt(UFixed value) public pure returns (uint256) {
        return UFixedLib.toInt(value);
    }

    //--- internal functions ----------------------------------------------------//

    function _getData(Key32 key) internal view returns (bytes memory data, bool success) {
        data = _store.getData(key);
        return (data, data.length > 0);
    }


    function _toPolicyKey(NftId policyNftId) internal pure returns (Key32) { 
        return policyNftId.toKey32(POLICY());
    }


    function _toPremiumKey(NftId policyNftId) internal pure returns (Key32) { 
        return policyNftId.toKey32(PREMIUM());
    }


    function _toBundleKey(NftId poolNftId) internal pure returns (Key32) { 
        return poolNftId.toKey32(BUNDLE());
    }


    function _toComponentKey(NftId componentNftId) internal pure returns (Key32) { 
        return componentNftId.toKey32(COMPONENT());
    }
}