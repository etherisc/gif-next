// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Product} from "../../contracts/components/Product.sol";
import {NftId, toNftId} from "../../contracts/types/NftId.sol";
import {Fee, zeroFee} from "../../contracts/types/Fee.sol";

contract TestProduct is Product {

    constructor(address registry, address instance, address token, address pool, Fee memory policyFee)
        Product(registry, instance, token, pool, policyFee, zeroFee())
    {}

    function applyForPolicy(
        uint256 sumInsuredAmount,
        uint256 premiumAmount,
        uint256 lifetime
    )
        external
        returns(NftId nftId)
    {
        nftId = _createApplication(
            msg.sender, // policy holder
            sumInsuredAmount,
            premiumAmount,
            lifetime,
            toNftId(0) // requested bundle nft id
        );
    }

    function underwrite(NftId nftId) external {
        _underwrite(nftId);
    }
}