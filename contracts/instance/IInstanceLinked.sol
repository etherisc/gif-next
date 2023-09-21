// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IInstance} from "./IInstance.sol";

interface IInstanceLinked {
    function getInstance() external view returns (IInstance instance);
}
