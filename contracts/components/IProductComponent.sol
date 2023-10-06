// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId} from "../types/NftId.sol";
import {Fee} from "../types/Fee.sol";
import {IBaseComponent} from "./IBaseComponent.sol";
import {IComponent} from "../instance/module/component/IComponent.sol";
import {IRegistry} from "../registry/IRegistry.sol";

interface IProductComponent is IBaseComponent {
    function setFees(
        Fee memory policyFee,
        Fee memory processingFee
    ) external;

    function getPoolNftId() external view returns (NftId poolNftId);
    
    function getPolicyFee() external view returns (Fee memory policyFee);

    function getProcessingFee() external view returns (Fee memory processingFee);

    function getProductInfo() external view returns (IRegistry.ObjectInfo memory, IComponent.ProductComponentInfo memory);

    function getInitialProductInfo() external view returns (IRegistry.ObjectInfo memory, IComponent.ProductComponentInfo memory);
}
