// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Product} from "../../contracts/components/Product.sol";
import {NftId, toNftId} from "../../contracts/types/NftId.sol";
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
        address pool,
        Fee memory policyFee,
        Fee memory processingFee
    )
        Product(registry, instanceNftid, token, pool, policyFee, processingFee)
    // solhint-disable-next-line no-empty-blocks
    {
    }

    function getDefaultRiskId() public pure returns (RiskId) {
        return _toRiskId(DEFAULT_RISK_NAME);
    }

    function applyForPolicy(
        uint256 sumInsuredAmount,
        uint256 premiumAmount,
        uint256 lifetime,
        NftId bundleNftId
    )
        external
        returns(NftId nftId)
    {
        if (!defaultRiskCreated) {
            _createRisk(getDefaultRiskId() , "");
            defaultRiskCreated = true;
        }

        nftId = _createApplication(
            msg.sender, // policy holder
            getDefaultRiskId(),
            sumInsuredAmount,
            premiumAmount,
            lifetime,
            bundleNftId
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