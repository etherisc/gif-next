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
import {NftId} from "../type/NftId.sol";
import {ObjectType, INSTANCE, ORACLE} from "../type/ObjectType.sol";
import {RoleId, RoleIdLib, ADMIN_ROLE} from "../type/RoleId.sol";
import {Str, StrLib} from "../type/String.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {TimestampLib} from "../type/Timestamp.sol";
import {VersionPart, VersionPartLib} from "../type/Version.sol";


contract InstanceAdmin is
    AccessAdmin
{
    string public constant INSTANCE_TARGET_NAME = "Instance";
    string public constant INSTANCE_ADMIN_TARGET_NAME = "InstanceAdmin";
    string public constant INSTANCE_STORE_TARGET_NAME = "InstanceStore";
    string public constant BUNDLE_SET_TARGET_NAME = "BundleSet";
    string public constant RISK_SET_TARGET_NAME = "RiskSet";

    error ErrorInstanceAdminNotInstanceService(address caller);

    error ErrorInstanceAdminNotCustomRole(RoleId roleId);

    error ErrorInstanceAdminNotRegistered(address instance);
    error ErrorInstanceAdminAlreadyAuthorized(address instance);

    error ErrorInstanceAdminNotComponentRole(RoleId roleId);
    error ErrorInstanceAdminRoleAlreadyExists(RoleId roleId);
    error ErrorInstanceAdminRoleTypeNotContract(RoleId roleId, IAccess.RoleType roleType);

    error ErrorInstanceAdminReleaseMismatch();
    error ErrorInstanceAdminExpectedTargetMissing(string targetName);

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
        address instance,
        address authorization,
        VersionPart release
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

        _checkAuthorization(authorization, INSTANCE(), release, true);

        // effects
        _registry = IRegistry(registry);
        _release = release;

        _instance = IInstance(instance);
        _authorization = IAuthorization(authorization);
        _components = 0;
        _customRoleIdNext = 0;

        // link nft ownability to instance
        _linkToNftOwnable(instance);

        _setupServiceRoles(_authorization);

        _createInstanceTargets(_authorization.getMainTargetName());

        // add instance authorization
        _createRoles(_authorization);

        // _setupInstanceHelperTargetsWithRoles();
        _createTargetAuthorizations(_authorization);
    }


    /// @dev grants the service roles to the service addresses based on the authorization specification.
    /// Service addresses used for the granting are determined by the registry and the release of this instance.
    function _setupServiceRoles(IAuthorization authorization)
        internal
    {
        ObjectType[] memory serviceDomains = authorization.getServiceDomains();

        for(uint256 i = 0; i < serviceDomains.length; i++) {
            ObjectType serviceDomain = serviceDomains[i];
            RoleId serviceRoleId = authorization.getServiceRole(serviceDomain);
            string memory serviceRoleName = authorization.getRoleName(serviceRoleId);

            // create service role if missing
            if (!roleExists(serviceRoleId)) {
                _createRole(
                    serviceRoleId, 
                    AccessAdminLib.toRole(
                        ADMIN_ROLE(), 
                        IAccess.RoleType.Contract, 
                        1, 
                        serviceRoleName));
            }

            // grant service role to service
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
        _checkAuthorization(address(authorization), expectedType, getRelease(), false);

        // effects
        _createRoles(authorization);
        _createManagedTarget(componentAddress, authorization.getMainTargetName(), TargetType.Component);
        _createTargetAuthorizations(authorization);

        // increase component count
        _components++;
    }

    function getRelease()
        public
        view
        override
        returns (VersionPart release)
    {
        return _release;
    }


    /// @dev Creates a custom role.
    function createRole(
        string memory roleName,
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
            AccessAdminLib.toRole(
                adminRoleId, 
                IAccess.RoleType.Custom, 
                maxMemberCount, 
                roleName));
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


    function setComponentLocked(address target, bool locked) 
        external 
        restricted()
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

    // ------------------- Internal functions ------------------- //


    function _createRoles(IAuthorization authorization)
        internal
    {
        RoleId[] memory roles = authorization.getRoles();
        RoleId mainTargetRoleId = authorization.getTargetRole(
            authorization.getMainTarget());

        for(uint256 i = 0; i < roles.length; i++) {
            RoleId roleId = roles[i];

            // skip main target role, create role if not exists
            if (roleId != mainTargetRoleId && !roleExists(roleId)) {
                _createRole(
                    roleId,
                    authorization.getRoleInfo(roleId));
            }
        }
    }


    function toComponentRole(RoleId roleId, uint64 componentIdx)
        internal
        pure
        returns (RoleId)
    {
        return RoleIdLib.toRoleId(
            RoleIdLib.toInt(roleId) + componentIdx);
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
