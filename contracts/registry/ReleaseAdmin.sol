// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccess} from "../authorization/IAccess.sol";
import {IAuthorization} from "../authorization/IAuthorization.sol";
import {IService} from "../shared/IService.sol";
import {IServiceAuthorization} from "../authorization/IServiceAuthorization.sol";

import {AccessAdmin} from "../authorization/AccessAdmin.sol";
import {AccessAdminLib} from "../authorization/AccessAdminLib.sol";
import {AccessManagerCloneable} from "../authorization/AccessManagerCloneable.sol";
import {ObjectType, ObjectTypeLib, RELEASE} from "../type/ObjectType.sol";
import {RoleId, ADMIN_ROLE, RELEASE_REGISTRY_ROLE} from "../type/RoleId.sol";
import {Str} from "../type/String.sol";
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
    string public constant RELEASE_REGISTRY_ROLE_NAME = "ReleaseRegistry_Role";

    /// @dev release core targets
    string public constant RELEASE_ADMIN_TARGET_NAME = "ReleaseAdmin";

    IServiceAuthorization internal _serviceAuthorization;


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
        address authorization,
        VersionPart release,
        address releaseRegistry
    )
        external
        reinitializer(uint64(release.toInt()))
    {
        // checks
        AccessAdminLib.checkRegistry(registry);

        AccessManagerCloneable(
            authority()).completeSetup(
                registry, 
                release);

        IServiceAuthorization serviceAuthorization = IServiceAuthorization(authorization);
        AccessAdminLib.checkAuthorization(
            address(_authorization),
            address(serviceAuthorization), 
            RELEASE(), 
            release, 
            true, // expectServiceAuthorization
            true); // checkAlreadyInitialized);

        _serviceAuthorization = serviceAuthorization;

        // link nft ownability to registry
        _linkToNftOwnable(registry);

        _createRoles(_serviceAuthorization);

        // setup release contract
        _setupReleaseRegistry(releaseRegistry);

        // relase services will be authorized one by one via authorizeService()
    }


    /// @dev Sets up authorizaion for specified service.
    /// For all authorized services its authorized functions are enabled.
    /// Permissioned function: Access is restricted to release registry.
    function authorizeService(
        IService service,
        ObjectType serviceDomain,
        VersionPart release
    )
        external
        restricted()
    {
        _createServiceTargetAndRole(service, serviceDomain, release);

        // authorize functions of service
        Str serviceTarget = _serviceAuthorization.getServiceTarget(serviceDomain);
        RoleId[] memory authorizedRoles = _serviceAuthorization.getAuthorizedRoles(serviceTarget);

        for (uint256 i = 0; i < authorizedRoles.length; i++) {
            _authorizeFunctions(
                IAuthorization(address(_serviceAuthorization)), 
                serviceTarget, 
                authorizedRoles[i]);
        }
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

        // create unchecked target
        _createTarget(address(service), serviceTargetName, TargetType.Service, false);
    }

    //--- private initialization functions -------------------------------------------//

    function _setupReleaseRegistry(address releaseRegistry)
        private 
        onlyInitializing()
    {

        _createRole(
            RELEASE_REGISTRY_ROLE(), 
            AccessAdminLib.coreRoleInfo(RELEASE_REGISTRY_ROLE_NAME),
            true); // revets on existing role

        _createTarget(
            address(this), 
            RELEASE_ADMIN_TARGET_NAME,
            IAccess.TargetType.Core, 
            true); // check authority maches

        FunctionInfo[] memory functions;
        functions = new FunctionInfo[](2);
        functions[0] = AccessAdminLib.toFunction(ReleaseAdmin.authorizeService.selector, "authorizeService");
        functions[1] = AccessAdminLib.toFunction(ReleaseAdmin.setServiceLocked.selector, "setServiceLocked");
        _authorizeTargetFunctions(address(this), RELEASE_REGISTRY_ROLE(), functions, false, true);

        _grantRoleToAccount(RELEASE_REGISTRY_ROLE(), releaseRegistry);
    }
}