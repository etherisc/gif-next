// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Version, VersionLib} from "../../contracts/types/Version.sol";
import {ContractV01} from "./ContractV01.sol";

contract ContractV02 is ContractV01 {

    struct StorageV2 {
        // copy paste StorageV1
        uint something;
        // add changes
        bool isDifferent;
    }

    function _getStorageV2() private pure returns (StorageV2 storage $) {
        assembly {
            $.slot := locationV1
        }
    }

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

    function _initialize(bytes memory data)
        internal
        virtual override
        onlyInitializing
    {
        // copy paste V1
        // add changes 
    }
    function _upgrade(bytes memory data)
        internal
        virtual override
        onlyInitializing
    {
        // add changes
    }
}