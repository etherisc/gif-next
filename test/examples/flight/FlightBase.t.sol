// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../../lib/forge-std/src/Test.sol";

import {IOracle} from "../../../contracts/oracle/IOracle.sol";
import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";

import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {FlightMessageVerifier} from "../../../contracts/examples/flight/FlightMessageVerifier.sol";
import {FlightOracle} from "../../../contracts/examples/flight/FlightOracle.sol";
import {FlightOracleAuthorization} from "../../../contracts/examples/flight/FlightOracleAuthorization.sol";
import {FlightPool} from "../../../contracts/examples/flight/FlightPool.sol";
import {FlightPoolAuthorization} from "../../../contracts/examples/flight/FlightPoolAuthorization.sol";
import {FlightProduct} from "../../../contracts/examples/flight/FlightProduct.sol";
import {FlightProductManager} from "../../../contracts/examples/flight/FlightProductManager.sol";
import {FlightProductAuthorization} from "../../../contracts/examples/flight/FlightProductAuthorization.sol";
import {FlightUSD} from "../../../contracts/examples/flight/FlightUSD.sol";
import {GifTest} from "../../base/GifTest.sol";
import {NftId} from "../../../contracts/type/NftId.sol";
import {RequestId} from "../../../contracts/type/RequestId.sol";
import {RiskId} from "../../../contracts/type/RiskId.sol";
import {RoleId} from "../../../contracts/type/RoleId.sol";
import {Seconds, SecondsLib} from "../../../contracts/type/Seconds.sol";
import {SigUtils} from "./SigUtils.sol";
import {Str, StrLib} from "../../../contracts/type/String.sol";
import {Timestamp, TimestampLib} from "../../../contracts/type/Timestamp.sol";
import {VersionPartLib} from "../../../contracts/type/Version.sol";


