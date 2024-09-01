// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IAuthorization} from "../authorization/IAuthorization.sol";
import {IComponent} from "../shared/IComponent.sol";
import {IRegistry} from "./IRegistry.sol";
import {IService} from "../shared/IService.sol";
import {IStaking} from "../staking/IStaking.sol";

import {AccessAdmin} from "../authorization/AccessAdmin.sol";
import {AccessAdminLib} from "../authorization/AccessAdminLib.sol";
import {AccessManagerCloneable} from "../authorization/AccessManagerCloneable.sol";
import {ContractLib} from "../shared/ContractLib.sol";
import {ObjectType, REGISTRY, STAKING, POOL, RELEASE} from "../type/ObjectType.sol";
import {ReleaseRegistry} from "./ReleaseRegistry.sol";
import {RoleId, RoleIdLib, ADMIN_ROLE, GIF_MANAGER_ROLE, GIF_ADMIN_ROLE, PUBLIC_ROLE} from "../type/RoleId.sol";
import {Staking} from "../staking/Staking.sol";
import {Str, StrLib} from "../type/String.sol";
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

    /// @dev gif core targets
    string public constant REGISTRY_ADMIN_TARGET_NAME = "RegistryAdmin";
    string public constant REGISTRY_TARGET_NAME = "Registry";
    string public constant RELEASE_REGISTRY_TARGET_NAME = "ReleaseRegistry";
    string public constant STAKING_TARGET_NAME = "Staking";
    string public constant STAKING_TH_TARGET_NAME = "StakingTH";
    string public constant STAKING_STORE_TARGET_NAME = "StakingStore";
    string public constant TOKEN_REGISTRY_TARGET_NAME = "TokenRegistry";
    string public constant TOKEN_HANDLER_TARGET_NAME = "TokenHandler";

    // completeSetup
    error ErrorRegistryAdminNotRegistry(address registry);

    address internal _registry;
    address private _releaseRegistry;
    address private _tokenRegistry;
    address private _staking;
    address private _stakingStore;

    constructor() {
        initialize(
            address(new AccessManagerCloneable()),
            "RegistryAdmin");
    }


    function completeSetup(
        address registry,
        address authorization,
        address gifAdmin, 
        address gifManager
    )
        public
        virtual
        reinitializer(type(uint8).max)
        onlyDeployer()
    {
        // checks
        AccessAdminLib.checkRegistry(registry);

        VersionPart release = VersionPartLib.toVersionPart(3);
        AccessManagerCloneable(
            authority()).completeSetup(
                registry, 
                release); 

        _checkAuthorization(authorization, REGISTRY(), release, true);

        _registry = registry;
        _authorization = IAuthorization(authorization);

        IRegistry registryContract = IRegistry(registry);
        _releaseRegistry = registryContract.getReleaseRegistryAddress();
        _tokenRegistry = registryContract.getTokenRegistryAddress();
        _staking = registryContract.getStakingAddress();
        _stakingStore = address(
            IStaking(_staking).getStakingStore());

        // link nft ownability to registry
        _linkToNftOwnable(_registry);

        // register core targets
        _createCoreTargets(_authorization.getMainTargetName());

        // setup authorization for registry and supporting contracts
        _createRoles(_authorization);
        _grantRoleToAccount(GIF_ADMIN_ROLE(), gifAdmin);
        _grantRoleToAccount(GIF_MANAGER_ROLE(), gifManager);

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

    function _createRoles(IAuthorization authorization)
        internal
    {
        RoleId[] memory roles = authorization.getRoles();

        for(uint256 i = 0; i < roles.length; i++) {
            RoleId roleId = roles[i];
            RoleInfo memory roleInfo = authorization.getRoleInfo(roleId);

            // create role if not exists
            if (!roleExists(roleInfo.name)) {
                _createRole(
                    roleId,
                    roleInfo);
            }
        }
    }


    function _createCoreTargets(string memory registryTargetName)
        internal
    {
        // registry
        _createUncheckedTarget(_registry, registryTargetName, TargetType.Core);
        _createUncheckedTarget(address(this), REGISTRY_ADMIN_TARGET_NAME, TargetType.Core);
        _createUncheckedTarget(_releaseRegistry, RELEASE_REGISTRY_TARGET_NAME, TargetType.Core);
        _createUncheckedTarget(_tokenRegistry, TOKEN_REGISTRY_TARGET_NAME, TargetType.Core);

        // staking
        _createUncheckedTarget(_staking, STAKING_TARGET_NAME, TargetType.Core);
        _createUncheckedTarget(_stakingStore, STAKING_STORE_TARGET_NAME, TargetType.Core);
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