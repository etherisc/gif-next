// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";

import {AccessAdmin} from "../authorization/AccessAdmin.sol";
import {AccessManagerCloneable} from "../authorization/AccessManagerCloneable.sol";
import {IAccessAdmin} from "../authorization/IAccessAdmin.sol";
import {IAuthorization} from "../authorization/IAuthorization.sol";
import {IComponent} from "../shared/IComponent.sol";
import {IModuleAuthorization} from "../authorization/IModuleAuthorization.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IInstance} from "./IInstance.sol";
import {IService} from "../shared/IService.sol";
import {ObjectType, ObjectTypeLib, ALL, POOL, RELEASE} from "../type/ObjectType.sol";
import {RoleId, RoleIdLib, ADMIN_ROLE, PUBLIC_ROLE, DISTRIBUTION_OWNER_ROLE, ORACLE_OWNER_ROLE, POOL_OWNER_ROLE, PRODUCT_OWNER_ROLE} from "../type/RoleId.sol";
import {Str, StrLib} from "../type/String.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {VersionPart} from "../type/Version.sol";


contract InstanceAdmin is
    AccessAdmin
{
    string public constant INSTANCE_TARGET_NAME = "Instance";
    string public constant INSTANCE_STORE_TARGET_NAME = "InstanceStore";
    string public constant INSTANCE_ADMIN_TARGET_NAME = "InstanceAdmin";
    string public constant BUNDLE_SET_TARGET_NAME = "BundleSet";
    string public constant RISK_SET_TAGET_NAME = "RiskSet";

    uint64 public constant CUSTOM_ROLE_ID_MIN = 10000; // MUST be even

    error ErrorInstanceAdminNotRegistered(address target);
    error ErrorInstanceAdminAlreadyAuthorized(address target);
    error ErrorInstanceAdminReleaseMismatch();
    error ErrorInstanceAdminExpectedTargetMissing(string targetName);

    IInstance _instance;
    IRegistry internal _registry;
    uint64 _idNext;

    IModuleAuthorization _instanceAuthorization;

    /// @dev Only used for master instance admin.
    /// Contracts created via constructor come with disabled initializers.
    constructor(
        IModuleAuthorization instanceAuthorization
    )
        AccessAdmin()
    {
        _instanceAuthorization = instanceAuthorization;
    }

    /// @dev Initializes this instance admin with the provided instances authorization specification.
    /// Internally the function creates an instance specific OpenZeppelin AccessManager that is used as the authority
    /// for the inststance authorizatios.
    /// Important: Initialization of this instance admin is only complete after calling function initializeInstance. 
    function initialize(
        AccessManagerCloneable accessManager,
        IModuleAuthorization instanceAuthorization
    )
        external
        initializer() 
    {
        // create new access manager for this instance admin
        _initializeAuthority(address(accessManager));

        // create basic instance independent setup
        _createAdminAndPublicRoles();

        // store instance authorization specification
        _instanceAuthorization = IModuleAuthorization(instanceAuthorization);
    }

    function _checkTargetIsReadyForAuthorization(address target)
        internal
        view
    {
        if (address(_registry) != address(0) && !_registry.isRegistered(target)) {
            revert ErrorInstanceAdminNotRegistered(target);
        }

        if (targetExists(target)) {
            revert ErrorInstanceAdminAlreadyAuthorized(target);
        }
    }

    /// @dev Completes the initialization of this instance admin using the provided instance.
    /// Important: The instance MUST be registered and all instance supporting contracts must be wired to this instance.
    function initializeInstanceAuthorization(address instanceAddress)
        external
    {
        _checkTargetIsReadyForAuthorization(instanceAddress);

        _idNext = CUSTOM_ROLE_ID_MIN;
        _instance = IInstance(instanceAddress);
        _registry = _instance.getRegistry();

        // check matching releases
        if (_instanceAuthorization.getRelease() != _instance.getMajorVersion()) {
            revert ErrorInstanceAdminReleaseMismatch();
        }

        // add instance authorization
        _createRoles(_instanceAuthorization);
        _createModuleTargetsWithRoles();
        _createTargetAuthorizations(_instanceAuthorization);

        // grant component owner roles to instance owner
        _grantComponentOwnerRoles();
    }


    /// @dev Initializes the authorization for the specified component.
    /// Important: The component MUST be registered.
    function initializeComponentAuthorization(
        IComponent component,
        IAuthorization authorization
    )
        external
    {
        _checkTargetIsReadyForAuthorization(address(component));

        _createRoles(authorization);

        // create component target
        _createTarget(
            address(component), 
            authorization.getTargetName(), 
            true, // checkAuthority
            false); // custom

        _createTarget(
            address(component.getTokenHandler()), 
            string(abi.encodePacked(authorization.getTargetName(), "TH")), 
            true, 
            false);
        
        // FIXME: make this a bit nicer and work with IAuthorization. Use a specific role, not public - access to TokenHandler must be restricted
        FunctionInfo[] memory functions = new FunctionInfo[](3);
        functions[0] = toFunction(TokenHandler.collectTokens.selector, "collectTokens");
        functions[1] = toFunction(TokenHandler.collectTokensToThreeRecipients.selector, "collectTokensToThreeRecipients");
        functions[2] = toFunction(TokenHandler.distributeTokens.selector, "distributeTokens");

        _authorizeTargetFunctions(
            address(component.getTokenHandler()),
            getPublicRole(),
            functions);

        _grantRoleToAccount(
            authorization.getTargetRole(
                authorization.getTarget()), 
            address(component));
        
        _createTargetAuthorizations(authorization);
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


    function _createRoles(IAuthorization authorization)
        internal
    {
        RoleId[] memory roles = authorization.getRoles();
        RoleId roleId;
        RoleInfo memory roleInfo;

        for(uint256 i = 0; i < roles.length; i++) {
            roleId = roles[i];

            if (!roleExists(roleId)) {
                _createRole(
                    roleId,
                    authorization.getRoleInfo(roleId));
            }
        }
    }


    function _createTargetAuthorizations(IAuthorization authorization)
        internal
    {
        Str[] memory targets = authorization.getTargets();
        Str target;

        for(uint256 i = 0; i < targets.length; i++) {
            target = targets[i];
            RoleId[] memory authorizedRoles = authorization.getAuthorizedRoles(target);
            RoleId authorizedRole;

            for(uint256 j = 0; j < authorizedRoles.length; j++) {
                authorizedRole = authorizedRoles[j];

                _authorizeTargetFunctions(
                    getTargetForName(target),
                    authorizedRole,
                    authorization.getAuthorizedFunctions(
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
            false, // check authority TODO check normal targets, don't check service targets (they share authority with release admin)
            false);

        // assign target role if defined
        RoleId targetRoleId = _instanceAuthorization.getTargetRole(name);
        if (targetRoleId != RoleIdLib.zero()) {
            _grantRoleToAccount(targetRoleId, target);
        }
    }

    function _createModuleTargetsWithRoles()
        internal
    {
        // create module targets
        _checkAndCreateTargetWithRole(address(_instance), INSTANCE_TARGET_NAME);
        _checkAndCreateTargetWithRole(address(_instance.getInstanceStore()), INSTANCE_STORE_TARGET_NAME);
        _checkAndCreateTargetWithRole(address(_instance.getInstanceAdmin()), INSTANCE_ADMIN_TARGET_NAME);
        _checkAndCreateTargetWithRole(address(_instance.getBundleSet()), BUNDLE_SET_TARGET_NAME);
        _checkAndCreateTargetWithRole(address(_instance.getRiskSet()), RISK_SET_TAGET_NAME);

        // create targets for services that need to access the module targets
        ObjectType[] memory serviceDomains = _instanceAuthorization.getServiceDomains();
        VersionPart release = _instanceAuthorization.getRelease();
        ObjectType serviceDomain;

        for (uint256 i = 0; i < serviceDomains.length; i++) {
            serviceDomain = serviceDomains[i];

            _checkAndCreateTargetWithRole(
                _registry.getServiceAddress(serviceDomain, release),
                _instanceAuthorization.getServiceName(serviceDomain).toString());
        }
    }
}