contract FlightBaseTest is GifTest {


    SigUtils internal sigUtils;

    address public flightOwner = makeAddr("flightOwner");

    FlightUSD public flightUSD;
    FlightOracle public flightOracle;
    FlightPool public flightPool;

    FlightProductManager public flightProductManager;
    FlightProduct public flightProduct;

    NftId public flightOracleNftId;
    NftId public flightPoolNftId;
    NftId public flightProductNftId;

    FlightMessageVerifier public flightMessageVerifier;
    address public verifierOwner = makeAddr("verifierOwner");
    address public statisticsProvider = makeAddr("statisticsProvider");
    address public statusProvider = makeAddr("statusProvider");

    uint256 public customerPrivateKey = 0xB0B;

    address public dataSigner;
    uint256 public dataSignerPrivateKey;

    function setUp() public virtual override {
        customer = vm.addr(customerPrivateKey);
        
        super.setUp();
        
        _deployFlightUSD();
        _deployFlightProductAndVerifier();
        _deployFlightOracle();
        _deployFlightPool();

        // fetches oracle nft id via instance
        flightProduct.setOracleNftId();

        // do some initial funding
        _initialFundAccounts();

        sigUtils = new SigUtils(flightUSD.DOMAIN_SEPARATOR());
    }


    function _createPermitWithSignature(
        address policyHolder,
        Amount premiumAmount,
        uint256 policyHolderPrivateKey,
        uint256 nonce
    )
        internal
        view
        returns (FlightProduct.PermitData memory permit)
    {
        SigUtils.Permit memory suPermit = SigUtils.Permit({
            owner: policyHolder,
            spender: address(flightProduct.getTokenHandler()),
            value: premiumAmount.toInt(),
            nonce: nonce,
            deadline: TimestampLib.current().toInt() + 3600
        });

        bytes32 digest = sigUtils.getTypedDataHash(suPermit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(policyHolderPrivateKey, digest);

        permit.owner = policyHolder;
        permit.spender = address(flightProduct.getTokenHandler());
        permit.value = premiumAmount.toInt();
        permit.deadline = TimestampLib.current().toInt() + 3600;
        permit.v = v;
        permit.r = r;
        permit.s = s;
    }


    function _createPolicySimple(
        Str flightData, // example: "LX 180 ZRH BKK 20241104"
        Timestamp departureTime,
        Timestamp arrivalTime,
        uint256 [6] memory statistics,
        FlightProduct.PermitData memory permit
    )
        internal
        returns (NftId policyNftId)
    {
        return _createPolicy(
            flightData,
            departureTime,
            "departure date time local timezone",
            arrivalTime,
            "arrival date time local timezome",
            statistics,
            permit
        );
    }


    function _createPolicy(
        Str flightData, // example: "LX 180 ZRH BKK 20241104"
        Timestamp departureTime,
        string memory departureTimeLocal, // example "2024-10-14T10:10:00.000 Europe/Zurich"
        Timestamp arrivalTime,
        string memory arrivalTimeLocal, // example "2024-10-14T10:10:00.000 Asia/Seoul"
        uint256 [6] memory statistics,
        FlightProduct.PermitData memory permit
    )
        internal
        returns (NftId policyNftId)
    {
        (, policyNftId) = flightProduct.createPolicyWithPermit(
            permit,
            FlightProduct.ApplicationData({
                flightData: flightData,
                departureTime: departureTime,
                departureTimeLocal: departureTimeLocal,
                arrivalTime: arrivalTime,
                arrivalTimeLocal: arrivalTimeLocal,
                premiumAmount: AmountLib.toAmount(permit.value),
                statistics: statistics
            })
        );
    }


    function _deployFlightUSD() internal {
        // deploy fire token
        vm.startPrank(flightOwner);
        flightUSD = new FlightUSD();
        vm.stopPrank();

        // whitelist fire token and make it active for release 3
        vm.startPrank(registryOwner);
        tokenRegistry.registerToken(address(flightUSD));
        tokenRegistry.setActiveForVersion(
            currentChainId, 
            address(flightUSD), 
            VersionPartLib.toVersionPart(3),
            true);
        vm.stopPrank();
    }


    function _deployFlightProductAndVerifier() internal {
        // setup signer infrastructure
        (dataSigner, dataSignerPrivateKey) = makeAddrAndKey("dataSigner");

        vm.startPrank(verifierOwner);
        flightMessageVerifier = new FlightMessageVerifier();
        flightMessageVerifier.setExpectedSigner(dataSigner);
        vm.stopPrank();

        vm.startPrank(flightOwner);
        FlightProductAuthorization productAuthz = new FlightProductAuthorization("FlightProduct");
        // flightProduct = new FlightProduct(
        //     address(registry),
        //     instanceNftId,
        //     "FlightProduct",
        //     productAuthz
        // );

        flightProductManager = new FlightProductManager(
            address(registry),
            instanceNftId,
            "FlightProduct",
            productAuthz);

        flightProduct = flightProductManager.getFlightProduct();

        vm.stopPrank();

        // instance owner registeres fire product with instance (and registry)
        vm.startPrank(instanceOwner);
        flightProductNftId = instance.registerProduct(
            address(flightProduct), 
            address(flightUSD));

        // grant statistics provider role to statistics provider
        (RoleId statisticProviderRoleId, bool exists) = instanceReader.getRoleForName(
            productAuthz.STATISTICS_PROVIDER_ROLE_NAME());

        assertTrue(exists, "role STATISTICS_PROVIDER_ROLE_NAME missing");
        instance.grantRole(statisticProviderRoleId, statisticsProvider);
        vm.stopPrank();

        // complete setup
        vm.startPrank(flightOwner);
        flightProduct.setConstants(
            AmountLib.toAmount(15 * 10 ** flightUSD.decimals()), // 15 USD min premium
            AmountLib.toAmount(15 * 10 ** flightUSD.decimals()), // 15 USD max premium
            AmountLib.toAmount(200 * 10 ** flightUSD.decimals()), // 200 USD max payout
            AmountLib.toAmount(600 * 10 ** flightUSD.decimals()), // 600 USD max total payout
            SecondsLib.fromDays(14), // min time before departure
            SecondsLib.fromDays(90), // max time before departure
            5 // max policies to process
        );
        vm.stopPrank();
    }


    function _deployFlightPool() internal {
        vm.startPrank(flightOwner);
        FlightPoolAuthorization poolAuthz = new FlightPoolAuthorization("FlightPool");
        flightPool = new FlightPool(
            address(registry),
            flightProductNftId,
            "FlightPool",
            poolAuthz
        );
        vm.stopPrank();

        flightPoolNftId = _registerComponent(
            flightOwner, 
            flightProduct, 
            address(flightPool), 
            "flightPool");
    }


    function _deployFlightOracle() internal {
        vm.startPrank(flightOwner);
        FlightOracleAuthorization oracleAuthz = new FlightOracleAuthorization("FlightOracle", COMMIT_HASH);
        flightOracle = new FlightOracle(
            address(registry),
            flightProductNftId,
            "FlightOracle",
            oracleAuthz
        );
        vm.stopPrank();

        flightOracleNftId = _registerComponent(
            flightOwner, 
            flightProduct, 
            address(flightOracle), 
            "FlightOracle");

        // grant status provider role to status provider
        (RoleId statusProviderRoleId, bool exists) = instanceReader.getRoleForName(
            oracleAuthz.STATUS_PROVIDER_ROLE_NAME());

        vm.startPrank(instanceOwner);
        instance.grantRole(statusProviderRoleId, statusProvider);
        vm.stopPrank();
    }


    function _getSignature(
        uint256 signerPrivateKey,
        Str flightData,
        Timestamp departureTime,
        Timestamp arrivalTime,
        Amount premiumAmount,
        uint256[6] memory statistics
    )
        internal 
        view 
        returns (
            uint8 v, 
            bytes32 r, 
            bytes32 s
        )
    {
        bytes32 ratingsHash = flightMessageVerifier.getRatingsHash(
            flightData, 
            departureTime, 
            arrivalTime, 
            premiumAmount, 
            statistics);

        (v, r, s) = vm.sign(signerPrivateKey, ratingsHash);
    }


    function _createInitialBundle() internal returns (NftId bundleNftId) {
        vm.startPrank(flightOwner);
        Amount investAmount = AmountLib.toAmount(10000000 * 10 ** 6);
        flightUSD.approve(
            address(flightPool.getTokenHandler()), 
            investAmount.toInt());
        bundleNftId = flightPool.createBundle(investAmount);
        vm.stopPrank();
    }


    function _initialFundAccounts() internal {
        _fundAccount(flightOwner, 100000 * 10 ** flightUSD.decimals());
        _fundAccount(customer, 10000 * 10 ** flightUSD.decimals());
    }


    function _fundAccount(address account, uint256 amount) internal {
        vm.startPrank(flightOwner);
        flightUSD.transfer(account, amount);
        vm.stopPrank();
    }


    function _printStatusRequest(FlightOracle.FlightStatusRequest memory statusRequest) internal {
        // solhint-disable
        console.log("FlightStatusRequest (requestData)", statusRequest.riskId.toInt());
        console.log("- riskId", statusRequest.riskId.toInt());
        console.log("- flightData", statusRequest.flightData.toString());
        console.log("- departureTime", statusRequest.departureTime.toInt());
        // solhint-enable
    }


    function _printRisk(RiskId riskId, FlightProduct.FlightRisk memory flightRisk) internal {
        // solhint-disable
        console.log("riskId", riskId.toInt());
        console.log("- flightData", flightRisk.flightData.toString());
        console.log("- departureTime", flightRisk.departureTime.toInt());
        console.log("- arrivalTime", flightRisk.arrivalTime.toInt());
        console.log("- delayMinutes", flightRisk.delayMinutes);
        console.log("- status", uint8(flightRisk.status));
        console.log("- sumOfSumInsuredAmounts", flightRisk.sumOfSumInsuredAmounts.toInt());
        // solhint-enable
    }


    function _printRequest(RequestId requestId, IOracle.RequestInfo memory requestInfo) internal {
        // solhint-disable
        console.log("requestId", requestId.toInt());
        console.log("- state", instanceReader.getRequestState(requestId).toInt());
        console.log("- requesterNftId", requestInfo.requesterNftId.toInt());
        console.log("- oracleNftId", requestInfo.oracleNftId.toInt());
        console.log("- isCancelled", requestInfo.isCancelled);
        console.log("- respondedAt", requestInfo.respondedAt.toInt());
        console.log("- expiredAt", requestInfo.expiredAt.toInt());
        console.log("- callbackMethodName", requestInfo.callbackMethodName);
        console.log("- requestData.length", requestInfo.requestData.length);
        console.log("- responseData.length", requestInfo.responseData.length);
        // solhint-enable
    }


    function _printPolicy(NftId policyNftId, IPolicy.PolicyInfo memory policyInfo) internal {
        // solhint-disable
        console.log("policy", policyNftId.toInt());
        console.log("- productNftId", policyInfo.productNftId.toInt());
        console.log("- bundleNftId", policyInfo.bundleNftId.toInt());
        console.log("- riskId referralId", policyInfo.riskId.toInt(), policyInfo.referralId.toInt());
        console.log("- activatedAt lifetime", policyInfo.activatedAt.toInt(), policyInfo.lifetime.toInt());
        console.log("- expiredAt closedAt", policyInfo.expiredAt.toInt(), policyInfo.closedAt.toInt());
        console.log("- sumInsuredAmount", policyInfo.sumInsuredAmount.toInt());
        console.log("- premiumAmount", policyInfo.premiumAmount.toInt());
        console.log("- claimsCount claimAmount", policyInfo.claimsCount, policyInfo.claimAmount.toInt());
        console.log("- payoutAmount", policyInfo.payoutAmount.toInt());
        // solhint-enable
    }


    function _printPremium(NftId policyNftId, IPolicy.PremiumInfo memory premiumInfo) internal {
        // solhint-disable
        console.log("premium", policyNftId.toInt());
        console.log("- premiumAmount", premiumInfo.premiumAmount.toInt());
        console.log("- netPremiumAmount", premiumInfo.netPremiumAmount.toInt());
        console.log("- productFeeAmount", premiumInfo.productFeeAmount.toInt());
        console.log("- distributionFeeAndCommissionAmount", premiumInfo.distributionFeeAndCommissionAmount.toInt());
        console.log("- poolPremiumAndFeeAmount", premiumInfo.poolPremiumAndFeeAmount.toInt());
        console.log("- discountAmount", premiumInfo.discountAmount.toInt());
        // solhint-enable
    }
}