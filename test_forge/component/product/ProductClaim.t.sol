// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {console} from "../../../lib/forge-std/src/Test.sol";

import {TestGifBase} from "../../base/TestGifBase.sol";
import {Amount, AmountLib} from "../../../contracts/types/Amount.sol";
import {NftId, NftIdLib} from "../../../contracts/types/NftId.sol";
import {ClaimId} from "../../../contracts/types/ClaimId.sol";
import {PRODUCT_OWNER_ROLE} from "../../../contracts/types/RoleId.sol";
import {SimpleProduct} from "../../mock/SimpleProduct.sol";
import {SimplePool} from "../../mock/SimplePool.sol";
import {IComponents} from "../../../contracts/instance/module/IComponents.sol";
import {ILifecycle} from "../../../contracts/instance/base/ILifecycle.sol";
import {ISetup} from "../../../contracts/instance/module/ISetup.sol";
import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";
import {IBundle} from "../../../contracts/instance/module/IBundle.sol";
import {Fee, FeeLib} from "../../../contracts/types/Fee.sol";
import {UFixedLib} from "../../../contracts/types/UFixed.sol";
import {Seconds, SecondsLib} from "../../../contracts/types/Seconds.sol";
import {Timestamp, TimestampLib, zeroTimestamp} from "../../../contracts/types/Timestamp.sol";
import {IRisk} from "../../../contracts/instance/module/IRisk.sol";
import {RiskId, RiskIdLib, eqRiskId} from "../../../contracts/types/RiskId.sol";
import {ReferralLib} from "../../../contracts/types/Referral.sol";
import {APPLIED, ACTIVE, UNDERWRITTEN, CLOSED} from "../../../contracts/types/StateId.sol";
import {POLICY} from "../../../contracts/types/ObjectType.sol";

contract TestProductClaim is TestGifBase {

    uint256 public constant BUNDLE_CAPITAL = 5000;
    uint256 public constant SUM_INSURED = 1000;
    uint256 public constant CUSTOMER_FUNDS = 400;
    
    SimpleProduct public prdct;
    RiskId public riskId;
    NftId public policyNftId;

    function setUp() public override {
        super.setUp();

        _prepareProduct();  

        // create risk
        vm.startPrank(productOwner);
        riskId = RiskIdLib.toRiskId("Risk_1");
        prdct.createRisk(riskId, "");
        vm.stopPrank();

        // create application
        policyNftId = _createApplication(
            1000, // sum insured
            SecondsLib.toSeconds(60)); // lifetime
    }

    event LogClaimTestClaimInfo(NftId policyNftId, IPolicy.PolicyInfo policyInfo, ClaimId claimId, IPolicy.ClaimInfo claimInfo);

    function test_ProductCreateClaimHappyCase() public {
        // GIVEN
        _approve();
        _collateralize(policyNftId, true, TimestampLib.blockTimestamp());

        // WHEN
        Amount claimAmount = AmountLib.toAmount(499);
        bytes memory claimData = "please pay";
        ClaimId claimId = prdct.createClaim(policyNftId, claimAmount, claimData); 

        // THEN
        assertTrue(claimId.gtz(), "claim id zero");

        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        IPolicy.ClaimInfo memory claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
        emit LogClaimTestClaimInfo(policyNftId, policyInfo, claimId, claimInfo);

        require(false, "ups");
    }

    event LogClaimTest(NftId productNftId, ISetup.ProductSetupInfo product);

    function _approve() internal {
        // add allowance to pay premiums
        ISetup.ProductSetupInfo memory productSetup = instanceReader.getProductSetupInfo(productNftId);(productNftId);
        emit LogClaimTest(productNftId, productSetup);

        vm.startPrank(customer);
        token.approve(
            address(productSetup.tokenHandler), 
            CUSTOMER_FUNDS);
        vm.stopPrank();
    }

    function _collateralize(
        NftId nftId,
        bool collectPremium,
        Timestamp activateAt
    )
        internal
    {
        vm.startPrank(productOwner);
        prdct.underwrite(nftId, collectPremium, activateAt); 
        vm.stopPrank();
    }


    function _createApplication(
        uint256 sumInsuredAmount,
        Seconds lifetime
    )
        internal
        returns (NftId)
    {
        return prdct.createApplication(
            customer,
            riskId,
            sumInsuredAmount,
            lifetime,
            "",
            bundleNftId,
            ReferralLib.zero());
    }


    function _prepareProduct() internal {
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(PRODUCT_OWNER_ROLE(), productOwner);
        vm.stopPrank();

        _prepareDistributionAndPool();

        vm.startPrank(productOwner);
        prdct = new SimpleProduct(
            address(registry),
            instanceNftId,
            address(token),
            false,
            address(pool), 
            address(distribution),
            FeeLib.zeroFee(),
            FeeLib.zeroFee(),
            productOwner
        );
        
        productNftId = productService.register(address(prdct));
        vm.stopPrank();


        vm.startPrank(registryOwner);
        token.transfer(investor, BUNDLE_CAPITAL);
        token.transfer(customer, CUSTOMER_FUNDS);
        vm.stopPrank();

        vm.startPrank(investor);
        IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);
        token.approve(address(poolComponentInfo.tokenHandler), BUNDLE_CAPITAL);

        // SimplePool spool = SimplePool(address(pool));
        bundleNftId = pool.createBundle(
            FeeLib.zeroFee(), 
            BUNDLE_CAPITAL, 
            SecondsLib.toSeconds(604800), 
            ""
        );
        vm.stopPrank();
    }

}
