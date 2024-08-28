// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;


import {GifClusterTest} from "../../base/GifClusterTest.sol";
import {IRiskService} from "../../../contracts/product/IRiskService.sol";
import {NftId} from "../../../contracts/type/NftId.sol";
import {RiskId} from "../../../contracts/type/RiskId.sol";
import {PAUSED} from "../../../contracts/type/StateId.sol";

// solhint-disable func-name-mixedcase
contract ProductRiskClusterTest is GifClusterTest {

    uint256 public constant BUNDLE_CAPITAL = 5000;
    uint256 public constant SUM_INSURED = 1000;
    uint256 public constant LIFETIME = 365 * 24 * 3600;
    uint256 public constant CUSTOMER_FUNDS = 2000;
    
    RiskId public initialRiskId;
    NftId public initialPolicyNftId;

    function setUp() public override {
        super.setUp();

        _setupProductClusters1and2();  
    }

    function test_updateRisk_fromOtherProductCluster() public {
        // GIVEN
        RiskId riskId = myProduct1.createRisk("risk1", "risk1data");
        
        // THEN 
        vm.expectRevert(abi.encodeWithSelector(
            IRiskService.ErrorRiskServiceRiskProductMismatch.selector, 
            riskId,
            myProductNftId1,
            myProductNftId2));
        // WHEN
        myProduct2.updateRisk(riskId, "risk1updated");
    }

    function test_updateRiskState_fromOtherProductCluster() public {
        // GIVEN
        RiskId riskId = myProduct1.createRisk("risk1", "risk1data");
        
        // THEN 
        vm.expectRevert(abi.encodeWithSelector(
            IRiskService.ErrorRiskServiceRiskProductMismatch.selector, 
            riskId,
            myProductNftId1,
            myProductNftId2));

        // WHEN
        myProduct2.updateRiskState(riskId, PAUSED());
    }

}
