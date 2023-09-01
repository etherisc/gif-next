// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import { TestGifBase } from  "../TestGifBase.sol";
import { NftId, toNftId, zeroNftId, eqNftId, neNftId, NftIdLib } from "../../contracts/types/NftId.sol";

contract NftIdTest is TestGifBase {
    using NftIdLib for NftId;

    NftId nftId1;
    NftId nftId2;
    NftId NftIdZero;
    
    function setUp() override public {
        nftId1 = toNftId(23133705);
        nftId2 = toNftId(43133705);
        NftIdZero = toNftId(0);
    }

    function test_toNftId() public {
        assertNftId(nftId1, toNftId(23133705), "nft id not equl to 23133705");
        assertNftId(nftId2, toNftId(43133705), "nft id not equl to 43133705");
    }

    function test_zeroNftId() public {
        assertNftIdZero(NftIdZero, "nft id not zero");
    }

    function test_op_equal() public {
        assertTrue(nftId1 == nftId1, "nft id not equal to itself");
        assertTrue(nftId2 == nftId2, "nft id not equal to itself");

        assertTrue(NftIdZero == NftIdZero, "nft id zero not equal to itself");

        assertFalse(nftId1 == nftId2, "nft id 1 equal to nft id 2");
        assertFalse(nftId2 == nftId1, "nft id 2 equal to nft id 1");

        assertFalse(nftId1 == NftIdZero, "nft id 1 equal to nft id zero");
        assertFalse(nftId2 == NftIdZero, "nft id 2 equal to nft id zero");

        assertFalse(NftIdZero == nftId1, "nft id zero equal to nft id 1");
        assertFalse(NftIdZero == nftId2, "nft id zero equal to nft id 2");
    }

    function test_op_not_equal() public {
        assertTrue(nftId1 != nftId2, "nft id 1 equal to nft id 2");
        assertTrue(nftId2 != nftId1, "nft id 2 equal to nft id 1");

        assertTrue(nftId1 != NftIdZero, "nft id 1 equal to nft id zero");
        assertTrue(nftId2 != NftIdZero, "nft id 2 equal to nft id zero");

        assertTrue(NftIdZero != nftId1, "nft id zero equal to nft id 1");
        assertTrue(NftIdZero != nftId2, "nft id zero equal to nft id 2");

        assertFalse(nftId1 != nftId1, "nft id not equal to itself");
        assertFalse(nftId2 != nftId2, "nft id not equal to itself");

        assertFalse(NftIdZero != NftIdZero, "nft id zero not equal to itself");
    }

    function test_eqNftId() public {
        assertTrue(eqNftId(nftId1, nftId1), "nft id not equal to itself");
        assertTrue(eqNftId(nftId2, nftId2), "nft id not equal to itself");

        assertTrue(eqNftId(NftIdZero, NftIdZero), "nft id zero not equal to itself");

        assertFalse(eqNftId(nftId1, nftId2), "nft id 1 equal to nft id 2");
        assertFalse(eqNftId(nftId2, nftId1), "nft id 2 equal to nft id 1");

        assertFalse(eqNftId(nftId1, NftIdZero), "nft id 1 equal to nft id zero");
        assertFalse(eqNftId(nftId2, NftIdZero), "nft id 2 equal to nft id zero");
    }

    function test_neNftId() public {
        assertFalse(neNftId(nftId1, nftId1), "nft id not equal to itself");
        assertFalse(neNftId(nftId2, nftId2), "nft id not equal to itself");

        assertFalse(neNftId(NftIdZero, NftIdZero), "nft id zero not equal to itself");

        assertTrue(neNftId(nftId1, nftId2), "nft id 1 equal to nft id 2");
        assertTrue(neNftId(nftId2, nftId1), "nft id 2 equal to nft id 1");

        assertTrue(neNftId(nftId1, NftIdZero), "nft id 1 equal to nft id zero");
        assertTrue(neNftId(nftId2, NftIdZero), "nft id 2 equal to nft id zero");
    }

    function test_NftIdLib_toInt() public {
        assertEq(nftId1.toInt(), 23133705, "nft id not equal to 23133705");
        assertEq(nftId2.toInt(), 43133705, "nft id not equal to 43133705");
    }

    function test_NftIdLib_gtz() public {
        assertTrue(nftId1.gtz(), "nft id 1 not greater than zero");
        assertTrue(nftId2.gtz(), "nft id 2 not greater than zero");

        assertFalse(NftIdZero.gtz(), "nft id zero greater than zero");
    }

    function test_NftIdLib_eqz() public {
        assertFalse(nftId1.eqz(), "nft id 1 equal to zero");
        assertFalse(nftId2.eqz(), "nft id 2 equal to zero");

        assertTrue(NftIdZero.eqz(), "nft id zero not equal to zero");
    }

    function test_NftIdLib_eq() public {
        assertTrue(nftId1.eq(nftId1), "nft id not equal to itself");
        assertTrue(nftId2.eq(nftId2), "nft id not equal to itself");

        assertTrue(NftIdZero.eq(NftIdZero), "nft id zero not equal to itself");

        assertFalse(nftId1.eq(nftId2), "nft id 1 equal to nft id 2");
        assertFalse(nftId2.eq(nftId1), "nft id 2 equal to nft id 1");

        assertFalse(nftId1.eq(NftIdZero), "nft id 1 equal to nft id zero");
        assertFalse(nftId2.eq(NftIdZero), "nft id 2 equal to nft id zero");
    }

}