// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessAdmin} from "../authorization/AccessAdmin.sol";
import {IAccess} from "../authorization/IAccess.sol";
import {IService} from "../shared/IService.sol";
import {IServiceAuthorization} from "../authorization/IServiceAuthorization.sol";
import {ObjectType, ObjectTypeLib, ALL, RELEASE} from "../type/ObjectType.sol";
import {RoleId, RoleIdLib, ADMIN_ROLE, RELEASE_ADMIN_ROLE, PUBLIC_ROLE} from "../type/RoleId.sol";
import {VersionPart} from "../type/Version.sol";
import {ReleaseAccessManagerCloneable} from "../authorization/ReleaseAccessManagerCloneable.sol";
import {AccessManagerCloneable} from "../authorization/AccessManagerCloneable.sol";


contract ReleaseAdmin is
    AccessAdmin
{
    error ErrorReleaseAdminCallerNotReleaseAdmin(address caller);

    /// @dev release core roles
    string public constant RELEASE_ADMIN_ROLE_NAME = "ReleaseAdminRole"; 

    /// @dev external to release roles
    string public constant RELEASE_REGISTRY_ROLE_NAME = "ReleaseRegistryRole";

    /// @dev external to release targets
    string public constant RELEASE_REGISTRY_TARGET_NAME = "ReleaseRegistry";

    //address internal _registry;
    address private _releaseRegistry;

    modifier onlyReleaseAdminRole() {
        //(bool isMember_1, ) = _authority.hasRole(GIF_MANAGER_ROLE().toInt(), msg.sender);
        //(bool isMember_2, ) = _authority.hasRole(GIF_ADMIN_ROLE().toInt(), msg.sender);
        //if(!(isMember_1 & isMember_2)) {
        //    revert ErrorReleaseAdminCallerNotReleaseAdmin(msg.sender);
        //}
        (bool isMember, ) = _authority.hasRole(RELEASE_ADMIN_ROLE().toInt(), msg.sender);
        if(!isMember) {
            revert ErrorReleaseAdminCallerNotReleaseAdmin(msg.sender);
        }
        _;
    }

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
    function initialize(ReleaseAccessManagerCloneable accessManager, address releaseRegistry)
        external
        initializer
    {
        _releaseRegistry = releaseRegistry;

        // set and initialize access manager for this release admin
        _initializeAuthority(accessManager);

        // create basic release independent setup
        _initializeAdminAndPublicRoles();

        // assume caller is ReleaseRegistry
        _setupReleaseAdminRole(msg.sender);
        _setupReleaseRegistry();
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

    function setReleaseLocked(bool locked)
        external
        onlyReleaseAdminRole()
    {
        _setReleaseLocked(locked);
    }

    function setServiceLocked(IService service, bool locked)
        external
        restricted()
    {
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

    function _setReleaseLocked(bool locked)
        internal
    {
        ReleaseAccessManagerCloneable(authority()).setReleaseLocked(locked);
    }

    //--- private initialization functions -------------------------------------------//

    function _setupReleaseAdminRole(address releaseAdmin) 
        private 
        onlyInitializing()
    {
        _createRole(
            RELEASE_ADMIN_ROLE(), 
            toRole({
                adminRoleId: ADMIN_ROLE(),
                roleType: RoleType.Gif,
                maxMemberCount: 1,
                name: RELEASE_ADMIN_ROLE_NAME}));

        // for ReleaseAdmin
        FunctionInfo[] memory functions;
        functions = new FunctionInfo[](1);
        functions[0] = toFunction(ReleaseAdmin.setReleaseLocked.selector, "setReleaseLocked");
        _authorizeTargetFunctions(address(this), RELEASE_ADMIN_ROLE(), functions);

        _grantRoleToAccount(RELEASE_ADMIN_ROLE(), releaseAdmin);
    }

    function _setupReleaseRegistry()
        private 
        onlyInitializing()
    {
        RoleId releaseRegistryRoleId = RoleIdLib.roleForType(RELEASE());
        _createRole(
            releaseRegistryRoleId, 
            toRole({
                adminRoleId: ADMIN_ROLE(),
                roleType: RoleType.Contract,
                maxMemberCount: 1,
                name: RELEASE_REGISTRY_ROLE_NAME}));

        FunctionInfo[] memory functions;
        functions = new FunctionInfo[](4);
        functions[0] = toFunction(ReleaseAdmin.authorizeService.selector, "authorizeService");
        functions[1] = toFunction(ReleaseAdmin.grantServiceRole.selector, "grantServiceRole");
        functions[2] = toFunction(ReleaseAdmin.setReleaseLocked.selector, "setReleaseLocked");
        functions[3] = toFunction(ReleaseAdmin.setServiceLocked.selector, "setServiceLocked");
        _authorizeTargetFunctions(address(this), releaseRegistryRoleId, functions);

        _grantRoleToAccount(releaseRegistryRoleId, _releaseRegistry);
    }
}