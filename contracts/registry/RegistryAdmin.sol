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
        _checkRegistry(registry);

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

        _setupRegistry(_registry);

        // setup authorization for registry and supporting contracts
        _createRoles(_authorization);
        _grantRoleToAccount(GIF_ADMIN_ROLE(), gifAdmin);
        _grantRoleToAccount(GIF_MANAGER_ROLE(), gifManager);

        _createTargets(_authorization);
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

    // create registry role and target
    function _setupRegistry(address registry) internal {

        // create registry role
        RoleId roleId = _authorization.getTargetRole(
            _authorization.getMainTarget());

        _createRole(
            roleId,
            _authorization.getRoleInfo(roleId));

        // create registry target
        _createTarget(
            registry, 
            _authorization.getMainTargetName(), 
            true, // checkAuthority
            false); // custom

        // assign registry role to registry
        _grantRoleToAccount(
            roleId, 
            registry);
    }


    function _createRoles(IAuthorization authorization)
        internal
    {
        RoleId[] memory roles = authorization.getRoles();
        RoleId mainTargetRoleId = authorization.getTargetRole(
            authorization.getMainTarget());

        RoleId roleId;
        RoleInfo memory roleInfo;

        for(uint256 i = 0; i < roles.length; i++) {

            roleId = roles[i];

            // skip main target role, create role if not exists
            if (roleId != mainTargetRoleId && !roleExists(roleId)) {
                _createRole(
                    roleId,
                    authorization.getRoleInfo(roleId));
            }
        }
    }


    function _createTargets(IAuthorization authorization)
        internal
    {
        // registry
        _createTargetWithRole(address(this), REGISTRY_ADMIN_TARGET_NAME, authorization.getTargetRole(StrLib.toStr(REGISTRY_ADMIN_TARGET_NAME)));
        _createTargetWithRole(_releaseRegistry, RELEASE_REGISTRY_TARGET_NAME, authorization.getTargetRole(StrLib.toStr(RELEASE_REGISTRY_TARGET_NAME)));
        _createTargetWithRole(_tokenRegistry, TOKEN_REGISTRY_TARGET_NAME, authorization.getTargetRole(StrLib.toStr(TOKEN_REGISTRY_TARGET_NAME)));

        // staking
        _createTargetWithRole(_staking, STAKING_TARGET_NAME, authorization.getTargetRole(StrLib.toStr(STAKING_TARGET_NAME)));
        _createTarget(_stakingStore, STAKING_STORE_TARGET_NAME, true, false);
        _createTarget(address(IComponent(_staking).getTokenHandler()), STAKING_TH_TARGET_NAME, true, false);
    }


    function _createTargetAuthorizations(IAuthorization authorization)
        internal
    {
        Str[] memory targets = authorization.getTargets();
        Str target;

        for(uint256 i = 0; i < targets.length; i++) {
            target = targets[i];
            RoleId[] memory authorizedRoles = authorization.getAuthorizedRoles(target);
            RoleId authorizedRole;

            for(uint256 j = 0; j < authorizedRoles.length; j++) {
                authorizedRole = authorizedRoles[j];

                _authorizeTargetFunctions(
                    getTargetForName(target),
                    authorizedRole,
                    authorization.getAuthorizedFunctions(
                        target, 
                        authorizedRole));
            }
        }
    }


    function _createTargets(address authorization)
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
}