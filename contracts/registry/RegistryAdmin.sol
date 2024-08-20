// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessAdmin} from "../authorization/AccessAdmin.sol";
import {AccessManagerCloneable} from "../authorization/AccessManagerCloneable.sol";
import {IAccess} from "../authorization/IAccess.sol";
import {IComponent} from "../shared/IComponent.sol";
import {IRegistry} from "./IRegistry.sol";
import {IService} from "../shared/IService.sol";
import {IServiceAuthorization} from "../authorization/IServiceAuthorization.sol";
import {IStaking} from "../staking/IStaking.sol";
import {ObjectType, ObjectTypeLib, ALL, COMPONENT, REGISTRY, STAKING, POOL, RELEASE} from "../type/ObjectType.sol";
import {ReleaseRegistry} from "./ReleaseRegistry.sol";
import {RoleId, RoleIdLib, ADMIN_ROLE, GIF_MANAGER_ROLE, GIF_ADMIN_ROLE, PUBLIC_ROLE} from "../type/RoleId.sol";
import {Staking} from "../staking/Staking.sol";
import {StakingStore} from "../staking/StakingStore.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {TokenRegistry} from "./TokenRegistry.sol";
import {VersionPart, VersionPartLib} from "../type/Version.sol";

/*
    1) GIF_MANAGER_ROLE
        - can have arbitrary number of members
        - responsible for release preparation
        - responsible for services registrations
        - responsible for token registration and activation

    2) GIF_ADMIN_ROLE
        - admin of GIF_MANAGER_ROLE
        - MUST have 1 member at any time
        - granted/revoked ONLY in transferAdminRole() -> consider lock out situations!!!
        - responsible for creation, activation and locking/unlocking of releases
*/

