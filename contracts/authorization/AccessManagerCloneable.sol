// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessManagerUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";

import {IAccessAdmin} from "./IAccessAdmin.sol";
import {InitializableERC165} from "../shared/InitializableERC165.sol";
import {VersionPartLib, VersionPart} from "../type/Version.sol";


/// @dev An AccessManager based on OpenZeppelin that is cloneable and has a central lock property.
/// The lock property allows to lock all services of a release in a central place.
/// Cloned by upon release preparation and instance cloning.
contract AccessManagerCloneable is
    AccessManagerUpgradeable,
    InitializableERC165
{
    error ErrorAccessManagerCallerNotAdmin(address caller);
    error ErrorAccessManagerRegistryAlreadySet(address registry);
    error ErrorAccessManagerInvalidRelease(VersionPart release);

    error ErrorAccessManagerTargetAdminLocked(address target);
    error ErrorAccessManagerCallerAdminLocked(address caller);

    bool private _isLocked;


    modifier onlyAdminRole() {
        (bool isMember, ) = hasRole(ADMIN_ROLE, msg.sender);
        if(!isMember) {
            revert ErrorAccessManagerCallerNotAdmin(msg.sender);
        }
        _;
    }

    function initialize(address adminAddress, VersionPart release)
        public

    {
        if(_getInitializedVersion() != 0) {
            revert InvalidInitialization();
        }

        AccessManagerCloneable_init(adminAddress, release);
    }

    function AccessManagerCloneable_init(
        address admin,
        VersionPart release
    )
        internal
        reinitializer(release.toInt())
    {
        if (!release.isValidRelease()) {
            revert ErrorAccessManagerInvalidRelease(release);
        }

        __ERC165_init();
        __AccessManager_init(admin);

        _registerInterface(type(IAccessManager).interfaceId);
    }

    /// @dev Returns true if the caller is authorized to call the target with the given selector and the manager lock is not set to locked.
    /// Return values as in OpenZeppelin AccessManager.
    /// For a locked manager the function reverts with ErrorAccessManagerTargetAdminLocked.
    function canCall(
        address caller,
        address target,
        bytes4 selector
    )
        public 
        view 
        virtual override 
        returns (
            bool immediate, 
            uint32 delay
        ) 
    {
        // locking of all contracts under control of this access manager
        if (_isLocked) {
            revert ErrorAccessManagerTargetAdminLocked(target);
        }

        (immediate, delay) = super.canCall(caller, target, selector);
    }


    /// @dev Locks/unlocks all services of this access manager.
    /// Only the corresponding access admin can lock/unlock the services.
    function setLocked(bool locked)
        external
        onlyAdminRole() 
    {
        _isLocked = locked;
    }


    /// @dev Returns the release version of this access manager.
    /// For the registry admin release 3 is returned.
    /// For the release admin and the instance admin the actual release version is returned.
    function getRelease() external view returns (VersionPart release) {
        return VersionPartLib.toVersionPart(
            uint8(_getInitializedVersion()));
    }

    /// @dev Returns true iff all contracts of this access manager are locked.
    function isLocked()
        public
        view
        returns (bool)
    {
        return _isLocked;
    }
}