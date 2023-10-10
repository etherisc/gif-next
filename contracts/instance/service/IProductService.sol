// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRisk} from "../module/risk/IRisk.sol";
import {IService} from "../base/IService.sol";

import {NftId} from "../../types/NftId.sol";
import {RiskId} from "../../types/RiskId.sol";
import {StateId} from "../../types/StateId.sol";
import {Timestamp} from "../../types/Timestamp.sol";
import {UFixed} from "../../types/UFixed.sol";
import {Fee} from "../../types/Fee.sol";

interface IProductService is IService {
    function setFees(
        Fee memory policyFee,
        Fee memory processingFee
    ) external;

    function createRisk(
        RiskId riskId,
        bytes memory data
    ) external;

    function setRiskInfo(
        RiskId riskId,
        IRisk.RiskInfo memory data
    ) external;

    function updateRiskState(
        RiskId riskId,
        StateId state
    ) external;

    function createApplication(
        address applicationOwner,
        RiskId riskId,
        uint256 sumInsuredAmount,
        uint256 premiumAmount,
        uint256 lifetime,
        NftId bundleNftId
    ) external returns (NftId nftId);

    // function revoke(unit256 nftId) external;

    /**
     * @dev underwrites the policy represented by {policyNftId}.
     * optionally collects premiums and activates the policy.
     * - premium payment is only attempted if requirePremiumPayment is set to true
     * - activation is only done if activateAt is a non-zero timestamp
     */
    function underwrite(
        NftId policyNftId,
        bool requirePremiumPayment,
        Timestamp activateAt
    ) external;

    // function decline(uint256 nftId) external;
    // function expire(uint256 nftId) external;

    function collectPremium(NftId nftId, Timestamp activateAt) external;

    function activate(NftId nftId, Timestamp activateAt) external;


    function close(NftId nftId) external;

    // function createClaim(uint256 nftId, uint256 claimAmount) external;
    // function confirmClaim(uint256 nftId, uint256 claimId, uint256 claimAmount) external;
    // function declineClaim(uint256 nftId, uint256 claimId) external;
    // function closeClaim(uint256 nftId, uint256 claimId) external;

    function calculateRequiredCollateral(
        UFixed collateralizationLevel, 
        uint256 sumInsuredAmount
    ) external pure returns(uint256 collateralAmount);

}
