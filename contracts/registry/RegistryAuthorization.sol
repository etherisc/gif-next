// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccess} from "../authorization/IAccess.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IStaking} from "../staking/IStaking.sol";

import {Authorization} from "../authorization/Authorization.sol";
import {POOL, REGISTRY, STAKING} from "../../contracts/type/ObjectType.sol";
import {PUBLIC_ROLE} from "../type/RoleId.sol";
import {ReleaseRegistry} from "./ReleaseRegistry.sol";
import {RegistryAdmin} from "./RegistryAdmin.sol";
import {RoleIdLib, ADMIN_ROLE, GIF_ADMIN_ROLE, GIF_MANAGER_ROLE} from "../type/RoleId.sol";
import {Staking} from "../staking/Staking.sol";
import {StakingStore} from "../staking/StakingStore.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {TokenRegistry} from "../registry/TokenRegistry.sol";
import {VersionPartLib} from "../type/Version.sol";


contract RegistryAuthorization
     is Authorization
{

     /// @dev gif core roles
     string public constant GIF_ADMIN_ROLE_NAME = "GifAdminRole";
     string public constant GIF_MANAGER_ROLE_NAME = "GifManagerRole";
     string public constant RELEASE_REGISTRY_ROLE_NAME = "ReleaseRegistryRole";
     string public constant STAKING_ROLE_NAME = "StakingRole";

     /// @dev gif roles for external contracts
     string public constant REGISTRY_SERVICE_ROLE_NAME = "RegistryServiceRole";
     string public constant COMPONENT_SERVICE_ROLE_NAME = "ComponentServiceRole";
     string public constant POOL_SERVICE_ROLE_NAME = "PoolServiceRole";
     string public constant STAKING_SERVICE_ROLE_NAME = "StakingServiceRole";

     /// @dev gif core targets
     string public constant REGISTRY_ADMIN_TARGET_NAME = "RegistryAdmin";
     string public constant REGISTRY_TARGET_NAME = "Registry";
     string public constant RELEASE_REGISTRY_TARGET_NAME = "ReleaseRegistry";
     string public constant TOKEN_REGISTRY_TARGET_NAME = "TokenRegistry";

     string public constant STAKING_TARGET_NAME = "Staking";
     string public constant STAKING_TH_TARGET_NAME = "StakingTh";
     string public constant STAKING_STORE_TARGET_NAME = "StakingStore";

     constructor(string memory commitHash)
          Authorization(
               REGISTRY_TARGET_NAME, 
               REGISTRY(), 
               3, 
               commitHash, 
               false, // isComponent
               false) // includeTokenHandler
     { }

     /// @dev Sets up the GIF admin and manager roles.
     function _setupRoles() internal override {

          // max number of versioned contracts per generic service
          uint32 maxReleases = uint32(VersionPartLib.releaseMax().toInt());

          // service roles (for all releases)
          _addRole(
               RoleIdLib.toGenericServiceRoleId(REGISTRY()), 
               _toRoleInfo({
                    adminRoleId: ADMIN_ROLE(),
                    roleType: RoleType.Core,
                    maxMemberCount: maxReleases, 
                    name: REGISTRY_SERVICE_ROLE_NAME}));

          _addRole(
               RoleIdLib.toGenericServiceRoleId(STAKING()), 
               _toRoleInfo({
                    adminRoleId: ADMIN_ROLE(),
                    roleType: RoleType.Core,
                    maxMemberCount: maxReleases, 
                    name: STAKING_SERVICE_ROLE_NAME}));

          _addRole(
               RoleIdLib.toGenericServiceRoleId(POOL()), 
               _toRoleInfo({
                    adminRoleId: ADMIN_ROLE(),
                    roleType: RoleType.Core,
                    maxMemberCount: maxReleases, 
                    name: POOL_SERVICE_ROLE_NAME}));

          // gif admin role
          _addRole(
               GIF_ADMIN_ROLE(),
               _toRoleInfo({
                    adminRoleId: ADMIN_ROLE(),
                    roleType: RoleType.Core,
                    maxMemberCount: 2, // TODO decide on max member count
                    name: GIF_ADMIN_ROLE_NAME}));

          // gif manager role
          _addRole(
               GIF_MANAGER_ROLE(), 
               _toRoleInfo({
                    adminRoleId: ADMIN_ROLE(),
                    roleType: RoleType.Core,
                    maxMemberCount: 1, // TODO decide on max member count
                    name: GIF_MANAGER_ROLE_NAME}));

     }

     /// @dev Sets up the relevant (non-service) targets for the registry.
     function _setupTargets() internal override {
          _addGifTarget(REGISTRY_ADMIN_TARGET_NAME);
          _addGifTarget(RELEASE_REGISTRY_TARGET_NAME);
          _addGifTarget(TOKEN_REGISTRY_TARGET_NAME);

          _addGifTarget(STAKING_TARGET_NAME);
          _addGifTarget(STAKING_TH_TARGET_NAME);
          _addGifTarget(STAKING_STORE_TARGET_NAME);
     }


     function _setupTargetAuthorizations()
          internal
          override
     {
          // registry
          _setupRegistryAuthorization();
          _setupRegistryAdminAuthorization();
          _setupReleaseRegistryAuthorization();
          _setupTokenRegistryAuthorization();

          // staking
          _setupStakingAuthorization();
          _setupStakingThAuthorization();
          _setupStakingStoreAuthorization();
     }

     event LogAccessAdminDebug(string message, string custom, uint256 value);

     function _setupRegistryAuthorization() internal {
          IAccess.FunctionInfo[] storage functions;

          // gif admin role
          functions = _authorizeForTarget(REGISTRY_TARGET_NAME, GIF_ADMIN_ROLE());
          _authorize(functions, IRegistry.registerRegistry.selector, "registerRegistry");

          // registry service role
          functions = _authorizeForTarget(
               REGISTRY_TARGET_NAME, 
               RoleIdLib.toGenericServiceRoleId(REGISTRY()));

          _authorize(functions, IRegistry.register.selector, "register");
          _authorize(functions, IRegistry.registerWithCustomType.selector, "registerWithCustomType");
          
          // release registry role
          functions = _authorizeForTarget(
               REGISTRY_TARGET_NAME, 
               getTargetRole(getTarget(RELEASE_REGISTRY_TARGET_NAME)));

          _authorize(functions, IRegistry.registerService.selector, "registerService");
     }


     function _setupRegistryAdminAuthorization() internal {
          IAccess.FunctionInfo[] storage functions;

          // release registry role
          functions = _authorizeForTarget(
               REGISTRY_ADMIN_TARGET_NAME, 
               getTargetRole(getTarget(RELEASE_REGISTRY_TARGET_NAME)));

          _authorize(functions, RegistryAdmin.grantServiceRoleForAllVersions.selector, "grantServiceRoleForAllVersions");
     }


     function _setupReleaseRegistryAuthorization() internal {
          IAccess.FunctionInfo[] storage functions;

          functions = _authorizeForTarget(RELEASE_REGISTRY_TARGET_NAME, GIF_ADMIN_ROLE());
          _authorize(functions, ReleaseRegistry.createNextRelease.selector, "createNextRelease");
          _authorize(functions, ReleaseRegistry.activateNextRelease.selector, "activateNextRelease");
          _authorize(functions, ReleaseRegistry.setActive.selector, "setActive");

          functions = _authorizeForTarget(RELEASE_REGISTRY_TARGET_NAME, GIF_MANAGER_ROLE());
          _authorize(functions, ReleaseRegistry.prepareNextRelease.selector, "prepareNextRelease");
          _authorize(functions, ReleaseRegistry.registerService.selector, "registerService");
     }


     function _setupTokenRegistryAuthorization() internal {
          IAccess.FunctionInfo[] storage functions;

          // gif manager role
          functions = _authorizeForTarget(TOKEN_REGISTRY_TARGET_NAME, GIF_MANAGER_ROLE());
          _authorize(functions, TokenRegistry.registerToken.selector, "registerToken");
          _authorize(functions, TokenRegistry.registerRemoteToken.selector, "registerRemoteToken");
          _authorize(functions, TokenRegistry.setActive.selector, "setActive");
          _authorize(functions, TokenRegistry.setActiveForVersion.selector, "setActiveForVersion");
          // TODO find a better way (only needed for testing)
          _authorize(functions, TokenRegistry.setActiveWithVersionCheck.selector, "setActiveWithVersionCheck");
     }


     function _setupStakingAuthorization() internal {
          IAccess.FunctionInfo[] storage functions;

          // staking public role (protected by owner)
          functions = _authorizeForTarget(
               STAKING_TARGET_NAME,
               PUBLIC_ROLE());

          _authorize(functions, IStaking.setProtocolLockingPeriod.selector, "setProtocolLockingPeriod");
          _authorize(functions, IStaking.setProtocolRewardRate.selector, "setProtocolRewardRate");
          _authorize(functions, IStaking.setStakingReader.selector, "setStakingReader");
          _authorize(functions, IStaking.approveTokenHandler.selector, "approveTokenHandler");
          _authorize(functions, IStaking.approveTokenHandler.selector, "approveTokenHandler");
          _authorize(functions, Staking.setStakingReader.selector, "setStakingReader");
          _authorize(functions, Staking.setStakingRate.selector, "setStaking");

          // staking service role
          functions = _authorizeForTarget(
               STAKING_TARGET_NAME, 
               RoleIdLib.toGenericServiceRoleId(STAKING()));

          _authorize(functions, IStaking.registerTarget.selector, "registerTarget");
          _authorize(functions, IStaking.setLockingPeriod.selector, "setLockingPeriod");
          _authorize(functions, IStaking.setRewardRate.selector, "setRewardRate");
          _authorize(functions, IStaking.setMaxStakedAmount.selector, "setMaxStakedAmount");
          _authorize(functions, IStaking.refillRewardReserves.selector, "refillRewardReserves");
          _authorize(functions, IStaking.withdrawRewardReserves.selector, "withdrawRewardReserves");
          _authorize(functions, IStaking.createStake.selector, "createStake");
          _authorize(functions, IStaking.stake.selector, "stake");
          _authorize(functions, IStaking.unstake.selector, "unstake");
          _authorize(functions, IStaking.restake.selector, "restake");
          _authorize(functions, IStaking.updateRewards.selector, "updateRewards");
          _authorize(functions, IStaking.claimRewards.selector, "claimRewards");

          // pool service role
          functions = _authorizeForTarget(
               STAKING_TARGET_NAME, 
               RoleIdLib.toGenericServiceRoleId(POOL()));

          _authorize(functions, IStaking.increaseTotalValueLocked.selector, "increaseTotalValueLocked");
          _authorize(functions, IStaking.decreaseTotalValueLocked.selector, "decreaseTotalValueLocked");
     }


     function _setupStakingThAuthorization() internal {
          IAccess.FunctionInfo[] storage functions;

          // staking service role
          functions = _authorizeForTarget(
               STAKING_TH_TARGET_NAME,
               RoleIdLib.toGenericServiceRoleId(STAKING()));

          _authorize(functions, TokenHandler.approve.selector, "approve");
          _authorize(functions, TokenHandler.pullToken.selector, "pullToken");
          _authorize(functions, TokenHandler.pushToken.selector, "pushToken");
     }


     function _setupStakingStoreAuthorization() internal {
          IAccess.FunctionInfo[] storage functions;

          // release registry role
          functions = _authorizeForTarget(
               STAKING_STORE_TARGET_NAME, 
               getTargetRole(getTarget(STAKING_TARGET_NAME)));

          _authorize(functions, StakingStore.setStakingRate.selector, "setStakingRate");
          _authorize(functions, StakingStore.createTarget.selector, "createTarget");
          _authorize(functions, StakingStore.updateTarget.selector, "updateTarget");
          _authorize(functions, StakingStore.increaseReserves.selector, "increaseReserves");
          _authorize(functions, StakingStore.decreaseReserves.selector, "decreaseReserves");
          _authorize(functions, StakingStore.increaseTotalValueLocked.selector, "increaseTotalValueLocked");
          _authorize(functions, StakingStore.decreaseTotalValueLocked.selector, "decreaseTotalValueLocked");
          _authorize(functions, StakingStore.create.selector, "create");
          _authorize(functions, StakingStore.update.selector, "update");
          _authorize(functions, StakingStore.increaseStake.selector, "increaseStake");
          _authorize(functions, StakingStore.restakeRewards.selector, "restakeRewards");
          _authorize(functions, StakingStore.updateRewards.selector, "updateRewards");
          _authorize(functions, StakingStore.claimUpTo.selector, "claimUpTo");
          _authorize(functions, StakingStore.unstakeUpTo.selector, "unstakeUpTo");
     }
}

