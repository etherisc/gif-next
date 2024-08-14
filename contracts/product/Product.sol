// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "../type/Amount.sol";
import {ClaimId} from "../type/ClaimId.sol";
import {IComponent} from "../shared/IComponent.sol";
import {Fee, FeeLib} from "../type/Fee.sol";
import {IRisk} from "../instance/module/IRisk.sol";
import {IApplicationService} from "./IApplicationService.sol";
import {IAuthorization} from "../authorization/IAuthorization.sol";
import {IComponentService} from "../shared/IComponentService.sol";
import {InstanceLinkedComponent} from "../shared/InstanceLinkedComponent.sol";
import {IInstanceLinkedComponent} from "../shared/IInstanceLinkedComponent.sol";
import {IPolicyService} from "./IPolicyService.sol";
import {IRiskService} from "./IRiskService.sol";
import {IClaimService} from "./IClaimService.sol";
import {IPricingService} from "./IPricingService.sol";
import {IProductComponent} from "./IProductComponent.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {ObjectType, COMPONENT, DISTRIBUTION, ORACLE, POOL, PRODUCT, BUNDLE, APPLICATION, POLICY, CLAIM, PRICE } from "../type/ObjectType.sol";
import {PayoutId} from "../type/PayoutId.sol";
import {COMPONENT, PRODUCT, APPLICATION, POLICY, CLAIM, PRICE, BUNDLE, RISK } from "../type/ObjectType.sol";
import {ReferralId} from "../type/Referral.sol";
import {RiskId, RiskIdLib} from "../type/RiskId.sol";
import {Seconds} from "../type/Seconds.sol";
import {StateId} from "../type/StateId.sol";
import {Timestamp} from "../type/Timestamp.sol";

import {IPolicy} from "../instance/module/IPolicy.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IDistributionComponent} from "../distribution/IDistributionComponent.sol";
import {IOracleComponent} from "../oracle/IOracleComponent.sol";
import {IPoolComponent} from "../pool/IPoolComponent.sol";

