// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ShortString, ShortStrings} from "@openzeppelin/contracts/utils/ShortStrings.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {AccessManagerUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";

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
import {ObjectType, BUNDLE, DISTRIBUTION, INSTANCE, POLICY, POOL, ROLE, PRODUCT, TARGET, COMPONENT} from "../types/ObjectType.sol";
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
import {InstanceBase} from "./InstanceBase.sol";

contract Instance is
    AccessManagedUpgradeable,
    IInstance,
    // Initializable,
    InstanceBase
{

    uint64 public constant ADMIN_ROLE = type(uint64).min;
    uint64 public constant PUBLIC_ROLE = type(uint64).max;
    uint64 public constant CUSTOM_ROLE_ID_MIN = 10000;

    uint32 public constant EXECUTION_DELAY = 0;

    bool private _initialized;

    mapping(ShortString name => RoleId roleId) internal _role;
    mapping(RoleId roleId => EnumerableSet.AddressSet roleMembers) internal _roleMembers; 
    RoleId [] internal _roles;

    mapping(ShortString name => address target) internal _target;

    AccessManagerUpgradeable internal _accessManager;
    InstanceReader internal _instanceReader;
    BundleManager internal _bundleManager;

    function initialize(address accessManagerAddress, address registryAddress, NftId registryNftId, address initialOwner) 
        public 
        initializer
    {
        require(!_initialized, "Contract instance has already been initialized");

        __AccessManaged_init(accessManagerAddress);
                
        _accessManager = AccessManagerUpgradeable(accessManagerAddress);
        _createRole(RoleIdLib.toRoleId(ADMIN_ROLE), "AdminRole", false, false);
        _createRole(RoleIdLib.toRoleId(PUBLIC_ROLE), "PublicRole", false, false);

        _initializeRegisterable(registryAddress, registryNftId, INSTANCE(), false, initialOwner, "");

        _registerInterface(type(IInstance).interfaceId);    
        _initialized = true;
    }

    //--- Role ------------------------------------------------------//
    function createStandardRole(RoleId roleId, string memory name) external restricted() {
        _createRole(roleId, name, false, true);
    }

    function createCustomRole(RoleId roleId, string memory name) external restricted() {
        _createRole(roleId, name, true, true);
    }

    function updateRole(RoleId roleId, string memory name, StateId newState) external restricted() {
        (bool isCustom,) = _validateRoleParameters(roleId, name, false);
        IAccess.RoleInfo memory role = _toRole(roleId, name, isCustom);
        update(toRoleKey32(roleId), abi.encode(role), newState);
    }

    function updateRoleState(RoleId roleId, StateId newState) external restricted() {
        updateState(toRoleKey32(roleId), newState);
    }

    function grantRole(RoleId roleId, address member) external restricted() returns (bool granted) {
        Key32 roleKey = toRoleKey32(roleId);

        if (!exists(roleKey)) {
            revert IAccess.ErrorGrantNonexstentRole(roleId);
        }

        if (getState(roleKey) != ACTIVE()) {
            revert IAccess.ErrorRoleIdNotActive(roleId);
        }

        if (!EnumerableSet.contains(_roleMembers[roleId], member)) {
            _accessManager.grantRole(roleId.toInt(), member, EXECUTION_DELAY);
            EnumerableSet.add(_roleMembers[roleId], member);
            return true;
        }

        return false;
    }

    function revokeRole(RoleId roleId, address member) external restricted() returns (bool revoked) {
        Key32 roleKey = toRoleKey32(roleId);

        if (!exists(roleKey)) {
            revert IAccess.ErrorRevokeNonexstentRole(roleId);
        }

        if (EnumerableSet.contains(_roleMembers[roleId], member)) {
            _accessManager.revokeRole(roleId.toInt(), member);
            EnumerableSet.remove(_roleMembers[roleId], member);
            return true;
        }

        return false;
    }

    /// @dev not restricted function by intention
    /// the restriction to role members is already enforced by the call to the access manger
    function renounceRole(RoleId roleId) external returns (bool revoked) {
        address member = msg.sender;
        Key32 roleKey = toRoleKey32(roleId);

        if (!exists(roleKey)) {
            revert IAccess.ErrorRenounceNonexstentRole(roleId);
        }

        if (EnumerableSet.contains(_roleMembers[roleId], member)) {
            _accessManager.renounceRole(roleId.toInt(), member);
            EnumerableSet.remove(_roleMembers[roleId], member);
            return true;
        }

        return false;
    }

    function roles() external view returns (uint256 numberOfRoles) {
        return _roles.length;
    }

    function getRoleId(uint256 idx) external view returns (RoleId roleId) {
        return _roles[idx];
    }

    function getRole(RoleId roleId) external view returns (IAccess.RoleInfo memory role) {
        return abi.decode(getData(roleId.toKey32()), (IAccess.RoleInfo));
    }

    function roleMembers(RoleId roleId) external view returns (uint256 numberOfMembers) {
        return EnumerableSet.length(_roleMembers[roleId]);
    }

    function getRoleMember(RoleId roleId, uint256 idx) external view returns (address roleMember) {
        return EnumerableSet.at(_roleMembers[roleId], idx);
    }

    function _createRole(RoleId roleId, string memory name, bool isCustom, bool validateParameters) internal {
        if (validateParameters) {
            _validateRoleParameters(roleId, name, isCustom);
        }

        IAccess.RoleInfo memory role = _toRole(roleId, name, isCustom);
        _role[role.name] = roleId;
        _roles.push(roleId);

        create(toRoleKey32(roleId), abi.encode(role));
    }

    //--- Target ------------------------------------------------------//
    function createTarget(address target, IAccess.TargetInfo memory targetInfo) external restricted() {
        _validateTargetParameters(target, targetInfo);
        create(toTargetKey32(target), abi.encode(targetInfo));
    }

    function setTargetClosed(address target, bool closed) external restricted() {
        if (!exists(toTargetKey32(target))) {
            revert IAccess.ErrorTargetDoesNotExist(target);
        }

        _accessManager.setTargetClosed(target, closed);
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

    //--- DistributorType ---------------------------------------------------//
    function createDistributorType(NftId policyNftId, NumberId payoutId, IPolicy.PayoutInfo memory payout) external restricted() {
        create(toPolicyKey32(policyNftId), abi.encode(payout));
    }

    function updateDistributorType(NftId policyNftId, NumberId payoutId, IPolicy.PayoutInfo memory payout, StateId newState) external restricted() {
        update(toPolicyKey32(policyNftId), abi.encode(payout), newState);
    }

    function updateDistributorTypeState(NftId policyNftId, StateId newState) external restricted() {
        updateState(toPolicyKey32(policyNftId), newState);
    }

    //--- Distributor -------------------------------------------------------//
    function createDistributor(NftId policyNftId, NumberId payoutId, IPolicy.PayoutInfo memory payout) external restricted() {
        create(toPolicyKey32(policyNftId), abi.encode(payout));
    }

    function updateDistributor(NftId policyNftId, NumberId payoutId, IPolicy.PayoutInfo memory payout, StateId newState) external restricted() {
        update(toPolicyKey32(policyNftId), abi.encode(payout), newState);
    }

    function updateDistributorState(NftId policyNftId, StateId newState) external restricted() {
        updateState(toPolicyKey32(policyNftId), newState);
    }

    //--- Referral ----------------------------------------------------------//
    function createReferral(NftId policyNftId, NumberId payoutId, IPolicy.PayoutInfo memory payout) external restricted() {
        create(toPolicyKey32(policyNftId), abi.encode(payout));
    }

    function updateReferral(NftId policyNftId, NumberId payoutId, IPolicy.PayoutInfo memory payout, StateId newState) external restricted() {
        update(toPolicyKey32(policyNftId), abi.encode(payout), newState);
    }

    function updateReferralState(NftId policyNftId, StateId newState) external restricted() {
        updateState(toPolicyKey32(policyNftId), newState);
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

    //--- Policy ------------------------------------------------------------//
    function createPolicy(NftId policyNftId, IPolicy.PolicyInfo memory policy) external restricted() {
        create(toPolicyKey32(policyNftId), abi.encode(policy));
    }

    function updatePolicy(NftId policyNftId, IPolicy.PolicyInfo memory policy, StateId newState) external restricted() {
        update(toPolicyKey32(policyNftId), abi.encode(policy), newState);
    }

    function updatePolicyState(NftId policyNftId, StateId newState) external restricted() {
        updateState(toPolicyKey32(policyNftId), newState);
    }

    //--- Claim -------------------------------------------------------------//
    function createClaim(NftId policyNftId, NumberId claimId, IPolicy.ClaimInfo memory claim) external restricted() {
        create(toPolicyKey32(policyNftId), abi.encode(claim));
    }

    function updateClaim(NftId policyNftId, NumberId claimId, IPolicy.ClaimInfo memory claim, StateId newState) external restricted() {
        update(toPolicyKey32(policyNftId), abi.encode(claim), newState);
    }

    function updateClaimState(NftId policyNftId, StateId newState) external restricted() {
        updateState(toPolicyKey32(policyNftId), newState);
    }

    //--- Payout ------------------------------------------------------------//
    function createPayout(NftId policyNftId, NumberId payoutId, IPolicy.PayoutInfo memory payout) external restricted() {
        create(toPolicyKey32(policyNftId), abi.encode(payout));
    }

    function updateClaim(NftId policyNftId, NumberId payoutId, IPolicy.PayoutInfo memory payout, StateId newState) external restricted() {
        update(toPolicyKey32(policyNftId), abi.encode(payout), newState);
    }

    function updatePayoutState(NftId policyNftId, StateId newState) external restricted() {
        updateState(toPolicyKey32(policyNftId), newState);
    }

    //--- internal view/pure functions --------------------------------------//
    function _toRole(RoleId roleId, string memory name, bool isCustom)
        internal
        pure
        returns (IAccess.RoleInfo memory role)
    {
        return IAccess.RoleInfo(
            ShortStrings.toShortString(name), 
            isCustom);
    }

    function _validateRoleParameters(
        RoleId roleId, 
        string memory name, 
        bool isCustom
    )
        internal
        view 
        returns (
            bool roleExists,
            bool roleIsCustom
        )
    {
        Key32 roleKey = toRoleKey32(roleId);
        roleExists = exists(roleKey);
        if (roleExists) {
            roleIsCustom = abi.decode(getData(roleKey), (IAccess.RoleInfo)).isCustom;
        } else {
            roleIsCustom = isCustom;
        }

        // check role id
        uint64 roleIdInt = RoleId.unwrap(roleId);
        if(roleIdInt == ADMIN_ROLE || roleIdInt == PUBLIC_ROLE) {
            revert IAccess.ErrorRoleIdInvalid(roleId); 
        }

        if (roleIsCustom && roleIdInt < CUSTOM_ROLE_ID_MIN) {
            revert IAccess.ErrorRoleIdTooSmall(roleId); 
        } else if (roleIsCustom && roleIdInt >= CUSTOM_ROLE_ID_MIN) {
            revert IAccess.ErrorRoleIdTooBig(roleId); 
        }

        // role name checks
        ShortString nameShort = ShortStrings.toShortString(name);
        if (ShortStrings.byteLength(nameShort) == 0) {
            revert IAccess.ErrorRoleNameEmpty(roleId);
        }

        if (_role[nameShort] != RoleIdLib.zero() && _role[nameShort] != roleId) {
            revert IAccess.ErrorRoleNameNotUnique(_role[nameShort], nameShort);
        }
    }

    function _validateTargetParameters(address target, IAccess.TargetInfo memory targetInfo) internal view {

    }

    function toRoleKey32(RoleId roleId) public pure returns (Key32) {
        return roleId.toKey32();
    }

    function toTargetKey32(address target) public pure returns (Key32) {
        return Key32Lib.toKey32(TARGET(), KeyId.wrap(bytes20(target)));
    }

    function _toNftKey32(NftId nftId, ObjectType objectType) internal pure returns (Key32) {
        return nftId.toKey32(objectType);
    }

    function toBundleKey32(NftId bundleNftId) public pure returns (Key32) {
        return bundleNftId.toKey32(BUNDLE());
    }

    function toPolicyKey32(NftId policyNftId) public pure returns (Key32) {
        return policyNftId.toKey32(POLICY());
    }

    function getComponentOwnerService() external view returns (IComponentOwnerService) {
        return ComponentOwnerService(_registry.getServiceAddress(COMPONENT(), VersionPart.wrap(3)));
    }

    function getDistributionService() external view returns (IDistributionService) {
        return IDistributionService(_registry.getServiceAddress(DISTRIBUTION(), VersionPart.wrap(3)));
    }

    function getProductService() external view returns (IProductService) {
        return IProductService(_registry.getServiceAddress(PRODUCT(), VersionPart.wrap(3)));
    }

    function getPoolService() external view returns (IPoolService) {
        return IPoolService(_registry.getServiceAddress(POOL(), VersionPart.wrap(3)));
    }

    function setInstanceReader(InstanceReader instanceReader) external restricted() {
        require(address(_instanceReader) == address(0), "InstanceReader is set");
        _instanceReader = instanceReader;
    }

    function getInstanceReader() external view returns (InstanceReader) {
        return _instanceReader;
    }
    
    function setBundleManager(BundleManager bundleManager) external restricted() {
        require(address(_bundleManager) == address(0), "BundleManager is set");
        _bundleManager = bundleManager;
    }

    function getBundleManager() external view returns (BundleManager) {
        return _bundleManager;
    }
}
