// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Vm, console} from "../../lib/forge-std/src/Test.sol";

import {GifTest} from "../base/GifTest.sol";
import {Amount, AmountLib} from "../../contracts/type/Amount.sol";
import {DistributionWithReinsuranceAuthorization} from "./DistributionWithReinsuranceAuthorization.sol";
import {PoolWithReinsuranceAuthorization} from "./PoolWithReinsuranceAuthorization.sol";
import {ProductWithReinsuranceAuthorization} from "./ProductWithReinsuranceAuthorization.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {ClaimId, ClaimIdLib} from "../../contracts/type/ClaimId.sol";
import {ContractLib} from "../../contracts/shared/ContractLib.sol";
import {PRODUCT_OWNER_ROLE} from "../../contracts/type/RoleId.sol";
import {ProductWithReinsurance} from "./ProductWithReinsurance.sol";
import {PoolWithReinsurance} from "./PoolWithReinsurance.sol";
import {SimpleDistribution} from "../../contracts/examples/unpermissioned/SimpleDistribution.sol";
import {SimpleProduct} from "../../contracts/examples/unpermissioned/SimpleProduct.sol";
import {SimplePool} from "../../contracts/examples/unpermissioned/SimplePool.sol";
import {IComponents} from "../../contracts/instance/module/IComponents.sol";
import {ILifecycle} from "../../contracts/shared/ILifecycle.sol";
import {IPolicy} from "../../contracts/instance/module/IPolicy.sol";
import {IPolicyHolder} from "../../contracts/shared/IPolicyHolder.sol";
import {IBundle} from "../../contracts/instance/module/IBundle.sol";
import {Fee, FeeLib} from "../../contracts/type/Fee.sol";
import {UFixedLib} from "../../contracts/type/UFixed.sol";
import {Seconds, SecondsLib} from "../../contracts/type/Seconds.sol";
import {Timestamp, TimestampLib, zeroTimestamp} from "../../contracts/type/Timestamp.sol";
import {IPolicyService} from "../../contracts/product/IPolicyService.sol";
import {IRisk} from "../../contracts/instance/module/IRisk.sol";
import {PayoutId, PayoutIdLib} from "../../contracts/type/PayoutId.sol";
import {POLICY} from "../../contracts/type/ObjectType.sol";
import {RiskId, RiskIdLib, eqRiskId} from "../../contracts/type/RiskId.sol";
import {ReferralLib} from "../../contracts/type/Referral.sol";
import {SUBMITTED, ACTIVE, COLLATERALIZED, CONFIRMED, PAID, DECLINED, CLOSED} from "../../contracts/type/StateId.sol";
import {StateId} from "../../contracts/type/StateId.sol";


