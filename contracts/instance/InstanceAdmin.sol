// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IAccess} from "../authorization/IAccess.sol";
import {IAuthorization} from "../authorization/IAuthorization.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IInstance} from "./IInstance.sol";

import {AccessAdmin} from "../authorization/AccessAdmin.sol";
import {AccessAdminLib} from "../authorization/AccessAdminLib.sol";
import {AccessManagerCloneable} from "../authorization/AccessManagerCloneable.sol";
import {ObjectType, INSTANCE} from "../type/ObjectType.sol";
import {RoleId, ADMIN_ROLE} from "../type/RoleId.sol";
import {Str} from "../type/String.sol";
import {VersionPartLib, VersionPart} from "../type/Version.sol";
import {INSTANCE_TARGET_NAME, INSTANCE_ADMIN_TARGET_NAME, INSTANCE_STORE_TARGET_NAME, PRODUCT_STORE_TARGET_NAME, BUNDLE_SET_TARGET_NAME, RISK_SET_TARGET_NAME} from "./TargetNames.sol";


contract InstanceAdmin is
    AccessAdmin
{
    // onlyInstanceService
    error ErrorInstanceAdminNotInstanceService(address caller);

    // authorizeFunctions
    error ErrorInstanceAdminNotComponentOrCustomTarget(address target);

    IInstance internal _instance;

    uint64 internal _customRoleIdNext;


    modifier onlyInstanceService() {
        if (msg.sender != getRegistry().getServiceAddress(INSTANCE(), getRelease())) {
            revert ErrorInstanceAdminNotInstanceService(msg.sender);
        }
        _;
    }


    /// @dev Only used for master instance admin.
    constructor(address accessManager) {
        initialize(
            accessManager,
            "MasterInstanceAdmin",
            VersionPartLib.toVersionPart(3));
    }


    /// @dev Completes the initialization of this instance admin using the provided instance, registry and version.
    /// Important: Initialization of instance admin is only complete after calling this function. 
    /// Important: The instance MUST be registered and all instance supporting contracts must be wired to this instance.
    function completeSetup(
        address registry,
        address authorization,
        address instance
    )
        external
    {
        // checks
        AccessAdminLib.checkIsRegistered(registry, instance, INSTANCE());

        // effects
        AccessAdminLib.checkAuthorization(
            address(_authorization), 
            authorization, 
            INSTANCE(), // expectedDomain
            release, // expectedRelease
            false, // expectServiceAuthorization
            true); // checkAlreadyInitialized

        __RegistryLinked_init(registry);

        _instance = IInstance(instance);
        _authorization = IAuthorization(authorization);
        _customRoleIdNext = 0;

        // link nft ownability to instance
        _linkToNftOwnable(instance);

        // setup roles and services
        _createRoles(_authorization);
        _setupServices(_authorization);

        // setup instance targets
        _createInstanceTargets(_authorization.getMainTargetName());

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
            address service = _registry.getServiceAddress(serviceDomain, getRelease());

            _grantRoleToAccount(
                serviceRoleId,
                service);
        }
    }


    function _createInstanceTargets(string memory instanceTargetName)
        internal
    {
        _createInstanceTarget(address(_instance), instanceTargetName); 
        _createInstanceTarget(address(this), INSTANCE_ADMIN_TARGET_NAME); 
        _createInstanceTarget(address(_instance.getInstanceStore()), INSTANCE_STORE_TARGET_NAME); 
        _createInstanceTarget(address(_instance.getProductStore()), PRODUCT_STORE_TARGET_NAME); 
        _createInstanceTarget(address(_instance.getBundleSet()), BUNDLE_SET_TARGET_NAME); 
        _createInstanceTarget(address(_instance.getRiskSet()), RISK_SET_TARGET_NAME); 
    }


    function _createInstanceTarget(address target, string memory name) internal {
        _createTarget(target, name, TargetType.Instance, true); 
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
        IAuthorization authorization = AccessAdminLib.checkComponentInitialization(
            this, _authorization, componentAddress, expectedType);

        // effects
        _createRoles(authorization);
        _createTarget(componentAddress, authorization.getMainTargetName(), TargetType.Component, true);
        _createTargetAuthorizations(authorization);
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
        // create roleId
        roleId = AccessAdminLib.getCustomRoleId(_customRoleIdNext++);

        // create role
        _createRole(
            roleId, 
            AccessAdminLib.roleInfo(
                adminRoleId, 
                IAccess.TargetType.Custom, 
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


    /// @dev Create a new contract target.
    /// The target needs to be an access managed contract.
    function createTarget(
        address target, 
        string memory name
    )
        external
        restricted()
        returns (RoleId contractRoleId)
    {
        return _createTarget(
            target, 
            name, 
            TargetType.Contract,
            true); // check authority matches
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
        _authorizeTargetFunctions(target, roleId, functions, true, true);
    }


    /// @dev Removes function authorizations for the specified component or custom target.
    function unauthorizeFunctions(
        address target,
        IAccess.FunctionInfo[] memory functions
    )
        external
        restricted()
    {
        _authorizeTargetFunctions(target, ADMIN_ROLE(), functions, true, false);
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
        // not restricted(): need to operate on locked instances to unlock instance
        onlyInstanceService()
    {
        _setTargetLocked(target, locked);
    }


    function setContractLocked(address target, bool locked) 
        external 
        restricted() // component service
    {
        _setTargetLocked(target, locked);
    }


    /// @dev Returns the instance authorization specification used to set up this instance admin.
    function getInstanceAuthorization()
        external
        view
        returns (IAuthorization instanceAuthorizaion)
    {
        return _authorization;
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
}
