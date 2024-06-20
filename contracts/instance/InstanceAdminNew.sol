// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";

import {AccessAdmin} from "../authorization/AccessAdmin.sol";
import {IAccessAdmin} from "../authorization/IAccessAdmin.sol";
import {IModuleAuthorization} from "../authorization/IModuleAuthorization.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IInstance} from "./IInstance.sol";
import {IService} from "../shared/IService.sol";
import {ObjectType, ObjectTypeLib, ALL, POOL, RELEASE} from "../type/ObjectType.sol";
import {RoleId, RoleIdLib, ADMIN_ROLE, PUBLIC_ROLE, INSTANCE_ROLE, DISTRIBUTION_OWNER_ROLE, ORACLE_OWNER_ROLE, POOL_OWNER_ROLE, PRODUCT_OWNER_ROLE} from "../type/RoleId.sol";
import {Str, StrLib} from "../type/String.sol";
import {VersionPart} from "../type/Version.sol";


contract InstanceAdminNew is
    AccessAdmin
{
    string public constant INSTANCE_TARGET_NAME = "Instance";
    string public constant INSTANCE_STORE_TARGET_NAME = "InstanceStore";
    string public constant INSTANCE_ADMIN_TARGET_NAME = "InstanceAdmin";
    string public constant BUNDLE_MANAGER_TARGET_NAME = "BundleManager";

    uint64 public constant CUSTOM_ROLE_ID_MIN = 10000; // MUST be even

    error ErrorInstanceAdminSetupAlreadyCompleted();
    error ErrorInstanceAdminReleaseMismatch();
    error ErrorInstanceAdminExpectedTargetMissing(string targetName);

    IInstance _instance;
    IRegistry internal _registry;
    uint64 _idNext;

    IModuleAuthorization _instanceAuthorization;
    bool private _setupCompleted = false;

    /// @dev Only used for master instance admin.
    /// Contracts created via constructor come with disabled initializers.
    constructor(IModuleAuthorization instanceAuthorization) AccessAdmin() {
        _instanceAuthorization = instanceAuthorization;
    }

    /// @dev Initializes this instance admin with the provided instances authorization specification.
    /// Internally the function creates an instance specific OpenZeppelin AccessManager that is used as the authority
    /// for the inststance authorizatios.
    /// Important: Initialization of this instance admin is only complete after calling function initializeInstance. 
    function initialize(
        IModuleAuthorization instanceAuthorization
    )
        external
        initializer() 
    {
        // create new access manager for this instance admin
        AccessManager accessManager = new AccessManager(address(this));
        _initializeAuthority(address(accessManager));

        // create basic instance independent setup
        _createAdminAndPublicRoles();

        // store instance authorization specification
        _instanceAuthorization = IModuleAuthorization(instanceAuthorization);
    }


    /// @dev Completes the initialization of this instance admin using the provided instance.
    /// Important: The instance MUST be registered and all instance supporting contracts must be wired to this instance.
    function initializeInstanceAuthorization(address instanceAddress)
        external
    {
        if (_setupCompleted) {
            revert ErrorInstanceAdminSetupAlreadyCompleted();
        }

        _setupCompleted = true;
        _idNext = CUSTOM_ROLE_ID_MIN;
        _instance = IInstance(instanceAddress);
        _registry = _instance.getRegistry();

        // check matching releases
        if (_instanceAuthorization.getRelease() != _instance.getMajorVersion()) {
            revert ErrorInstanceAdminReleaseMismatch();
        }

        // add instance authorization
        _creatRoles();
        _createTargetsWithRoles();
        _createTargetAuthorizations();

        // grant component owner roles to instance owner
        _grantComponentOwnerRoles();
    }

    function _grantComponentOwnerRoles()
        internal
    {
        address instanceOwner = _registry.ownerOf(_instance.getNftId());
        _grantRoleToAccount(DISTRIBUTION_OWNER_ROLE(), instanceOwner);
        _grantRoleToAccount(ORACLE_OWNER_ROLE(), instanceOwner);
        _grantRoleToAccount(POOL_OWNER_ROLE(), instanceOwner);
        _grantRoleToAccount(PRODUCT_OWNER_ROLE(), instanceOwner);
    }

    /// @dev Creates a custom role
    // TODO implement
    // function createRole()
    //     external
    //     restricted()
    // {

    // }

    /// @dev Grants the provided role to the specified account
    function grantRole(
        RoleId roleId, 
        address account)
        external
        restricted()
    {
        _grantRoleToAccount(roleId, account);
    }

    /// @dev Returns the instance authorization specification used to set up this instance admin.
    function getInstanceAuthorization()
        external
        view
        returns (IModuleAuthorization instanceAuthorizaion)
    {
        return _instanceAuthorization;
    }


    function _creatRoles()
        internal
    {
        RoleId[] memory roles = _instanceAuthorization.getRoles();
        RoleId adminRoleId = RoleIdLib.toRoleId(_authority.ADMIN_ROLE());
        RoleId roleId;
        RoleInfo memory roleInfo;

        for(uint256 i = 0; i < roles.length; i++) {
            roleId = roles[i];
            _createRole(
                roleId,
                _instanceAuthorization.getRoleInfo(roleId));
        }
    }

    function _createTargetsWithRoles()
        internal
    {
        // create module targets
        _checkAndCreateTargetWithRole(address(_instance), INSTANCE_TARGET_NAME);
        _checkAndCreateTargetWithRole(address(_instance.getInstanceStore()), INSTANCE_STORE_TARGET_NAME);
        _checkAndCreateTargetWithRole(address(_instance.getInstanceAdmin()), INSTANCE_ADMIN_TARGET_NAME);
        _checkAndCreateTargetWithRole(address(_instance.getBundleManager()), BUNDLE_MANAGER_TARGET_NAME);

        // create targets for services that need to access the module targets
        ObjectType[] memory serviceDomains = _instanceAuthorization.getServiceDomains();
        VersionPart release = _instanceAuthorization.getRelease();
        ObjectType serviceDomain;

        for (uint256 i = 0; i < serviceDomains.length; i++) {
            serviceDomain = serviceDomains[i];

            _checkAndCreateTargetWithRole(
                _registry.getServiceAddress(serviceDomain, release),
                _instanceAuthorization.getServiceTarget(serviceDomain).toString());
        }
    }

    function _createTargetAuthorizations()
        internal
    {
        Str[] memory targets = _instanceAuthorization.getTargets();
        Str target;

        for(uint256 i = 0; i < targets.length; i++) {
            target = targets[i];
            RoleId[] memory authorizedRoles = _instanceAuthorization.getAuthorizedRoles(target);
            RoleId authorizedRole;

            for(uint256 j = 0; j < authorizedRoles.length; j++) {
                authorizedRole = authorizedRoles[j];

                _authorizeTargetFunctions(
                    getTargetForName(target),
                    authorizedRole,
                    _instanceAuthorization.getAuthorizedFunctions(
                        target, 
                        authorizedRole));
            }
        }
    }

    function _checkAndCreateTargetWithRole(
        address target,
        string memory targetName
    )
        internal
    {
        // check that target name is defined in authorization specification
        Str name = StrLib.toStr(targetName);
        if (!_instanceAuthorization.targetExists(name)) {
            revert ErrorInstanceAdminExpectedTargetMissing(targetName);
        }

        // create named target
        _createTarget(
            target, 
            targetName, 
            false, // check authority TODO check normal targets, don't check service targets (they share authority with registry admin)
            false);

        // assign target role if defined
        RoleId targetRoleId = _instanceAuthorization.getTargetRole(name);
        if (targetRoleId != RoleIdLib.zero()) {
            _grantRoleToAccount(targetRoleId, target);
        }
    }
}