abstract contract Product is
    InstanceLinkedComponent, 
    IProductComponent
{
    // keccak256(abi.encode(uint256(keccak256("etherisc.storage.Product")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant PRODUCT_STORAGE_LOCATION_V1 = 0x0bb7aafdb8e380f81267337bc5b5dfdf76e6d3a380ecadb51ec665246d9d6800;

    struct ProductStorage {
        IComponents.ProductInfo _productInfo;
        IComponentService _componentService;
        IRiskService _riskService;
        IApplicationService _applicationService;
        IPolicyService _policyService;
        IClaimService _claimService;
        IPricingService _pricingService;
    }


    function registerComponent(address component)
        external
        virtual
        onlyOwner()
        returns (NftId componentNftId)
    {
        return _getProductStorage()._componentService.registerComponent(component);
    }


    function processFundedClaim(
        NftId policyNftId, 
        ClaimId claimId, 
        Amount availableAmount
    )
        external
        virtual
        restricted() // pool service role
        onlyNftOfType(policyNftId, POLICY())
    {
        // default implementation does nothing
    }


    function calculatePremium(
        Amount sumInsuredAmount,
        RiskId riskId,
        Seconds lifetime,
        bytes memory applicationData,
        NftId bundleNftId,
        ReferralId referralId
    )
        public 
        view 
        override 
        onlyNftOfType(bundleNftId, BUNDLE())
        returns (Amount premiumAmount)
    {
        IPolicy.PremiumInfo memory premium = _getProductStorage()._pricingService.calculatePremium(
            getNftId(),
            riskId,
            sumInsuredAmount,
            lifetime,
            applicationData,
            bundleNftId,
            referralId
        );

        return premium.premiumAmount;
    }

    function calculateNetPremium(
        Amount sumInsuredAmount,
        RiskId,
        Seconds,
        bytes memory
    )
        external
        view
        virtual override
        returns (Amount netPremiumAmount)
    {
        // default 10% of sum insured
        return AmountLib.toAmount(sumInsuredAmount.toInt() / 10);
    }


    function getInitialProductInfo()
        public 
        virtual 
        view 
        returns (IComponents.ProductInfo memory poolInfo)
    {
        return _getProductStorage()._productInfo;
    }


    function _initializeProduct(
        address registry,
        NftId instanceNftId,
        string memory name,
        address token,
        IComponents.ProductInfo memory productInfo,
        IAuthorization authorization,
        address initialOwner,
        bytes memory componentData // writeonly data that will saved in the object info record of the registry
    )
        internal
        virtual
        onlyInitializing()
    {
        _initializeInstanceLinkedComponent(
            registry, 
            instanceNftId, 
            name, 
            token, 
            PRODUCT(), 
            authorization, 
            productInfo.isInterceptingPolicyTransfers, 
            initialOwner, 
            componentData);

        ProductStorage storage $ = _getProductStorage();
        $._productInfo = productInfo;
        $._riskService = IRiskService(_getServiceAddress(RISK())); 
        $._applicationService = IApplicationService(_getServiceAddress(APPLICATION())); 
        $._policyService = IPolicyService(_getServiceAddress(POLICY())); 
        $._claimService = IClaimService(_getServiceAddress(CLAIM())); 
        $._pricingService = IPricingService(_getServiceAddress(PRICE()));
        $._componentService = IComponentService(_getServiceAddress(COMPONENT()));

        _registerInterface(type(IProductComponent).interfaceId);  
    }


    function _setFees(
        Fee memory productFee,
        Fee memory processingFee
    )
        internal
        virtual
    {
        _getProductStorage()._componentService.setProductFees(productFee, processingFee);
    }


    function _createRisk(
        RiskId id,
        bytes memory data
    )
        internal
        virtual
    {
        _getProductStorage()._riskService.createRisk(
            id,
            data
        );
    }

    function _updateRisk(
        RiskId id,
        bytes memory data
    )
        internal
        virtual
    {
        _getProductStorage()._riskService.updateRisk(
            id,
            data
        );
    }

    function _updateRiskState(
        RiskId id,
        StateId state
    )
        internal
        virtual
    {
        _getProductStorage()._riskService.updateRiskState(
            id,
            state
        );
    }


    function _createApplication(
        address applicationOwner,
        RiskId riskId,
        Amount sumInsuredAmount,
        Amount premiumAmount,
        Seconds lifetime,
        NftId bundleNftId,
        ReferralId referralId,
        bytes memory applicationData
    )
        internal
        virtual
        returns (NftId applicationNftId) 
    {
        return _getProductStorage()._applicationService.create(
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

    function _createPolicy(
        NftId applicationNftId,
        Timestamp activateAt
    )
        internal
        virtual
        returns (Amount premiumAmount)
    {
        premiumAmount = _getProductStorage()._policyService.createPolicy(
            applicationNftId, 
            activateAt);
    }

    function _decline(
        NftId policyNftId
    )
        internal
        virtual
    {
        _getProductStorage()._policyService.decline(
            policyNftId);
    }

    function _expire(
        NftId policyNftId,
        Timestamp expireAt
    )
        internal
        virtual
        returns (Timestamp expiredAt)
    {
        expiredAt = _getProductStorage()._policyService.expire(policyNftId, expireAt);
    }

    function _collectPremium(
        NftId policyNftId,
        Timestamp activateAt
    )
        internal
        virtual
    {
        _getProductStorage()._policyService.collectPremium(
            policyNftId, 
            activateAt);
    }

    function _activate(
        NftId policyNftId,
        Timestamp activateAt
    )
        internal
        virtual
    {
        _getProductStorage()._policyService.activate(
            policyNftId, 
            activateAt);
    }

    function _close(
        NftId policyNftId
    )
        internal
        virtual
    {
        _getProductStorage()._policyService.close(
            policyNftId);
    }

    function _submitClaim(
        NftId policyNftId,
        Amount claimAmount,
        bytes memory claimData
    )
        internal
        virtual
        returns(ClaimId)
    {
        return _getProductStorage()._claimService.submit(
            policyNftId,
            claimAmount,
            claimData);
    }

    function _confirmClaim(
        NftId policyNftId,
        ClaimId claimId,
        Amount confirmedAmount,
        bytes memory data
    )
        internal
        virtual
    {
        _getProductStorage()._claimService.confirm(
            policyNftId,
            claimId,
            confirmedAmount,
            data);
    }

    function _declineClaim(
        NftId policyNftId,
        ClaimId claimId,
        bytes memory data
    )
        internal
        virtual
    {
        _getProductStorage()._claimService.decline(
            policyNftId,
            claimId,
            data);
    }

    function _closeClaim(
        NftId policyNftId,
        ClaimId claimId
    )
        internal
        virtual
    {
        _getProductStorage()._claimService.close(
            policyNftId,
            claimId);
    }

    function _createPayout(
        NftId policyNftId,
        ClaimId claimId,
        Amount amount,
        bytes memory data
    )
        internal
        virtual
        returns (PayoutId)
    {
        return _getProductStorage()._claimService.createPayout(
            policyNftId, 
            claimId, 
            amount, 
            data);
    }

    function _createPayoutForBeneficiary(
        NftId policyNftId,
        ClaimId claimId,
        Amount amount,
        address beneficiary,
        bytes memory data
    )
        internal
        virtual
        returns (PayoutId)
    {
        return _getProductStorage()._claimService.createPayoutForBeneficiary(
            policyNftId, 
            claimId, 
            amount, 
            beneficiary,
            data);
    }

    function _processPayout(
        NftId policyNftId,
        PayoutId payoutId
    )
        internal
        virtual
    {
        _getProductStorage()._claimService.processPayout(
            policyNftId,
            payoutId);
    }

    function _toRiskId(string memory riskName) internal virtual pure returns (RiskId riskId) {
        return RiskIdLib.toRiskId(riskName);
    }

    function _getProductStorage() internal virtual pure returns (ProductStorage storage $) {
        assembly {
            $.slot := PRODUCT_STORAGE_LOCATION_V1
        }
    }
}