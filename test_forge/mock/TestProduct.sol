// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Product} from "../../contracts/components/Product.sol";


contract TestProduct is Product {

    constructor(address registry, address instance, address pool)
        Product(registry, instance, pool)
    {}

    function applyForPolicy(
        uint256 sumInsuredAmount,
        uint256 premiumAmount,
        uint256 lifetime
    )
        external
        returns(uint256 nftId)
    {
        nftId = _createApplication(
            msg.sender, // policy holder
            sumInsuredAmount,
            premiumAmount,
            lifetime,
            0 // requested bundle nft id
        );
    }


}