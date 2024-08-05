// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";

abstract contract ReleaseAccessManager is
    AccessManager
{
    bool private _releaseIsLocked;

    function setReleaseLocked(bool locked)
        external
        onlyAuthorized() 
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