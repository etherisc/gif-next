// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Pool} from "../../contracts/components/Pool.sol";
import {NftId} from "../../contracts/types/NftId.sol";
import {Fee} from "../../contracts/types/Fee.sol";
import {UFixed} from "../../contracts/types/UFixed.sol";

contract SimplePool is Pool {
    
    constructor(
        address registry,
        NftId instanceNftId,
        address token,
        bool isInterceptor,
        bool isConfirmingApplication,
        UFixed collateralizationLevel,
        Fee memory poolFee,
        Fee memory stakingFee,
        Fee memory performanceFee,
        address initialOwner
    ) Pool (
        registry,
        instanceNftId,
        "SimplePool",
        token,
        isInterceptor,
        isConfirmingApplication,
        collateralizationLevel,
        poolFee,
        stakingFee,
        performanceFee,
        initialOwner,
        ""
    ) {
    }

    function createBundle(
        Fee memory fee,
        uint256 initialAmount,
        uint256 lifetime,
        bytes calldata filter
    )
        external
        virtual 
        returns(NftId bundleNftId)
    {
        address owner = msg.sender;
        bundleNftId = _createBundle(
            owner,
            fee,
            initialAmount,
            lifetime,
            filter
        );
    }

}