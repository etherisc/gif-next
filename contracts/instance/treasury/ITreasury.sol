// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {NftId} from "../../types/NftId.sol";
import {UFixed} from "../../types/UFixed.sol";
import {Fee} from "../../types/Fee.sol";

interface ITreasury {

    // TODO add events
    // TODO add errors
}

interface ITreasuryModule is ITreasury {

    struct ProductSetup {
        NftId productNftId;
        NftId distributorNftId;
        NftId poolNftId;
        IERC20 token;
        address wallet;
        Fee policyFee;
        Fee processingFee;
    }

    struct DistributorSetup {
        NftId distributorNftId;
        address wallet;
        Fee commissionFees;
    }

    struct PoolSetup {
        NftId poolNftId;
        address wallet;
        Fee stakingFee;
        Fee performanceFee;
    }

    function registerProduct(
            NftId productNftId,
            NftId distributorNftId,
            NftId poolNftId,
            IERC20 token,
            address wallet,
            Fee memory policyFee,
            Fee memory processingFee
        )
            external;

    function registerPool(
            NftId poolNftId,
            address wallet,
            Fee memory stakingFee,
            Fee memory performanceFee
        )
            external;

    function getProductSetup(NftId productNftId) external view returns(ProductSetup memory setup);
    function getPoolSetup(NftId poolNftId) external view returns(PoolSetup memory setup);

    function processPremium(NftId policyNftId) external;
}