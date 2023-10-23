// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Version, VersionLib} from "../../contracts/types/Version.sol";
import {VersionableUpgradeable} from "../../contracts/shared/VersionableUpgradeable.sol";


contract ContractV01 is VersionableUpgradeable {

    // IMPORTANT this function needs to be implemented by each new version
    // and needs to call internal function call _activate() 
    function initialize(address implementation, address activatedBy, bytes memory activationData)
        public
        virtual override
        initializer
    {
        _activate(implementation, activatedBy);
        //initializeV01(data);
    }

    // IMPORTANT this function needs to be implemented by each new version
    // and needs to call internal function call _activate() 
    function upgrade(address implementation, address activatedBy, bytes memory upgradeData)
        public
        virtual
    {
        revert();
    }

    // IMPORTANT 1. version needed for upgradable versions
    // _activate is using this to check if this is a new version
    // and if this version is higher than the last activated version
    function getVersion()
        public
        pure
        virtual override
        returns(Version)
    {
        return VersionLib.toVersion(1, 0, 0);
    }


    function getDataV01() external view returns(bytes memory) {
        return "hi from version 1";
    }

    function initializeV01(bytes memory data)
        internal
        onlyInitializing
    {}
}