// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (access/manager/AccessManager.sol)

pragma solidity ^0.8.20;

import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";

import {VersionPart} from "../type/Version.sol";

import {IAccessManagerExtendedWithDisable} from "./IAccessManagerExtendedWithDisable.sol";
import {AccessManagerExtended} from "./AccessManagerExtended.sol";
import {AccessManagerCustom} from "./AccessManagerCustom.sol";


contract AccessManagerExtendedWithDisable is AccessManagerExtended, IAccessManagerExtendedWithDisable {

    /// @custom:storage-location erc7201:etherisc.storage.ReleaseAccessManager
    struct AccessManagerExtendedWithDisableStorage {
        VersionPart _version;
        bool _disabled; // disable restricted functions for all targets
    }

    // keccak256(abi.encode(uint256(keccak256("etherisc.storage.AccessManagerExtendedWithDisable")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant AccessManagerExtendedWithDisableStorageLocation = 0x6eab09faeebddf4f4430139353ec193aaa0bd7382b47d6e52082f5add274e600;

    function _getAccessManagerExtendedWithDisableStorage() private pure returns (AccessManagerExtendedWithDisableStorage storage $) {
        assembly {
            $.slot := AccessManagerExtendedWithDisableStorageLocation
        }
    }

    // TODO add version
    function __AccessManagerExtendedWithDisable_init(address initialAdmin, VersionPart version) internal onlyInitializing {
        AccessManagerExtendedWithDisableStorage storage $ = _getAccessManagerExtendedWithDisableStorage();
        $._version = version;
        
        __AccessManagerExtended_init(initialAdmin);
    }

    // =================================================== GETTERS ====================================================
    // TODO should functions with onlyAuthorized revert too if disabled???
    function canCall(
        address caller,
        address target,
        bytes4 selector
    )
        public view 
        virtual override (AccessManagerCustom, IAccessManager)
        returns (bool immediate, uint32 delay) {
        AccessManagerExtendedWithDisableStorage storage $ = _getAccessManagerExtendedWithDisableStorage();
        if($._disabled) {
            revert AccessManagerDisabled();
        }
        return super.canCall(caller, target, selector);
    }

    function getVersion() public view returns (VersionPart) {
        AccessManagerExtendedWithDisableStorage storage $ = _getAccessManagerExtendedWithDisableStorage();
        return $._version;
    }

    // ===================================== ACCESS MANAGER MODE MANAGEMENT ============================================

    // TODO GIF_MANAGER_ROLE -> releaseManager.disableRelease() -> releaseAccessManager.disable() -> wrong
    // GIF_MANAGER_ROLE -> releaseManager.disableRelease() - will retire release with delay, after expiration will also disable it forever?
    // GIF_MANAGER_ROLE -> releaseAccessManager.disable() - emergency shutdown, upgrades, etc. will disable temporary right away whithout any delay
    /// inheritdoc IAccessManagerExtended
    function disable() external onlyAuthorized {
        AccessManagerExtendedWithDisableStorage storage $ = _getAccessManagerExtendedWithDisableStorage();
        $._disabled = true;
    }
    /// inheritdoc IAccessManagerExtended
    function enable() external onlyAuthorized {
        AccessManagerExtendedWithDisableStorage storage $ = _getAccessManagerExtendedWithDisableStorage();
        $._disabled = false;
    }


    // ========================= INTERNAL ==============================
    function _getAdminRestrictions(
        bytes calldata data
    ) internal virtual override view returns (bool restricted, uint64 roleAdminId, uint32 executionDelay) {
        if (data.length < 4) {
            return (false, 0, 0);
        }

        bytes4 selector = _checkSelector(data);

        // Restricted to ADMIN with no delay beside any execution delay the caller may have
        if (
            selector == this.createRole.selector ||
            selector == this.labelRole.selector ||
            selector == this.setRoleAdmin.selector ||
            selector == this.setRoleGuardian.selector ||
            selector == this.setGrantDelay.selector ||
            selector == this.createTarget.selector ||
            selector == this.setTargetAdminDelay.selector ||
            selector == this.enable.selector || 
            selector == this.disable.selector
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