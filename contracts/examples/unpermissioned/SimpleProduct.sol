// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Amount, AmountLib} from "../../type/Amount.sol";
import {BasicProduct} from "../../product/BasicProduct.sol";
import {ClaimId} from "../../type/ClaimId.sol";
import {IAuthorization} from "../../authorization/IAuthorization.sol";
import {IComponents} from "../../instance/module/IComponents.sol";
import {IOracleService} from "../../oracle/IOracleService.sol";
import {ORACLE} from "../../type/ObjectType.sol";
import {NftId} from "../../type/NftId.sol";
import {PayoutId} from "../../type/PayoutId.sol";
import {ReferralId} from "../../type/Referral.sol";
import {RequestId} from "../../type/RequestId.sol";
import {RiskId} from "../../type/RiskId.sol";
import {Seconds} from "../../type/Seconds.sol";
import {SimpleOracle} from "./SimpleOracle.sol";
import {StateId} from "../../type/StateId.sol";
import {Timestamp, TimestampLib} from "../../type/Timestamp.sol";

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
        NftId instanceNftId,
        string memory name,
        address token,
        IComponents.ProductInfo memory productInfo,
        IComponents.FeeInfo memory feeInfo,
        IAuthorization authorization,
        address initialOwner
    )
    {
        initialize(
            registry,
            instanceNftId,
            name,
            token,
            productInfo,
            feeInfo,
            authorization,
            initialOwner); 
    }


    function initialize(
        address registry,
        NftId instanceNftid,
        string memory name,
        address token,
        IComponents.ProductInfo memory productInfo,
        IComponents.FeeInfo memory feeInfo,
        IAuthorization authorization,
        address initialOwner
    )
        public
        virtual
        initializer()
    {
        _initializeBasicProduct(
            registry,
            instanceNftid,
            name,
            token,
            productInfo,
            feeInfo,
            authorization,
            initialOwner); 

        _oracleService = IOracleService(_getServiceAddress(ORACLE()));
    }


    function createRisk(
        string memory id,
        bytes memory data
    ) public returns (RiskId) {
        return _createRisk(
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
        _createPolicy(applicationNftId, activateAt);
        if (requirePremiumPayment == true) {
            _collectPremium(applicationNftId, activateAt);
        }
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

    function adjustActivation(
        NftId policyNftId,
        Timestamp activateAt
    ) public {
        _adjustActivation(policyNftId, activateAt);
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

    function revokeClaim(
        NftId policyNftId,
        ClaimId claimId
    ) public {
        _revokeClaim(policyNftId, claimId);
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

    function cancelPayout(
        NftId policyNftId,
        PayoutId payoutId
    ) public {
        _cancelPayout(policyNftId, payoutId);
    }

    // TODO add test
    function createPayoutForBeneficiary(
        NftId policyNftId,
        ClaimId claimId,
        Amount amount,
        address beneficiary,
        bytes memory data
    ) public returns (PayoutId) {
        return _createPayoutForBeneficiary(policyNftId, claimId, amount, beneficiary, data);
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

    function approveTokenHandler(IERC20Metadata token, Amount amount) external restricted() onlyOwner() { _approveTokenHandler(token, amount); }
    function setLocked(bool locked) external onlyOwner() { _setLocked(locked); }
    function setWallet(address newWallet) external restricted() onlyOwner() { _setWallet(newWallet); }
}