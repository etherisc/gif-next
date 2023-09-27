// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../../../registry/IRegistry.sol";
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
        NftId productNftId;
        NftId bundleNftId;
        address beneficiary;
        StateId state; // applied, withdrawn, rejected, active, closed
        uint256 sumInsuredAmount;
        uint256 premiumAmount;
        uint256 premiumPaidAmount;
        uint256 lifetime;
        bytes data;
        Timestamp createdAt;
        Timestamp activatedAt; // time of underwriting
        Timestamp expiredAt; // no new claims (activatedAt + lifetime)
        Timestamp closedAt; // no locked capital
        Blocknumber updatedIn; // write log entries in a way to support backtracking of all state changes
    }
}

interface IPolicyModule is IPolicy {
    function createApplication(
        NftId productNftId,
        NftId policyNftId,
        uint256 sumInsuredAmount,
        uint256 premiumAmount,
        uint256 lifetime,
        NftId bundleNftId
    ) external;

    function setPolicyInfo(PolicyInfo memory policyInfo) external;

    // function underwrite(NftId nftId) external;

    // function processPremium(NftId nftId, uint256 amount) external;

    // function activate(NftId nftId, Timestamp activateAt) external;

    function getPolicyInfo(
        NftId nftId
    ) external view returns (PolicyInfo memory info);

    // repeat registry linked signature
    function getRegistry() external view returns (IRegistry registry);

    // repeat service linked signature to avoid linearization issues
    function getProductService() external  returns(IProductService);
}
