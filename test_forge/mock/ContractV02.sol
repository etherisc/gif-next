// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Version, VersionLib} from "../../contracts/types/Version.sol";
import {ContractV01} from "./ContractV01.sol";

contract ContractV02 is ContractV01 {

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

    // IMPORTANT this function needs to be implemented by each new version
    // and needs to call internal function call _activate() 
    function activate(address implementation, address activatedBy)
        external 
        virtual override
    { 
        // ensure proper version history
        _activate(implementation, activatedBy);
    }

    function getDataV02() external view returns(bytes memory) {
        return "hi from version 2";
    }
}