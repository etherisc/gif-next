// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {IVersionable} from "./IVersionable.sol";
import {Version, VersionLib} from "../type/Version.sol";


abstract contract Versionable is 
    Initializable,
    IVersionable 
{
    constructor() {
        _disableInitializers();
    }

    function initializeVersionable(
        address activatedBy,
        bytes memory data
    )
        public
        initializer()
    {
        _initialize(activatedBy, data);
    }

    function upgradeVersionable(
        bytes memory data
    )
        external
        reinitializer(VersionLib.toUint64(getVersion()))
    {
        _upgrade(data);
    }

    function getVersion() public pure virtual returns(Version);

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
        revert();
    }

    // IMPORTANT each version except version "1" must implement this function 
    // each implementation MUST use onlyInitialising modifier
    function _upgrade(bytes memory data)
        internal
        onlyInitializing
        virtual
    {
        revert();
    }
}