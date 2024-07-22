// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ProxyManager} from "../../contracts/upgradeability/ProxyManager.sol";

contract MockSizeProxyManager is ProxyManager {
    constructor(address registry) {}
}
