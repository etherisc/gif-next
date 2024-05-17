// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IAccessManagerExtended} from "./IAccessManagerExtended.sol";
import {AccessManagerCustom} from "./AccessManagerCustom.sol";

import {Timestamp, TimestampLib} from "../type/Timestamp.sol";


// IMPORTANT: check role/target for existance before using return value of getter
contract AccessManagerExtended is AccessManagerCustom, IAccessManagerExtended {
    using EnumerableSet for EnumerableSet.AddressSet;

    string constant private ADMIN_ROLE_NAME = "Admin";
    string constant private PUBLIC_ROLE_NAME = "Public";

    /// @custom:storage-location erc7201:etherisc.storage.AccessManagerExtended
    struct AccessManagerExtendedStorage {
        mapping(address target => TargetInfo info) _targetInfo;
        mapping(string name => address target) _targetAddressForName;
        address[] _targetAddresses;

        mapping(uint64 roleId => RoleInfo) _roleInfo;
        mapping(uint64 roleId => EnumerableSet.AddressSet roleMembers) _roleMembers;
        mapping(string => uint64) _roleIdForName;
        uint64[] _roleIds;
    }

    // keccak256(abi.encode(uint256(keccak256("etherisc.storage.AccessManagerExtended")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant AccessManagerExtendedStorageLocation = 0x5bf600af9ae77c7c374fa7aa6d8057fe6114c74f945a04f4a14ca05a62876900;

    function _getAccessManagerExtendedStorage() private pure returns (AccessManagerExtendedStorage storage $) {
        assembly {
            $.slot := AccessManagerExtendedStorageLocation
        }
    }

    modifier roleExists(uint64 roleId) {
        if(!isRoleExists(roleId)) {
            revert AccessManagerRoleIdNotExists(roleId);
        }
        _;
    }

    modifier targetExists(address target) {
        if(!isTargetExists(target)) {
            revert AccessManagerTargetNotExists(target);
        }
        _;
    }

    function __AccessManagerExtended_init(address initialAdmin) internal onlyInitializing {

        _createRole(ADMIN_ROLE, ADMIN_ROLE_NAME);//, IAccess.Type.Core);
        _createRole(PUBLIC_ROLE, PUBLIC_ROLE_NAME);//, IAccess.Type.Core);


        // grants ADMIN role to initialAdmin
        __AccessManagerCustom_init(initialAdmin);
    }

    // =================================================== GETTERS ====================================================

    function isTargetExists(address target) public view returns (bool) {
        AccessManagerExtendedStorage storage $ = _getAccessManagerExtendedStorage();
        return $._targetInfo[target].createdAt.gtz();
    }

    function isTargetNameExists(string memory name) public view returns (bool) {
        AccessManagerExtendedStorage storage $ = _getAccessManagerExtendedStorage();
        return $._targetAddressForName[name] != address(0);
    }

    function getTargetAddress(string memory name) public view returns(address targetAddress) {
        AccessManagerExtendedStorage storage $ = _getAccessManagerExtendedStorage();
        return $._targetAddressForName[name];
    }

    function getTargetInfo(address target) public view returns (TargetInfo memory) {
        AccessManagerExtendedStorage storage $ = _getAccessManagerExtendedStorage();
        return $._targetInfo[target];
    }

    function getRoleInfo(uint64 roleId) public view returns (RoleInfo memory) {
        AccessManagerExtendedStorage storage $ = _getAccessManagerExtendedStorage();
        return $._roleInfo[roleId];
    }

    function getRoleMembers(uint64 roleId) public view returns (uint256 numberOfMembers) {
        AccessManagerExtendedStorage storage $ = _getAccessManagerExtendedStorage();
        return EnumerableSet.length($._roleMembers[roleId]);
    }

    function getRoleMember(uint64 roleId, uint256 idx) public view returns (address member) {
        AccessManagerExtendedStorage storage $ = _getAccessManagerExtendedStorage();
        return EnumerableSet.at($._roleMembers[roleId], idx);
    }

    function getRoleId(uint256 idx) public view returns (uint64 roleId) {
        AccessManagerExtendedStorage storage $ = _getAccessManagerExtendedStorage();
        return $._roleIds[idx];
    }

    // TODO returns ADMIN_ROLE id for non existent name
    function getRoleId(string memory name) public view returns (uint64 roleId) {
        AccessManagerExtendedStorage storage $ = _getAccessManagerExtendedStorage();
        return $._roleIdForName[name];
    }

    function getRoles() public view returns (uint256 numberOfRoles) {
        AccessManagerExtendedStorage storage $ = _getAccessManagerExtendedStorage();
        return $._roleIds.length;
    }

    function isRoleExists(uint64 roleId) public view returns (bool exists) {
        AccessManagerExtendedStorage storage $ = _getAccessManagerExtendedStorage();
        return $._roleInfo[roleId].createdAt.gtz();
    }

    function isRoleNameExists(string memory name) public view returns (bool exists) {
        AccessManagerExtendedStorage storage $ = _getAccessManagerExtendedStorage();
        return $._roleIdForName[name] != 0;
    }

    // =============================================== ROLE MANAGEMENT ===============================================

    /// inheritdoc IAccessManagerExtended
    function createRole(uint64 roleId, string memory name)//, IAccess.Type rtype) 
        public
        onlyAuthorized
    {
        name = _validateRole(roleId, name);//, rtype);
        _createRole(roleId, name);//, rtype);
    }

    function _validateRole(uint64 roleId, string memory name)//, IAccess.Type rtype)
        internal 
        virtual
        view
        returns(string memory)
    {
        /*
        if(rtype == IAccess.Type.Custom && roleId < CUSTOM_ROLE_ID_MIN) {
            revert IAccess.ErrorIAccessRoleIdTooSmall(roleId);
        }

        if(
            rtype != IAccess.Type.Custom && 
            roleId >= CUSTOM_ROLE_ID_MIN && 
            roleId != PUBLIC_ROLE().toInt()) 
        {
            revert AccessManagerRoleIdTooBig(roleId);
        }
        */
        
        if(roleId == 0) {
            revert AccessManagerRoleIdZero();
        }

        if(bytes(name).length == 0) {
            revert AccessManagerRoleNameEmpty(roleId);
        }

        return name;
    }

    function _createRole(uint64 roleId, string memory name/*, IAccess.Type rtype*/) private
    {
        AccessManagerExtendedStorage storage $ = _getAccessManagerExtendedStorage();

        if(isRoleExists(roleId)) {
            revert AccessManagerRoleIdAlreadyExists(roleId);
        }

        if(isRoleNameExists(name)) {
            revert AccessManagerRoleNameAlreadyExists(
                roleId, 
                getRoleId(name), 
                name);
        }

        $._roleInfo[roleId] = RoleInfo({
            id: roleId,
            name: name,
            //rtype: rtype,
            createdAt: TimestampLib.blockTimestamp()
            // disableAt: 0;
        });

        $._roleIdForName[name] = roleId;
        $._roleIds.push(roleId);

        emit LogRoleCreation(roleId, name);//, rtype);
    }

    /// inheritdoc IAccessManager
    function labelRole(uint64 roleId, string calldata label) 
        public 
        override (AccessManagerCustom, IAccessManager)
        roleExists(roleId) 
    {
        super.labelRole(roleId, label);
    }

    /// inheritdoc IAccessManager
    function grantRole(uint64 roleId, address account, uint32 executionDelay) 
        public 
        override (AccessManagerCustom, IAccessManager)
        roleExists(roleId) 
    {
        AccessManagerExtendedStorage storage $ = _getAccessManagerExtendedStorage();
        $._roleMembers[roleId].add(account);
        super.grantRole(roleId, account, executionDelay);
    }

    /// inheritdoc IAccessManager
    function revokeRole(uint64 roleId, address account) 
        public 
        override (AccessManagerCustom, IAccessManager)
        roleExists(roleId) 
    {
        AccessManagerExtendedStorage storage $ = _getAccessManagerExtendedStorage();
        $._roleMembers[roleId].remove(account);
        super.revokeRole(roleId, account);
    }

    /// inheritdoc IAccessManager
    function renounceRole(uint64 roleId, address callerConfirmation) 
        public 
        override (AccessManagerCustom, IAccessManager)
        roleExists(roleId) 
    {
        AccessManagerExtendedStorage storage $ = _getAccessManagerExtendedStorage();
        $._roleMembers[roleId].remove(_msgSender());
        super.renounceRole(roleId, callerConfirmation);
    }

    /// inheritdoc IAccessManager
    function setRoleAdmin(uint64 roleId, uint64 admin) 
        public 
        override (AccessManagerCustom, IAccessManager)
        roleExists(roleId)
        roleExists(admin)
    {
        super.setRoleAdmin(roleId, admin);
    }

    /// inheritdoc IAccessManager
    function setRoleGuardian(uint64 roleId, uint64 guardian) 
        public 
        override (AccessManagerCustom, IAccessManager)
        roleExists(roleId) 
    {
        super.setRoleGuardian(roleId, guardian);
    }

    /// inheritdoc IAccessManager
    function setGrantDelay(uint64 roleId, uint32 newDelay) 
        public 
        override (AccessManagerCustom, IAccessManager)
        roleExists(roleId) 
    {
        super.setGrantDelay(roleId, newDelay);
    }

    // ============================================= TARGET MANAGEMENT ==============================================
    /// inheritdoc IAccessManagerExtended
    function createTarget(address target, string memory name)//, IAccess.Type.Custom) 
        public
        onlyAuthorized
    {
        name = _validateTarget(target, name);
        _createTarget(target, name);//, IAccess.Type.Custom);
    }

    /// inheritdoc IAccessManager
    // TODO must not allow "target = this" -> access manager as target created at the begining
    function _createTarget(address target, string memory name) private//, IAccess.Type ttype) private 
    {
        AccessManagerExtendedStorage storage $ = _getAccessManagerExtendedStorage();
        
        if(isTargetExists(target)) {
            revert AccessManagerTargetAlreadyExists(target);
        }

        if(isTargetNameExists(name)) {
            revert AccessManagerTargetNameAlreadyExists(
                target, 
                $._targetAddressForName[name], 
                name);
        }

        $._targetInfo[target] = TargetInfo ({
            taddress: target,
            //ttype: ttype,
            name: name,
            createdAt: TimestampLib.blockTimestamp()
            // disableAt: 0;
        });

        $._targetAddressForName[name] = target;
        // must revert / panic on duplicate address -> -1 check then
        $._targetAddresses.push(target);

        emit LogTargetCreation(target, name);//, ttype);
    }

    /// inheritdoc IAccessManagerExtended
    // panics in case interface is not supported, 0 address included
    function _validateTarget(address target, string memory name) 
        internal
        virtual
        returns (string memory)
    {
        if(target == address(0)) {
            revert AccessManagerTargetAddressZero();
        }
        // panic if not contract
        //address authority = IAccessManaged(target).authority();

        //if(authority != address(this)) {
        //    revert AccessManagerTargetAuthorityInvalid(target, authority);
        //}

        if(bytes(name).length == 0) {
            revert AccessManagerTargetNameEmpty(target);
        }

        return name;
    }

    // ============================================= FUNCTION MANAGEMENT ==============================================

    /// inheritdoc IAccessManager
    function setTargetFunctionRole(
        address target,
        bytes4[] calldata selectors,
        uint64 roleId
    ) 
        public 
        override (AccessManagerCustom, IAccessManager)
        targetExists(target)
        roleExists(roleId)
    {
        super.setTargetFunctionRole(target, selectors, roleId);
    }
    /// inheritdoc IAccessManager
    function setTargetAdminDelay(address target, uint32 newDelay) 
        public
        override (AccessManagerCustom, IAccessManager)
        targetExists(target)
    {
        super.setTargetAdminDelay(target, newDelay);
    }

    // =============================================== MODE MANAGEMENT ================================================
    /// inheritdoc IAccessManager
    function setTargetClosed(address target, bool closed) 
        public
        override (AccessManagerCustom, IAccessManager)
        targetExists(target)
    {
        super.setTargetClosed(target, closed);
    }

    // ============================================== DELAYED OPERATIONS ==============================================
    /// inheritdoc IAccessManager
    function schedule(
        address target,
        bytes calldata data,
        uint48 when
    ) 
        public 
        override (AccessManagerCustom, IAccessManager)
        targetExists(target) 
        returns (bytes32 operationId, uint32 nonce) 
    {
        (operationId, nonce) = super.schedule(target, data, when);
    }

    /// inheritdoc IAccessManager
    function execute(address target, bytes calldata data) 
        public 
        payable 
        override (AccessManagerCustom, IAccessManager)
        targetExists(target) returns (uint32) 
    {
        return super.execute(target, data);
    }

    /// inheritdoc IAccessManager
    function cancel(address caller, address target, bytes calldata data) 
        public 
        override (AccessManagerCustom, IAccessManager)
        targetExists(target) returns (uint32) 
    {
        return super.cancel(caller, target, data);
    }

    /// inheritdoc IAccessManager
    function consumeScheduledOp(address caller, bytes calldata data) 
        public 
        override (AccessManagerCustom, IAccessManager)
        targetExists(_msgSender()) 
    {
        super.consumeScheduledOp(caller, data);
    }

    // ==================================================== OTHERS ====================================================
    /// inheritdoc IAccessManager
    function updateAuthority(address target, address newAuthority) 
        public 
        override (AccessManagerCustom, IAccessManager)
        targetExists(target) 
    {
        super.updateAuthority(target, newAuthority);
    }

    // ================================================= ADMIN LOGIC ==================================================

    function _getAdminRestrictions(
        bytes calldata data
    ) internal virtual override view returns (bool restricted, uint64 roleAdminId, uint32 executionDelay) {
        if (data.length < 4) {
            return (false, 0, 0);
        }

        bytes4 selector = _checkSelector(data);

        // Restricted to ADMIN with no delay beside any execution delay the caller may have
        if (
            selector == this.labelRole.selector ||
            selector == this.setRoleAdmin.selector ||
            selector == this.setRoleGuardian.selector ||
            selector == this.setGrantDelay.selector ||
            selector == this.setTargetAdminDelay.selector ||
            selector == this.createRole.selector ||
            selector == this.createTarget.selector
        ) {
            return (true, ADMIN_ROLE, 0);
        }

        // Restricted to ADMIN with the admin delay corresponding to the target
        if (
            selector == this.updateAuthority.selector ||
            selector == this.setTargetClosed.selector ||
            selector == this.setTargetFunctionRole.selector
        ) {
            // First argument is a target.
            address target = abi.decode(data[0x04:0x24], (address));// who is target???
            uint32 delay = getTargetAdminDelay(target);
            return (true, ADMIN_ROLE, delay);
        }

        // Restricted to that role's admin with no delay beside any execution delay the caller may have.
        if (selector == this.grantRole.selector || selector == this.revokeRole.selector) {
            // First argument is a roleId.
            uint64 roleId = abi.decode(data[0x04:0x24], (uint64));
            return (true, getRoleAdmin(roleId), 0);
        }

        return (false, 0, 0);
    }

}