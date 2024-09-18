// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {IUpgradeable} from "./IUpgradeable.sol";
import {Version} from "../type/Version.sol";
import {Versionable} from "../shared/Versionable.sol";

abstract contract Upgradeable is
    Initializable, 
    Versionable,
    IUpgradeable 
{
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address activatedBy,
        bytes memory data
    )
        external
    {
        if(_getInitializedVersion() != 0) {
            revert InvalidInitialization();
        }
        __Upgradeable_init(activatedBy, data);
    }

    function upgrade(
        bytes memory data
    )
        external
        reinitializer(getVersion().toInt())
    {
        _upgrade(data);
    }

    // IMPORTANT each version must implement this function 
    // each implementation MUST use onlyInitialising modifier
    // each implementation MUST call intializers of all base contracts...
    function _initialize(
        address, // owner
        bytes memory // data
    ) 
        internal
        onlyInitializing()
        virtual 
    {
        revert ErrorVersionableInitializeNotImplemented();
    }

    // IMPORTANT each version except version "1" must implement this function 
    // each implementation MUST use onlyInitialising modifier
    function _upgrade(bytes memory data)
        internal
        onlyInitializing
        virtual
    {
        revert ErrorVersionableUpgradeNotImplemented();
    }

    function __Upgradeable_init(
        address activatedBy,
        bytes memory data
    )
        private
        reinitializer(getVersion().toInt())
    {
        _initialize(activatedBy, data);
    }
}