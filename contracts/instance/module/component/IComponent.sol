// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IComponentOwnerService} from "../../service/IComponentOwnerService.sol";

import {StateId} from "../../../types/StateId.sol";
import {NftId} from "../../../types/NftId.sol";

interface IComponent {
    struct ComponentInfo {
        IERC20Metadata token;
    }
}

interface IComponentModule is IComponent {

    function registerComponent(NftId nftId, IERC20Metadata token) external;
    function getComponentState(NftId nftId) external view returns (StateId state);
    function getComponentToken(NftId nftId) external view returns (IERC20Metadata token);

    function getComponentCount() external view returns (uint256 numberOfCompnents);
    function getComponentId(uint256 idx) external view returns (NftId nftId);

    // repeat service linked signaturea to avoid linearization issues
    function getComponentOwnerService() external view returns(IComponentOwnerService);
}
