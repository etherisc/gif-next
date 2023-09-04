// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IOwnable, IRegistryLinked, IRegisterable, IRegistry} from "../../registry/IRegistry.sol";
import {IInstance} from "../IInstance.sol";
import {IProductService} from "../product/IProductService.sol";
import {NftId} from "../../types/NftId.sol";

// TODO check if there is value to introuce IContract and let IPolicy derive from IContract
interface IPolicy {
    enum PolicyState {
        Undefined,
        Applied,
        Rejected,
        Active,
        Closed
    }

    struct PolicyInfo {
        NftId nftId;
        PolicyState state; // applied, withdrawn, rejected, active, closed
        uint256 sumInsuredAmount;
        uint256 premiumAmount;
        uint256 lifetime; // activatedAt + lifetime >= expiredAt
        uint256 createdAt;
        uint256 activatedAt; // time of underwriting
        uint256 expiredAt; // no new claims
        uint256 closedAt; // no locked capital
    }
}

interface IPolicyModule is IOwnable, IRegistryLinked, IPolicy {
    function createApplication(
        IRegistry.RegistryInfo memory productInfo,
        address applicationOwner,
        uint256 sumInsuredAmount,
        uint256 premiumAmount,
        uint256 lifetime,
        NftId bundleNftId
    ) external returns (NftId nftId);

    function activate(NftId nftId) external;

    function getBundleNftForPolicy(
        NftId nftId
    ) external view returns (NftId bundleNft);

    function getPolicyInfo(
        NftId nftId
    ) external view returns (PolicyInfo memory info);
}
