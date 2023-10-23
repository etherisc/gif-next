// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Version, VersionLib} from "../../contracts/types/Version.sol";
import {ContractV01} from "./ContractV01.sol";

contract ContractV02 is ContractV01 {

    // IMPORTANT this function needs to be implemented by each new version
    // and needs to call internal function call _activate() 
    function initialize(address implementation, address activatedBy, bytes memory activationData)
        public
        virtual override
        initializer
    {
        _activate(implementation, activatedBy);

        initializeV02(activationData);
    }

    // IMPORTANT this function needs to be implemented by each new version
    // and needs to call internal function call _activate() 
    function upgrade(address implementation, address activatedBy, bytes memory upgradeData)
        public
        virtual override
        reinitializer(getVersion().toUint64())
    {
        initializeV2FromV1(upgradeData);
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
        return VersionLib.toVersion(1, 0, 1);
    }

    function getDataV02() external view returns(bytes memory) {
        return "hi from version 2";
    }

    function initializeV02(bytes memory data)
        internal
        onlyInitializing
    {
        initializeV01(data);

        initializeV2FromV1(data);
    }
    function initializeV2FromV1(bytes memory data)
        private
        onlyInitializing
    {

    }
}