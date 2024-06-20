// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {KeyValueStore} from "../../contracts/shared/KeyValueStore.sol";

contract MockSizeKeyValueStore is KeyValueStore {
        function _setupLifecycle() internal override {}
}
