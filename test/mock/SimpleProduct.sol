// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "../../contracts/type/Amount.sol";
import {BasicProduct} from "../../contracts/product/BasicProduct.sol";
import {BasicProductAuthorization} from "../../contracts/product/BasicProductAuthorization.sol";
import {ClaimId} from "../../contracts/type/ClaimId.sol";
import {Fee, FeeLib} from "../../contracts/type/Fee.sol";
import {IAuthorization} from "../../contracts/authorization/IAuthorization.sol";
import {IOracleService} from "../../contracts/oracle/IOracleService.sol";
import {ORACLE} from "../../contracts/type/ObjectType.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {PayoutId} from "../../contracts/type/PayoutId.sol";
import {ReferralId} from "../../contracts/type/Referral.sol";
import {RequestId} from "../../contracts/type/RequestId.sol";
import {RiskId} from "../../contracts/type/RiskId.sol";
import {Seconds} from "../../contracts/type/Seconds.sol";
import {SimpleOracle} from "./SimpleOracle.sol";
import {StateId} from "../../contracts/type/StateId.sol";
import {Timestamp, TimestampLib} from "../../contracts/type/Timestamp.sol";

uint64 constant SPECIAL_ROLE_INT = 11111;

contract SimpleProduct is 
    BasicProduct
{

    event LogSimpleProductRequestAsyncFulfilled(RequestId requestId, string responseText, uint256 responseDataLength);
    event LogSimpleProductRequestSyncFulfilled(RequestId requestId, string responseText, uint256 responseDataLength);

    error ErrorSimpleProductRevertedWhileProcessingResponse(RequestId requestId);

    IOracleService private _oracleService;

    constructor(
        address registry,
        NftId instanceNftid,
        IAuthorization authorization,
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
            authorization,
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
        IAuthorization authorization,
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
        _initializeBasicProduct(
            registry,
            instanceNftid,
            authorization,
            initialOwner,
            name,
            token,
            isInterceptor,
            pool,
            distribution); 

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
        uint256 sumInsured,
        Seconds lifetime,
        bytes memory applicationData,
        NftId bundleNftId,
        ReferralId referralId
    )
        public
        returns (NftId nftId)
    {
        Amount sumInsuredAmount = AmountLib.toAmount(sumInsured);
        Amount premiumAmount = calculatePremium(
            sumInsuredAmount,
            riskId,
            lifetime,
            applicationData,
            bundleNftId,
            referralId);

        return _createApplication(
            applicationOwner,
            riskId,
            sumInsuredAmount,
            premiumAmount,
            lifetime,
            bundleNftId,
            referralId,
            applicationData
        );
    }

    function createPolicy(
        NftId applicationNftId,
        bool requirePremiumPayment,
        Timestamp activateAt
    ) public {
        _createPolicy(applicationNftId, requirePremiumPayment, activateAt);
    }

    function decline(
        NftId policyNftId
    ) public {
        _decline(policyNftId);
    }

    function expire(
        NftId policyNftId,
        Timestamp expireAt
    ) 
        public 
        returns (Timestamp)
    {
        return _expire(policyNftId, expireAt);
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

    function createOracleRequest(
        NftId oracleNftId,
        string memory requestText,
        Timestamp expiryAt,
        bool synchronous
    )
        public
        // restricted()
        returns (RequestId)
    {
        bytes memory requestData = abi.encode(SimpleOracle.SimpleRequest(
            synchronous,
            requestText));

        if (synchronous) {
            return _oracleService.request(
                oracleNftId, 
                requestData, 
                expiryAt, 
                "fulfillOracleRequestSync");
        } else {
            return _oracleService.request(
                oracleNftId, 
                requestData, 
                expiryAt, 
                "fulfillOracleRequestAsync");
        }
    }

    function cancelOracleRequest(
        RequestId requestId
    )
        public
        // restricted() // 
    {
        _oracleService.cancel(requestId);
    }

    function fulfillOracleRequestSync(
        RequestId requestId,
        bytes memory responseData
    )
        public
        // restricted() // only oracle service
    {
        string memory responseText = abi.decode(responseData, (string));
        emit LogSimpleProductRequestSyncFulfilled(requestId, responseText, bytes(responseText).length);
    }

    function fulfillOracleRequestAsync(
        RequestId requestId,
        bytes memory responseData
    )
        public
        // restricted() // only oracle service
    {
        SimpleOracle.SimpleResponse memory response = abi.decode(
            responseData, (SimpleOracle.SimpleResponse));

        if (response.revertInCall && response.revertUntil >= TimestampLib.blockTimestamp()) {
            revert ErrorSimpleProductRevertedWhileProcessingResponse(requestId);
        }

        emit LogSimpleProductRequestAsyncFulfilled(requestId, response.text, bytes(response.text).length);
    }


    function resend(
        RequestId requestId
    )
        public
        // restricted() // 
    {
        _oracleService.resend(requestId);
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