// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {IAccess} from "./IAccess.sol";
import {IAccessAdmin} from "./IAccessAdmin.sol";
import {IAuthorization} from "./IAuthorization.sol";
import {IComponent} from "../shared/IComponent.sol";
import {IAuthorizedComponent} from "../shared/IAuthorizedComponent.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IService} from "../shared/IService.sol";
import {IServiceAuthorization} from "./IServiceAuthorization.sol";

import {AccessManagerCloneable} from "./AccessManagerCloneable.sol";
import {BlocknumberLib} from "../type/Blocknumber.sol";
import {ContractLib} from "../shared/ContractLib.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {RoleId, RoleIdLib, ADMIN_ROLE, PUBLIC_ROLE} from "../type/RoleId.sol";
import {Selector, SelectorLib} from "../type/Selector.sol";
import {Str, StrLib} from "../type/String.sol";
import {TimestampLib} from "../type/Timestamp.sol";
import {VersionPart, VersionPartLib} from "../type/Version.sol";


library AccessAdminLib { // ACCESS_ADMIN_LIB

    string public constant TOKEN_HANDLER_SUFFIX = "Th";
    string public constant ROLE_SUFFIX = "_Role";

    uint64 public constant SERVICE_DOMAIN_ROLE_FACTOR = 100;
    uint64 public constant COMPONENT_ROLE_FACTOR = 1000;
    uint64 public constant COMPONENT_ROLE_MAX = 19000;

    uint64 public constant CORE_ROLE_MIN        =     100;
    uint64 public constant SERVICE_ROLE_MIN     =    1000; // + service domain * SERVICE_ROLE_FACTOR + release
    uint64 public constant SERVICE_ROLE_FACTOR  =    1000; 
    uint64 public constant INSTANCE_ROLE_MIN    =  100000;

    // MUST match with Authorization.COMPONENT_ROLE_MIN
    uint64 public constant COMPONENT_ROLE_MIN   =  110000;

    uint64 public constant CUSTOM_ROLE_MIN      = 1000000;


    function ADMIN_ROLE_NAME() public pure returns (string memory) { 
        return "AdminRole"; 
    }


    function isAdminRoleName(string memory name) public pure returns (bool) { 
        return StrLib.eq(name, ADMIN_ROLE_NAME()); 
    }


    function PUBLIC_ROLE_NAME() public pure returns (string memory) { 
        return "PublicRole"; 
    }


    function getAdminRole() public pure returns (RoleId adminRoleId) { 
        // see oz AccessManagerUpgradeable
        return RoleId.wrap(type(uint64).min); 
    }


    function getPublicRole() public pure returns (RoleId publicRoleId) { 
        // see oz AccessManagerUpgradeable
        return RoleId.wrap(type(uint64).max); 
    }


    function isAdminOrPublicRole(string memory name) 
        public
        view
        returns (bool)
    {
        return StrLib.eq(name, ADMIN_ROLE_NAME())
            || StrLib.eq(name, PUBLIC_ROLE_NAME()); 
    }


    function isDynamicRoleId(RoleId roleId) 
        public 
        pure 
        returns (bool)
    {
        return roleId.toInt() >= COMPONENT_ROLE_MIN;
    }


    function adminRoleInfo()
        public 
        view 
        returns (IAccess.RoleInfo memory)
    {
        return roleInfo(
            getAdminRole(), 
            IAccess.TargetType.Core, 
            1, 
            ADMIN_ROLE_NAME());
    }


    function publicRoleInfo()
        public 
        view 
        returns (IAccess.RoleInfo memory)
    {
        return roleInfo(
            getAdminRole(), 
            IAccess.TargetType.Custom, 
            type(uint32).max, 
            PUBLIC_ROLE_NAME());
    }


    function coreRoleInfo(string memory name)
        public 
        view 
        returns (IAccess.RoleInfo memory)
    {
        return roleInfo(
            getAdminRole(), 
            IAccess.TargetType.Core, 
            1, 
            name);
    }


    function serviceRoleInfo(string memory serviceName)
        public 
        view 
        returns (IAccess.RoleInfo memory)
    {
        return roleInfo(
            getAdminRole(), 
            IAccess.TargetType.Service, 
            1, 
            serviceName);
    }


    /// @dev Creates a role info object from the provided parameters
    function roleInfo(
        RoleId adminRoleId, 
        IAccess.TargetType targetType, 
        uint32 maxMemberCount, 
        string memory roleName
    )
        public 
        view 
        returns (IAccess.RoleInfo memory info)
    {
        return IAccess.RoleInfo({
            name: StrLib.toStr(roleName),
            adminRoleId: adminRoleId,
            targetType: targetType,
            maxMemberCount: maxMemberCount,
            createdAt: TimestampLib.current(),
            pausedAt: TimestampLib.max(),
            lastUpdateIn: BlocknumberLib.current()});
    }


    function getSelectors(
        IAccess.FunctionInfo[] memory functions
    )
        public
        pure
        returns (
            bytes4[] memory selectors
        )
    {
        uint256 n = functions.length;
        selectors = new bytes4[](n);
        for (uint256 i = 0; i < n; i++) {
            selectors[i] = functions[i].selector.toBytes4();
        }
    }


    function checkInitParameters(
        address authority, 
        string memory adminName 
    )
        public
        view
    {
        // only contract check (authority might not yet be initialized at this time)
        if (!ContractLib.isContract(authority)) {
            revert IAccessAdmin.ErrorAccessAdminAuthorityNotContract(authority);
        }

        // check name not empty
        if (bytes(adminName).length == 0) {
            revert IAccessAdmin.ErrorAccessAdminAccessManagerEmptyName();
        }
    }


    function checkRoleCreation(
        IAccessAdmin accessAdmin,
        RoleId roleId, 
        IAccess.RoleInfo memory info,
        bool revertOnExistingRole
    )
        public 
        view
        returns (bool isAdminOrPublicRole)
    {
        // check 
        if (roleId == ADMIN_ROLE() || roleId == PUBLIC_ROLE()) {
            return true;
        }

        // check role does not yet exist 
        if(revertOnExistingRole && accessAdmin.roleExists(roleId)) {
            revert IAccessAdmin.ErrorAccessAdminRoleAlreadyCreated(
                roleId, 
                accessAdmin.getRoleInfo(roleId).name.toString());
        }

        // check admin role exists
        if(!accessAdmin.roleExists(info.adminRoleId)) {
            revert IAccessAdmin.ErrorAccessAdminRoleAdminNotExisting(info.adminRoleId);
        }

        // check role name is not empty
        if(info.name.length() == 0) {
            revert IAccessAdmin.ErrorAccessAdminRoleNameEmpty(roleId);
        }

        // check role name is not used for another role
        (RoleId roleIdForName, bool exists) = accessAdmin.getRoleForName(StrLib.toString(info.name));
        if(revertOnExistingRole && exists) {
            revert IAccessAdmin.ErrorAccessAdminRoleNameAlreadyExists(
                roleId, 
                info.name.toString(),
                roleIdForName);
        }

        return false;
    }


    function checkRoleExists(
        IAccessAdmin accessAdmin,
        RoleId roleId, 
        bool onlyActiveRole,
        bool allowAdminAndPublicRoles
    )
        internal
        view
    {
        // check role exists
        if (!accessAdmin.roleExists(roleId)) {
            revert IAccessAdmin.ErrorAccessAdminRoleUnknown(roleId);
        }

        // if onlyActiveRoles: check if role is disabled
        if (onlyActiveRole && accessAdmin.getRoleInfo(roleId).pausedAt <= TimestampLib.current()) {
            revert IAccessAdmin.ErrorAccessAdminRoleIsPaused(roleId);
        }

        // if not allowAdminAndPublicRoles, check if role is admin or public role
        if (!allowAdminAndPublicRoles) {
            checkNotAdminOrPublicRole(roleId);
        }
    }


    function checkNotAdminOrPublicRole(RoleId roleId) public pure {
        if (roleId == ADMIN_ROLE()) {
            revert IAccessAdmin.ErrorAccessAdminInvalidUseOfAdminRole();
        }

        if (roleId == PUBLIC_ROLE()) {
            revert IAccessAdmin.ErrorAccessAdminInvalidUseOfPublicRole();
        }
    }

    function checkTargetCreation(
        IAccessAdmin accessAdmin,
        address target, 
        string memory targetName, 
        bool checkAuthority
    )
        public 
        view
    {
        // check target does not yet exist
        if(accessAdmin.targetExists(target)) {
            revert IAccessAdmin.ErrorAccessAdminTargetAlreadyCreated(
                target, 
                accessAdmin.getTargetInfo(target).name.toString());
        }

        // check target name is not empty
        Str name = StrLib.toStr(targetName);
        if(name.length() == 0) {
            revert IAccessAdmin.ErrorAccessAdminTargetNameEmpty(target);
        }

        // check target name is not used for another target
        address targetForName = accessAdmin.getTargetForName(name);
        if(targetForName != address(0)) {
            revert IAccessAdmin.ErrorAccessAdminTargetNameAlreadyExists(
                target, 
                targetName,
                targetForName);
        }

        // check target is an access managed contract
        if (!ContractLib.isAccessManaged(target)) {
            revert IAccessAdmin.ErrorAccessAdminTargetNotAccessManaged(target);
        }

        // check target shares authority with this contract
        if (checkAuthority) {
            address targetAuthority = AccessManagedUpgradeable(target).authority();
            if (targetAuthority != accessAdmin.authority()) {
                revert IAccessAdmin.ErrorAccessAdminTargetAuthorityMismatch(accessAdmin.authority(), targetAuthority);
            }
        }
    }


    function checkComponentInitialization(
        IAccessAdmin accessAdmin,
        IAuthorization instanceAuthorization,
        address componentAddress,
        ObjectType expectedType
    )
        public
        view
        returns (IAuthorization componentAuthorization)
    {
        checkIsRegistered(address(accessAdmin.getRegistry()), componentAddress, expectedType);

        VersionPart expecteRelease = accessAdmin.getRelease();
        IAuthorizedComponent component = IAuthorizedComponent(componentAddress);
        componentAuthorization = component.getAuthorization();

        checkAuthorization(
            address(instanceAuthorization), 
            address(componentAuthorization), 
            expectedType, 
            expecteRelease,
            false, // expectServiceAuthorization,
            false); // checkAlreadyInitialized
    }


    function checkTargetAndRoleForFunctions(
        IAccessAdmin accessAdmin,
        address target,
        RoleId roleId,
        bool onlyComponentOrContractTargets
    ) 
        public
        view
    {
        // check target exists
        IAccess.TargetType targetType = accessAdmin.getTargetInfo(target).targetType;
        if (targetType == IAccess.TargetType.Undefined) {
            revert IAccessAdmin.ErrorAccessAdminTargetNotCreated(target);
        }

        // check target type
        if (onlyComponentOrContractTargets) {
            if (targetType != IAccess.TargetType.Component && targetType != IAccess.TargetType.Contract) {
                revert IAccessAdmin.ErrorAccessAdminNotComponentOrCustomTarget(target);
            }
        }

        // check role exist
        checkRoleExists(accessAdmin, roleId, true, true);
    } 


    function checkTargetExists(
        IAccessAdmin accessAdmin,
        address target
    )
        public
        view
    {
        // check not yet created
        if (!accessAdmin.targetExists(target)) {
            revert IAccessAdmin.ErrorAccessAdminTargetNotCreated(target);
        }
    }


    function checkAuthorization( 
        address authorizationOld,
        address authorization,
        ObjectType expectedDomain, 
        VersionPart expectedRelease,
        bool expectServiceAuthorization,
        bool checkAlreadyInitialized
    )
        public
        view
    {
        // checks
        // check not yet initialized
        if (checkAlreadyInitialized && authorizationOld != address(0)) {
            revert IAccessAdmin.ErrorAccessAdminAlreadyInitialized(authorizationOld);
        }

        // check contract type matches
        if (expectServiceAuthorization) {
            if (!ContractLib.supportsInterface(authorization, type(IServiceAuthorization).interfaceId)) {
                revert IAccessAdmin.ErrorAccessAdminNotServiceAuthorization(authorization);
            }
        } else {
            if (!ContractLib.supportsInterface(authorization, type(IAuthorization).interfaceId)) {  
                revert IAccessAdmin.ErrorAccessAdminNotAuthorization(authorization);
            }
        }

        // check domain matches
        ObjectType domain = IAuthorization(authorization).getDomain();
        if (domain != expectedDomain) {
            revert IAccessAdmin.ErrorAccessAdminDomainMismatch(authorization, expectedDomain, domain);
        }

        // check release matches
        VersionPart authorizationRelease = IAuthorization(authorization).getRelease();
        if (authorizationRelease != expectedRelease) {
            revert IAccessAdmin.ErrorAccessAdminReleaseMismatch(authorization, expectedRelease, authorizationRelease);
        }
    }


    function checkIsRegistered( 
        address registry,
        address target,
        ObjectType expectedType
    )
        public
        view 
    {
        checkRegistry(registry);

        ObjectType tagetType = IRegistry(registry).getObjectInfo(target).objectType;
        if (tagetType.eqz()) {
            revert IAccessAdmin.ErrorAccessAdminNotRegistered(target);
        }

        if (tagetType != expectedType) {
            revert IAccessAdmin.ErrorAccessAdminTargetTypeMismatch(target, expectedType, tagetType);
        }
    }


    function checkRegistry(
        address registry
    )
        public
        view
    {
        if (!ContractLib.isRegistry(registry)) {
            revert IAccessAdmin.ErrorAccessAdminNotRegistry(registry);
        }
    }


    function getAuthorizedRole(
        IAccessAdmin accessAdmin,
        IAuthorization authorization, 
        RoleId roleId
    )
        public
        view 
        returns (RoleId authorizedRoleId)
    {
        string memory roleName = authorization.getRoleInfo(roleId).name.toString();
        (authorizedRoleId, ) = accessAdmin.getRoleForName(roleName);
    }


    function getFunctionRoleId(
        AccessManagerCloneable authority,
        address target,
        Selector selector
    )
        public
        view
        returns (RoleId functionRoleId)
    {
        return RoleIdLib.toRoleId(
            authority.getTargetFunctionRole(
                target, 
                selector.toBytes4()));
    }


    function getServiceRoleId(
        address serviceAddress,
        IAccess.TargetType serviceTargetType
    )
        public
        view
        returns (RoleId serviceRoleId)
    {
        IService service = IService(serviceAddress);

        if (serviceTargetType == IAccess.TargetType.Service) {
            return RoleIdLib.toServiceRoleId(service.getDomain(), service.getRelease());
        } else if (serviceTargetType == IAccess.TargetType.GenericService) {
            return RoleIdLib.toGenericServiceRoleId(service.getDomain());
        }

        revert IAccessAdmin.ErrorAccessAdminInvalidServiceType(serviceAddress, serviceTargetType);
    }


    function getVersionedServiceRoleId(
        ObjectType serviceDomain,
        VersionPart release
    )
        public
        pure
        returns (RoleId serviceRoleId)
    {
        return RoleIdLib.toRoleId(
            SERVICE_ROLE_MIN + SERVICE_ROLE_FACTOR * serviceDomain.toInt() + release.toInt());
    }


    function getGenericServiceRoleId(
        ObjectType serviceDomain
    )
        public
        pure
        returns (RoleId serviceRoleId)
    {
        return RoleIdLib.toRoleId(
            SERVICE_ROLE_MIN + SERVICE_ROLE_FACTOR * serviceDomain.toInt() + VersionPartLib.releaseMax().toInt());
    }


    function getCustomRoleId(uint64 index)
        public 
        pure 
        returns (RoleId customRoleId)
    {
        return RoleIdLib.toRoleId(CUSTOM_ROLE_MIN + index);
    }


    function isCustomRole(RoleId roleId)
        public
        pure
        returns (bool)
    {
        return roleId.toInt() >= CUSTOM_ROLE_MIN;
    }


    function getTargetRoleId(
        address target,
        IAccess.TargetType targetType,
        uint64 index
    )
        public 
        view
        returns (RoleId targetRoleId)
    {
        if (targetType == IAccess.TargetType.Core) {
            return RoleIdLib.toRoleId(CORE_ROLE_MIN + index);
        }

        if (targetType == IAccess.TargetType.Service || targetType == IAccess.TargetType.GenericService ) { 
            return getServiceRoleId(target, targetType);
        }

        if (targetType == IAccess.TargetType.Instance) { 
            return RoleIdLib.toRoleId(INSTANCE_ROLE_MIN + index);
        }

        if (targetType == IAccess.TargetType.Component) { 
            return RoleIdLib.toRoleId(COMPONENT_ROLE_MIN + index);
        }

        if (targetType == IAccess.TargetType.Custom
            || targetType == IAccess.TargetType.Contract) 
        { 
            return RoleIdLib.toRoleId(CUSTOM_ROLE_MIN + index);
        }

        revert IAccessAdmin.ErrorAccessAdminInvalidTargetType(target, targetType);
    }


    function getTokenHandler(
        address target, 
        string memory targetName, 
        IAccess.TargetType targetType
    )
        public
        view
        returns (
            address tokenHandler,
            string memory tokenHandlerName
        )
    {
        // not component or core (we need to check core because of staking)
        if (targetType != IAccess.TargetType.Component && targetType != IAccess.TargetType.Core) {
            return (address(0), "");
        }

        // not contract
        if (!ContractLib.isContract(target)) {
            return (address(0), "");
        }

        // not component
        if (!ContractLib.supportsInterface(target, type(IComponent).interfaceId)) {
            return (address(0), "");
        }

        tokenHandler = address(IComponent(target).getTokenHandler());
        tokenHandlerName = string(abi.encodePacked(targetName, TOKEN_HANDLER_SUFFIX));
    }


    function toFunctionGrantingString(
        IAccessAdmin accessAdmin,
        Str functionName,
        RoleId roleId
    )
        public
        view
        returns (string memory)
    {
        return string(
            abi.encodePacked(
                functionName.toString(),
                "(): ",
                getRoleName(accessAdmin, roleId)));
    }


    function getRoleName(
        IAccessAdmin accessAdmin,
        RoleId roleId
    )
        public
        view 
        returns (string memory)
    {
        if (accessAdmin.roleExists(roleId)) {
            return accessAdmin.getRoleInfo(roleId).name.toString();
        }

        return "<unknown-role>";
    }


    function toRoleName(string memory name) public pure returns (string memory) {
        return string(
            abi.encodePacked(
                name,
                ROLE_SUFFIX));
    }


    function toFunction(
        bytes4 selector, 
        string memory name
    ) 
        public 
        view 
        returns (IAccess.FunctionInfo memory) 
    { 
        if(selector == bytes4(0)) {
            revert IAccessAdmin.ErrorAccessAdminSelectorZero();
        }

        if(bytes(name).length == 0) {
            revert IAccessAdmin.ErrorAccessAdminFunctionNameEmpty();
        }

        return IAccess.FunctionInfo({
            name: StrLib.toStr(name),
            selector: SelectorLib.toSelector(selector),
            createdAt: TimestampLib.current(),
            lastUpdateIn: BlocknumberLib.current()});
    }

}