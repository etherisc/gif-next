// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";

import {ContractDeployerLib} from "../shared/ContractDeployerLib.sol";
import {RoleId, RoleIdLib,
        REGISTRY_SERVICE_MANAGER_ROLE,
        REGISTRY_SERVICE_ADMIN_ROLE,
        RELEASE_MANAGER_ROLE} from "../types/RoleId.sol";

import {Registry} from "./Registry.sol";
import {IVersionable} from "../shared/IVersionable.sol";
import {IRegistryService} from "./RegistryService.sol";
import {TokenRegistry} from "./TokenRegistry.sol";
import {RegistryServiceReleaseManager} from "./RegistryServiceReleaseManager.sol";

/*
    3 types of roles: 
    1) REGISTRAR roles 
        - each one is unique
        - always have 1 member
        - one role is set for each function of each version of registry service
    2) REGISTRY_SERVICE_MANAGER_ROLE aka GIF_MANAGER_ROLE
        - can have arbitrary number of members
        - responsible for services registrations
        - responsible for token registration and activation
    3) REGISTRY_SERVICE_ADMIN_ROLE aka GIF_ADMIN_ROLE
        - admin of REGISTRY_SERVICE_MANAGER_ROLE
        - MUST have 1 member at any time
        - granted/revoked ONLY in transferAdminRole() -> consider lock out situations!!!
        - responsible for release manager initialization
        - responsible for creation and activation of each release

*/

contract RegistryServiceAccessManager is AccessManaged
{
    uint64 public constant CUSTOM_ROLE_ID_MIN = 1000000;
    
    AccessManager private _accessManager;
    address private _releaseManager;
    address private _tokenRegistry;

    uint64 private _idNext; // role id
    bool private _isInitialized;

    modifier onlyOnce() {
        if(_isInitialized) {
            revert();
        }
        _;
        _isInitialized = true;
    }

    modifier onlyInitialized() {
        if(!_isInitialized) {
            revert();
        }
        _;
    }

    constructor(address manager)
        AccessManaged(msg.sender)
    {
        _accessManager = new AccessManager(address(this));
        setAuthority(address(_accessManager));

        _idNext = CUSTOM_ROLE_ID_MIN;

        _configureAdminRoleInitial();

        address admin = msg.sender;
        _grantRole(REGISTRY_SERVICE_ADMIN_ROLE(), admin, 0);
        _grantRole(REGISTRY_SERVICE_MANAGER_ROLE(), manager, 0);
    }

    // TODO need release manager authorization to configure roles for service functions and to grant those roles
    function initialize(address releaseManager, address tokenRegistry)
        external 
        restricted // GIF_ADMIN_ROLE
        onlyOnce
    {
        if(
            _releaseManager > address(0) ||
            _tokenRegistry > address(0))
        { revert(); }

        _releaseManager = releaseManager;
        _tokenRegistry = tokenRegistry;

        _configureAdminRole();
        _configureManagerRole();
        _configureReleaseManagerRole();

        _grantRole(RELEASE_MANAGER_ROLE(), releaseManager, 0);
    }

    // set unique role for target, role forever have 1 member and never revoked
    function setAndGrantUniqueRole(
        address account, 
        address target, 
        bytes4[] memory selector
    )
        external
        restricted // RELEASE_MANAGER_ROLE
        onlyInitialized
        returns(RoleId)
    {
        // target is not part of `runtime`
        if(
            target == address(this) ||
            target == address(_accessManager) || 
            target == _releaseManager || 
            target == _tokenRegistry)
        { revert(); }

        RoleId roleId = _getNextRoleId();

        _setTargetFunctionRole(target, selector, roleId);
        _grantRole(roleId, account, 0);
    }

    /*function transferAdmin(address to)
        external
        restricted // only with REGISTRY_SERVICE_ADMIN_ROLE or nft owner
    {
        _accessManager.revoke(REGISTRY_SERVICE_ADMIN_ROLE, );
        _accesssManager.grant(REGISTRY_SERVICE_ADMIN_ROLE, to, 0);
    }*/

    //--- view functions ----------------------------------------------------//

    function getAccessManager()
        external
        view
        returns (AccessManager)
    {
        return _accessManager;
    }

    //--- private functions -------------------------------------------------//

    function _configureAdminRoleInitial() private
    {
        bytes4[] memory functionSelector = new bytes4[](1);

        functionSelector[0] = RegistryServiceAccessManager.initialize.selector;
        _setTargetFunctionRole(address(this), functionSelector, REGISTRY_SERVICE_ADMIN_ROLE());
    }

    function _configureAdminRole() private
    {
        bytes4[] memory functionSelector = new bytes4[](1);

        // REGISTRY_SERVICE_ADMIN_ROLE for RegistryServiceProxyManager
        // TODO upgrading with releaseManager.upgrade()->proxy.upgrade()???
        //functionSelector[0] = RegistryServiceManager.upgrade.selector;
        //_setTargetFunctionRole(address(this), functionSelector, REGISTRY_SERVICE_ADMIN_ROLE());

        // REGISTRY_SERVICE_ADMIN_ROLE for TokenRegistry

        // REGISTRY_SERVICE_ADMIN_ROLE for RegistryServiceReleaseManager
        functionSelector[0] = RegistryServiceReleaseManager.createNextRelease.selector;
        _setTargetFunctionRole(_releaseManager, functionSelector, REGISTRY_SERVICE_ADMIN_ROLE());
        functionSelector[0] = RegistryServiceReleaseManager.activateNextRelease.selector;
        _setTargetFunctionRole(_releaseManager, functionSelector, REGISTRY_SERVICE_ADMIN_ROLE());
    }
    
    function _configureManagerRole() private 
    {
        bytes4[] memory functionSelector = new bytes4[](1);

        // REGISTRY_SERVICE_MANAGER_ROLE for TokenRegistry
        functionSelector[0] = TokenRegistry.setActive.selector;
        _setTargetFunctionRole(address(_tokenRegistry), functionSelector, REGISTRY_SERVICE_MANAGER_ROLE());

        // REGISTRY_SERVICE_MANAGER_ROLE for RegistryServiceReleaseManager
        functionSelector[0] = RegistryServiceReleaseManager.registerService.selector;
        _setTargetFunctionRole(_releaseManager, functionSelector, REGISTRY_SERVICE_MANAGER_ROLE());

        // set REGISTRY_SERVICE_ADMIN_ROLE as admin for REGISTRY_SERVICE_MANAGER_ROLE
        _setRoleAdmin(REGISTRY_SERVICE_MANAGER_ROLE(), REGISTRY_SERVICE_ADMIN_ROLE());
    }

    function _configureReleaseManagerRole() private
    {
        bytes4[] memory functionSelector = new bytes4[](1);

        functionSelector[0] = RegistryServiceAccessManager.setAndGrantUniqueRole.selector;
        _setTargetFunctionRole(address(this), functionSelector, RELEASE_MANAGER_ROLE());
    }

    function _setTargetFunctionRole(address target, bytes4[] memory selectors, RoleId roleId) private {
        _accessManager.setTargetFunctionRole(target, selectors, roleId.toInt());        
    }

    function _setRoleAdmin(RoleId roleId, RoleId adminRoleId) private {
        _accessManager.setRoleAdmin(roleId.toInt(), adminRoleId.toInt());
    }

    function _grantRole(RoleId roleId, address account, uint32 executionDelay) private {
            _accessManager.grantRole(roleId.toInt(), account, executionDelay);
    }

    function _getNextRoleId() private returns(RoleId roleId) {
        roleId = RoleIdLib.toRoleId(_idNext++);
    }
}