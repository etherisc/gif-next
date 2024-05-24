// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {AuthorityUtils} from "@openzeppelin/contracts/access/manager/AuthorityUtils.sol";

import {RoleId, RoleIdLib, GIF_MANAGER_ROLE, GIF_ADMIN_ROLE} from "../type/RoleId.sol";

import {AccessManagerExtendedInitializeable} from "../shared/AccessManagerExtendedInitializeable.sol";
import {InitializableCustom} from "../shared/InitializableCustom.sol";

import {IRegistry} from "./IRegistry.sol";
import {ReleaseManager} from "./ReleaseManager.sol";
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

// !!! USE BUILDER PATTERN FOR CONFIG 
// introduce class - config
// create instance of this class in admin initializer function
// call it "add"/"push" function for each entry in config (provide entry parameneters)
// each call will configure access manager for given parameneters
// in the end you have fully configured access manager and config object

// grants GIF_ADMIN_ROLE to registry owner as registryOwner is transaction sender
// grants GIF_MANAGER_ROLE to registry owner via contructor argument
contract RegistryAdmin is
    AccessManaged,
    InitializableCustom
{
    error ErrorRegistryAdminReleaseManagerAuthorityMismatch();
    error ErrorRegistryAdminTokenRegistryAuthorityMismatch();
    error ErrorRegistryAdminStakingAuthorityMismatch();

    string public constant GIF_ADMIN_ROLE_NAME = "GifAdminRole";
    string public constant GIF_MANAGER_ROLE_NAME = "GifManagerRole";

    string public constant RELEASE_MANAGER_TARGET_NAME = "ReleaseManager";
    string public constant TOKEN_REGISTRY_TARGET_NAME = "TokenRegistry";
    string public constant STAKING_TARGET_NAME = "Staking";
    
    address private _releaseManager;
    address private _tokenRegistry;
    address private _staking;

    constructor()
        AccessManaged(msg.sender)
        InitializableCustom()
    {
        AccessManagerExtendedInitializeable accessManager = new AccessManagerExtendedInitializeable();
        accessManager.initialize(address(this));
        setAuthority(address(accessManager));
    }

    function initialize(
        IRegistry registry,
        address gifAdmin, 
        address gifManager
    )
        external
        initializer
    {
        // validate input
        address releaseManagerAddress = registry.getReleaseManagerAddress();
        if(IAccessManaged(releaseManagerAddress).authority() != authority()) {
            revert ErrorRegistryAdminReleaseManagerAuthorityMismatch();
        }

        address tokenRegistryAddress = registry.getTokenRegistryAddress();
        if(IAccessManaged(tokenRegistryAddress).authority() != authority()) {
            revert ErrorRegistryAdminTokenRegistryAuthorityMismatch();
        }

        address stakingAddress = registry.getStakingAddress();
        if(IAccessManaged(stakingAddress).authority() != authority()) {
            revert ErrorRegistryAdminStakingAuthorityMismatch();
        }

        _releaseManager = releaseManagerAddress;
        _tokenRegistry = tokenRegistryAddress;
        _staking = stakingAddress;

        // at this moment all registry contracts are deployed and fully intialized
        _createRole(GIF_ADMIN_ROLE(), GIF_ADMIN_ROLE_NAME);
        _createRole(GIF_MANAGER_ROLE(), GIF_MANAGER_ROLE_NAME);

        _createTarget(_releaseManager, RELEASE_MANAGER_TARGET_NAME);
        _createTarget(_tokenRegistry, TOKEN_REGISTRY_TARGET_NAME);
        _createTarget(_staking, STAKING_TARGET_NAME);

        _setGifAdminRole();
        _setGifManagerRole();

        _grantRole(GIF_ADMIN_ROLE(), gifAdmin, 0);
        _grantRole(GIF_MANAGER_ROLE(), gifManager, 0);

        // set gif manager role admin
        _setRoleAdmin(GIF_MANAGER_ROLE(), GIF_ADMIN_ROLE());
    }


    function setTargetFunctionRole(
        address target, 
        bytes4[] memory selector,
        RoleId roleId
    )
        external
        restricted // RELEASE_MANAGER_ROLE -> TODO create this role
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

    function targets() external view returns (uint256 numberOfTargets) {
        return AccessManagerExtendedInitializeable(authority()).getTargets();
    }

    function getTargetAddress(uint256 idx) external view returns (address target) {
        return AccessManagerExtendedInitializeable(authority()).getTarget(idx);
    }

    function getTargetInfo(address target) external view returns (AccessManagerExtendedInitializeable.TargetInfo memory info) {
        return AccessManagerExtendedInitializeable(authority()).getTargetInfo(target);
    }

    function roles() external view returns (uint256 numberOfRoles) {
        return AccessManagerExtendedInitializeable(authority()).getRoles();
    }

    function getRoleId(uint256 idx) external view returns (RoleId roleId) {
        uint64 roleIdInt = AccessManagerExtendedInitializeable(authority()).getRoleId(idx);
        return RoleIdLib.toRoleId(roleIdInt);
    }

    function getRoleInfo(RoleId roleId) external view returns (AccessManagerExtendedInitializeable.RoleInfo memory) {
        uint64 roleIdInt = uint64(roleId.toInt()); 
        return AccessManagerExtendedInitializeable(authority()).getRoleInfo(roleIdInt);
    }

    function roleMembers(RoleId roleId) external view returns (uint256 numberOfMembers) {
        uint64 roleIdInt = uint64(roleId.toInt());
        return AccessManagerExtendedInitializeable(authority()).getRoleMembers(roleIdInt);
    }

    function hasRole(address account, RoleId roleId) external view returns(bool) {
        (bool isMember,) =  AccessManagerExtendedInitializeable(authority()).hasRole(roleId.toInt(), account);
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

    function _setGifAdminRole() private
    {
        // for ReleaseManager
        bytes4[] memory functionSelector2 = new bytes4[](2);
        //functionSelector2[0] = ReleaseManager.registerStaking.selector;
        functionSelector2[0] = ReleaseManager.createNextRelease.selector;
        functionSelector2[1] = ReleaseManager.activateNextRelease.selector;

        _setTargetFunctionRole(_releaseManager, functionSelector2, GIF_ADMIN_ROLE());

        // for Staking
    }
    
    function _setGifManagerRole() private 
    {
        // for TokenRegistry
        bytes4[] memory functionSelectorTr = new bytes4[](5);
        functionSelectorTr[0] = TokenRegistry.registerToken.selector;
        functionSelectorTr[1] = TokenRegistry.registerRemoteToken.selector;
        functionSelectorTr[2] = TokenRegistry.setActive.selector;
        functionSelectorTr[3] = TokenRegistry.setActiveForVersion.selector;

        // only needed for testing TODO find a better way
        functionSelectorTr[4] = TokenRegistry.setActiveWithVersionCheck.selector;
        _setTargetFunctionRole(_tokenRegistry, functionSelectorTr, GIF_MANAGER_ROLE());

        // for ReleaseManager
        bytes4[] memory functionSelectorRm = new bytes4[](2);
        functionSelectorRm[0] = ReleaseManager.registerService.selector;
        functionSelectorRm[1] = ReleaseManager.prepareNextRelease.selector;
        _setTargetFunctionRole(_releaseManager, functionSelectorRm, GIF_MANAGER_ROLE());

        // for Staking
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