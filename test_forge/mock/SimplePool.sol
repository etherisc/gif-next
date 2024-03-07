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
        UFixed retentionLevel,
        address initialOwner
    ) 
    {
        initialize(
            registry,
            instanceNftId,
            token,
            isInterceptor,
            isConfirmingApplication,
            collateralizationLevel,
            retentionLevel,
            initialOwner
        );
    }

    function initialize(
        address registry,
        NftId instanceNftId,
        address token,
        bool isInterceptor,
        bool isConfirmingApplication,
        UFixed collateralizationLevel,
        UFixed retentionLevel,
        address initialOwner
    )
        public
        virtual
        initializer()
    {
        initializePool(
            registry,
            instanceNftId,
            "SimplePool",
            token,
            isInterceptor,
            false, // externally managed
            isConfirmingApplication, // verifying applications
            collateralizationLevel,
            retentionLevel,
            initialOwner,
            "");
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