// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId} from "../../contracts/types/NftId.sol";
import {InstanceBase} from "../../contracts/instance/InstanceBase.sol";

contract TestInstanceBase  is
    InstanceBase
{
    constructor(
        address registry,
        NftId registryNftId
    )
        InstanceBase(registry, registryNftId)
    {
    }

    function senderIsComponentOwnerService() external view override returns(bool isService) { return msg.sender == address(_componentOwnerService); }
    function senderIsProductService() external view override returns(bool isService) { return msg.sender == address(_productService); }
    function senderIsPoolService() external view override returns(bool isService) { return msg.sender == address(_poolService); }
}
