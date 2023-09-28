// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Product} from "../../contracts/components/Product.sol";
import {NftId, toNftId} from "../../contracts/types/NftId.sol";
import {Timestamp, blockTimestamp} from "../../contracts/types/Timestamp.sol";
import {Fee} from "../../contracts/types/Fee.sol";

contract TestProduct is Product {

    event LogTestProductSender(address sender);

    constructor(address registry, NftId instanceNftid, address token, address pool)
        Product(registry, instanceNftid, token, pool)
    // solhint-disable-next-line no-empty-blocks
    {}

    function applyForPolicy(
        uint256 sumInsuredAmount,
        uint256 premiumAmount,
        uint256 lifetime,
        NftId bundleNftId
    )
        external
        returns(NftId nftId)
    {
        nftId = _createApplication(
            msg.sender, // policy holder
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