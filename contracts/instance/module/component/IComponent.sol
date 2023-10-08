// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";


import {IRegistry} from "../../../registry/IRegistry.sol";
import {IInstance} from "../../IInstance.sol";
import {StateId} from "../../../types/StateId.sol";
import {Key32} from "../../../types/Key32.sol";
import {NftId} from "../../../types/NftId.sol";
import {ObjectType} from "../../../types/ObjectType.sol";
import {RoleId} from "../../../types/RoleId.sol";
import {Fee} from "../../../types/Fee.sol";
import {UFixed} from "../../../types/UFixed.sol";

import {IKeyValueStore} from "../../base/IKeyValueStore.sol";
import {IComponentOwnerService} from "../../service/IComponentOwnerService.sol";

interface IComponent {
    struct ComponentInfo {
        IERC20Metadata token;
    }
}

interface IComponentModule is IComponent {

    function registerComponent(
        NftId nftId,
        IERC20Metadata token
    ) external;

    function getComponentToken(
        NftId nftId
    ) external view returns (IERC20Metadata token);

    function getComponentCount() external view returns (uint256 numberOfCompnents);

    function getComponentId(uint256 idx) external view returns (NftId nftId);

    // repeat registry linked signature
    function getRegistry() external view returns (IRegistry registry);

    // repeat instance base signature
    function getKeyValueStore() external view returns (IKeyValueStore keyValueStore);

    // repeat service linked signaturea to avoid linearization issues
    function getComponentOwnerService() external view returns(IComponentOwnerService);
}
