// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ChainId} from "../../contracts/type/ChainId.sol";
import {StdAssertions} from "forge-std/StdAssertions.sol";

contract GifTestHelper is StdAssertions {

    function assertEqChainId(ChainId chainId1, ChainId chainId2) public pure {
        assertEq(chainId1.toInt(), chainId2.toInt(), "ChainId not equal");
    }

        function assertEqChainId(ChainId chainId1, ChainId chainId2, string memory err) public pure {
        assertEq(chainId1.toInt(), chainId2.toInt(), err);
    }
    
}