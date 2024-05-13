// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {AuthorityUtils} from "@openzeppelin/contracts/access/manager/AuthorityUtils.sol";

import {AccessManagerUpgradeableInitializeable} from "../shared/AccessManagerUpgradeableInitializeable.sol";
import {ReleaseManager} from "./ReleaseManager.sol";
import {RoleId, RoleIdLib, GIF_MANAGER_ROLE, GIF_ADMIN_ROLE} from "../type/RoleId.sol";
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

// grants GIF_ADMIN_ROLE to registry owner as registryOwner is transaction sender
// grants GIF_MANAGER_ROLE to registry owner via contructor argument
contract RegistryAccessManager is
    AccessManaged
{
    uint64 public constant UNIQUE_ROLE_ID_MIN = 1000000;
    
    address private _releaseManager;
    uint64 private _idNext; // role id


    // IMPORTNAT: this.authority() must be valid before initialize() function....
    // -> have constructor and initializer function
    constructor(
        address gifAdmin,
        address gifManager
    )
        AccessManaged(msg.sender)
    {
        _releaseManager = msg.sender;

        AccessManagerUpgradeableInitializeable accessManager = new AccessManagerUpgradeableInitializeable();
        accessManager.initialize(address(this));
        setAuthority(address(accessManager));

        _idNext = UNIQUE_ROLE_ID_MIN;

        _setAdminRole();
        _setManagerRole();

        _grantRole(GIF_ADMIN_ROLE(), gifAdmin, 0);
        _grantRole(GIF_MANAGER_ROLE(), gifManager, 0);

        // set gif manager role admin
        _setRoleAdmin(GIF_MANAGER_ROLE(), GIF_ADMIN_ROLE());
    }


    function setTokenRegistry(
        address tokenRegistry    
    )
        external
        restricted() // GIF_ADMIN_ROLE
    {
        // for TokenRegistry
        bytes4[] memory functionSelector = new bytes4[](5);
        functionSelector[0] = TokenRegistry.registerToken.selector;
        functionSelector[1] = TokenRegistry.registerRemoteToken.selector;
        functionSelector[2] = TokenRegistry.setActive.selector;
        functionSelector[3] = TokenRegistry.setActiveForVersion.selector;

        // only needed for testing TODO find a better way
        functionSelector[4] = TokenRegistry.setActiveWithVersionCheck.selector;
        _setTargetFunctionRole(address(tokenRegistry), functionSelector, GIF_MANAGER_ROLE());
    }


    // set unique role for target, role forever have 1 member and never revoked
    function setAndGrantUniqueRole(
        address account, 
        address target, 
        bytes4[] memory selector
    )
        external
        restricted // RELEASE_MANAGER_ROLE
        returns(RoleId)
    {
        // TODO define and add checks
        RoleId roleId = _getNextRoleId();

        _setTargetFunctionRole(target, selector, roleId);
        _grantRole(roleId, account, 0);
    }

    function setTargetFunctionRole(
        address target, 
        bytes4[] memory selector,
        RoleId roleId
    )
        external
        restricted // RELEASE_MANAGER_ROLE
    {
        _setTargetFunctionRole(target, selector, roleId);
    }

    /*function transferAdmin(address to)
        external
        restricted // only with GIF_ADMIN_ROLE or nft owner
    {
        _accessManager.revoke(GIF_ADMIN_ROLE, );
        _accesssManager.grant(GIF_ADMIN_ROLE, to, 0);
    }*/

    //--- view functions ----------------------------------------------------//

    function hasRole(
        address account,
        RoleId roleId
    )
        external
        view
        returns(bool)
    {
        (bool isMember, ) = AccessManager(authority()).hasRole(roleId.toInt(), account);
        return isMember;
    }


    function canCall(
        address account,
        address target,
        bytes4 functionSelector
    )
        external
        view
        returns(bool)
    {
        (bool immediate,) = AuthorityUtils.canCallWithDelay(
            authority(),
            account,
            target,
            functionSelector);

        return immediate;
    }

    //--- private functions -------------------------------------------------//

    function _setAdminRole() private
    {
        // for this contract
        bytes4[] memory functionSelector = new bytes4[](1);
        functionSelector[0] = RegistryAccessManager.setTokenRegistry.selector;

        _setTargetFunctionRole(address(this), functionSelector, GIF_ADMIN_ROLE());

        // for ReleaseManager
        bytes4[] memory functionSelector2 = new bytes4[](3);
        functionSelector2[0] = ReleaseManager.registerStaking.selector;
        functionSelector2[1] = ReleaseManager.createNextRelease.selector;
        functionSelector2[2] = ReleaseManager.activateNextRelease.selector;

        _setTargetFunctionRole(_releaseManager, functionSelector2, GIF_ADMIN_ROLE());
    }
    
    function _setManagerRole() private 
    {
        // for ReleaseManager
        bytes4[] memory functionSelector = new bytes4[](2);
        functionSelector[0] = ReleaseManager.registerService.selector; // for ReleaseManager
        functionSelector[1] = ReleaseManager.prepareNextRelease.selector;
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