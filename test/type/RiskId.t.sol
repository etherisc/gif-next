// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Test} from "../../lib/forge-std/src/Test.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {RiskId, RiskIdLib} from "../../contracts/type/RiskId.sol";

contract RiskIdTest is Test {

    function testEncodeRiskIdWithProductNftId() public {
        NftId productNftId = NftIdLib.toNftId(42);
        NftId productNftId2 = NftIdLib.toNftId(43);
        RiskId riskId1 = RiskIdLib.toRiskId(productNftId, "Risk1");
        RiskId riskId2 = RiskIdLib.toRiskId(productNftId2, "Risk1");
        assertFalse(riskId1.eq(riskId2), "riskId1 should not be equal to riskId2");
    }

}