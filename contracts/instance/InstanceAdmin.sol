// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;


import {AccessAdmin} from "../authorization/AccessAdmin.sol";
import {AccessManagerCloneable} from "../authorization/AccessManagerCloneable.sol";
import {IAuthorization} from "../authorization/IAuthorization.sol";
import {IInstanceLinkedComponent} from "../shared/IInstanceLinkedComponent.sol";
import {IAuthorization} from "../authorization/IAuthorization.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IInstance} from "./IInstance.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {RoleId, RoleIdLib} from "../type/RoleId.sol";
import {Str, StrLib} from "../type/String.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {VersionPart, VersionPartLib} from "../type/Version.sol";


contract InstanceAdmin is
    AccessAdmin
{
    string public constant INSTANCE_TARGET_NAME = "Instance";
    string public constant INSTANCE_STORE_TARGET_NAME = "InstanceStore";
    string public constant INSTANCE_ADMIN_TARGET_NAME = "InstanceAdmin";
    string public constant BUNDLE_SET_TARGET_NAME = "BundleSet";
    string public constant RISK_SET_TAGET_NAME = "RiskSet";

    uint64 public constant CUSTOM_ROLE_ID_MIN = 10000; // MUST be even

    error ErrorInstanceAdminCallerNotInstanceOwner(address caller);
    error ErrorInstanceAdminInstanceAlreadyLocked();
    error ErrorInstanceAdminNotRegistered(address target);
    error ErrorInstanceAdminAlreadyAuthorized(address target);
    error ErrorInstanceAdminReleaseMismatch();
    error ErrorInstanceAdminExpectedTargetMissing(string targetName);

    IInstance internal _instance;
    IRegistry internal _registry;
    uint64 internal _idNext;

    IAuthorization internal _instanceAuthorization;


    modifier onlyInstanceOwner() {        
        if(msg.sender != _registry.ownerOf(address(_instance))) {
            revert ErrorInstanceAdminCallerNotInstanceOwner(msg.sender);
        }
        _;
    }

    /// @dev Only used for master instance admin.
    /// Contracts created via constructor come with disabled initializers.
    constructor(
        address instanceAuthorization
    ) {
        initialize(new AccessManagerCloneable());

        _instanceAuthorization = IAuthorization(instanceAuthorization);

        _disableInitializers();
    }

    /// @dev Completes the initialization of this instance admin using the provided instance, registry and version.
    /// Important: Initialization of instance admin is only complete after calling this function. 
    /// Important: The instance MUST be registered and all instance supporting contracts must be wired to this instance.
    function completeSetup(
        address instanceAddress,
        address instanceAuthorization,
        VersionPart releaseVersion
    )
        external
        reinitializer(uint64(releaseVersion.toInt()))
        onlyDeployer()
    {
        _idNext = CUSTOM_ROLE_ID_MIN;
        _instance = IInstance(instanceAddress);
        _registry = IRegistry(_instance.getRegistry());
        _instanceAuthorization = IAuthorization(instanceAuthorization);

        AccessManagerCloneable accessManager = AccessManagerCloneable(authority());
        accessManager.completeSetup(address(_registry), VersionPartLib.toVersionPart(type(uint8).max)); 

        _checkTargetIsReadyForAuthorization(instanceAddress);

        // check matching releases
        if (_instanceAuthorization.getRelease() != _instance.getRelease()) {
            revert ErrorInstanceAdminReleaseMismatch();
        }

        // add instance authorization
        _createRoles(_instanceAuthorization);
        _createModuleTargetsWithRoles();
        _createTargetAuthorizations(_instanceAuthorization);
    }


    /// @dev Initializes the authorization for the specified component.
    /// Important: The component MUST be registered.
    function initializeComponentAuthorization(
        IInstanceLinkedComponent component
    )
        external
    {
        // !!! TODO add caller restrictions?

        _checkTargetIsReadyForAuthorization(address(component));

        // get authorization specification
        IAuthorization authorization = component.getAuthorization();
        string memory targetName = authorization.getTargetName();
        _checkTargetIsReadyForAuthorization(address(component));


        // create roles
        _createRoles(authorization);

        // create component target
        _createTarget(
            address(component), 
            targetName, 
            true, // checkAuthority
            false); // custom

        _createTarget(
            address(component.getTokenHandler()), 
            string(abi.encodePacked(targetName, "TH")), 
            true, 
            false);
        
        FunctionInfo[] memory functions = new FunctionInfo[](3);
        functions[0] = toFunction(TokenHandler.collectTokens.selector, "collectTokens");
        functions[1] = toFunction(TokenHandler.collectTokensToThreeRecipients.selector, "collectTokensToThreeRecipients");
        functions[2] = toFunction(TokenHandler.distributeTokens.selector, "distributeTokens");

        // FIXME: make this a bit nicer and work with IAuthorization. Use a specific role, not public - access to TokenHandler must be restricted
        _authorizeTargetFunctions(
            address(component.getTokenHandler()),
            getPublicRole(),
            functions);

        _grantRoleToAccount(
            authorization.getTargetRole(
                authorization.getMainTarget()), 
            address(component));
        
        _createTargetAuthorizations(authorization);
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


    function setInstanceLocked(bool locked)
        external
        onlyInstanceOwner()
    {
        AccessManagerCloneable accessManager = AccessManagerCloneable(authority());

        if(accessManager.isLocked() == locked) {
            revert ErrorInstanceAdminInstanceAlreadyLocked();
        }
        accessManager.setLocked(locked);
    }

    function setTargetLocked(address target, bool locked) 
        external 
        restricted()
    {
        _setTargetClosed(target, locked);
    }



    /// @dev Returns the instance authorization specification used to set up this instance admin.
    function getInstanceAuthorization()
        external
        view
        returns (IAuthorization instanceAuthorizaion)
    {
        return _instanceAuthorization;
    }

    // ------------------- Internal functions ------------------- //

    function _checkTargetIsReadyForAuthorization(address target)
        internal
        view
    {
        if (!_registry.isRegistered(target)) {
            revert ErrorInstanceAdminNotRegistered(target);
        }

        if (targetExists(target)) {
            revert ErrorInstanceAdminAlreadyAuthorized(target);
        }
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
                _instanceAuthorization.getServiceTarget(serviceDomain).toString());
        }
    }
}
