// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import { Test } from  "../../lib/forge-std/src/Test.sol";
import { ChainId, ChainIdLib, toChainId, thisChainId, eqChainId, neChainId } from "../../contracts/types/ChainId.sol";

contract ChainIdTest is Test {
    using ChainIdLib for ChainId;

    ChainId chainId1;
    ChainId chainId2;
    ChainId ChainIdZero;
    
    function setUp() public {
        chainId1 = toChainId(1);
        chainId2 = toChainId(2);
        ChainIdZero = toChainId(0);
    }

    function test_toChainId() public {
        assertEq(chainId1.toInt(), 1);
        assertEq(chainId2.toInt(), 2);
    }

    function test_thisChainId() public {
        assertEq(thisChainId().toInt(), block.chainid);
    }

    function test_eqChainId() public {
        assertTrue(eqChainId(chainId1, chainId1));
        assertTrue(eqChainId(chainId2, chainId2));

        assertTrue(eqChainId(ChainIdZero, ChainIdZero));

        assertFalse(eqChainId(chainId1, chainId2));
        assertFalse(eqChainId(chainId2, chainId1));

        assertFalse(eqChainId(chainId1, ChainIdZero));
        assertFalse(eqChainId(chainId2, ChainIdZero));
    }

    function test_neChainId() public {
        assertFalse(neChainId(chainId1, chainId1));
        assertFalse(neChainId(chainId2, chainId2));

        assertFalse(neChainId(ChainIdZero, ChainIdZero));

        assertTrue(neChainId(chainId1, chainId2));
        assertTrue(neChainId(chainId2, chainId1));

        assertTrue(neChainId(chainId1, ChainIdZero));
        assertTrue(neChainId(chainId2, ChainIdZero));
    }
    
}
