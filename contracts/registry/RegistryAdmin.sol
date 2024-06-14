// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessAdmin} from "../shared/AccessAdmin.sol";
import {IAccessAdmin} from "../shared/IAccessAdmin.sol";
import {IRegistry} from "./IRegistry.sol";
import {IService} from "../shared/IService.sol";
import {IServiceAuthorization} from "./IServiceAuthorization.sol";
import {IStaking} from "../staking/IStaking.sol";
import {ObjectType, ObjectTypeLib, ALL, POOL, RELEASE} from "../type/ObjectType.sol";
import {ReleaseManager} from "./ReleaseManager.sol";
import {RoleId, RoleIdLib, ADMIN_ROLE, GIF_MANAGER_ROLE, GIF_ADMIN_ROLE, PUBLIC_ROLE} from "../type/RoleId.sol";
import {StakingStore} from "../staking/StakingStore.sol";
import {STAKING} from "../type/ObjectType.sol";
import {TokenRegistry} from "./TokenRegistry.sol";
import {VersionPart} from "../type/Version.sol";

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
    string public constant STAKING_SERVICE_ROLE_NAME = "StakingServiceRole";
    string public constant POOL_SERVICE_ROLE_NAME = "PoolServiceRole";

    string public constant RELEASE_MANAGER_TARGET_NAME = "ReleaseManagerTarget";
    string public constant TOKEN_REGISTRY_TARGET_NAME = "TokenRegistryTarget";
    string public constant STAKING_TARGET_NAME = "StakingTarget";
    string public constant STAKING_STORE_TARGET_NAME = "StakingStoreTarget";

    mapping(address service => VersionPart majorVersion) private _ServiceRelease;

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
        _createTarget(_tokenRegistry, TOKEN_REGISTRY_TARGET_NAME);

        _setupGifAdminRole(gifAdmin);
        _setupGifManagerRole(gifManager);

        _setupReleaseManager();
        _setupStaking();
    }


    /// @dev Sets up authorizaion for specified service.
    /// For all authorized services its authorized functions are enabled.
    /// Permissioned function: Access is restricted to release manager.
    function authorizeService(
        IServiceAuthorization serviceAuthorization,
        IService service
    )
        external
        restricted()
    {
        _createServiceTargetAndRole(service);
        _authorizeServiceFunctions(serviceAuthorization, service);
    }


    function grantServiceRoleForAllVersions(IService service, ObjectType domain)
        external
        restricted()
    {
        _grantRoleToAccount( 
            RoleIdLib.roleForTypeAndAllVersions(domain),
            address(service)); 
    }


    function _createServiceTargetAndRole(IService service)
        private
    {
        ObjectType domain = service.getDomain();
        string memory baseName = ObjectTypeLib.toName(domain);
        VersionPart version = service.getVersion().toMajorPart();
        uint256 versionInt = version.toInt();
        string memory versionName = "_v0";
        string memory versionNumber = ObjectTypeLib.toString(versionInt);

        if (versionInt >= 10) {
            versionName = "_v";
        }

        // create service target
        string memory serviceTargetName = string(
            abi.encodePacked(
                baseName,
                "Service",
                versionName,
                versionNumber));

        _createTarget(
            address(service), 
            serviceTargetName);

        // create service role
        string memory serviceRoleName = string(
            abi.encodePacked(
                baseName,
                "ServiceRole",
                versionName,
                versionNumber));

        RoleId roleId = RoleIdLib.roleForTypeAndVersion(
            domain, 
            version);

        _createRole(
            roleId, 
            ADMIN_ROLE(), 
            serviceRoleName,
            1, // service roles must only be given to this unique service
            true); // it must not be possible to remove this role once granted

        _grantRoleToAccount( 
            roleId,
            address(service)); 
    }


    function _authorizeServiceFunctions(
        IServiceAuthorization serviceAuthorization,
        IService service
    )
        private
    {
        ObjectType serviceDomain = service.getDomain();
        ObjectType authorizedDomain;
        RoleId authorizedRoleId;

        VersionPart release = service.getVersion().toMajorPart();
        ObjectType[] memory authorizedDomains = serviceAuthorization.getAuthorizedDomains(serviceDomain);

        for (uint256 i = 0; i < authorizedDomains.length; i++) {
            authorizedDomain = authorizedDomains[i];

            // derive authorized role from authorized domain
            if (authorizedDomain == ALL()) {
                authorizedRoleId = PUBLIC_ROLE();
            } else {
                authorizedRoleId = RoleIdLib.roleForTypeAndVersion(
                authorizedDomain, 
                release);
            }

            // get authorized functions for authorized domain
            IAccessAdmin.Function[] memory authorizatedFunctions = serviceAuthorization.getAuthorizedFunctions(
                serviceDomain, 
                authorizedDomain);

            _authorizeTargetFunctions(
                    address(service), 
                    authorizedRoleId, 
                    authorizatedFunctions);
        }
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
        // TODO decide on max member count
        _createRole(GIF_ADMIN_ROLE(), getAdminRole(), GIF_ADMIN_ROLE_NAME, 2, false);
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
        _createRole(GIF_MANAGER_ROLE(), GIF_ADMIN_ROLE(), GIF_MANAGER_ROLE_NAME, 1, false);
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


    function _setupReleaseManager() private {
        _createTarget(_releaseManager, RELEASE_MANAGER_TARGET_NAME);

        RoleId releaseManagerRoleId = RoleIdLib.roleForType(RELEASE());
        _createRole(releaseManagerRoleId, ADMIN_ROLE(), RELEASE_MANAGER_TARGET_NAME, 1, true);
        _grantRoleToAccount(releaseManagerRoleId, _releaseManager);

        Function[] memory functions;
        functions = new Function[](2);
        functions[0] = toFunction(RegistryAdmin.authorizeService.selector, "authorizeService");
        functions[1] = toFunction(RegistryAdmin.grantServiceRoleForAllVersions.selector, "grantServiceRoleForAllVersions");
        _authorizeTargetFunctions(address(this), releaseManagerRoleId, functions);
    }


    function _setupStaking() private {
        _createTarget(_staking, STAKING_TARGET_NAME);
        _createTarget(_stakingStore, STAKING_STORE_TARGET_NAME);


        // staking function authorization for staking service
        RoleId stakingServiceRoleId = RoleIdLib.roleForTypeAndAllVersions(STAKING());
        _createRole(stakingServiceRoleId, ADMIN_ROLE(), STAKING_SERVICE_ROLE_NAME, 1, true);

        Function[] memory functions;
        functions = new Function[](13);
        functions[0] = toFunction(IStaking.registerTarget.selector, "registerTarget");
        functions[1] = toFunction(IStaking.setLockingPeriod.selector, "setLockingPeriod");
        functions[2] = toFunction(IStaking.setRewardRate.selector, "setRewardRate");
        functions[3] = toFunction(IStaking.refillRewardReserves.selector, "refillRewardReserves");
        functions[4] = toFunction(IStaking.withdrawRewardReserves.selector, "withdrawRewardReserves");
        functions[5] = toFunction(IStaking.createStake.selector, "createStake");
        functions[6] = toFunction(IStaking.stake.selector, "stake");
        functions[7] = toFunction(IStaking.unstake.selector, "unstake");
        functions[8] = toFunction(IStaking.restake.selector, "restake");
        functions[9] = toFunction(IStaking.updateRewards.selector, "updateRewards");
        functions[10] = toFunction(IStaking.claimRewards.selector, "claimRewards");
        functions[11] = toFunction(IStaking.collectDipAmount.selector, "collectDipAmount");
        functions[12] = toFunction(IStaking.transferDipAmount.selector, "transferDipAmount");
        _authorizeTargetFunctions(_staking, stakingServiceRoleId, functions);

        // staking function authorization for pool service
        RoleId poolServiceRoleId = RoleIdLib.roleForTypeAndAllVersions(POOL());
        _createRole(poolServiceRoleId, ADMIN_ROLE(), POOL_SERVICE_ROLE_NAME, 1, true);

        // staking function authorizations
        functions = new Function[](2);
        functions[0] = toFunction(IStaking.increaseTotalValueLocked.selector, "increaseTotalValueLocked");
        functions[1] = toFunction(IStaking.decreaseTotalValueLocked.selector, "decreaseTotalValueLocked");
        _authorizeTargetFunctions(_staking, poolServiceRoleId, functions);

        // staking store function authorizations
        RoleId stakingRoleId = RoleIdLib.roleForType(STAKING());
        _createRole(stakingRoleId, ADMIN_ROLE(), STAKING_TARGET_NAME, 1, true);
        _grantRoleToAccount(stakingRoleId, _staking);

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