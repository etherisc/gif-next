// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessManagerCloneable} from "../authorization/AccessManagerCloneable.sol";


contract ReleaseAccessManagerCloneable is
    AccessManagerCloneable
{
    error ErrorReleaseAccessManagerCallerNotAdmin(address caller);

    bool private _releaseIsLocked;

    modifier onlyAdminRole() {
        (bool isMember, ) = hasRole(ADMIN_ROLE, msg.sender);
        if(!isMember) {
            revert ErrorReleaseAccessManagerCallerNotAdmin(msg.sender);
        }
        _;
    }

    function setReleaseLocked(bool locked)
        external
        onlyAdminRole() 
    {
        _releaseIsLocked = locked;
    }

    function isReleaseLocked()
        external
        view
        returns (bool isLocked)
    {
        return _releaseIsLocked;
    }

    function isTargetClosed(address target)
        public 
        virtual override 
        view 
        returns (bool)
    {
        if (_releaseIsLocked) {
            return true;
        }

        return super.isTargetClosed(target);
    }
}