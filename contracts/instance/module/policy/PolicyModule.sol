// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../../../registry/IRegistry.sol";

import {IProductService} from "../../service/IProductService.sol";
import {IPolicy, IPolicyModule} from "./IPolicy.sol";
import {ObjectType, POLICY} from "../../../types/ObjectType.sol";
import {NftId, NftIdLib} from "../../../types/NftId.sol";
import {RiskId} from "../../../types/RiskId.sol";
import {StateId} from "../../../types/StateId.sol";
import {Timestamp, blockTimestamp, zeroTimestamp} from "../../../types/Timestamp.sol";

import {IKeyValueStore} from "../../base/IKeyValueStore.sol";
import {ModuleBase} from "../../base/ModuleBase.sol";

abstract contract PolicyModule is
    ModuleBase,
    IPolicyModule
{

    // TODO find a better place to avoid dupliation
    modifier onlyProductService2() {
        require(
            msg.sender == address(this.getProductService()),
            "ERROR:POL-001:NOT_PRODUCT_SERVICE"
        );
        _;
    }

    function initializePolicyModule(IKeyValueStore keyValueStore) internal {
        _initialize(keyValueStore);
    }

    function createPolicyInfo(
        NftId policyNftId,
        NftId productNftId,
        RiskId riskId,
        uint256 sumInsuredAmount,
        uint256 premiumAmount,
        uint256 lifetime,
        NftId bundleNftId
    )
        external
        onlyProductService2
        override
    {
        PolicyInfo memory info = PolicyInfo(
            productNftId,
            bundleNftId,
            address(0), // beneficiary = policy nft holder
            riskId,
            sumInsuredAmount,
            premiumAmount,
            0, // premium paid amount
            lifetime, 
            "", // applicationData
            "", // policyData
            zeroTimestamp(), // activatedAt
            zeroTimestamp(), // expiredAt
            zeroTimestamp() // closedAt
        );

        _create(POLICY(), policyNftId, abi.encode(info));
    }

    function setPolicyInfo(NftId policyNftId, PolicyInfo memory info)
        external
        override
        onlyProductService2
    {
        _updateData(POLICY(), policyNftId, abi.encode(info));
    }

    function updatePolicyState(NftId bundleNftId, StateId state)
        external
        override
        onlyProductService2
    {
        _updateState(POLICY(), bundleNftId, state);
    }

    function getPolicyInfo(
        NftId nftId
    ) external view returns (PolicyInfo memory info) {
        return abi.decode(_getData(POLICY(), nftId), (PolicyInfo));
    }

    function getPolicyState(NftId nftId) external view override returns(StateId state) {
        return _getState(POLICY(), nftId);
    }
}
