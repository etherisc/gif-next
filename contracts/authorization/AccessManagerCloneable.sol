// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessManagerUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";

import {RegistryLinked} from "../shared/RegistryLinked.sol";
import {VersionPart} from "../type/Version.sol";


/// @dev An AccessManager based on OpenZeppelin that is cloneable and has a central lock property.
/// The lock property allows to lock all services of a release in a central place.
/// Cloned by upon release preparation and instance cloning.
contract AccessManagerCloneable is
    AccessManagerUpgradeable,
    RegistryLinked
{
    error ErrorAccessManagerCallerNotAdmin(address caller);
    error ErrorAccessManagerRegistryAlreadySet(address registry);
    error ErrorAccessManagerTargetAdminLocked(address target);

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


    function completeSetup(
        address registry, 
        VersionPart release
    )
        public
        onlyAdminRole
        reinitializer(uint64(release.toInt()))
    {
        if(address(getRegistry()) != address(0)) {
            revert ErrorAccessManagerRegistryAlreadySet(address(getRegistry()) );
        }

        _initializeRegistryLinked(registry);
    }

    function canCall(
        address caller,
        address target,
        bytes4 selector
    ) public view virtual override returns (bool immediate, uint32 delay) 
    {
        (immediate, delay) = super.canCall(caller, target, selector);

        if(isLocked()) {
            revert ErrorAccessManagerTargetAdminLocked(target);
        }
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