// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {RoleId, RoleIdLib, GIF_MANAGER_ROLE, GIF_ADMIN_ROLE} from "../type/RoleId.sol";

import {AccessManagerExtendedInitializeable} from "../shared/AccessManagerExtendedInitializeable.sol";

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

contract RegistryAdmin is AccessManaged, Initializable 
{
    error ErrorRegistryAdminReleaseManagerAuthorityMismatch();
    error ErrorRegistryAdminTokenRegistryZero();

    string public constant GIF_ADMIN_ROLE_NAME = "GifAdminRole";
    string public constant GIF_MANAGER_ROLE_NAME = "GifManagerRole";

    string public constant RELEASE_MANAGER_TARGET_NAME = "ReleaseManager";
    //string public constant TOKEN_REGISTRY_TARGET_NAME = "TokenRegistry";

    uint64 public constant UNIQUE_ROLE_ID_MIN = 1000000;
    
    address private _releaseManager;
    address private _tokenRegistry;

    // IMPORTNAT: this.authority() must be valid before initialize() function
    // -> have both, constructor and initializer
    constructor()
        AccessManaged(msg.sender)
    {
        AccessManagerExtendedInitializeable accessManager = new AccessManagerExtendedInitializeable();
        accessManager.initialize(address(this));
        setAuthority(address(accessManager));
    }

    /// @dev any body can call this function
    function initialize(address admin, address manager, address releaseManager, address tokenRegistry)
        external
        initializer
    {
        // validate input
        if(AccessManaged(releaseManager).authority() != authority()) {
            revert ErrorRegistryAdminReleaseManagerAuthorityMismatch();
        }
        if(tokenRegistry == address(0)) {
            revert ErrorRegistryAdminTokenRegistryZero();
        }

        _releaseManager = releaseManager;
        _tokenRegistry = tokenRegistry;

        _createRole(GIF_ADMIN_ROLE(), GIF_ADMIN_ROLE_NAME);
        _createRole(GIF_MANAGER_ROLE(), GIF_MANAGER_ROLE_NAME);

        _createTarget(_releaseManager, RELEASE_MANAGER_TARGET_NAME);
        //_createTarget(_tokenRegistry, TOKEN_REGISTRY_TARGET_NAME);

        _setGifAdminRole();
        _setGifManagerRole();

        _grantRole(GIF_ADMIN_ROLE(), admin, 0);
        _grantRole(GIF_MANAGER_ROLE(), manager, 0);

        _setRoleAdmin(GIF_MANAGER_ROLE(), GIF_ADMIN_ROLE());
    }
    // in instance access mamanger it done differently -> instance have role and calls instance access manager revoke()/grant()
    /*function transferAdmin(address to)
        external
        restricted // only with GIF_ADMIN_ROLE or nft owner
    {
        _accessManager.revoke(GIF_ADMIN_ROLE, );
        _accesssManager.grant(GIF_ADMIN_ROLE, to, 0);
    }*/

    //--- view functions ----------------------------------------------------//

    //--- private functions -------------------------------------------------//

    function _setGifAdminRole() private
    {
        bytes4[] memory functionSelector = new bytes4[](1);

        // for ReleaseManager
        functionSelector[0] = ReleaseManager.createNextRelease.selector;
        _setTargetFunctionRole(_releaseManager, functionSelector, GIF_ADMIN_ROLE());

        functionSelector[0] = ReleaseManager.activateNextRelease.selector;
        _setTargetFunctionRole(_releaseManager, functionSelector, GIF_ADMIN_ROLE());
    }
    
    function _setGifManagerRole() private 
    {
        bytes4[] memory functionSelector = new bytes4[](1);

        // for TokenRegistry
        //functionSelector[0] = TokenRegistry.setActive.selector;
        //_setTargetFunctionRole(_tokenRegistry, functionSelector, GIF_MANAGER_ROLE());

        // for ReleaseManager
        functionSelector[0] = ReleaseManager.registerService.selector;
        _setTargetFunctionRole(_releaseManager, functionSelector, GIF_MANAGER_ROLE());

        functionSelector[0] = ReleaseManager.prepareNextRelease.selector;
        _setTargetFunctionRole(_releaseManager, functionSelector, GIF_MANAGER_ROLE());
    }

    function _setTargetFunctionRole(address target, bytes4[] memory selectors, RoleId roleId) private {
        AccessManagerExtendedInitializeable(authority()).setTargetFunctionRole(target, selectors, roleId.toInt());        
    }

    function _setRoleAdmin(RoleId roleId, RoleId adminRoleId) private {
        AccessManagerExtendedInitializeable(authority()).setRoleAdmin(roleId.toInt(), adminRoleId.toInt());
    }

    function _grantRole(RoleId roleId, address account, uint32 executionDelay) private {
        AccessManagerExtendedInitializeable(authority()).grantRole(roleId.toInt(), account, executionDelay);
    }

    function _createRole(RoleId roleId, string memory roleName) private {
        AccessManagerExtendedInitializeable(authority()).createRole(roleId.toInt(), roleName);
    }

    function _createTarget(address target, string memory targetName) private {
        AccessManagerExtendedInitializeable(authority()).createTarget(target, targetName);
    }
}