// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessManagerUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";

import {InitializableERC165} from "../shared/InitializableERC165.sol";
import {RegistryLinked} from "../shared/RegistryLinked.sol";
import {VersionPart, VersionLib} from "../type/Version.sol";


/// @dev An AccessManager based on OpenZeppelin that is cloneable and has a central lock property.
/// The lock property allows to lock all services of a release in a central place.
/// Cloned by upon release preparation and instance cloning.
contract AccessManagerCloneable is
    AccessManagerUpgradeable,
    InitializableERC165,
    RegistryLinked
{
    error ErrorAccessManagerCallerNotAdmin(address caller);
    error ErrorAccessManagerRegistryAlreadySet(address registry);
    error ErrorAccessManagerInvalidRelease(VersionPart release);

    error ErrorAccessManagerTargetAdminLocked(address target);
    error ErrorAccessManagerCallerAdminLocked(address caller);

    VersionPart private _release;
    bool private _isLocked;

    modifier onlyAdminRole() {
        (bool isMember, ) = hasRole(ADMIN_ROLE, msg.sender);
        if(!isMember) {
            revert ErrorAccessManagerCallerNotAdmin(msg.sender);
        }
        _;
    }

    function initialize(address admin)
        external
        initializer()
    {
        __AccessManager_init(admin);
        _initializeERC165();
        _registerInterface(type(IAccessManager).interfaceId);
    }


    /// @dev Completes the setup of the access manager.
    /// Links the access manager to the registry and sets the release version.
    function completeSetup(
        address registry, 
        VersionPart release
    )
        external
        onlyAdminRole
        reinitializer(uint64(release.toInt()))
    {
        _completeSetup(registry, release, true);
    }

    /// @dev Completes the setup of the access manager.
    /// Links the access manager to the registry and sets the release version.
    function completeSetup(
        address registry, 
        VersionPart release,
        bool verifyRelease
    )
        public
        onlyAdminRole
        reinitializer(uint64(release.toInt()))
    {
        _completeSetup(registry, release, verifyRelease);
    }

    /// @dev Returns true if the caller is authorized to call the target with the given selector and the manager lock is not set to locked.
    /// Feturn values as in OpenZeppelin AccessManager.
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
        (immediate, delay) = super.canCall(caller, target, selector);

        // locking of all contracts under control of this access manager
        if (isLocked()) {
            revert ErrorAccessManagerTargetAdminLocked(target);
        }
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
        return _release;
    }


    /// @dev Returns true iff all contracts of this access manager are locked.
    function isLocked()
        public
        view
        returns (bool)
    {
        return _isLocked;
    }


    function _completeSetup(
        address registry,
        VersionPart release,
        bool verifyRelease
    )
        internal
    {
        // checks
        if(address(getRegistry()) != address(0)) {
            revert ErrorAccessManagerRegistryAlreadySet(address(getRegistry()) );
        }

        if (verifyRelease && !release.isValidRelease()) {
            revert ErrorAccessManagerInvalidRelease(release);
        }

        // effects
        __RegistryLinked_init(registry);
        _release = release;
    }
}