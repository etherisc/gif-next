// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "../../contracts/type/Amount.sol";
import {ClaimId} from "../../contracts/type/ClaimId.sol";
import {Fee, FeeLib} from "../../contracts/type/Fee.sol";
import {IOracleService} from "../../contracts/oracle/IOracleService.sol";
import {ORACLE} from "../../contracts/type/ObjectType.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {PayoutId} from "../../contracts/type/PayoutId.sol";
import {Product} from "../../contracts/product/Product.sol";
import {ReferralId} from "../../contracts/type/Referral.sol";
import {RequestId} from "../../contracts/type/RequestId.sol";
import {RiskId} from "../../contracts/type/RiskId.sol";
import {StateId} from "../../contracts/type/StateId.sol";
import {Timestamp, Seconds} from "../../contracts/type/Timestamp.sol";

uint64 constant SPECIAL_ROLE_INT = 11111;

contract SimpleProduct is Product {

    event LogSimpleProductRequestFulfilled(RequestId requestId, string responseText, uint256 responseDataLength);

    IOracleService private _oracleService;

    constructor(
        address registry,
        NftId instanceNftid,
        address initialOwner,
        address token,
        bool isInterceptor,
        address pool,
        address distribution
    )
    {
        initialize(
            registry,
            instanceNftid,
            initialOwner,
            "SimpleProduct",
            token,
            isInterceptor,
            pool,
            distribution); 
    }


    function initialize(
        address registry,
        NftId instanceNftid,
        address initialOwner,
        string memory name,
        address token,
        bool isInterceptor,
        address pool,
        address distribution
    )
        public
        virtual
        initializer()
    {
        initializeProduct(
            registry,
            instanceNftid,
            initialOwner,
            name,
            token,
            isInterceptor,
            pool,
            distribution,
            "",
            ""); 

        _oracleService = IOracleService(_getServiceAddress(ORACLE()));
    }

    function createRisk(
        RiskId id,
        bytes memory data
    ) public {
        _createRisk(
            id,
            data
        );
    }

    function updateRisk(
        RiskId id,
        bytes memory data
    ) public {
        _updateRisk(
            id,
            data
        );
    }

    function updateRiskState(
        RiskId id,
        StateId state
    ) public {
        _updateRiskState(
            id,
            state
        );
    }

    function createApplication(
        address applicationOwner,
        RiskId riskId,
        uint256 sumInsuredAmount,
        Seconds lifetime,
        bytes memory applicationData,
        NftId bundleNftId,
        ReferralId referralId
    ) public returns (NftId nftId) {
        return _createApplication(
            applicationOwner,
            riskId,
            AmountLib.toAmount(sumInsuredAmount),
            lifetime,
            bundleNftId,
            referralId,
            applicationData
        );
    }

    function collateralize(
        NftId policyNftId,
        bool requirePremiumPayment,
        Timestamp activateAt
    ) public {
        _collateralize(policyNftId, requirePremiumPayment, activateAt);
    }

    function collectPremium(
        NftId policyNftId,
        Timestamp activateAt
    ) public {
        _collectPremium(policyNftId, activateAt);
    }

    function activate(
        NftId policyNftId,
        Timestamp activateAt
    ) public {
        _activate(policyNftId, activateAt);
    }

    function close(
        NftId policyNftId
    ) public {
        _close(policyNftId);
    }

    function submitClaim(
        NftId policyNftId,
        Amount claimAmount,
        bytes memory submissionData
    ) public returns (ClaimId) {
        return _submitClaim(policyNftId, claimAmount, submissionData);
    }

    function confirmClaim(
        NftId policyNftId,
        ClaimId claimId,
        Amount confirmedAmount,
        bytes memory processData
    ) public {
        _confirmClaim(policyNftId, claimId, confirmedAmount, processData);
    }

    function declineClaim(
        NftId policyNftId,
        ClaimId claimId,
        bytes memory processData
    ) public {
        _declineClaim(policyNftId, claimId, processData);
    }

    function closeClaim(
        NftId policyNftId,
        ClaimId claimId
    ) public {
        _closeClaim(policyNftId, claimId);
    }

    function createPayout(
        NftId policyNftId,
        ClaimId claimId,
        Amount amount,
        bytes memory data
    ) public returns (PayoutId) {
        return _createPayout(policyNftId, claimId, amount, data);
    }

    function processPayout(
        NftId policyNftId,
        PayoutId payoutId
    ) public {
        _processPayout(policyNftId, payoutId);
    }

    function createOracleTextRequest(
        NftId oracleNftId,
        string memory requestText,
        Timestamp expiryAt
    )
        public
        // restricted()
        returns (RequestId)
    {
        bytes memory requestData = abi.encode(requestText);

        return _oracleService.request(
            oracleNftId, 
            requestData, 
            expiryAt, 
            "fulfillOracleTextRequest");
    }

    function cancelOracleTextRequest(
        RequestId requestId
    )
        public
        // restricted() // 
    {
        _oracleService.cancel(requestId);
    }

    function fulfillOracleTextRequest(
        RequestId requestId,
        bytes memory responseData
    )
        public
        // restricted() // only oracle service
    {
        string memory responseText = abi.decode(responseData, (string));
        emit LogSimpleProductRequestFulfilled(requestId, responseText, responseData.length);
    }

    function doSomethingSpecial() 
        public 
        restricted()
        returns (bool) 
    {
        return true;
    }

    function doWhenNotLocked() 
        public 
        restricted()
        returns (bool) 
    {
        return true;
    }

    function getOracleService() public view returns (IOracleService) {
        return _oracleService;
    }
}