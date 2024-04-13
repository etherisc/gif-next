// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Version, VersionLib} from "../../contracts/type/Version.sol";
import {Versionable} from "../../contracts/shared/Versionable.sol";


contract ContractV01 is Versionable {

    // keccak256(abi.encode(uint256(keccak256("gif-next.test_forge.mock.contractV01.sol")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant LOCATION_V1 = 0x6548007c3f4340f82f348c576c0ff69f4f529cadd5ad41f96aae61abceeaa300;

    // @custom:storage-location erc7201:gif-next.test_forge.mock.contractV01.sol
    struct StorageV1 {
        // some initial variables
        uint some;
    }

    function getVersion()
        public
        pure
        virtual override
        returns(Version)
    {
        return VersionLib.toVersion(1, 0, 0);
    }

    function getDataV01() 
        external 
        view 
        returns(bytes memory) 
    {
        return "hi from version 1";
    }

    function _initialize(address owner, bytes memory data)
        internal
        onlyInitializing
        virtual override
    {}

    function _getStorage() private pure returns (StorageV1 storage $) {
        assembly {
            $.slot := LOCATION_V1
        }
    }
}