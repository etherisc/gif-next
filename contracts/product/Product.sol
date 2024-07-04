// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {ClaimId} from "../type/ClaimId.sol";
import {InstanceLinkedComponent} from "../shared/InstanceLinkedComponent.sol";
import {Fee, FeeLib} from "../type/Fee.sol";
import {IRisk} from "../instance/module/IRisk.sol";
import {IApplicationService} from "./IApplicationService.sol";
import {IAuthorization} from "../authorization/IAuthorization.sol";
import {IComponentService} from "../shared/IComponentService.sol";
import {IPolicyService} from "./IPolicyService.sol";
import {IProductService} from "./IProductService.sol";
import {IClaimService} from "./IClaimService.sol";
import {IPricingService} from "./IPricingService.sol";
import {IProductComponent} from "./IProductComponent.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {PayoutId} from "../type/PayoutId.sol";
import {COMPONENT, PRODUCT, APPLICATION, POLICY, CLAIM, PRICE } from "../type/ObjectType.sol";
import {ReferralId} from "../type/Referral.sol";
import {RiskId, RiskIdLib} from "../type/RiskId.sol";
import {Seconds} from "../type/Seconds.sol";
import {StateId} from "../type/StateId.sol";
import {Timestamp} from "../type/Timestamp.sol";

import {TokenHandler} from "../shared/TokenHandler.sol";

import {InstanceReader} from "../instance/InstanceReader.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {Pool} from "../pool/Pool.sol";
import {Distribution} from "../distribution/Distribution.sol";

