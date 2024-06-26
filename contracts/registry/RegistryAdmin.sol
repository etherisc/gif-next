// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessAdmin} from "../authorization/AccessAdmin.sol";
import {IAccess} from "../authorization/IAccess.sol";
import {IRegistry} from "./IRegistry.sol";
import {IService} from "../shared/IService.sol";
import {IServiceAuthorization} from "../authorization/IServiceAuthorization.sol";
import {IStaking} from "../staking/IStaking.sol";
import {ObjectType, ObjectTypeLib, ALL, REGISTRY, STAKING, POOL, RELEASE} from "../type/ObjectType.sol";
import {ReleaseRegistry} from "./ReleaseRegistry.sol";
import {RoleId, RoleIdLib, ADMIN_ROLE, GIF_MANAGER_ROLE, GIF_ADMIN_ROLE, PUBLIC_ROLE} from "../type/RoleId.sol";
import {StakingStore} from "../staking/StakingStore.sol";
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
    string public constant POOL_SERVICE_ROLE_NAME = "PoolServiceRole";
    string public constant RELEASE_REGISTRY_ROLE_NAME = "ReleaseRegistryRole";
    string public constant REGISTRY_SERVICE_ROLE_NAME = "RegistryServiceRole";
    string public constant STAKING_SERVICE_ROLE_NAME = "StakingServiceRole";
    string public constant STAKING_ROLE_NAME = "StakingRole";

    string public constant REGISTRY_TARGET_NAME = "Registry";
    string public constant RELEASE_REGISTRY_TARGET_NAME = "ReleaseRegistry";
    string public constant TOKEN_REGISTRY_TARGET_NAME = "TokenRegistry";
    string public constant STAKING_TARGET_NAME = "Staking";
    string public constant STAKING_STORE_TARGET_NAME = "StakingStore";

    uint8 public constant MAX_NUM_RELEASES = 99;

    mapping(address service => VersionPart majorVersion) private _ServiceRelease;

    address private _registry;
    address private _releaseRegistry;
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
        initializer
        onlyDeployer()
    {
        if (_setupCompleted) { revert ErrorRegistryAdminIsAlreadySetUp(); } 
        else { _setupCompleted = true; }

        _registry = address(registry);
        _releaseRegistry = registry.getReleaseRegistryAddress();
        _tokenRegistry = registry.getTokenRegistryAddress();
        _staking = registry.getStakingAddress();
        _stakingStore = address(
            IStaking(_staking).getStakingStore());

        // at this moment all registry contracts are deployed and fully intialized
        _createTarget(_tokenRegistry, TOKEN_REGISTRY_TARGET_NAME, true, false);

        _setupGifAdminRole(gifAdmin);
        _setupGifManagerRole(gifManager);

        _setupRegistry();
        _setupReleaseRegistry();
        _setupStaking();
    }


    /// @dev Sets up authorizaion for specified service.
    /// For all authorized services its authorized functions are enabled.
    /// Permissioned function: Access is restricted to release manager.
    function authorizeService(
        IServiceAuthorization serviceAuthorization,
        IService service,
        ObjectType serviceDomain,
        VersionPart releaseVersion
    )
        external
        restricted()
    {
        _createServiceTargetAndRole(service, serviceDomain, releaseVersion);
        _authorizeServiceFunctions(serviceAuthorization, service, serviceDomain, releaseVersion);
    }

    function grantServiceRole(
        IService service,
        ObjectType domain, 
        VersionPart version
    )
        external
        restricted()
    {
        _grantRoleToAccount( 
            RoleIdLib.roleForTypeAndVersion(
                domain, 
                version),
            address(service)); 
    }

    function revokeServiceRole(
        IService service,
        ObjectType domain, 
        VersionPart version
    )
        external
        restricted()
    {
        _revokeRoleFromAccount(
            RoleIdLib.roleForTypeAndVersion(
                domain, 
                version), 
            address(service));
    }

    function grantServiceRoleForAllVersions(IService service, ObjectType domain)
        external
        restricted()
    {
        _grantRoleToAccount( 
            RoleIdLib.roleForTypeAndAllVersions(domain),
            address(service)); 
    }

    function revokeServiceRoleForAllVersions(IService service, ObjectType domain)
        external
        restricted()
    {
        _revokeRoleFromAccount(
            RoleIdLib.roleForTypeAndAllVersions(domain), 
            address(service));
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

    function _createServiceTargetAndRole(
        IService service, 
        ObjectType serviceDomain, 
        VersionPart releaseVersion
    )
        private
    {
        string memory baseName = ObjectTypeLib.toName(serviceDomain);
        uint256 versionInt = releaseVersion.toInt();

        // create service target
        string memory serviceTargetName = ObjectTypeLib.toVersionedName(
            baseName, "Service", versionInt);

        _createTarget(
            address(service), 
            serviceTargetName,
            true,
            false);

        // create service role
        RoleId serviceRoleId = RoleIdLib.roleForTypeAndVersion(
            serviceDomain, 
            releaseVersion);

        _createRole(
            serviceRoleId, 
            toRole({
                adminRoleId: ADMIN_ROLE(),
                roleType: RoleType.Contract,
                maxMemberCount: 1,
                name: ObjectTypeLib.toVersionedName(
                    baseName, 
                    "ServiceRole", 
                    versionInt)}));

        _grantRoleToAccount( 
            serviceRoleId,
            address(service)); 
    }


    function _authorizeServiceFunctions(
        IServiceAuthorization serviceAuthorization,
        IService service,
        ObjectType serviceDomain, 
        VersionPart releaseVersion
    )
        private
    {
        ObjectType authorizedDomain;
        RoleId authorizedRoleId;

        ObjectType[] memory authorizedDomains = serviceAuthorization.getAuthorizedDomains(serviceDomain);

        for (uint256 i = 0; i < authorizedDomains.length; i++) {
            authorizedDomain = authorizedDomains[i];

            // derive authorized role from authorized domain
            if (authorizedDomain == ALL()) {
                authorizedRoleId = PUBLIC_ROLE();
            } else {
                authorizedRoleId = RoleIdLib.roleForTypeAndVersion(
                authorizedDomain, 
                releaseVersion);
            }

            // get authorized functions for authorized domain
            IAccess.FunctionInfo[] memory authorizatedFunctions = serviceAuthorization.getAuthorizedFunctions(
                serviceDomain, 
                authorizedDomain);

            _authorizeTargetFunctions(
                    address(service), 
                    authorizedRoleId, 
                    authorizatedFunctions);
        }
    }

    //--- private initialization functions -------------------------------------------//

    function _setupGifAdminRole(address gifAdmin) 
        private 
        onlyInitializing()
    {
        
        _createRole(
            GIF_ADMIN_ROLE(), 
            toRole({
                adminRoleId: ADMIN_ROLE(),
                roleType: RoleType.Gif,
                maxMemberCount: 2, // TODO decide on max member count
                name: GIF_ADMIN_ROLE_NAME}));

        // for ReleaseRegistry
        FunctionInfo[] memory functions;
        functions = new FunctionInfo[](4);
        functions[0] = toFunction(ReleaseRegistry.createNextRelease.selector, "createNextRelease");
        functions[1] = toFunction(ReleaseRegistry.activateNextRelease.selector, "activateNextRelease");
        functions[2] = toFunction(ReleaseRegistry.pauseRelease.selector, "pauseRelease");
        functions[3] = toFunction(ReleaseRegistry.unpauseRelease.selector, "unpauseRelease");
        _authorizeTargetFunctions(_releaseRegistry, GIF_ADMIN_ROLE(), functions);

        _grantRoleToAccount(GIF_ADMIN_ROLE(), gifAdmin);
    }
    
    function _setupGifManagerRole(address gifManager)
        private 
        onlyInitializing()
    {

        _createRole(
            GIF_MANAGER_ROLE(), 
            toRole({
                adminRoleId: ADMIN_ROLE(),
                roleType: RoleType.Gif,
                maxMemberCount: 1,
                name: GIF_MANAGER_ROLE_NAME}));

        // for TokenRegistry
        FunctionInfo[] memory functions;
        functions = new FunctionInfo[](5);
        functions[0] = toFunction(TokenRegistry.registerToken.selector, "registerToken");
        functions[1] = toFunction(TokenRegistry.registerRemoteToken.selector, "registerRemoteToken");
        functions[2] = toFunction(TokenRegistry.setActive.selector, "setActive");
        functions[3] = toFunction(TokenRegistry.setActiveForVersion.selector, "setActiveForVersion");
        // TODO find a better way (only needed for testing)
        functions[4] = toFunction(TokenRegistry.setActiveWithVersionCheck.selector, "setActiveWithVersionCheck");
        _authorizeTargetFunctions(_tokenRegistry, GIF_MANAGER_ROLE(), functions);

        // for ReleaseRegistry
        functions = new FunctionInfo[](2);
        functions[0] = toFunction(ReleaseRegistry.prepareNextRelease.selector, "prepareNextRelease");
        functions[1] = toFunction(ReleaseRegistry.registerService.selector, "registerService");
        _authorizeTargetFunctions(_releaseRegistry, GIF_MANAGER_ROLE(), functions);

        _grantRoleToAccount(GIF_MANAGER_ROLE(), gifManager);
    }

    function _setupRegistry()
        private 
        onlyInitializing()
    {
        _createTarget(_registry, REGISTRY_TARGET_NAME, true, false);

        // registry function authorization for registry service
        RoleId registryServiceRoleId = RoleIdLib.roleForTypeAndAllVersions(REGISTRY());
        _createRole(
            registryServiceRoleId, 
            toRole({
                adminRoleId: ADMIN_ROLE(),
                roleType: RoleType.Contract,
                maxMemberCount: MAX_NUM_RELEASES,
                name: REGISTRY_SERVICE_ROLE_NAME}));

        FunctionInfo[] memory functions;
        functions = new FunctionInfo[](2);
        functions[0] = toFunction(IRegistry.register.selector, "register");
        functions[1] = toFunction(IRegistry.registerWithCustomType.selector, "registerWithCustomType");
        // TODO add registerChainRegistry()

        _authorizeTargetFunctions(_registry, registryServiceRoleId, functions);
    }


    function _setupReleaseRegistry()
        private 
        onlyInitializing()
    {

        _createTarget(_releaseRegistry, RELEASE_REGISTRY_TARGET_NAME, true, false);

        RoleId releaseRegistryRoleId = RoleIdLib.roleForType(RELEASE());
        _createRole(
            releaseRegistryRoleId, 
            toRole({
                adminRoleId: ADMIN_ROLE(),
                roleType: RoleType.Contract,
                maxMemberCount: 1,
                name: RELEASE_REGISTRY_ROLE_NAME}));

        FunctionInfo[] memory functions;
        functions = new FunctionInfo[](5);
        functions[0] = toFunction(RegistryAdmin.authorizeService.selector, "authorizeService");
        functions[1] = toFunction(RegistryAdmin.grantServiceRoleForAllVersions.selector, "grantServiceRoleForAllVersions");
        functions[2] = toFunction(RegistryAdmin.revokeServiceRoleForAllVersions.selector, "revokeServiceRoleForAllVersions");
        functions[3] = toFunction(RegistryAdmin.grantServiceRole.selector, "grantServiceRole");
        functions[4] = toFunction(RegistryAdmin.revokeServiceRole.selector, "revokeServiceRole");

        _authorizeTargetFunctions(address(this), releaseRegistryRoleId, functions);

        _grantRoleToAccount(releaseRegistryRoleId, _releaseRegistry);
    }


    function _setupStaking()
        private 
        onlyInitializing()
    {
        _createTarget(_staking, STAKING_TARGET_NAME, true, false);
        _createTarget(_stakingStore, STAKING_STORE_TARGET_NAME, true, false);

        // staking function authorization for staking service
        RoleId stakingServiceRoleId = RoleIdLib.roleForTypeAndAllVersions(STAKING());
        _createRole(
            stakingServiceRoleId, 
            toRole({
                adminRoleId: ADMIN_ROLE(),
                roleType: RoleType.Contract,
                maxMemberCount: MAX_NUM_RELEASES,
                name: STAKING_SERVICE_ROLE_NAME}));

        FunctionInfo[] memory functions;
        functions = new FunctionInfo[](13);
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
        _createRole(
            poolServiceRoleId, 
            toRole({
                adminRoleId: ADMIN_ROLE(),
                roleType: RoleType.Contract,
                maxMemberCount: MAX_NUM_RELEASES,
                name: POOL_SERVICE_ROLE_NAME}));

        // staking function authorizations
        functions = new FunctionInfo[](2);
        functions[0] = toFunction(IStaking.increaseTotalValueLocked.selector, "increaseTotalValueLocked");
        functions[1] = toFunction(IStaking.decreaseTotalValueLocked.selector, "decreaseTotalValueLocked");
        _authorizeTargetFunctions(_staking, poolServiceRoleId, functions);

        // staking store function authorizations
        RoleId stakingRoleId = RoleIdLib.roleForType(STAKING());
        _createRole(
            stakingRoleId, 
            toRole({
                adminRoleId: ADMIN_ROLE(),
                roleType: RoleType.Contract,
                maxMemberCount: 1,
                name: STAKING_ROLE_NAME}));

        functions = new FunctionInfo[](14);
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

        _grantRoleToAccount(stakingRoleId, _staking);
    }
}