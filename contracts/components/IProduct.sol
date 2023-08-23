// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IComponentContract} from "../instance/component/IComponent.sol";

interface IProduct is
    IComponentContract
{

    function getPoolNftId() external view returns(uint256 poolNftId);
}