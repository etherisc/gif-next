// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../../lib/forge-std/src/Test.sol";

import {GifClusterTest} from "../../base/GifClusterTest.sol";
import {IRiskService} from "../../../contracts/product/IRiskService.sol";
import {KeyId} from "../../../contracts/type/Key32.sol";
import {NftId} from "../../../contracts/type/NftId.sol";
import {ILifecycle} from "../../../contracts/shared/ILifecycle.sol";
import {SecondsLib} from "../../../contracts/type/Seconds.sol";
import {Timestamp, zeroTimestamp} from "../../../contracts/type/Timestamp.sol";
import {RISK} from "../../../contracts/type/ObjectType.sol";
import {RiskId, RiskIdLib, eqRiskId} from "../../../contracts/type/RiskId.sol";
import {ReferralLib} from "../../../contracts/type/Referral.sol";
import {ACTIVE, PAUSED, ARCHIVED} from "../../../contracts/type/StateId.sol";

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
