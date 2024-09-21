// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IAccess} from "../authorization/IAccess.sol";
import {IAuthorization} from "../authorization/IAuthorization.sol";
import {IInstanceLinkedComponent} from "../shared/IInstanceLinkedComponent.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IInstance} from "./IInstance.sol";

import {AccessAdmin} from "../authorization/AccessAdmin.sol";
import {AccessAdminLib} from "../authorization/AccessAdminLib.sol";
import {AccessManagerCloneable} from "../authorization/AccessManagerCloneable.sol";
import {ObjectType, INSTANCE} from "../type/ObjectType.sol";
import {RoleId, ADMIN_ROLE} from "../type/RoleId.sol";
import {Str} from "../type/String.sol";
import {VersionPart} from "../type/Version.sol";
import {INSTANCE_TARGET_NAME, INSTANCE_ADMIN_TARGET_NAME, INSTANCE_STORE_TARGET_NAME, PRODUCT_STORE_TARGET_NAME, BUNDLE_SET_TARGET_NAME, RISK_SET_TARGET_NAME} from "./TargetNames.sol";


contract InstanceAdmin is
    AccessAdmin
{
    // onlyInstanceService
    error ErrorInstanceAdminNotInstanceService(address caller);

    // authorizeFunctions
    error ErrorInstanceAdminNotComponentOrCustomTarget(address target);

    IInstance internal _instance;
    IRegistry internal _registry;
    VersionPart internal _release;

    uint64 internal _customRoleIdNext;

    mapping(address target => RoleId roleId) internal _targetRoleId;
    uint64 internal _components;


    modifier onlyInstanceService() {
        if (msg.sender != _registry.getServiceAddress(INSTANCE(), getRelease())) {
            revert ErrorInstanceAdminNotInstanceService(msg.sender);
        }
        _;
    }

    /// @dev Only used for master instance admin.
    constructor(address accessManager) {
        initialize(
            accessManager,
            "MasterInstanceAdmin");
    }


    /// @dev Completes the initialization of this instance admin using the provided instance, registry and version.
    /// Important: Initialization of instance admin is only complete after calling this function. 
    /// Important: The instance MUST be registered and all instance supporting contracts must be wired to this instance.
    function completeSetup(
        address registry,
        address authorization,
        VersionPart release,
        address instance
    )
        external
        reinitializer(uint64(release.toInt()))
        onlyDeployer()
    {
        // checks
        AccessAdminLib.checkIsRegistered(registry, instance, INSTANCE());

        AccessManagerCloneable(
            authority()).completeSetup(
                registry, 
                release); 

        _checkAuthorization(authorization, INSTANCE(), release, false, true);

        // effects
        _registry = IRegistry(registry);
        _release = release;

        _instance = IInstance(instance);
        _authorization = IAuthorization(authorization);
        _components = 0;
        _customRoleIdNext = 0;

        // link nft ownability to instance
        _linkToNftOwnable(instance);

        // setup instance targets
        _createInstanceTargets(_authorization.getMainTargetName());

        // setup roles and services
        _createRoles(_authorization);
        _setupServices(_authorization);

        // authorize functions of instance contracts
        _createTargetAuthorizations(_authorization);
    }

    /// @dev grants the service roles to the service addresses based on the authorization specification.
    /// Service addresses used for the granting are determined by the registry and the release of this instance.
    function _setupServices(IAuthorization authorization)
        internal
    {
        ObjectType[] memory serviceDomains = authorization.getServiceDomains();

        for(uint256 i = 0; i < serviceDomains.length; i++) {
            ObjectType serviceDomain = serviceDomains[i];
            RoleId serviceRoleId = authorization.getServiceRole(serviceDomain);
            address service = _registry.getServiceAddress(serviceDomain, _release);

            _grantRoleToAccount(
                serviceRoleId,
                service);
        }
    }


    function _createInstanceTargets(string memory instanceTargetName)
        internal
    {
        _createManagedTarget(address(_instance), instanceTargetName, TargetType.Instance); 
        _createManagedTarget(address(this), INSTANCE_ADMIN_TARGET_NAME, TargetType.Instance); 
        _createManagedTarget(address(_instance.getInstanceStore()), INSTANCE_STORE_TARGET_NAME, TargetType.Instance); 
        _createManagedTarget(address(_instance.getProductStore()), PRODUCT_STORE_TARGET_NAME, TargetType.Instance);
        _createManagedTarget(address(_instance.getBundleSet()), BUNDLE_SET_TARGET_NAME, TargetType.Instance); 
        _createManagedTarget(address(_instance.getRiskSet()), RISK_SET_TARGET_NAME, TargetType.Instance); 
    }


    /// @dev Initializes the authorization for the specified component.
    /// Important: The component MUST be registered.
    function initializeComponentAuthorization(
        address componentAddress,
        ObjectType expectedType
    )
        external
        restricted()
    {
        // checks
        AccessAdminLib.checkIsRegistered(address(getRegistry()), componentAddress, expectedType);

        IInstanceLinkedComponent component = IInstanceLinkedComponent(componentAddress);
        IAuthorization authorization = component.getAuthorization();
        _checkAuthorization(address(authorization), expectedType, getRelease(), false, false);

        // effects
        _createRoles(authorization);
        _createManagedTarget(componentAddress, authorization.getMainTargetName(), TargetType.Component);
        _createTargetAuthorizations(authorization);

        // increase component count
        _components++;
    }


    /// @dev Creates a custom role.
    function createRole(
        string memory name,
        RoleId adminRoleId,
        uint32 maxMemberCount
    )
        external
        restricted()
        returns (RoleId roleId)
    {
        // check role does not yet exist
        bool exists;
        (roleId, exists) = getRoleForName(name);
        if (exists) {
            revert ErrorAccessAdminRoleAlreadyCreated(
                roleId,
                name);
        }

        // create roleId
        roleId = AccessAdminLib.getCustomRoleId(_customRoleIdNext++);

        // create role
        _createRole(
            roleId, 
            AccessAdminLib.toRole(
                adminRoleId, 
                IAccess.RoleType.Custom, 
                maxMemberCount, 
                name),
            true); // revert on existing role
    }


    /// @dev Activtes/pauses the specified role.
    function setRoleActive(RoleId roleId, bool active)
        external
        restricted()
    {
        _setRoleActive(roleId, active);
    }


    /// @dev Grants the provided role to the specified account
    function grantRole(
        RoleId roleId, 
        address account)
        external
        restricted()
    {
        _grantRoleToAccount(roleId, account);
    }


    /// @dev Revokes the provided role from the specified account
    function revokeRole(
        RoleId roleId, 
        address account)
        external
        restricted()
    {
        _revokeRoleFromAccount(roleId, account);
    }


    /// @dev Create a new custom target.
    /// The target needs to be an access managed contract.
    function createTarget(
        address target, 
        string memory name
    )
        external
        restricted()
        returns (RoleId contractRoleId)
    {
        return _createManagedTarget(
            target, 
            name, 
            TargetType.Custom);
    }


    /// @dev Add function authorizations for the specified component or custom target.
    function authorizeFunctions(
        address target,
        RoleId roleId,
        IAccess.FunctionInfo[] memory functions
    )
        external
        restricted()
    {
        _checkComponentOrCustomTarget(target);
        _authorizeTargetFunctions(target, roleId, functions, true);
    }


    /// @dev Removes function authorizations for the specified component or custom target.
    function unauthorizeFunctions(
        address target,
        IAccess.FunctionInfo[] memory functions
    )
        external
        restricted()
    {
        _checkComponentOrCustomTarget(target);
        _authorizeTargetFunctions(target, ADMIN_ROLE(), functions, false);
    }


    function setComponentLocked(address target, bool locked) 
        external 
        restricted()
    {
        _setTargetLocked(target, locked);
    }


    /// @dev locks the instance and all its releated targets including component and custom targets.
    function setInstanceLocked(bool locked)
        external
        // not restricted(): need to operate on locked instances to unlock instance
        onlyInstanceService()
    {
        AccessManagerCloneable accessManager = AccessManagerCloneable(authority());
        accessManager.setLocked(locked);
    }


    function setTargetLocked(address target, bool locked) 
        external 
        // not restricted(): might need to operate on targets while instance is locked
        onlyInstanceService()
    {
        _setTargetLocked(target, locked);
    }


    /// @dev Returns the number of components that have been registered with this instance.   
    function components() 
        external 
        view 
        returns (uint64)
    {
        return _components;
    }


    /// @dev Returns the instance authorization specification used to set up this instance admin.
    function getInstanceAuthorization()
        external
        view
        returns (IAuthorization instanceAuthorizaion)
    {
        return _authorization;
    }


    function getRelease()
        public
        view
        override
        returns (VersionPart release)
    {
        return _release;
    }

    // ------------------- Internal functions ------------------- //


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

    // CANDIDATE AccessAdminLib
    function _checkComponentOrCustomTarget(address target) 
        internal
        view
    {
        IAccess.TargetType targetType = getTargetInfo(target).targetType;
        if (targetType != TargetType.Component && targetType != TargetType.Custom) {
            revert ErrorInstanceAdminNotComponentOrCustomTarget(target);
        }
    }
}
