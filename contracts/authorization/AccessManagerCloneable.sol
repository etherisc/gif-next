// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessManagerUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";

import {InitializableERC165} from "../shared/InitializableERC165.sol";
import {RegistryLinked} from "../shared/RegistryLinked.sol";
import {VersionPart} from "../type/Version.sol";


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
        public
        initializer()
    {
        __ERC165_init();
        __AccessManager_init(admin);

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
        _checkAndSetRegistry(registry);
        _checkAndSetRelease(release);
    }

    // /// @dev Completes the setup of the access manager.
    // /// Links the access manager to the registry and sets the release version.
    // function completeSetup(
    //     address registry, 
    //     VersionPart release,
    //     bool verifyRelease
    // )
    //     public
    //     onlyAdminRole
    //     reinitializer(uint64(release.toInt()))
    // {
    //     _checkAndSetRegistry(registry);

    //     if (verifyRelease) {
    //         _checkAndSetRelease(release);
    //     }
    // }

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


    function _checkAndSetRelease(VersionPart release)
        internal
    {
        if (!release.isValidRelease()) {
            revert ErrorAccessManagerInvalidRelease(release);
        }

        _release = release;
    }


    function _checkAndSetRegistry(address registry)
        internal
    {
        // checks
        if(address(getRegistry()) != address(0)) {
            revert ErrorAccessManagerRegistryAlreadySet(address(getRegistry()) );
        }

        // effects
        __RegistryLinked_init(registry);
    }
}