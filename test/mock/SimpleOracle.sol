// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AmountLib} from "../../contracts/type/Amount.sol";
import {Fee} from "../../contracts/type/Fee.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {Oracle} from "../../contracts/oracle/Oracle.sol";
import {Seconds} from "../../contracts/type/Timestamp.sol";
import {UFixed} from "../../contracts/type/UFixed.sol";

contract SimpleOracle is Oracle {
    
    constructor(
        address registry,
        NftId instanceNftId,
        address initialOwner,
        address token
    ) 
    {
        initialize(
            registry,
            instanceNftId,
            initialOwner,
            "SimpleOracle",
            token
        );
    }

    function initialize(
        address registry,
        NftId instanceNftId,
        address initialOwner,
        string memory name,
        address token
    )
        public
        virtual
        initializer()
    {
        initializeOracle(
            registry,
            instanceNftId,
            initialOwner,
            name,
            token,
            "",
            "");
    }

}