abstract contract Product is
    InstanceLinkedComponent, 
    IProductComponent
{
    // keccak256(abi.encode(uint256(keccak256("etherisc.storage.Product")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant PRODUCT_STORAGE_LOCATION_V1 = 0x0bb7aafdb8e380f81267337bc5b5dfdf76e6d3a380ecadb51ec665246d9d6800;

    struct ProductStorage {
        IProductService _productService;
        IApplicationService _applicationService;
        IPolicyService _policyService;
        IClaimService _claimService;
        IPricingService _pricingService;
        IComponentService _componentService;
        NftId _poolNftId;
        NftId _distributionNftId;
        Pool _pool;
        Distribution _distribution;
    }


    function calculatePremium(
        Amount sumInsuredAmount,
        RiskId riskId,
        Seconds lifetime,
        bytes memory applicationData,
        NftId bundleNftId,
        ReferralId referralId
    )
        external 
        view 
        override 
        returns (Amount premiumAmount)
    {
        IPolicy.Premium memory premium = _getProductStorage()._pricingService.calculatePremium(
            getNftId(),
            riskId,
            sumInsuredAmount,
            lifetime,
            applicationData,
            bundleNftId,
            referralId
        );

        return AmountLib.toAmount(premium.premiumAmount);
    }

    function calculateNetPremium(
        Amount sumInsuredAmount,
        RiskId riskId,
        Seconds lifetime,
        bytes memory applicationData
    )
        external
        view
        virtual override
        returns (Amount netPremiumAmount)
    {
        // default 10% of sum insured
        return AmountLib.toAmount(sumInsuredAmount.toInt() / 10);
    }


    function register()
        external
        virtual
        onlyOwner()
    {
        _getProductStorage()._componentService.registerProduct();
        _approveTokenHandler(type(uint256).max);
    }


    function getInitialProductInfo()
        public 
        virtual 
        view 
        returns (IComponents.ProductInfo memory poolInfo)
    {
        ProductStorage storage $ = _getProductStorage();

        return IComponents.ProductInfo({
            distributionNftId: $._distributionNftId,
            poolNftId: $._poolNftId,
            productFee: FeeLib.zero(),
            processingFee: FeeLib.zero(),
            distributionFee: FeeLib.zero(),
            minDistributionOwnerFee: FeeLib.zero(),
            poolFee: FeeLib.zero(),
            stakingFee: FeeLib.zero(),
            performanceFee: FeeLib.zero()
        });
    }

    function getPoolNftId() external view override returns (NftId poolNftId) {
        return getRegistry().getNftId(address(_getProductStorage()._pool));
    }

    function getDistributionNftId() external view override returns (NftId distributionNftId) {
        return getRegistry().getNftId(address(_getProductStorage()._distribution));
    }

    function _initializeProduct(
        address registry,
        NftId instanceNftId,
        IAuthorization authorization,
        address initialOwner,
        string memory name,
        address token,
        bool isInterceptor,
        address pool,
        address distribution,
        bytes memory registryData, // writeonly data that will saved in the object info record of the registry
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
            isInterceptor, 
            initialOwner, 
            registryData, 
            componentData);

        ProductStorage storage $ = _getProductStorage();
        // TODO add validation
        // TODO refactor to go via registry ?
        $._productService = IProductService(_getServiceAddress(PRODUCT())); 
        $._applicationService = IApplicationService(_getServiceAddress(APPLICATION())); 
        $._policyService = IPolicyService(_getServiceAddress(POLICY())); 
        $._claimService = IClaimService(_getServiceAddress(CLAIM())); 
        $._pricingService = IPricingService(_getServiceAddress(PRICE()));
        $._componentService = IComponentService(_getServiceAddress(COMPONENT()));
        $._pool = Pool(pool);
        $._distribution = Distribution(distribution);
        $._poolNftId = getRegistry().getNftId(pool);
        $._distributionNftId = getRegistry().getNftId(distribution);

        registerInterface(type(IProductComponent).interfaceId);  
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
    ) internal {
        _getProductService().createRisk(
            id,
            data
        );
    }

    function _updateRisk(
        RiskId id,
        bytes memory data
    ) internal {
        _getProductService().updateRisk(
            id,
            data
        );
    }

    function _updateRiskState(
        RiskId id,
        StateId state
    ) internal {
        _getProductService().updateRiskState(
            id,
            state
        );
    }


    function _getRiskInfo(RiskId id) internal view returns (IRisk.RiskInfo memory info) {
        return getInstance().getInstanceReader().getRiskInfo(id);
    }


    function _createApplication(
        address applicationOwner,
        RiskId riskId,
        Amount sumInsuredAmount,
        Seconds lifetime,
        NftId bundleNftId,
        ReferralId referralId,
        bytes memory applicationData
    )
        internal
        returns (NftId applicationNftId) 
    {
        return _getProductStorage()._applicationService.create(
            applicationOwner,
            riskId,
            sumInsuredAmount,
            lifetime,
            bundleNftId,
            referralId,
            applicationData
        );
    }

    function _collateralize(
        NftId policyNftId,
        bool requirePremiumPayment,
        Timestamp activateAt
    )
        internal
    {
        _getProductStorage()._policyService.collateralize(
            policyNftId, 
            requirePremiumPayment, 
            activateAt);
    }

    function _decline(
        NftId policyNftId
    )
        internal
    {
        _getProductStorage()._policyService.decline(
            policyNftId);
    }

    function _expire(
        NftId policyNftId,
        Timestamp expireAt
    )
        internal
    {
        _getProductStorage()._policyService.expire(policyNftId, expireAt);
    }

    function _collectPremium(
        NftId policyNftId,
        Timestamp activateAt
    )
        internal
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
    {
        _getProductStorage()._policyService.activate(
            policyNftId, 
            activateAt);
    }

    function _close(
        NftId policyNftId
    )
        internal
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
        returns (PayoutId)
    {
        return _getProductStorage()._claimService.createPayout(
            policyNftId, 
            claimId, 
            amount, 
            data);
    }

    function _processPayout(
        NftId policyNftId,
        PayoutId payoutId
    )
        internal
    {
        _getProductStorage()._claimService.processPayout(
            policyNftId,
            payoutId);
    }

    function _toRiskId(string memory riskName) internal pure returns (RiskId riskId) {
        return RiskIdLib.toRiskId(riskName);
    }

    function _getProductStorage() private pure returns (ProductStorage storage $) {
        assembly {
            $.slot := PRODUCT_STORAGE_LOCATION_V1
        }
    }

    function _getProductService() internal view returns (IProductService) {
        return _getProductStorage()._productService;
    }
}