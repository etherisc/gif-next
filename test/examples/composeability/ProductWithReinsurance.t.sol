// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Vm, console} from "../../../lib/forge-std/src/Test.sol";

import {GifTest} from "../../base/GifTest.sol";
import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {DistributionWithReinsuranceAuthorization} from "./DistributionWithReinsuranceAuthorization.sol";
import {PoolWithReinsuranceAuthorization} from "./PoolWithReinsuranceAuthorization.sol";
import {ProductWithReinsuranceAuthorization} from "./ProductWithReinsuranceAuthorization.sol";
import {NftId, NftIdLib} from "../../../contracts/type/NftId.sol";
import {ClaimId, ClaimIdLib} from "../../../contracts/type/ClaimId.sol";
import {ContractLib} from "../../../contracts/shared/ContractLib.sol";
import {ProductWithReinsurance} from "./ProductWithReinsurance.sol";
import {PoolWithReinsurance} from "./PoolWithReinsurance.sol";
import {SimpleDistribution} from "../../../contracts/examples/unpermissioned/SimpleDistribution.sol";
import {SimpleProduct} from "../../../contracts/examples/unpermissioned/SimpleProduct.sol";
import {SimplePool} from "../../../contracts/examples/unpermissioned/SimplePool.sol";
import {IComponents} from "../../../contracts/instance/module/IComponents.sol";
import {ILifecycle} from "../../../contracts/shared/ILifecycle.sol";
import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";
import {IPolicyHolder} from "../../../contracts/shared/IPolicyHolder.sol";
import {IBundle} from "../../../contracts/instance/module/IBundle.sol";
import {Fee, FeeLib} from "../../../contracts/type/Fee.sol";
import {UFixedLib} from "../../../contracts/type/UFixed.sol";
import {Seconds, SecondsLib} from "../../../contracts/type/Seconds.sol";
import {Timestamp, TimestampLib, zeroTimestamp} from "../../../contracts/type/Timestamp.sol";
import {IPolicyService} from "../../../contracts/product/IPolicyService.sol";
import {IRisk} from "../../../contracts/instance/module/IRisk.sol";
import {PayoutId, PayoutIdLib} from "../../../contracts/type/PayoutId.sol";
import {POLICY} from "../../../contracts/type/ObjectType.sol";
import {RiskId, RiskIdLib, eqRiskId} from "../../../contracts/type/RiskId.sol";
import {ReferralLib} from "../../../contracts/type/Referral.sol";
import {SUBMITTED, ACTIVE, COLLATERALIZED, CONFIRMED, PAID, DECLINED, CLOSED} from "../../../contracts/type/StateId.sol";
import {StateId} from "../../../contracts/type/StateId.sol";


