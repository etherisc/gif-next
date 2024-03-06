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
            collateralizationLevel,
            isInterceptor,
            false, // externally managed
            isConfirmingApplication,
            initialOwner,
            "");
    }

    function createBundle(
        Fee memory fee,
        uint256 initialAmount,
        uint256 lifetime,
        bytes memory filter
    )
        external
        returns (NftId bundleNftId)
    {
        address bundleOwner = msg.sender;
        return _createBundle(
            bundleOwner, 
            fee, 
            initialAmount, 
            lifetime, 
            filter);
    }
}