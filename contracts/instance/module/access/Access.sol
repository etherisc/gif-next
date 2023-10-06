// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

// role admin handling of oz doesn't fit nft ownability
// import {AccessControlEnumerable} from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {RoleId, toRoleId} from "../../../types/RoleId.sol";
import {DISTRIBUTOR_OWNER_ROLE, ORACLE_OWNER_ROLE, POOL_OWNER_ROLE, PRODUCT_OWNER_ROLE} from "../../../types/RoleId.sol";
import {DISTRIBUTOR_OWNER_ROLE_NAME, ORACLE_OWNER_ROLE_NAME, POOL_OWNER_ROLE_NAME, PRODUCT_OWNER_ROLE_NAME} from "../../../types/RoleId.sol";
import {IAccessModule} from "./IAccess.sol";

abstract contract AccessModule is IAccessModule {

    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(RoleId role => RoleInfo info) private _info;
    RoleId[] private _roles;

    mapping(RoleId role => mapping(address member => bool isMember))
        private _isRoleMember;
    mapping(RoleId role => EnumerableSet.AddressSet members) private _roleMembers;

    modifier onlyAccessOwner() {
        require(
            msg.sender == this.getOwner(), // TODO without this
            "ERROR:ACS-001:NOT_OWNER");
        _;
    }

    modifier onlyExistingRole(RoleId role) {
        require(
            _info[role].id == role,
            "ERROR:ACS-002:ROLE_NOT_EXISTING");
        _;
    }

    constructor() {
        _createRole(DISTRIBUTOR_OWNER_ROLE(), DISTRIBUTOR_OWNER_ROLE_NAME());
        _createRole(ORACLE_OWNER_ROLE(), ORACLE_OWNER_ROLE_NAME());
        _createRole(POOL_OWNER_ROLE(), POOL_OWNER_ROLE_NAME());
        _createRole(PRODUCT_OWNER_ROLE(), PRODUCT_OWNER_ROLE_NAME());
    }

    function createRole(
        string memory roleName
    ) public override onlyAccessOwner returns (RoleId role) {
        role = toRoleId(roleName);
        require(
            !roleExists(role),
            "ERROR:ACS-010:ROLE_ALREADY_EXISTS");
        
        _createRole(role, roleName);
    }

    function setRoleState(RoleId role, bool active) external override onlyExistingRole(role) onlyAccessOwner {
        RoleInfo memory info = _info[role];
        info.isActive = active;
        _setRoleInfo(info);

        emit LogAccessRoleStateSet(role, active);
    }

    function grantRole(
        RoleId role,
        address member
    ) external override onlyExistingRole(role) onlyAccessOwner {
        require(_info[role].isActive, "ERROR:ACS-040:ROLE_NOT_ACTIVE");

        _isRoleMember[role][member] = true;
        _roleMembers[role].add(member);

        emit LogAccessRoleGranted(role, member, _isRoleMember[role][member]);
    }

    function revokeRole(
        RoleId role,
        address member
    ) external override onlyExistingRole(role) onlyAccessOwner {
        delete _isRoleMember[role][member];
        _roleMembers[role].remove(member);

        emit LogAccessRoleGranted(role, member, false);
    }

    function roleExists(RoleId role) public view virtual override returns (bool) {
        return _info[role].id == role;
    }

    function hasRole(
        RoleId role,
        address member
    ) public view virtual override returns (bool) {
        return _isRoleMember[role][member];
    }

    function getRoleId(string memory roleName) external pure override returns (RoleId role) {
        return toRoleId(roleName);
    }

    function getRoleInfo(
        RoleId role
    ) external view override returns (RoleInfo memory info) {
        return _info[role];
    }

    function getRole(
        uint256 idx
    ) external view override returns (RoleId role) {
        return _roles[idx];
    }

    function getRoleCount() external view override returns (uint256 roles) {
        return _roles.length;
    }

    function getRoleMemberCount(
        RoleId role
    ) public view override returns (uint256 roleMembers) {
        return _roleMembers[role].length();
    }

    function getRoleMember(
        RoleId role,
        uint256 idx
    ) public view override returns (address roleMembers) {
        return _roleMembers[role].at(idx);
    }

    function _createRole(
        RoleId role,
        string memory roleName
    ) internal {
        RoleInfo memory info = RoleInfo(role, roleName, true);
        _setRoleInfo(info);

        emit LogAccessRoleCreated(role, roleName);
    }

    function _setRoleInfo(
        RoleInfo memory info
    ) internal {
        RoleId role = info.id;
        _info[role] = info;
        if(!roleExists(role)) {
            _roles.push(role);
        }
    }
}
