// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessAdmin} from "../authorization/AccessAdmin.sol";
import {AccessAdminLib} from "../authorization/AccessAdminLib.sol";
import {AccessManagerCloneable} from "../authorization/AccessManagerCloneable.sol";
import {IAccess} from "../authorization/IAccess.sol";
import {IService} from "../shared/IService.sol";
import {IServiceAuthorization} from "../authorization/IServiceAuthorization.sol";
import {ObjectType, ObjectTypeLib, ALL} from "../type/ObjectType.sol";
import {RoleId, RoleIdLib, ADMIN_ROLE, RELEASE_REGISTRY_ROLE, PUBLIC_ROLE} from "../type/RoleId.sol";
import {VersionPart} from "../type/Version.sol";

/// @dev The ReleaseAdmin contract implements the central authorization for the services of a specific release.
/// There is one ReleaseAdmin contract per major GIF release.
/// Locking/unlocking of all services of a release is implemented in function setReleaseLocked.
contract ReleaseAdmin is
    AccessAdmin
{
    event LogReleaseAdminReleaseLockChanged(VersionPart release, bool locked);
    event LogReleaseAdminServiceLockChanged(VersionPart release, address service, bool locked);

    error ErrorReleaseAdminCallerNotReleaseRegistry(address caller);
    error ErrorReleaseAdminNotService(address notService);
    error ErrorReleaseAdminReleaseLockAlreadySetTo(bool locked);

    /// @dev release core roles
    string public constant RELEASE_REGISTRY_ROLE_NAME = "ReleaseRegistryRole";

    /// @dev release core targets
    string public constant RELEASE_ADMIN_TARGET_NAME = "ReleaseAdmin";


    modifier onlyReleaseRegistry() {
        (bool isMember, ) = _authority.hasRole(RELEASE_REGISTRY_ROLE().toInt(), msg.sender);
        if(!isMember) {
            revert ErrorReleaseAdminCallerNotReleaseRegistry(msg.sender);
        }
        _;
    }

    // @dev Only used for master release admin
    constructor(address accessManager) {
        initialize(
            accessManager,
            "MasterReleaseAdmin");
    }


    function completeSetup(
        address registry,
        address releaseRegistry,
        VersionPart release
    )
        external
        reinitializer(uint64(release.toInt()))
    {

        // checks
        _checkRegistry(registry);

        AccessManagerCloneable(
            authority()).completeSetup(
                registry, 
                release); 

        // link nft ownability to registry
        _linkToNftOwnable(registry);

        _setupReleaseRegistry(releaseRegistry);
    }

    /// @dev Sets up authorizaion for specified service.
    /// For all authorized services its authorized functions are enabled.
    /// Permissioned function: Access is restricted to release registry.
    function authorizeService(
        IServiceAuthorization serviceAuthorization,
        IService service,
        ObjectType serviceDomain,
        VersionPart release
    )
        external
        restricted()
    {
        _createServiceTargetAndRole(service, serviceDomain, release);
        _authorizeServiceFunctions(serviceAuthorization, service, serviceDomain, release);
    }

    /// @dev Locks/unlocks all release targets.
    /// For all authorized services of release its authorized functions are disabled/enabled.
    /// Permissioned function: Access is restricted to release registry.
    /// Note: onlyReleaseRegistry() modifier is used to prevent dead lock.
    function setReleaseLocked(bool locked)
        external
        onlyReleaseRegistry()
    {
        // checks
        AccessManagerCloneable accessManager = AccessManagerCloneable(authority());
        if(accessManager.isLocked() == locked) {
            revert ErrorReleaseAdminReleaseLockAlreadySetTo(locked);
        }

        // effects
        accessManager.setLocked(locked);

        emit LogReleaseAdminReleaseLockChanged(getRelease(), locked);
    }

    /// @dev Lock/unlock specific service of release.
    /// Permissioned function: Access is restricted to release registry.
    function setServiceLocked(IService service, bool locked)
        external
        restricted()
    {
        // assume all targets except release admin are services
        // ensure release admin can not be locked
        if(address(service) == address(this)) {
            revert ErrorReleaseAdminNotService(address(service));
        }

        _setTargetLocked(address(service), locked);

        emit LogReleaseAdminServiceLockChanged(service.getRelease(), address(service), locked);
    }

    //--- view functions ----------------------------------------------------//

/*
    function getReleaseAdminRole() external view returns (RoleId) {
        return GIF_ADMIN_ROLE();
    }
*/
    //--- private functions -------------------------------------------------//

    function _createServiceTargetAndRole(
        IService service, 
        ObjectType serviceDomain, 
        VersionPart release
    )
        private
    {
        string memory baseName = ObjectTypeLib.toName(serviceDomain);

        // create service target
        string memory serviceTargetName = ObjectTypeLib.toVersionedName(
            baseName, "Service", release);

        _createTarget(
            address(service), 
            serviceTargetName,
            true,
            false);

        // create service role
        RoleId serviceRoleId = RoleIdLib.roleForTypeAndVersion(
            serviceDomain, 
            release);

        if(!roleExists(serviceRoleId)) {
            _createRole(
                serviceRoleId, 
                AccessAdminLib.toRole({
                    adminRoleId: ADMIN_ROLE(),
                    roleType: RoleType.Contract,
                    maxMemberCount: 1,
                    name: ObjectTypeLib.toVersionedName(
                        baseName, 
                        "ServiceRole", 
                        release)}));
        }

        _grantRoleToAccount( 
            serviceRoleId,
            address(service)); 
    }


    function _authorizeServiceFunctions(
        IServiceAuthorization serviceAuthorization,
        IService service,
        ObjectType serviceDomain, 
        VersionPart release
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
                release);
            }

            if(!roleExists(authorizedRoleId)) {
                // create role for authorized domain
                _createRole(
                    authorizedRoleId, 
                    AccessAdminLib.toRole({
                        adminRoleId: ADMIN_ROLE(),
                        roleType: RoleType.Contract,
                        maxMemberCount: 1,
                        name: ObjectTypeLib.toVersionedName(
                            ObjectTypeLib.toName(authorizedDomain), 
                            "Role", 
                            release)}));
            }

            // get authorized functions for authorized domain
            IAccess.FunctionInfo[] memory authorizatedFunctions = serviceAuthorization.getAuthorizedFunctions(
                serviceDomain, 
                authorizedDomain);

            _authorizeTargetFunctions(
                    address(service), 
                    authorizedRoleId, 
                    authorizatedFunctions,
                    true);
        }
    }

    //--- private initialization functions -------------------------------------------//

    function _setupReleaseRegistry(address releaseRegistry)
        private 
        onlyInitializing()
    {
        _createTarget(address(this), RELEASE_ADMIN_TARGET_NAME, false, false);

        _createRole(
            RELEASE_REGISTRY_ROLE(), 
            AccessAdminLib.toRole({
                adminRoleId: ADMIN_ROLE(),
                roleType: RoleType.Contract,
                maxMemberCount: 1,
                name: RELEASE_REGISTRY_ROLE_NAME}));

        FunctionInfo[] memory functions;
        functions = new FunctionInfo[](2);
        functions[0] = AccessAdminLib.toFunction(ReleaseAdmin.authorizeService.selector, "authorizeService");
        functions[1] = AccessAdminLib.toFunction(ReleaseAdmin.setServiceLocked.selector, "setServiceLocked");
        _authorizeTargetFunctions(address(this), RELEASE_REGISTRY_ROLE(), functions, true);

        _grantRoleToAccount(RELEASE_REGISTRY_ROLE(), releaseRegistry);
    }
}