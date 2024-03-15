// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Fee} from "../../contracts/types/Fee.sol";
import {NftId} from "../../contracts/types/NftId.sol";
import {Pool} from "../../contracts/components/Pool.sol";
import {Seconds} from "../../contracts/types/Timestamp.sol";
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
            // TODO refactor
            // false, // externally managed
            // isConfirmingApplication, // verifying applications
            // collateralizationLevel,
            // retentionLevel,
            initialOwner,
            "");
    }

    function createBundle(
        Fee memory fee,
        uint256 initialAmount,
        Seconds lifetime,
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