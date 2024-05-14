// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {ClaimId, ClaimIdLib} from "../../contracts/type/ClaimId.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {ObjectType, POLICY} from "../../contracts/type/ObjectType.sol";
import {Key32} from "../../contracts/type/Key32.sol";
import {PayoutId, PayoutIdLib} from "../../contracts/type/PayoutId.sol";

contract PayoutIdClaimIdTest is Test {

    function test_ClaimIdToIntHappyCase() public {
        uint claimNo = 42;
        ClaimId claimId = ClaimIdLib.toClaimId(claimNo);
        assertEq(claimId.toInt(), claimNo, "unexpected claim no from claimid");
    }

    function test_ClaimIdMinMax() public {
        assertEq(ClaimIdLib.zero().toInt(), 0, "claim id zero not 0");
        assertEq(ClaimIdLib.max().toInt(), 2**16 - 1, "claim id unexpected max ");
    }

    function test_PayoutIdToIntHappyCase() public {
        uint claimNo = 42;
        ClaimId claimId = ClaimIdLib.toClaimId(claimNo);

        uint8 payoutNo = 17;
        PayoutId payoutId = PayoutIdLib.toPayoutId(claimId, payoutNo);
        assertEq(payoutId.toInt(), (claimNo << 8) + payoutNo, "unexpected payout id");
        assertEq(payoutId.toClaimId().toInt(), claimId.toInt(), "unexpected claim id for payout id");
        assertEq(payoutId.toPayoutNo(), payoutNo, "unexpected payout no for payout id");
    }

    function test_PayoutIdMaxPayoutNo() public {
        uint claimNo = 42;
        ClaimId claimId = ClaimIdLib.toClaimId(claimNo);

        uint8 payoutNo = type(uint8).max;
        assertEq(payoutNo, 255, "unexpected max payout no");

        PayoutId payoutId = PayoutIdLib.toPayoutId(claimId, payoutNo);
        assertEq(payoutId.toInt(), (claimNo << 8) + payoutNo, "unexpected payout id");
        assertEq(payoutId.toClaimId().toInt(), claimId.toInt(), "unexpected claim id for payout id");
        assertEq(payoutId.toPayoutNo(), payoutNo, "unexpected payout no for payout id");
    }

    // continue here
    // TODO add toKey32 testing (likely the reason that test_ProductPayoutCreateHappyCase fails with ERROR:KVS-012:ALREADY_CREATED)
    function test_PayoutIdToKey32() public {
        uint claimNo = 42;
        uint8 payoutNo = 17;

        ClaimId claimId = ClaimIdLib.toClaimId(claimNo);
        PayoutId payoutId = PayoutIdLib.toPayoutId(claimId, payoutNo);

        NftId policyNftId = NftId.wrap(100101);
        Key32 policyKey = policyNftId.toKey32(POLICY());
        Key32 claimKey = claimId.toKey32(policyNftId);
        Key32 payoutKey = payoutId.toKey32(policyNftId);

        console.log("policy key", ObjectType.unwrap(policyKey.toObjectType()));
        console.log("claim key", ObjectType.unwrap(claimKey.toObjectType()));
        console.log("payout key", ObjectType.unwrap(payoutKey.toObjectType()));
    }
}
