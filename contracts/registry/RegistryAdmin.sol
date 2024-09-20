// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IAuthorization} from "../authorization/IAuthorization.sol";
import {IRegistry} from "./IRegistry.sol";
import {IService} from "../shared/IService.sol";
import {IStaking} from "../staking/IStaking.sol";

import {AccessAdmin} from "../authorization/AccessAdmin.sol";
import {AccessAdminLib} from "../authorization/AccessAdminLib.sol";
import {AccessManagerCloneable} from "../authorization/AccessManagerCloneable.sol";
import {ObjectType, REGISTRY} from "../type/ObjectType.sol";
import {RoleId, RoleIdLib, GIF_MANAGER_ROLE, GIF_ADMIN_ROLE} from "../type/RoleId.sol";
import {GIF_INITIAL_RELEASE} from "../registry/Registry.sol";
import {Str} from "../type/String.sol";
import {VersionPartLib} from "../type/Version.sol";

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

    /// @dev gif core targets
    string public constant REGISTRY_ADMIN_TARGET_NAME = "RegistryAdmin";
    string public constant REGISTRY_TARGET_NAME = "Registry";
    string public constant RELEASE_REGISTRY_TARGET_NAME = "ReleaseRegistry";
    string public constant STAKING_TARGET_NAME = "Staking";
    string public constant STAKING_TARGET_HANDLER_NAME = "TargetHandler";
    string public constant STAKING_STORE_TARGET_NAME = "StakingStore";
    string public constant STAKING_TH_TARGET_NAME = "StakingTH";
    string public constant TOKEN_REGISTRY_TARGET_NAME = "TokenRegistry";
    string public constant TOKEN_HANDLER_TARGET_NAME = "TokenHandler";

    // completeSetup
    error ErrorRegistryAdminNotRegistry(address registry);

    address private _releaseRegistry;
    address private _tokenRegistry;
    address private _staking;
    address private _stakingTargetHandler;
    address private _stakingStore;

    constructor() {
        initialize(
            address(new AccessManagerCloneable()),
            "RegistryAdmin",
            GIF_INITIAL_RELEASE());
    }


    function completeSetup(
        address registry,
        address authorization,
        address gifAdmin, 
        address gifManager
    )
        public
        virtual
    {
        // checks
        AccessAdminLib.checkAuthorization(
            address(_authorization),
            authorization, 
            REGISTRY(), 
            getRelease(), 
            false, // expectServiceAuthorization
            false); // checkAlreadyInitialized);
        
        // effects
        __RegistryLinked_init(registry);

        _authorization = IAuthorization(authorization);

        IRegistry registryContract = IRegistry(registry);
        _releaseRegistry = registryContract.getReleaseRegistryAddress();
        _tokenRegistry = registryContract.getTokenRegistryAddress();
        _staking = registryContract.getStakingAddress();
        _stakingTargetHandler = address(IStaking(_staking).getTargetHandler());
        _stakingStore = address(IStaking(_staking).getStakingStore());

        // link nft ownability to registry
        _linkToNftOwnable(address(getRegistry()));

        _createRoles(_authorization);

        // setup registry core targets
        _createCoreTargets(_authorization.getMainTargetName());

        // setup non-contract roles
        _grantRoleToAccount(GIF_ADMIN_ROLE(), gifAdmin);
        _grantRoleToAccount(GIF_MANAGER_ROLE(), gifManager);

        // authorize functions of registry and staking contracts
        _createTargetAuthorizations(_authorization);
    }


    function grantServiceRoleForAllVersions(
        IService service, 
        ObjectType domain
    )
        external
        restricted()
    {
        _grantRoleToAccount( 
            RoleIdLib.toGenericServiceRoleId(domain),
            address(service)); 
    }

    //--- view functions ----------------------------------------------------//

    function getGifAdminRole() external pure returns (RoleId) {
        return GIF_ADMIN_ROLE();
    }

    function getGifManagerRole() external pure returns (RoleId) {
        return GIF_MANAGER_ROLE();
    }

    //--- private initialization functions -------------------------------------------//


    function _createCoreTargets(string memory registryTargetName)
        internal
    {
        // create unchecked registry targets
        _createTarget(address(getRegistry()), registryTargetName, TargetType.Core, false);
        _createTarget(address(this), REGISTRY_ADMIN_TARGET_NAME, TargetType.Core, false);
        _createTarget(_releaseRegistry, RELEASE_REGISTRY_TARGET_NAME, TargetType.Core, false);
        _createTarget(_tokenRegistry, TOKEN_REGISTRY_TARGET_NAME, TargetType.Core, false);

        // create unchecked staking targets
        _createTarget(_staking, STAKING_TARGET_NAME, TargetType.Core, false);
        _createTarget(_stakingTargetHandler, STAKING_TARGET_HANDLER_NAME, TargetType.Core, false);
        _createTarget(_stakingStore, STAKING_STORE_TARGET_NAME, TargetType.Core, false);
    }


    function _createTargetAuthorizations(IAuthorization authorization)
        internal
    {
        Str[] memory targets = authorization.getTargets();
        Str target;

        for(uint256 i = 0; i < targets.length; i++) {
            target = targets[i];
            RoleId[] memory authorizedRoles = authorization.getAuthorizedRoles(target);

            for(uint256 j = 0; j < authorizedRoles.length; j++) {
                _authorizeFunctions(authorization, target, authorizedRoles[j]);
            }
        }
    }
}