// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Amount} from "../types/Amount.sol";
import {ClaimId} from "../types/ClaimId.sol";
import {Component} from "./Component.sol";
import {Fee} from "../types/Fee.sol";
import {IRisk} from "../instance/module/IRisk.sol";
import {IApplicationService} from "../instance/service/IApplicationService.sol";
import {IPolicyService} from "../instance/service/IPolicyService.sol";
import {IProductService} from "../instance/service/IProductService.sol";
import {IClaimService} from "../instance/service/IClaimService.sol";
import {IProductComponent} from "./IProductComponent.sol";
import {NftId, NftIdLib} from "../types/NftId.sol";
import {PayoutId} from "../types/PayoutId.sol";
import {PRODUCT, APPLICATION, POLICY, CLAIM } from "../types/ObjectType.sol";
import {ReferralId} from "../types/Referral.sol";
import {RiskId, RiskIdLib} from "../types/RiskId.sol";
import {Seconds} from "../types/Seconds.sol";
import {StateId} from "../types/StateId.sol";
import {Timestamp} from "../types/Timestamp.sol";

import {TokenHandler} from "../shared/TokenHandler.sol";

import {InstanceReader} from "../instance/InstanceReader.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";
import {ISetup} from "../instance/module/ISetup.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {Pool} from "../components/Pool.sol";
import {Distribution} from "../components/Distribution.sol";

abstract contract Product is
    Component, 
    IProductComponent
{
    // keccak256(abi.encode(uint256(keccak256("etherisc.storage.Product")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant PRODUCT_STORAGE_LOCATION_V1 = 0x0bb7aafdb8e380f81267337bc5b5dfdf76e6d3a380ecadb51ec665246d9d6800;

    struct ProductStorage {
        IProductService _productService;
        IApplicationService _applicationService;
        IPolicyService _policyService;
        IClaimService _claimService;
        Pool _pool;
        Distribution _distribution;
        Fee _initialProductFee;
        Fee _initialProcessingFee;
        TokenHandler _tokenHandler;
        NftId _poolNftId;
        NftId _distributionNftId;
    }

    function initializeProduct(
        address registry,
        NftId instanceNftId,
        string memory name,
        address token,
        bool isInterceptor,
        address pool,
        address distribution,
        Fee memory productFee,
        Fee memory processingFee,
        address initialOwner,
        bytes memory registryData // writeonly data that will saved in the object info record of the registry
    )
        public
        virtual
        onlyInitializing()
    {
        initializeComponent(registry, instanceNftId, name, token, PRODUCT(), isInterceptor, initialOwner, registryData);

        ProductStorage storage $ = _getProductStorage();
        // TODO add validation
        // TODO refactor to go via registry ?
        $._productService = IProductService(_getServiceAddress(PRODUCT())); 
        $._applicationService = IApplicationService(_getServiceAddress(APPLICATION())); 
        $._policyService = IPolicyService(_getServiceAddress(POLICY())); 
        $._claimService = IClaimService(_getServiceAddress(CLAIM())); 
        $._pool = Pool(pool);
        $._distribution = Distribution(distribution);
        $._initialProductFee = productFee;
        $._initialProcessingFee = processingFee;  
        $._tokenHandler = new TokenHandler(token);
        $._poolNftId = getRegistry().getNftId(pool);
        $._distributionNftId = getRegistry().getNftId(distribution);

        registerInterface(type(IProductComponent).interfaceId);  
    }

    // from product component
    function setFees(
        Fee memory productFee,
        Fee memory processingFee
    )
        external
        onlyOwner
        restricted()
        override
    {
        _getProductService().setFees(productFee, processingFee);
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
        uint256 sumInsuredAmount,
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
        Amount confirmedAmount
    )
        internal
    {
        _getProductStorage()._claimService.confirm(
            policyNftId,
            claimId,
            confirmedAmount);
    }

    function _declineClaim(
        NftId policyNftId,
        ClaimId claimId
    )
        internal
    {
        _getProductStorage()._claimService.decline(
            policyNftId,
            claimId);
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

    function calculatePremium(
        uint256 sumInsuredAmount,
        RiskId riskId,
        Seconds lifetime,
        bytes memory applicationData,
        NftId bundleNftId,
        ReferralId referralId
    )
        external 
        view 
        override 
        returns (uint256 premiumAmount)
    {
        IPolicy.Premium memory premium = _getProductStorage()._applicationService.calculatePremium(
            getNftId(),
            riskId,
            sumInsuredAmount,
            lifetime,
            applicationData,
            bundleNftId,
            referralId
        );
        premiumAmount = premium.premiumAmount;
    }

    function calculateNetPremium(
        uint256 sumInsuredAmount,
        RiskId riskId,
        Seconds lifetime,
        bytes memory applicationData
    )
        external
        view
        virtual override
        returns (uint256 netPremiumAmount)
    {
        // default 10% of sum insured
        return sumInsuredAmount / 10;
    }

    function _toRiskId(string memory riskName) internal pure returns (RiskId riskId) {
        return RiskIdLib.toRiskId(riskName);
    }

    function getPoolNftId() external view override returns (NftId poolNftId) {
        return getRegistry().getNftId(address(_getProductStorage()._pool));
    }

    function getDistributionNftId() external view override returns (NftId distributionNftId) {
        return getRegistry().getNftId(address(_getProductStorage()._distribution));
    }

    function getSetupInfo() public view returns (ISetup.ProductSetupInfo memory setupInfo) {
        InstanceReader reader = getInstance().getInstanceReader();
        setupInfo = reader.getProductSetupInfo(getNftId());

        // fallback to initial setup info (wallet is always != address(0))
        if(setupInfo.wallet == address(0)) {
            setupInfo = _getInitialSetupInfo();
        }
    }

    function _getInitialSetupInfo() internal view returns (ISetup.ProductSetupInfo memory setupInfo) {
        ProductStorage storage $ = _getProductStorage();

        ISetup.DistributionSetupInfo memory distributionSetupInfo = $._distribution.getSetupInfo();
        IComponents.PoolInfo memory poolInfo = $._pool.getPoolInfo();

        return ISetup.ProductSetupInfo(
            getToken(),
            $._tokenHandler,
            $._distributionNftId,
            $._poolNftId,
            $._initialProductFee,
            $._initialProcessingFee,
            false,
            getWallet()
        );
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
