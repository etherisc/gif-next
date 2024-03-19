// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Fee} from "../../types/Fee.sol";
import {NftId} from "../../types/NftId.sol";
import {RoleId} from "../../types/RoleId.sol";
import {TokenHandler} from "../../shared/TokenHandler.sol";
import {UFixed} from "../../types/UFixed.sol";

interface ISetup {

    struct ProductSetupInfo {
        IERC20Metadata token;
        TokenHandler tokenHandler;
        NftId distributionNftId;
        NftId poolNftId;
        Fee productFee; // product fee on net premium
        Fee processingFee; // product fee on payout amounts        
        bool isIntercepting; // intercepts nft transfers (for products)
        address wallet;
    }

    struct DistributionSetupInfo {
        NftId productNftId;
        TokenHandler tokenHandler;
        Fee minDistributionOwnerFee;
        Fee distributionFee; // recalculated whenever any fee on the product/pool/dist/disttype is changed
        address wallet;
        uint256 sumDistributionFees;
    }
}
