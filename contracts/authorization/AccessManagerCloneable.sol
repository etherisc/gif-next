// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {AccessManagerUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";

import {VersionPart} from "../type/Version.sol";

import {RegistryLinked} from "../shared/RegistryLinked.sol";

import {IRegistry} from "../registry/IRegistry.sol";

// cloned by upon release preparation and instance cloning
contract AccessManagerCloneable is
    AccessManagerUpgradeable,
    RegistryLinked
{
    error ErrorAccessManagerCallerNotAdmin(address caller);
    error ErrorAccessManagerRegistryAlreadySet(address registry);
    error ErrorAccessManagedCallerAdminLocked(address caller);
    error ErrorAccessManagedTargetAdminLocked(address target);

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
    }

    function completeSetup(address registry, VersionPart version)
        public
        onlyAdminRole
        reinitializer(uint64(version.toInt()))
    {
        address setRegistry = address(getRegistry());

        if(setRegistry != address(0)) {
            revert ErrorAccessManagerRegistryAlreadySet(setRegistry);
        }
        _initializeRegistryLinked(registry);
    }

    function canCall(
        address caller,
        address target,
        bytes4 selector
    ) public view virtual override returns (bool immediate, uint32 delay) 
    {
        IRegistry registry = getRegistry();

        // TODO limitation: in order to be checked for a lock caller must be registered
        if(registry.isRegistered(caller)) { // caller is access managed

            // TODO getAdmin() returns 0 if registered caller is managed by registry / instance access managers
            //      register must be aware of registry and instance admins too?
            //AccessManagerCloneable callerAm = AccessManagerCloneable(getRegistry().getAdmin(caller).authority());
            AccessManagerCloneable callerAm = AccessManagerCloneable(IAccessManaged(caller).authority());

            if(callerAm.isLocked()) {
                revert ErrorAccessManagedCallerAdminLocked(caller);
                // ErrorReleaseAccessManagedReleaseLockViolated(caller, version);
                // MUST be impossible to get here if caller contract is properlly engineered
                // otherwise caller violates lock
            }
        }

        if(isLocked()) {
            revert ErrorAccessManagedTargetAdminLocked(target);
        }

        (immediate, delay) = super.canCall(caller, target, selector);
    }

    function setLocked(bool locked)
        external
        onlyAdminRole() 
    {
        _isLocked = locked;
    }

    function isLocked()
        public
        view
        returns (bool)
    {
        return _isLocked;
    }
}