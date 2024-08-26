// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {GifClusterTest} from "../../base/GifClusterTest.sol";
import {NftId} from "../../../contracts/type/NftId.sol";
import {RiskId} from "../../../contracts/type/RiskId.sol";

// solhint-disable func-name-mixedcase
contract ProductClusterRiskTest is GifClusterTest {

    uint256 public constant BUNDLE_CAPITAL = 5000;
    uint256 public constant SUM_INSURED = 1000;
    uint256 public constant LIFETIME = 365 * 24 * 3600;
    uint256 public constant CUSTOMER_FUNDS = 2000;
    
    RiskId public initialRiskId;
    NftId public initialPolicyNftId;

    function setUp() public override {
        super.setUp();
        _setupProductClusters1to4();
    }

    /// @dev create a risk with the same name of two different product clusters in the same instance
    function test_createRisk_twoProductsSameRiskId() public {
        // GIVEN
        string memory riskName = "Risk1";

        // WHEN
        riskId1 = myProduct1.createRisk(riskName, abi.encode(1,2,3));
        riskId2 = myProduct2.createRisk(riskName, abi.encode(1,2,3));

        // THEN
        assertFalse(riskId1.eq(riskId2), "riskId1 and riskid2 should not be equal");
    }
}