contract ProductWithReinsuranceTest
    is GifTest
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


    function test_reinsuranceSetUp() public {
        assertTrue(productNftId.gtz(), "product zero (reinsurance)");
        assertTrue(poolNftId.gtz(), "pool zero (reinsurance)");

        assertTrue(productReNftId.gtz(), "product zero (insurance)");
        assertTrue(poolReNftId.gtz(), "pool zero (insurance)");

        assertEq(poolRe.reinsuranceProduct().getNftId().toInt(), product.getNftId().toInt(), "unexpected reinsurance product");

        console.log("reinsurance bundle balance", instanceReader.getBalanceAmount(bundleNftId).toInt());
        console.log("reinsurance bundle locked", instanceReader.getLockedAmount(bundleNftId).toInt());

        console.log("insurance bundle balance", instanceReader.getBalanceAmount(bundleReNftId).toInt());
        console.log("insurance bundle locked", instanceReader.getLockedAmount(bundleReNftId).toInt());

        // test pool with reinsurance
        IComponents.PoolInfo memory poolReInfo = instanceReader.getPoolInfo(poolReNftId);
        assertTrue(poolReInfo.isProcessingConfirmedClaims, "not processing confirmed claims");
        assertTrue(poolReInfo.collateralizationLevel == UFixedLib.one(), "collateralization level not 100%");
        assertTrue(poolReInfo.retentionLevel == UFixedLib.toUFixed(2, -1), "retention level not 20%");

        // check reinsurance policy
        assertTrue(poolRe.resinsurancePolicyNftId().gtz(), "reinsurance policy zero");
        assertEq(registry.ownerOf(poolRe.resinsurancePolicyNftId()), address(poolRe), "unexpected reinsurance policy owner");
        assertTrue(instanceReader.policyIsActive(poolRe.resinsurancePolicyNftId()), "reinsurance policy not active");

        // checking reinsurance policy info
        IPolicy.PolicyInfo memory reinsurancePolicyInfo = instanceReader.getPolicyInfo(poolRe.resinsurancePolicyNftId());
        console.log("reinsurance policy sum insured", reinsurancePolicyInfo.sumInsuredAmount.toInt());

        assertEq(reinsurancePolicyInfo.sumInsuredAmount.toInt(), 5000 * 10**token.decimals(), "unexpected reinsurance policy sum insured");
        assertEq(reinsurancePolicyInfo.claimsCount, 0, "claims count not 0");
    }


    function test_reinsuranceCreatePolicy() public {
        console.log("insurance bundle locked (before)", instanceReader.getLockedAmount(bundleReNftId).toInt());

        uint256 sumInsured = 1000 * 10**token.decimals();
        uint256 lifetime = 30 * 24 * 3600;
        productReNftId = _createPolicy(customer, sumInsured, lifetime);

        console.log("insurance bundle locked (after)", instanceReader.getLockedAmount(bundleReNftId).toInt());
        console.log("policy sum insured (after)", sumInsured);

        // retention level 20% -> locally only 20% of sum insured locked, rest covered by reinsurance
        assertEq(instanceReader.getLockedAmount(bundleReNftId).toInt(), sumInsured / 5);
    }


    function setUp() public override {
        super.setUp();

        // reinsurance product
        _prepareProduct();  

        // setup product with reinsurance
        _prepareProductWithReinsurance();
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

        // solhint-disable-next-line
        console.log("policy nft id", newPolicyNftId.toInt());
    }


    function _prepareProductWithReinsurance() internal {

        // solhint-disable
        console.log("--- reinsurance pool");
        console.log("active bundle", instanceReader.getActiveBundleNftId(poolNftId, 0).toInt());
        // solhint-enable

        // solhint-disable-next-line
        console.log("--- deploy and register distribution with reinsurance");

        vm.startPrank(distributionOwner);
        distributionRe = new SimpleDistribution(
            address(registry),
            instanceNftId,
            new DistributionWithReinsuranceAuthorization(),
            distributionOwner,
            address(token));

        distributionRe.register();
        distributionReNftId = distributionRe.getNftId();
        vm.stopPrank();

        // solhint-disable
        console.log("distribution nft id", distributionReNftId.toInt());
        console.log("distribution component at", address(distributionRe));
        // solhint-enable

        // deploy and register pool
        // solhint-disable-next-line
        console.log("--- deploy and register pool with reinsurace");

        vm.startPrank(poolOwner);
        poolRe = new PoolWithReinsurance(
            address(registry),
            instanceNftId,
            address(token),
            new PoolWithReinsuranceAuthorization(),
            poolOwner
        );

        poolRe.register();
        poolReNftId = poolRe.getNftId();
        pool.approveTokenHandler(AmountLib.max());
        vm.stopPrank();

        // solhint-disable
        console.log("pool nft id", poolReNftId.toInt());
        console.log("pool component at", address(poolRe));
        // solhint-enable

        // solhint-disable-next-line
        console.log("--- deploy and register product with reinsurace");

        vm.startPrank(productOwner);
        productRe = new ProductWithReinsurance(
            address(registry),
            instanceNftId,
            new ProductWithReinsuranceAuthorization(),
            productOwner,
            address(token),
            address(poolRe), 
            address(distributionRe)
        );
        
        productRe.register();
        productReNftId = productRe.getNftId();
        vm.stopPrank();
        
        // solhint-disable
        console.log("product nft id", productReNftId.toInt());
        console.log("product component at", address(productRe));
        // solhint-enable

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
        console.logBytes8(RiskId.unwrap(riskReId));

        // solhint-disable-next-line
        console.log("--- pool creating its reinsurance policy");

        poolRe.createReinsurance(product, 5 * SUM_INSURED * 10**token.decimals());

        // solhint-disable
        console.log("reinsurance policy nft id", poolRe.resinsurancePolicyNftId().toInt());

    }
}