contract ProductWithReinsuranceTest is
    GifTest
{

    uint256 public constant BUNDLE_CAPITAL = 5000;
    uint256 public constant SUM_INSURED = 1000;
    uint256 public constant CUSTOMER_FUNDS = 400;

    SimpleDistribution public distributionRe;
    PoolWithReinsurance public poolRe;
    ProductWithReinsurance public productRe;

    NftId public distributionReNftId;
    NftId public poolReNftId;
    NftId public productReNftId;
    NftId public policyReNftId;
    NftId public bundleReNftId;

    RiskId public riskReId;


    // TODO this should not be here (copy paste from IPolicyService)
    event LogPolicyServiceClaimSubmitted(NftId policyNftId, ClaimId claimId, Amount claimAmount);
    event LogPolicyServiceClaimDeclined(NftId policyNftId, ClaimId claimId);
    event LogPolicyServiceClaimConfirmed(NftId policyNftId, ClaimId claimId, Amount confirmedAmount);
    event LogClaimServicePayoutCreated(NftId policyNftId, PayoutId payoutId, Amount amount);
    event LogClaimServicePayoutProcessed(NftId policyNftId, PayoutId payoutId, Amount amount);


    function setUp() public override {
        super.setUp();

        // reinsurance product
        _prepareProduct();

        // setup product with reinsurance
        _prepareProductWithReinsurance();
    }

    function test_reinsuranceSetUp() public {

        assertTrue(productNftId.gtz(), "product zero (reinsurance)");
        assertTrue(poolNftId.gtz(), "pool zero (reinsurance)");

        assertTrue(productReNftId.gtz(), "product zero (insurance)");
        assertTrue(poolReNftId.gtz(), "pool zero (insurance)");

        assertEq(poolRe.reinsuranceProduct().getNftId().toInt(), product.getNftId().toInt(), "unexpected reinsurance product");

        // test product with reinsurance
        IComponents.ProductInfo memory productReInfo = instanceReader.getProductInfo(productReNftId);
        assertTrue(productReInfo.isProcessingFundedClaims, "product not processing funded claims");

        // test pool with reinsurance
        IComponents.PoolInfo memory poolReInfo = instanceReader.getPoolInfo(poolReNftId);
        assertTrue(poolReInfo.isProcessingConfirmedClaims, "pool not processing confirmed claims");
        assertTrue(poolReInfo.collateralizationLevel == UFixedLib.one(), "collateralization level not 100%");
        assertTrue(poolReInfo.retentionLevel == UFixedLib.toUFixed(2, -1), "retention level not 20%");

        // solhint-disable
        console.log("reinsurance bundle balance", instanceReader.getBalanceAmount(bundleNftId).toInt());
        console.log("reinsurance bundle locked", instanceReader.getLockedAmount(bundleNftId).toInt());

        console.log("insurance bundle balance", instanceReader.getBalanceAmount(bundleReNftId).toInt());
        console.log("insurance bundle locked", instanceReader.getLockedAmount(bundleReNftId).toInt());
        // solhint-enable

        // check reinsurance policy
        assertTrue(poolRe.resinsurancePolicyNftId().gtz(), "reinsurance policy zero");
        assertEq(registry.ownerOf(poolRe.resinsurancePolicyNftId()), address(poolRe), "unexpected reinsurance policy owner");
        assertTrue(instanceReader.policyIsActive(poolRe.resinsurancePolicyNftId()), "reinsurance policy not active");

        // checking reinsurance policy info
        IPolicy.PolicyInfo memory reinsurancePolicyInfo = instanceReader.getPolicyInfo(poolRe.resinsurancePolicyNftId());

        // solhint-disable-next-line
        console.log("reinsurance policy sum insured", reinsurancePolicyInfo.sumInsuredAmount.toInt());

        assertEq(reinsurancePolicyInfo.sumInsuredAmount.toInt(), 5000 * 10**token.decimals(), "unexpected reinsurance policy sum insured");
        assertEq(reinsurancePolicyInfo.claimsCount, 0, "claims count not 0");
    }


    function test_reinsuranceCreatePolicy() public {
        // solhint-disable
        console.log("insurance bundle balance (before)", instanceReader.getBalanceAmount(bundleReNftId).toInt());
        console.log("insurance bundle locked (before)", instanceReader.getLockedAmount(bundleReNftId).toInt());
        // solhint-enable

        uint256 sumInsured = 1000 * 10**token.decimals();
        uint256 lifetime = 30 * 24 * 3600;
        policyReNftId = _createPolicy(customer, sumInsured, lifetime);

        // check policy is active and has right owner
        assertEq(registry.ownerOf(policyReNftId), customer, "unexpected policy owner");
        assertTrue(instanceReader.policyIsActive(policyReNftId), "policy not active");

        // solhint-disable
        console.log("insurance bundle balance (after)", instanceReader.getBalanceAmount(bundleReNftId).toInt());
        console.log("insurance bundle locked (after)", instanceReader.getLockedAmount(bundleReNftId).toInt());
        console.log("policy sum insured (after)", sumInsured);
        // solhint-enable

        // retention level 20% -> locally only 20% of sum insured locked, rest covered by reinsurance
        assertEq(instanceReader.getLockedAmount(bundleReNftId).toInt(), sumInsured / 5);

        // checking reinsurance policy info
        IPolicy.PolicyInfo memory reinsurancePolicyInfo = instanceReader.getPolicyInfo(poolRe.resinsurancePolicyNftId());
        assertEq(reinsurancePolicyInfo.claimsCount, 0, "claims count of reinsurance policy not 0");
    }


    function test_reinsuranceCreateClaim() public {
        // GIVEN setup and active policy
        // checking reinsurance policy info
        assertEq(instanceReader.claims(poolRe.resinsurancePolicyNftId()), 0, "claims count of reinsurance policy not 0 (before)");

        uint256 sumInsured = 1000 * 10**token.decimals();
        uint256 lifetime = 30 * 24 * 3600;
        policyReNftId = _createPolicy(customer, sumInsured, lifetime);

        uint256 customerBalanceBefore = token.balanceOf(customer);
        uint256 poolWalletBalanceBefore = token.balanceOf(pool.getWallet());
        uint256 poolReWalletBalanceBefore = token.balanceOf(poolRe.getWallet());

        // solhint-disable
        console.log("insurance pool wallet balance (before)", poolReWalletBalanceBefore);
        console.log("insurance pool balance (before)", instanceReader.getBalanceAmount(poolReNftId).toInt());
        console.log("insurance bundle balance (before)", instanceReader.getBalanceAmount(bundleReNftId).toInt());
        console.log("insurance bundle locked (before)", instanceReader.getLockedAmount(bundleReNftId).toInt());
        // solhint-enable

        ClaimId claimReExpectedId = ClaimIdLib.toClaimId(1);
        assertTrue(productRe.claimFundingAmount(policyReNftId, claimReExpectedId).eqz(), "unexpected claim funded amount (before)");

        // WHEN creating a claim
        uint256 claim = 100 * 10**token.decimals();
        ClaimId claimReId = _createClaim(policyReNftId, claim);

        // THEN
        // solhint-disable
        console.log("insurance pool wallet balance (after)", token.balanceOf(poolRe.getWallet()));
        console.log("insurance pool balance (after)", instanceReader.getBalanceAmount(poolReNftId).toInt());
        console.log("insurance bundle balance (after)", instanceReader.getBalanceAmount(bundleReNftId).toInt());
        console.log("insurance bundle locked (after)", instanceReader.getLockedAmount(bundleReNftId).toInt());
        // solhint-enable

        // check claim info
        IPolicy.ClaimInfo memory claimInfo = instanceReader.getClaimInfo(
            policyReNftId, 
            claimReId);

        assertEq(claimInfo.payoutsCount, 0, "unexpected payouts count");
        assertEq(claimInfo.openPayoutsCount, 0, "unexpected open payouts count");

        // check claim funded amount
        uint expectedClaimFunding = claim * 4 / 5;
        assertEq(productRe.claimFundingAmount(policyReNftId, claimReExpectedId).toInt(), expectedClaimFunding, "unexpected claim funded amount (after)");

        // checking reinsurance policy info: there must now be a claim
        assertEq(instanceReader.claims(poolRe.resinsurancePolicyNftId()), 1, "claims count of reinsurance policy not 1 (after)");

        // get info from claim from reinsurace policy
        IPolicy.ClaimInfo memory reinsuranceClaimInfo = instanceReader.getClaimInfo(
            poolRe.resinsurancePolicyNftId(), 
            instanceReader.getClaimId(0));

        assertEq(reinsuranceClaimInfo.payoutsCount, 1, "unexpected payouts count");
        assertEq(reinsuranceClaimInfo.openPayoutsCount, 0, "unexpected open payouts count");

        // check reinsurace claim amount
        Amount reInsClaimAmount = reinsuranceClaimInfo.claimAmount;
        assertTrue(reInsClaimAmount.gtz(), "reinsurance claim amount zero");
        assertEq(reInsClaimAmount.toInt(), claim * 4 / 5, "reinsurance claim amount not 80% of claim");

        // check reinsurace claim submission data
        (
            NftId claimingPolicyNftId, 
            ClaimId sourceClaimId
        ) = poolRe.decodeClaimData(reinsuranceClaimInfo.submissionData);

        assertEq(claimingPolicyNftId.toInt(), policyReNftId.toInt(), "unexpected claiming policy");
        assertEq(sourceClaimId.toInt(), claimReId.toInt(), "unexpected claiming claim id");

        // check reinsurance pool balance has been decreased by 80% of claims amount
        uint expectedPoolContribution = claim * 4 / 5;
        assertEq(token.balanceOf(pool.getWallet()), poolWalletBalanceBefore - expectedPoolContribution, "unexpected reinsurance pool wallet balance");

        // check pool balance has been decreased by 20% of claims amount
        assertEq(token.balanceOf(poolRe.getWallet()), poolReWalletBalanceBefore + expectedPoolContribution, "unexpected pool wallet balance");

        // check customer has unchanged balance
        assertEq(token.balanceOf(customer), customerBalanceBefore, "unexpected customer balance");
    }


    function test_reinsuranceCreatePayout() public {
        // GIVEN setup and active policy
        // checking reinsurance policy info
        assertEq(instanceReader.claims(poolRe.resinsurancePolicyNftId()), 0, "claims count of reinsurance policy not 0 (before)");

        uint256 sumInsured = 1000 * 10**token.decimals();
        uint256 lifetime = 30 * 24 * 3600;
        policyReNftId = _createPolicy(customer, sumInsured, lifetime);

        uint256 customerBalanceBefore = token.balanceOf(customer);
        uint256 poolWalletBalanceBefore = token.balanceOf(pool.getWallet());
        uint256 poolReWalletBalanceBefore = token.balanceOf(poolRe.getWallet());

        productRe.setAutoPayout(true);
        assertTrue(productRe.isAutoPayout(), "auto payout not set");

        // WHEN creating a claim
        uint256 claim = 100 * 10**token.decimals();
        ClaimId claimReId = _createClaim(policyReNftId, claim);

        // THEN

        // check claim info
        IPolicy.ClaimInfo memory claimInfo = instanceReader.getClaimInfo(
            policyReNftId, 
            claimReId);

        assertEq(claimInfo.payoutsCount, 1, "unexpected payouts count");
        assertEq(claimInfo.openPayoutsCount, 0, "unexpected open payouts count");

        // check reinsurance pool balance has been decreased by 80% of claims amount
        uint expectedPoolContribution = claim * 4 / 5;
        assertEq(token.balanceOf(pool.getWallet()), poolWalletBalanceBefore - expectedPoolContribution, "unexpected reinsurance pool wallet balance");

        // check pool balance has been decreased by 20% of claims amount
        uint expectedPoolReContribution = claim / 5;
        assertEq(token.balanceOf(poolRe.getWallet()), poolReWalletBalanceBefore - expectedPoolReContribution, "unexpected pool wallet balance");

        // check customer has been increased by claim amount
        assertEq(token.balanceOf(customer), customerBalanceBefore + claim, "unexpected customer balance");
    }


    function _createClaim(
        NftId policyNftId,
        uint256 claim
    )
        internal
        returns (ClaimId newClaimId)
    {
        // solhint-disable
        console.log("--- creating a claim");
        console.log("amount", claim);
        // solhint-enable

        Amount claimAmount = AmountLib.toAmount(claim);
        newClaimId = productRe.submitClaim(
            policyNftId, 
            claimAmount, 
            ""); // claim submission data

        productRe.confirmClaim(
            policyNftId, 
            newClaimId, 
            claimAmount, 
            ""); // claim process data

        // solhint-disable
        console.log("claim id", newClaimId.toInt());
        // solhint-enable
    }


    function _createPolicy(
        address policyHolder, 
        uint256 sumInsured, 
        uint256 lifetime
    )
        internal 
        returns (NftId newPolicyNftId)
    {
        // solhint-disable
        console.log("--- creating a policy");
        console.log("policy holder", policyHolder);
        console.log("lifetime", lifetime);
        console.log("sum insured", sumInsured);
        // solhint-enable

        // create allowance to pay for premium
        uint256 maxPremiumAmount = SUM_INSURED * 10**token.decimals() / 4;
        vm.startPrank(policyHolder);
        token.approve(instanceReader.getTokenHandler(productReNftId), maxPremiumAmount);
        vm.stopPrank();

        newPolicyNftId = productRe.createApplication(
            policyHolder, 
            riskReId, 
            sumInsured,
            SecondsLib.toSeconds(lifetime), 
            "", // application data
            bundleReNftId, 
            ReferralLib.zero());

        productRe.createPolicy(
            newPolicyNftId, 
            true, // require premium payment
            TimestampLib.blockTimestamp()); // activate policy now

        // solhint-disable
        console.log("nft id", newPolicyNftId.toInt());
        console.log("premium", instanceReader.getPolicyInfo(newPolicyNftId).premiumAmount.toInt());
        // solhint-enable
    }


    function _prepareProductWithReinsurance() internal {

        // solhint-disable
        console.log("--- reinsurance pool");
        console.log("active bundle", instanceReader.getActiveBundleNftId(poolNftId, 0).toInt());
        // solhint-enable

        // solhint-disable-next-line
        console.log("--- deploy and register product with reinsurace");

        vm.startPrank(productOwner);
        productRe = new ProductWithReinsurance(
            address(registry),
            instanceNftId,
            address(token),
            _getProductWithReinsuranceProductInfo(),
            _getSimpleFeeInfo(),
            new ProductWithReinsuranceAuthorization(),
            productOwner
        );
        vm.stopPrank();

        // instance owner registeres product with instance (and registry)
        vm.startPrank(instanceOwner);
        productReNftId = instance.registerProduct(address(productRe));
        vm.stopPrank();

        // solhint-disable
        console.log("product nft id", productReNftId.toInt());
        console.log("product component at", address(productRe));
        // solhint-enable

        // solhint-disable-next-line
        console.log("--- deploy and register pool with reinsurace");

        vm.startPrank(poolOwner);
        poolRe = new PoolWithReinsurance(
            address(registry),
            productReNftId,
            address(token),
            new PoolWithReinsuranceAuthorization(),
            poolOwner
        );
        vm.stopPrank();

        poolReNftId = _registerComponent(productRe, address(poolRe), "pool re");

        // solhint-disable-next-line
        console.log("--- fund investor and customer");

        vm.startPrank(registryOwner);
        token.transfer(investor, DEFAULT_BUNDLE_CAPITALIZATION * 10**token.decimals());
        token.transfer(customer, DEFAULT_CUSTOMER_FUNDS * 10**token.decimals());
        vm.stopPrank();

        vm.startPrank(investor);
        token.approve(instanceReader.getTokenHandler(poolReNftId), DEFAULT_BUNDLE_CAPITALIZATION * 10**token.decimals());

        // solhint-disable-next-line
        console.log("--- create bundle");

        (bundleReNftId,) = poolRe.createBundle(
            FeeLib.zero(), 
            DEFAULT_BUNDLE_CAPITALIZATION * 10**token.decimals(), 
            SecondsLib.toSeconds(DEFAULT_BUNDLE_LIFETIME), 
            ""
        );
        vm.stopPrank();

        // solhint-disable-next-line
        console.log("bundle nft id", bundleReNftId.toInt());

        // solhint-disable-next-line
        console.log("--- create risk");

        vm.startPrank(productOwner);
        riskReId = RiskIdLib.toRiskId("RiskWithReinsurance");
        productRe.createRisk(riskReId, "");
        vm.stopPrank();

        // solhint-disable-next-line
        console.log("risk id");
        // solhint-disable-next-line
        console.logBytes8(RiskId.unwrap(riskReId));

        // solhint-disable-next-line
        console.log("--- pool creating its reinsurance policy");

        poolRe.createReinsurance(product, 5 * SUM_INSURED * 10**token.decimals());

        // solhint-disable
        console.log("reinsurance policy nft id", poolRe.resinsurancePolicyNftId().toInt());
    }

    function _getProductWithReinsuranceProductInfo()
        internal
        view
        returns (IComponents.ProductInfo memory productInfo)
    {
        productInfo = _getSimpleProductInfo();
        productInfo.isProcessingFundedClaims = true;
        productInfo.expectedNumberOfOracles = 0;
        productInfo.oracleNftId = new NftId[](0);
    }   
}
