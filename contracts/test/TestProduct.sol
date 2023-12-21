// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Product} from "../../contracts/components/Product.sol";
import {NftId, toNftId} from "../../contracts/types/NftId.sol";
import {ReferralId} from "../types/ReferralId.sol";
import {RiskId} from "../../contracts/types/RiskId.sol";
import {Timestamp, blockTimestamp} from "../../contracts/types/Timestamp.sol";
import {Fee} from "../../contracts/types/Fee.sol";

contract TestProduct is Product {

    event LogTestProductSender(address sender);

    string public constant DEFAULT_RISK_NAME = "DEFAULT_RISK";
    bool private defaultRiskCreated;

    constructor(
        address registry,
        NftId instanceNftid,
        address token,
        bool isInterceptor,
        address pool,
        address distribution,
        Fee memory productFee,
        Fee memory processingFee,
        address initialOwner
    )
        Product(registry, instanceNftid, token, isInterceptor, pool, distribution, productFee, processingFee, initialOwner)
    // solhint-disable-next-line no-empty-blocks
    {
    }

    function getDefaultRiskId() public pure returns (RiskId) {
        return _toRiskId(DEFAULT_RISK_NAME);
    }

    function applyForPolicy(
        uint256 sumInsuredAmount,
        uint256 lifetime,
        NftId bundleNftId,
        ReferralId referralId
    )
        external
        returns(NftId nftId)
    {
        RiskId riskId = getDefaultRiskId();
        bytes memory applicationData = "";

        if (!defaultRiskCreated) {
            _createRisk(riskId, "");
            defaultRiskCreated = true;
        }

        nftId = _createApplication(
            msg.sender, // policy holder
            riskId,
            sumInsuredAmount,
            lifetime,
            applicationData,
            bundleNftId,
            referralId
        );
    }

    function underwrite(NftId nftId, bool requirePremiumPayment, Timestamp activateAt) external {
        emit LogTestProductSender(msg.sender);
        _underwrite(nftId, requirePremiumPayment, activateAt);
    }

    function collectPremium(NftId nftId, Timestamp activateAt) external {
        _collectPremium(nftId, activateAt);
    }
}