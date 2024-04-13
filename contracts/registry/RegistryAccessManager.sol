// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {RoleId, RoleIdLib, GIF_MANAGER_ROLE, GIF_ADMIN_ROLE} from "../type/RoleId.sol";

import {AccessManagerUpgradeableInitializeable} from "../shared/AccessManagerUpgradeableInitializeable.sol";

import {TokenRegistry} from "./TokenRegistry.sol";
import {ReleaseManager} from "./ReleaseManager.sol";

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

contract RegistryAccessManager is AccessManaged, Initializable
{
    error ErrorRegistryAccessManagerReleaseManagerAuthorityMismatch();
    error ErrorRegistryAccessManagerTokenRegistryZero();

    uint64 public constant UNIQUE_ROLE_ID_MIN = 1000000;
    
    address private _releaseManager;
    address private _tokenRegistry;

    uint64 private _idNext; // role id


    // IMPORTNAT: this.authority() must be valid before initialize() function....
    // -> have constructor and initializer function
    constructor()
        AccessManaged(msg.sender)
    {
        AccessManagerUpgradeableInitializeable accessManager = new AccessManagerUpgradeableInitializeable();
        accessManager.initialize(address(this));
        setAuthority(address(accessManager));
    }

    function initialize(address admin, address manager, address releaseManager, address tokenRegistry)
        external
        initializer
    {
        // validate input
        if(IAccessManaged(releaseManager).authority() != authority()) {
            revert ErrorRegistryAccessManagerReleaseManagerAuthorityMismatch();
        }
        if(tokenRegistry == address(0)) {
            revert ErrorRegistryAccessManagerTokenRegistryZero();
        }

        _releaseManager = releaseManager;
        _tokenRegistry = tokenRegistry;
        _idNext = UNIQUE_ROLE_ID_MIN;

        _setAdminRole();
        _setManagerRole();

        _grantRole(GIF_ADMIN_ROLE(), admin, 0);
        _grantRole(GIF_MANAGER_ROLE(), manager, 0);

        _setRoleAdmin(GIF_MANAGER_ROLE(), GIF_ADMIN_ROLE());
    }

    /*function transferAdmin(address to)
        external
        restricted // only with GIF_ADMIN_ROLE or nft owner
    {
        _accessManager.revoke(GIF_ADMIN_ROLE, );
        _accesssManager.grant(GIF_ADMIN_ROLE, to, 0);
    }*/

    //--- view functions ----------------------------------------------------//

    //--- private functions -------------------------------------------------//

    function _setAdminRole() private
    {
        bytes4[] memory functionSelector = new bytes4[](1);

        // for ReleaseManager
        functionSelector[0] = ReleaseManager.createNextRelease.selector;
        _setTargetFunctionRole(_releaseManager, functionSelector, GIF_ADMIN_ROLE());

        functionSelector[0] = ReleaseManager.activateNextRelease.selector;
        _setTargetFunctionRole(_releaseManager, functionSelector, GIF_ADMIN_ROLE());
    }
    
    function _setManagerRole() private 
    {
        bytes4[] memory functionSelector = new bytes4[](1);

        // for TokenRegistry
        functionSelector[0] = TokenRegistry.setActive.selector;
        _setTargetFunctionRole(address(_tokenRegistry), functionSelector, GIF_MANAGER_ROLE());

        // for ReleaseManager
        functionSelector[0] = ReleaseManager.registerService.selector;
        _setTargetFunctionRole(_releaseManager, functionSelector, GIF_MANAGER_ROLE());
    }

    function _setTargetFunctionRole(address target, bytes4[] memory selectors, RoleId roleId) private {
        AccessManager(authority()).setTargetFunctionRole(target, selectors, roleId.toInt());        
    }

    function _setRoleAdmin(RoleId roleId, RoleId adminRoleId) private {
        AccessManager(authority()).setRoleAdmin(roleId.toInt(), adminRoleId.toInt());
    }

    function _grantRole(RoleId roleId, address account, uint32 executionDelay) private {
        AccessManager(authority()).grantRole(roleId.toInt(), account, executionDelay);
    }

    function _getNextRoleId() private returns(RoleId roleId) {
        roleId = RoleIdLib.toRoleId(_idNext++);
    }
}