/// @dev The RegistryAdmin contract implements the central authorization for the GIF core contracts.
/// These are the release independent registry and staking contracts and their respective helper contracts.
/// The RegistryAdmin also manages the access from service contracts to the GIF core contracts
contract RegistryAdmin is
    AccessAdmin
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
    string public constant STAKING_TARGET_NAME = "Staking";
    string public constant STAKING_TH_TARGET_NAME = "StakingTH";
    string public constant STAKING_STORE_TARGET_NAME = "StakingStore";
    string public constant TOKEN_REGISTRY_TARGET_NAME = "TokenRegistry";
    string public constant TOKEN_HANDLER_TARGET_NAME = "TokenHandler";

    uint8 public constant MAX_NUM_RELEASES = 99;

    address internal _registry;
    address private _releaseRegistry;
    address private _tokenRegistry;
    address private _staking;
    address private _stakingStore;

    constructor() {
        initialize(new AccessManagerCloneable());
    }

    function completeSetup(
        IRegistry registry,
        address gifAdmin, 
        address gifManager
    )
        public
        virtual
        reinitializer(type(uint8).max)
        onlyDeployer()
    {
        AccessManagerCloneable accessManager = AccessManagerCloneable(authority());
        accessManager.completeSetup(
            address(registry), 
            VersionPartLib.toVersionPart(type(uint8).max),
            false); 

        _registry = address(registry);
        _releaseRegistry = registry.getReleaseRegistryAddress();
        _tokenRegistry = registry.getTokenRegistryAddress();
        _staking = registry.getStakingAddress();
        _stakingStore = address(
            IStaking(_staking).getStakingStore());

        _createTargets();

        _setupGifAdminRole(gifAdmin);
        _setupGifManagerRole(gifManager);

        _setupRegistryRoles();
        _setupStakingRoles();
    }

    /*function transferAdmin(address to)
        external
        restricted // only with GIF_ADMIN_ROLE or nft owner
    {
        _accessManager.revoke(GIF_ADMIN_ROLE, );
        _accesssManager.grant(GIF_ADMIN_ROLE, to, 0);
    }*/

    function grantServiceRoleForAllVersions(IService service, ObjectType domain)
        external
        restricted()
    {
        _grantRoleToAccount( 
            RoleIdLib.roleForTypeAndAllVersions(domain),
            address(service)); 
    }

    //--- view functions ----------------------------------------------------//

    function getGifAdminRole() external view returns (RoleId) {
        return GIF_ADMIN_ROLE();
    }

    function getGifManagerRole() external view returns (RoleId) {
        return GIF_MANAGER_ROLE();
    }

    //--- private initialization functions -------------------------------------------//

    function _createTargets()
        private 
        onlyInitializing()
    {
        IStaking staking = IStaking(_staking);
        address tokenHandler = address(staking.getTokenHandler());

        _createTarget(address(this), REGISTRY_ADMIN_TARGET_NAME, false, false);
        _createTarget(_registry, REGISTRY_TARGET_NAME, true, false);
        _createTarget(_releaseRegistry, RELEASE_REGISTRY_TARGET_NAME, true, false);
        _createTarget(_staking, STAKING_TARGET_NAME, true, false);
        _createTarget(_stakingStore, STAKING_STORE_TARGET_NAME, true, false);
        _createTarget(_tokenRegistry, TOKEN_REGISTRY_TARGET_NAME, true, false);
        _createTarget(tokenHandler, TOKEN_HANDLER_TARGET_NAME, true, false);
    }

    function _setupGifAdminRole(address gifAdmin) 
        private 
        onlyInitializing()
    {
        // create gif admin role
        _createRole(
            GIF_ADMIN_ROLE(), 
            toRole({
                adminRoleId: ADMIN_ROLE(),
                roleType: RoleType.Gif,
                maxMemberCount: 2, // TODO decide on max member count
                name: GIF_ADMIN_ROLE_NAME}));

        // grant permissions to the gif admin role for registry contract
        FunctionInfo[] memory functions;
        functions = new FunctionInfo[](1);
        functions[0] = toFunction(IRegistry.registerRegistry.selector, "registerRegistry");
        _authorizeTargetFunctions(_registry, GIF_ADMIN_ROLE(), functions);

        // grant permissions to the gif admin role for release registry contract
        functions = new FunctionInfo[](3);
        functions[0] = toFunction(ReleaseRegistry.createNextRelease.selector, "createNextRelease");
        functions[1] = toFunction(ReleaseRegistry.activateNextRelease.selector, "activateNextRelease");
        functions[2] = toFunction(ReleaseRegistry.setActive.selector, "setActive");
        _authorizeTargetFunctions(_releaseRegistry, GIF_ADMIN_ROLE(), functions);

        _grantRoleToAccount(GIF_ADMIN_ROLE(), gifAdmin);
    }
    
    function _setupGifManagerRole(address gifManager)
        private 
        onlyInitializing()
    {
        // create gif manager role
        _createRole(
            GIF_MANAGER_ROLE(), 
            toRole({
                adminRoleId: ADMIN_ROLE(),
                roleType: RoleType.Gif,
                maxMemberCount: 1, // TODO decide on max member count
                name: GIF_MANAGER_ROLE_NAME}));

        // grant permissions to the gif manager role for token registry contract
        FunctionInfo[] memory functions;
        functions = new FunctionInfo[](5);
        functions[0] = toFunction(TokenRegistry.registerToken.selector, "registerToken");
        functions[1] = toFunction(TokenRegistry.registerRemoteToken.selector, "registerRemoteToken");
        functions[2] = toFunction(TokenRegistry.setActive.selector, "setActive");
        functions[3] = toFunction(TokenRegistry.setActiveForVersion.selector, "setActiveForVersion");
        // TODO find a better way (only needed for testing)
        functions[4] = toFunction(TokenRegistry.setActiveWithVersionCheck.selector, "setActiveWithVersionCheck");
        _authorizeTargetFunctions(_tokenRegistry, GIF_MANAGER_ROLE(), functions);

        // grant permissions to the gif manager role for release registry contract
        functions = new FunctionInfo[](2);
        functions[0] = toFunction(ReleaseRegistry.prepareNextRelease.selector, "prepareNextRelease");
        functions[1] = toFunction(ReleaseRegistry.registerService.selector, "registerService");
        _authorizeTargetFunctions(_releaseRegistry, GIF_MANAGER_ROLE(), functions);

        _grantRoleToAccount(GIF_MANAGER_ROLE(), gifManager);
    }

    function _setupRegistryRoles()
        private
        onlyInitializing()
    {
        // TODO use RELEASE_REGISTRY_ROLE instead
        // create and grant release registry role
        RoleId releaseRegistryRoleId = RoleIdLib.roleForType(RELEASE());
        _createRole(
            releaseRegistryRoleId, 
            toRole({
                adminRoleId: ADMIN_ROLE(),
                roleType: RoleType.Contract,
                maxMemberCount: 1,
                name: RELEASE_REGISTRY_ROLE_NAME}));
        _grantRoleToAccount(releaseRegistryRoleId, _releaseRegistry);

        // grant permissions to the release registry role for release admin contract
        FunctionInfo[] memory functions;
        functions = new FunctionInfo[](1);
        functions[0] = toFunction(RegistryAdmin.grantServiceRoleForAllVersions.selector, "grantServiceRoleForAllVersions");
        _authorizeTargetFunctions(address(this), releaseRegistryRoleId, functions);

        // grant permissions to the release registry role for registry contract
        functions = new FunctionInfo[](1);
        functions[0] = toFunction(IRegistry.registerService.selector, "registerService");
        _authorizeTargetFunctions(_registry, releaseRegistryRoleId, functions);

        // create registry service role
        RoleId registryServiceRoleId = RoleIdLib.roleForTypeAndAllVersions(REGISTRY());
        _createRole(
            registryServiceRoleId, 
            toRole({
                adminRoleId: ADMIN_ROLE(),
                roleType: RoleType.Contract,
                maxMemberCount: MAX_NUM_RELEASES,
                name: REGISTRY_SERVICE_ROLE_NAME}));

        // grant permissions to the registry service role for registry contract
        functions = new FunctionInfo[](2);
        functions[0] = toFunction(IRegistry.register.selector, "register");
        functions[1] = toFunction(IRegistry.registerWithCustomType.selector, "registerWithCustomType");
        _authorizeTargetFunctions(_registry, registryServiceRoleId, functions);
    }


    function _setupStakingRoles()
        private 
        onlyInitializing()
    {
        // create and grant staking contract role
        RoleId stakingRoleId = RoleIdLib.roleForType(STAKING());
        _createRole(
            stakingRoleId, 
            toRole({
                adminRoleId: ADMIN_ROLE(),
                roleType: RoleType.Contract,
                maxMemberCount: 1,
                name: STAKING_ROLE_NAME}));
        _grantRoleToAccount(stakingRoleId, _staking);

        // grant permissions to the staking role for staking store contract
        FunctionInfo[] memory functions;
        functions = new FunctionInfo[](14);
        functions[0] = toFunction(StakingStore.setStakingRate.selector, "setStakingRate");
        functions[1] = toFunction(StakingStore.createTarget.selector, "createTarget");
        functions[2] = toFunction(StakingStore.updateTarget.selector, "updateTarget");
        functions[3] = toFunction(StakingStore.increaseReserves.selector, "increaseReserves");
        functions[4] = toFunction(StakingStore.decreaseReserves.selector, "decreaseReserves");
        functions[5] = toFunction(StakingStore.increaseTotalValueLocked.selector, "increaseTotalValueLocked");
        functions[6] = toFunction(StakingStore.decreaseTotalValueLocked.selector, "decreaseTotalValueLocked");
        functions[7] = toFunction(StakingStore.create.selector, "create");
        functions[8] = toFunction(StakingStore.update.selector, "update");
        functions[9] = toFunction(StakingStore.increaseStake.selector, "increaseStake");
        functions[10] = toFunction(StakingStore.restakeRewards.selector, "restakeRewards");
        functions[11] = toFunction(StakingStore.updateRewards.selector, "updateRewards");
        functions[12] = toFunction(StakingStore.claimUpTo.selector, "claimUpTo");
        functions[13] = toFunction(StakingStore.unstakeUpTo.selector, "unstakeUpTo");
        _authorizeTargetFunctions(_stakingStore, stakingRoleId, functions);
    
        // grant permissions to the staking role for token handler contract
        IStaking staking = IStaking(_staking);
        functions = new FunctionInfo[](2);
        functions[0] = toFunction(TokenHandler.pullToken.selector, "pullToken");
        functions[1] = toFunction(TokenHandler.pushToken.selector, "pushToken");
        _authorizeTargetFunctions(address(staking.getTokenHandler()), stakingRoleId, functions);

        // create staking service role
        RoleId stakingServiceRoleId = RoleIdLib.roleForTypeAndAllVersions(STAKING());
        _createRole(
            stakingServiceRoleId, 
            toRole({
                adminRoleId: ADMIN_ROLE(),
                roleType: RoleType.Contract,
                maxMemberCount: MAX_NUM_RELEASES,
                name: STAKING_SERVICE_ROLE_NAME}));

        // grant permissions to the staking service role for staking contract
        functions = new FunctionInfo[](11);
        functions[0] = toFunction(IStaking.registerTarget.selector, "registerTarget");
        functions[1] = toFunction(IStaking.setLockingPeriod.selector, "setLockingPeriod");
        functions[2] = toFunction(IStaking.setRewardRate.selector, "setRewardRate");
        functions[3] = toFunction(IStaking.refillRewardReserves.selector, "refillRewardReserves");
        functions[4] = toFunction(IStaking.withdrawRewardReserves.selector, "withdrawRewardReserves");
        functions[5] = toFunction(IStaking.createStake.selector, "createStake");
        functions[6] = toFunction(IStaking.stake.selector, "stake");
        functions[7] = toFunction(IStaking.unstake.selector, "unstake");
        functions[8] = toFunction(IStaking.restake.selector, "restake");
        functions[9] = toFunction(IStaking.updateRewards.selector, "updateRewards");
        functions[10] = toFunction(IStaking.claimRewards.selector, "claimRewards");
        _authorizeTargetFunctions(_staking, stakingServiceRoleId, functions);

        // grant permissions to the staking service role for staking token handler
        functions = new FunctionInfo[](2);
        functions[0] = toFunction(TokenHandler.approve.selector, "approve");
        functions[1] = toFunction(TokenHandler.pullToken.selector, "pullToken");
        _authorizeTargetFunctions(
            address(IComponent(_staking).getTokenHandler()), stakingServiceRoleId, functions);

        // create pool service role
        RoleId poolServiceRoleId = RoleIdLib.roleForTypeAndAllVersions(POOL());
        _createRole(
            poolServiceRoleId, 
            toRole({
                adminRoleId: ADMIN_ROLE(),
                roleType: RoleType.Contract,
                maxMemberCount: MAX_NUM_RELEASES,
                name: POOL_SERVICE_ROLE_NAME}));

        // grant permissions to the pool service role for staking contract
        functions = new FunctionInfo[](2);
        functions[0] = toFunction(IStaking.increaseTotalValueLocked.selector, "increaseTotalValueLocked");
        functions[1] = toFunction(IStaking.decreaseTotalValueLocked.selector, "decreaseTotalValueLocked");
        _authorizeTargetFunctions(_staking, poolServiceRoleId, functions);

        // grant permissions to public role for staking contract
        functions = new FunctionInfo[](1);
        functions[0] = toFunction(Staking.approveTokenHandler.selector, "approveTokenHandler");
        _authorizeTargetFunctions(_staking, PUBLIC_ROLE(), functions);
    }
}