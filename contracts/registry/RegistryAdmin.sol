// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessAdmin} from "../shared/AccessAdmin.sol";
import {IRegistry} from "./IRegistry.sol";
import {IStaking} from "../staking/IStaking.sol";
import {ReleaseManager} from "./ReleaseManager.sol";
import {RoleId, RoleIdLib, ADMIN_ROLE, GIF_MANAGER_ROLE, GIF_ADMIN_ROLE} from "../type/RoleId.sol";
import {StakingStore} from "../staking/StakingStore.sol";
import {STAKING} from "../type/ObjectType.sol";
import {TokenRegistry} from "./TokenRegistry.sol";

/*
    1) GIF_MANAGER_ROLE
        - can have arbitrary number of members
        - responsible for services registrations
        - responsible for token registration and activation

    2) GIF_ADMIN_ROLE
        - admin of GIF_MANAGER_ROLE
        - MUST have 1 member at any time
        - granted/revoked ONLY in transferAdminRole() -> consider lock out situations!!!
        - responsible for creation and activation of releases

    createServiceTarget(type, release)
    createServiceRole(type,release)
    getServiceRole(type, release)
*/
contract RegistryAdmin is
    AccessAdmin
{
    error ErrorRegistryAdminIsAlreadySetUp();

    string public constant GIF_ADMIN_ROLE_NAME = "GifAdminRole";
    string public constant GIF_MANAGER_ROLE_NAME = "GifManagerRole";

    string public constant RELEASE_MANAGER_TARGET_NAME = "ReleaseManager";
    string public constant TOKEN_REGISTRY_TARGET_NAME = "TokenRegistry";
    string public constant STAKING_TARGET_NAME = "Staking";
    string public constant STAKING_STORE_TARGET_NAME = "StakingStore";
    
    address private _releaseManager;
    address private _tokenRegistry;
    address private _staking;
    address private _stakingStore;
    bool private _setupCompleted;

    constructor() AccessAdmin() { }

    function completeSetup(
        IRegistry registry,
        address gifAdmin, 
        address gifManager
    )
        external
        onlyDeployer()
    {
        if (_setupCompleted) { revert ErrorRegistryAdminIsAlreadySetUp(); } 
        else { _setupCompleted = true; }

        _releaseManager = registry.getReleaseManagerAddress();
        _tokenRegistry = registry.getTokenRegistryAddress();
        _staking = registry.getStakingAddress();
        _stakingStore = address(
            IStaking(_staking).getStakingStore());

        // at this moment all registry contracts are deployed and fully intialized
        _createTarget(_releaseManager, RELEASE_MANAGER_TARGET_NAME);
        _createTarget(_tokenRegistry, TOKEN_REGISTRY_TARGET_NAME);

        _setupGifAdminRole(gifAdmin);
        _setupGifManagerRole(gifManager);

        _setupStakingRole();
    }

    /*function transferAdmin(address to)
        external
        restricted // only with GIF_ADMIN_ROLE or nft owner
    {
        _accessManager.revoke(GIF_ADMIN_ROLE, );
        _accesssManager.grant(GIF_ADMIN_ROLE, to, 0);
    }*/

    //--- view functions ----------------------------------------------------//

    function getGifAdminRole() external view returns (RoleId) {
        return GIF_ADMIN_ROLE();
    }

    function getGifManagerRole() external view returns (RoleId) {
        return GIF_MANAGER_ROLE();
    }

    //--- private functions -------------------------------------------------//

    function _setupGifAdminRole(address gifAdmin) private {
        _createRole(GIF_ADMIN_ROLE(), getAdminRole(), GIF_ADMIN_ROLE_NAME);
        _grantRoleToAccount(GIF_ADMIN_ROLE(), gifAdmin);

        // for ReleaseManager
        Function[] memory functions;
        functions = new Function[](2);
        functions[0] = toFunction(ReleaseManager.createNextRelease.selector, "createNextRelease");
        functions[1] = toFunction(ReleaseManager.activateNextRelease.selector, "activateNextRelease");
        _authorizeTargetFunctions(_releaseManager, GIF_ADMIN_ROLE(), functions);

        // for Staking
    }
    
    function _setupGifManagerRole(address gifManager) private {
        _createRole(GIF_MANAGER_ROLE(), GIF_ADMIN_ROLE(), GIF_MANAGER_ROLE_NAME);
        _grantRoleToAccount(GIF_MANAGER_ROLE(), gifManager);

        // for TokenRegistry
        Function[] memory functions;
        functions = new Function[](5);
        functions[0] = toFunction(TokenRegistry.registerToken.selector, "registerToken");
        functions[1] = toFunction(TokenRegistry.registerRemoteToken.selector, "registerRemoteToken");
        functions[2] = toFunction(TokenRegistry.setActive.selector, "setActive");
        functions[3] = toFunction(TokenRegistry.setActiveForVersion.selector, "setActiveForVersion");
        // TODO find a better way (only needed for testing)
        functions[4] = toFunction(TokenRegistry.setActiveWithVersionCheck.selector, "setActiveWithVersionCheck");
        _authorizeTargetFunctions(_tokenRegistry, GIF_MANAGER_ROLE(), functions);

        // for ReleaseManager
        functions = new Function[](2);
        functions[0] = toFunction(ReleaseManager.prepareNextRelease.selector, "prepareNextRelease");
        functions[1] = toFunction(ReleaseManager.registerService.selector, "registerService");
        _authorizeTargetFunctions(_releaseManager, GIF_MANAGER_ROLE(), functions);

        // for Staking
    }

    function _setupStakingRole() private {
        _createTarget(_staking, STAKING_TARGET_NAME);
        _createTarget(_stakingStore, STAKING_STORE_TARGET_NAME);

        RoleId stakingRoleId = RoleIdLib.roleForType(STAKING());
        _createRole(stakingRoleId, ADMIN_ROLE(), STAKING_TARGET_NAME);
        _grantRoleToAccount(stakingRoleId, _staking);

        Function[] memory functions;
        functions = new Function[](14);
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
    }
}