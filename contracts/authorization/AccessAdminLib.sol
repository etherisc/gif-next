// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {IAccess} from "./IAccess.sol";
import {IAccessAdmin} from "./IAccessAdmin.sol";
import {IAuthorization} from "./IAuthorization.sol";
import {IRegistry} from "../registry/IRegistry.sol";

import {ContractLib} from "../shared/ContractLib.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {RoleId} from "../type/RoleId.sol";
import {SelectorLib} from "../type/Selector.sol";
import {Str, StrLib} from "../type/String.sol";
import {TimestampLib} from "../type/Timestamp.sol";
import {VersionPart} from "../type/Version.sol";


library AccessAdminLib { // ACCESS_ADMIN_LIB

    function checkRoleCreation(
        IAccessAdmin accessAdmin,
        RoleId roleId, 
        IAccess.RoleInfo memory info
    )
        public 
        view
    {
        // check role does not yet exist    // ACCESS_ADMIN_LIB role creation checks
        if(accessAdmin.roleExists(roleId)) {
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
        RoleId roleIdForName = accessAdmin.getRoleForName(StrLib.toString(info.name));
        if(roleIdForName.gtz()) {
            revert IAccessAdmin.ErrorAccessAdminRoleNameAlreadyExists(
                roleId, 
                info.name.toString(),
                roleIdForName);
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


    function checkAuthorization( 
        address authorizationOld,
        address authorization,
        ObjectType expectedDomain, 
        VersionPart expectedRelease,
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
        if (!ContractLib.supportsInterface(authorization, type(IAuthorization).interfaceId)) {  
            revert IAccessAdmin.ErrorAccessAdminNotAuthorization(authorization);
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
        ObjectType tagetType = IRegistry(registry).getObjectInfo(target).objectType;
        if (tagetType.eqz()) {
            revert IAccessAdmin.ErrorAccessAdminNotRegistered(target);
        }

        if (tagetType != expectedType) {
            revert IAccessAdmin.ErrorAccessAdminTargetTypeMismatch(target, expectedType, tagetType);
        }
    }

    function toRole(RoleId adminRoleId, IAccessAdmin.RoleType roleType, uint32 maxMemberCount, string memory name)
        public 
        view 
        returns (IAccess.RoleInfo memory)
    { 
        return IAccess.RoleInfo({
            name: StrLib.toStr(name),
            adminRoleId: adminRoleId,
            roleType: roleType,
            maxMemberCount: maxMemberCount,
            createdAt: TimestampLib.blockTimestamp(),
            pausedAt: TimestampLib.max()
        });
    }

    function toFunction(bytes4 selector, string memory name) 
        public 
        view 
        returns (IAccess.FunctionInfo memory) 
    { 
        return IAccess.FunctionInfo({
            name: StrLib.toStr(name),
            selector: SelectorLib.toSelector(selector),
            createdAt: TimestampLib.blockTimestamp()});
    }

}