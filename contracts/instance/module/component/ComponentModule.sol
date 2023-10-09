// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IKeyValueStore} from "../../base/IKeyValueStore.sol";
import {IComponentModule} from "./IComponent.sol";

import {NftId} from "../../../types/NftId.sol";
import {ObjectType, COMPONENT} from "../../../types/ObjectType.sol";
import {StateId} from "../../../types/StateId.sol";
import {ModuleBase} from "../../base/ModuleBase.sol";

abstract contract ComponentModule is 
    ModuleBase,
    IComponentModule
{

    NftId[] private _nftIds;

    modifier onlyComponentOwnerService() {
        require(
            msg.sender == address(this.getComponentOwnerService()),
            "ERROR:CMP-001:NOT_OWNER_SERVICE"
        );
        _;
    }

    function initializeComponentModule(IKeyValueStore keyValueStore) internal {
        _initialize(keyValueStore);
    }

    function registerComponent(
        NftId nftId,
        IERC20Metadata token
    )
        external
        onlyComponentOwnerService
        override
    {
        ComponentInfo memory info = ComponentInfo(token);
        _nftIds.push(nftId);
        _create(COMPONENT(), nftId, abi.encode(info));
    }

    function getComponentState(
        NftId nftId
    ) 
        external 
        view 
        override
        returns (StateId state)
    {
        return _getState(COMPONENT(), nftId);
    }

    function getComponentToken(NftId nftId) external view override returns(IERC20Metadata token) {
        ComponentInfo memory info = abi.decode(_getData(COMPONENT(), nftId), (ComponentInfo));
        return info.token;
    }

    function getComponentCount()
        external
        view
        override
        returns (uint256 numberOfCompnents)
    {
        return _nftIds.length;
    }

    function getComponentId(
        uint256 idx
    ) external view override returns (NftId componentNftId) {
        return _nftIds[idx];
    }
}