// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IOwnable, IRegistryLinked, IRegisterable, IRegistry} from "../../../registry/IRegistry.sol";
import {IInstance} from "../../IInstance.sol";
import {IProductService} from "../../service/IProductService.sol";
import {NftId} from "../../../types/NftId.sol";
import {StateId} from "../../../types/StateId.sol";
import {Timestamp} from "../../../types/Timestamp.sol";
import {Blocknumber} from "../../../types/Blocknumber.sol";

// TODO check if there is value to introuce IContract and let IPolicy derive from IContract
interface IPolicy {
    struct PolicyInfo {
        NftId nftId;
        StateId state; // applied, withdrawn, rejected, active, closed
        // TODO add beneficiary address
        uint256 sumInsuredAmount;
        uint256 premiumAmount;
        uint256 premiumPaidAmount;
        uint256 lifetime;
        Timestamp createdAt;
        Timestamp activatedAt; // time of underwriting
        Timestamp expiredAt; // no new claims (activatedAt + lifetime)
        Timestamp closedAt; // no locked capital
        Blocknumber updatedIn; // write log entries in a way to support backtracking of all state changes
    }
}

interface IPolicyModule is IOwnable, IRegistryLinked, IPolicy {
    function createApplication(
        IRegistry.ObjectInfo memory productInfo,
        address initialOwner,
        uint256 sumInsuredAmount,
        uint256 premiumAmount,
        uint256 lifetime,
        NftId bundleNftId
    ) external returns (NftId nftId);

    function processPremium(NftId nftId, uint256 amount) external;

    function activate(NftId nftId) external;

    function getBundleNftForPolicy(
        NftId nftId
    ) external view returns (NftId bundleNft);

    function getPolicyInfo(
        NftId nftId
    ) external view returns (PolicyInfo memory info);

    function getPremiumAmount(NftId nftId) external view returns(uint256 premiumAmount);
}
