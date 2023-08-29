// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IComponentContract} from "../instance/component/IComponent.sol";
import {NftId} from "../types/NftId.sol";

interface IProductComponent is
    IComponentContract
{

    function getPoolNftId() external view returns(NftId poolNftId);
}