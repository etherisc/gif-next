// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessAdmin} from "../shared/AccessAdmin.sol";
import {IRegistry} from "./IRegistry.sol";
import {ReleaseManager} from "./ReleaseManager.sol";
import {RoleId, GIF_MANAGER_ROLE, GIF_ADMIN_ROLE} from "../type/RoleId.sol";
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
    
    address private _releaseManager;
    address private _tokenRegistry;
    address private _staking;
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

        // at this moment all registry contracts are deployed and fully intialized
        _createRole(GIF_ADMIN_ROLE(), getAdminRole(), GIF_ADMIN_ROLE_NAME);
        _createRole(GIF_MANAGER_ROLE(), GIF_ADMIN_ROLE(), GIF_MANAGER_ROLE_NAME);

        _createTarget(_releaseManager, RELEASE_MANAGER_TARGET_NAME);
        _createTarget(_tokenRegistry, TOKEN_REGISTRY_TARGET_NAME);
        _createTarget(_staking, STAKING_TARGET_NAME);

        _setupGifAdminRole();
        _setupGifManagerRole();

        _grantRoleToAccount(GIF_ADMIN_ROLE(), gifAdmin);
        _grantRoleToAccount(GIF_MANAGER_ROLE(), gifManager);
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

    function _setupGifAdminRole() private
    {
        Function[] memory functions;

        // for ReleaseManager
        functions = new Function[](2);
        functions[0] = toFunction(ReleaseManager.createNextRelease.selector, "createNextRelease");
        functions[1] = toFunction(ReleaseManager.activateNextRelease.selector, "activateNextRelease");
        _authorizeTargetFunctions(_releaseManager, GIF_ADMIN_ROLE(), functions);

        // for Staking
    }
    
    function _setupGifManagerRole() private 
    {
        Function[] memory functions;

        // for TokenRegistry
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
}