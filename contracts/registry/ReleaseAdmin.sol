// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessAdmin} from "../authorization/AccessAdmin.sol";
import {IAccess} from "../authorization/IAccess.sol";
import {IAccessAdmin} from "../authorization/IAccessAdmin.sol";
import {IService} from "../shared/IService.sol";
import {IServiceAuthorization} from "../authorization/IServiceAuthorization.sol";
import {ObjectType, ObjectTypeLib, ALL, RELEASE} from "../type/ObjectType.sol";
import {RoleId, RoleIdLib, ADMIN_ROLE, RELEASE_REGISTRY_ROLE, PUBLIC_ROLE} from "../type/RoleId.sol";
import {VersionPart} from "../type/Version.sol";
import {ReleaseAccessManagerCloneable} from "../authorization/ReleaseAccessManagerCloneable.sol";
import {AccessManagerCloneable} from "../authorization/AccessManagerCloneable.sol";


contract ReleaseAdmin is
    AccessAdmin
{
    error ErrorReleaseAdminCallerNotReleaseRegistry(address caller);
    error ErrorReleaseAdminNotService(address notService);
    error ErrorReleaseAdminReleaseAlreadyLocked();

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
    /// @dev Only used for master release admin.
    /// Contracts created via constructor come with disabled initializers.
    constructor()
        AccessAdmin()
    {
        _disableInitializers();
    }

    function _createAuthority()
        internal
        virtual override
        returns (AccessManagerCloneable)
    {
        return new ReleaseAccessManagerCloneable();
    }

    // TODO can store IServiceAuthorization like InstanceAdmin does
    /// @dev Initializes this releae admin with the provided access manager and release registry address.
    /// Used for cloned release admin.
    function initialize(ReleaseAccessManagerCloneable accessManager, address releaseRegistry)
        external
        initializer
    {
        // set and initialize access manager for this release admin
        // admin role is granted before it is created
        // _deployer initialized here
        _initializeAuthority(accessManager);

        // create basic release independent setup
        _initializeAdminAndPublicRoles();

        _setupReleaseRegistry(releaseRegistry);
    }


    /// @dev Sets up authorizaion for specified service.
    /// For all authorized services its authorized functions are enabled.
    /// Permissioned function: Access is restricted to release registry.
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

    /// @dev Locks/unlocks all release targets.
    /// For all authorized services of release its authorized functions are disabled/enabled.
    /// Permissioned function: Access is restricted to release registry.
    /// Note: onlyReleaseRegistry() modifier is used to prevent dead lock.
    function setReleaseLocked(bool locked)
        external
        onlyReleaseRegistry()
    {
        _setReleaseLocked(locked);
    }

    /// @dev Lock/unlock specific service of release.
    /// Permissioned function: Access is restricted to release registry.
    /// Note: service locked with this function wont'be unlocked by setReleaseLocked(false).
    function setServiceLocked(IService service, bool locked)
        external
        restricted()
    {
        // assume all targets except release admin are services
        // ensure release admin can not be locked
        if(address(service) == address(this)) {
            revert ErrorReleaseAdminNotService(address(service));
        }

        // will check for release lock
        _setTargetClosed(address(service), locked);
    }

    /*function transferAdmin(address to)
        external
        restricted // only with GIF_ADMIN_ROLE or nft owner
    {
        _accessManager.revoke(GIF_ADMIN_ROLE, );
        _accesssManager.grant(GIF_ADMIN_ROLE, to, 0);
    }*/

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

        if(!roleExists(serviceRoleId)) {
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
        }

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

            if(!roleExists(authorizedRoleId)) {
                // create role for authorized domain
                _createRole(
                    authorizedRoleId, 
                    toRole({
                        adminRoleId: ADMIN_ROLE(),
                        roleType: RoleType.Contract,
                        maxMemberCount: 1,
                        name: ObjectTypeLib.toVersionedName(
                            ObjectTypeLib.toName(authorizedDomain), 
                            "Role", 
                            releaseVersion.toInt())}));
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

    function _setReleaseLocked(bool locked)
        private
    {
        ReleaseAccessManagerCloneable accessManager = ReleaseAccessManagerCloneable(authority());
        if(accessManager.isReleaseLocked() == locked) {
            revert ErrorReleaseAdminReleaseAlreadyLocked();
        }

        accessManager.setReleaseLocked(locked);
    }

    //--- private initialization functions -------------------------------------------//

    function _setupReleaseRegistry(address releaseRegistry)
        private 
        onlyInitializing()
    {
        _createTarget(address(this), RELEASE_ADMIN_TARGET_NAME, false, false);

        // TODO why release registry role is calculated?
        //RoleId releaseRegistryRoleId = RoleIdLib.roleForType(RELEASE());
        RoleId releaseRegistryRoleId = RELEASE_REGISTRY_ROLE();
        _createRole(
            releaseRegistryRoleId, 
            toRole({
                adminRoleId: ADMIN_ROLE(),
                roleType: RoleType.Contract,
                maxMemberCount: 1,
                name: RELEASE_REGISTRY_ROLE_NAME}));

        FunctionInfo[] memory functions;
        functions = new FunctionInfo[](2);
        functions[0] = toFunction(ReleaseAdmin.authorizeService.selector, "authorizeService");
        functions[1] = toFunction(ReleaseAdmin.setServiceLocked.selector, "setServiceLocked");
        _authorizeTargetFunctions(address(this), releaseRegistryRoleId, functions);

        _grantRoleToAccount(releaseRegistryRoleId, releaseRegistry);
    }
}