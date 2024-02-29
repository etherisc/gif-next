// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IRisk} from "../instance/module/IRisk.sol";
import {IPolicyService} from "../instance/service/IPolicyService.sol";
import {IProductComponent} from "./IProductComponent.sol";
import {NftId, NftIdLib} from "../types/NftId.sol";
import {PRODUCT} from "../types/ObjectType.sol";
import {ReferralId} from "../types/Referral.sol";
import {RiskId, RiskIdLib} from "../types/RiskId.sol";
import {StateId} from "../types/StateId.sol";
import {Timestamp} from "../types/Timestamp.sol";
import {Fee} from "../types/Fee.sol";
import {Component} from "./Component.sol";

import {IRegistry} from "../registry/IRegistry.sol";
import {IRegisterable} from "../shared/IRegisterable.sol";
import {Registerable} from "../shared/Registerable.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";

import {InstanceReader} from "../instance/InstanceReader.sol";
import {ISetup} from "../instance/module/ISetup.sol";
import {Pool} from "../components/Pool.sol";
import {Distribution} from "../components/Distribution.sol";

abstract contract Product is
    Component, 
    IProductComponent
{
    // keccak256(abi.encode(uint256(keccak256("etherisc.storage.Product")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant PRODUCT_STORAGE_LOCATION_V1 = 0x0bb7aafdb8e380f81267337bc5b5dfdf76e6d3a380ecadb51ec665246d9d6800;

    struct ProductStorage {
        IPolicyService _policyService;
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
        bytes memory data
    )
        public
        virtual
        onlyInitializing()
    {
        initializeComponent(registry, instanceNftId, name, token, PRODUCT(), isInterceptor, initialOwner, data);

        ProductStorage storage $ = _getProductStorage();
        // TODO add validation
        $._policyService = getInstance().getPolicyService(); 
        $._pool = Pool(pool);
        $._distribution = Distribution(distribution);
        $._initialProductFee = productFee;
        $._initialProcessingFee = processingFee;  
        $._tokenHandler = new TokenHandler(token);
        $._poolNftId = getRegistry().getNftId(pool);
        $._distributionNftId = getRegistry().getNftId(distribution);

        registerInterface(type(IProductComponent).interfaceId);  
    }


    function calculatePremium(
        uint256 sumInsuredAmount,
        RiskId riskId,
        uint256 lifetime,
        bytes memory applicationData,
        NftId bundleNftId,
        ReferralId referralId
    )
        external 
        view 
        override 
        returns (uint256 premiumAmount)
    {
        (premiumAmount,,,,) = _getProductStorage()._policyService.calculatePremium(
            riskId,
            sumInsuredAmount,
            lifetime,
            applicationData,
            bundleNftId,
            referralId
        );
    }


    function calculateNetPremium(
        uint256 sumInsuredAmount,
        RiskId riskId,
        uint256 lifetime,
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

    function _createRisk(
        RiskId id,
        bytes memory data
    ) internal {
        getProductService().createRisk(
            id,
            data
        );
    }

    function _updateRisk(
        RiskId id,
        bytes memory data
    ) internal {
        getProductService().updateRisk(
            id,
            data
        );
    }

    function _updateRiskState(
        RiskId id,
        StateId state
    ) internal {
        getProductService().updateRiskState(
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
        uint256 lifetime,
        bytes memory applicationData,
        NftId bundleNftId,
        ReferralId referralId
    )
        internal
        returns (NftId nftId) 
    {
        return _getProductStorage()._policyService.createApplication(
            applicationOwner,
            riskId,
            sumInsuredAmount,
            lifetime,
            applicationData,
            bundleNftId,
            referralId
        );
    }

    function _underwrite(
        NftId policyNftId,
        bool requirePremiumPayment,
        Timestamp activateAt
    )
        internal
    {
        _getProductStorage()._policyService.underwrite(
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
        _getProductStorage()._policyService.close(policyNftId);
    }

    function getPoolNftId() external view override returns (NftId poolNftId) {
        return getRegistry().getNftId(address(_getProductStorage()._pool));
    }

    function getDistributionNftId() external view override returns (NftId distributionNftId) {
        return getRegistry().getNftId(address(_getProductStorage()._distribution));
    }

    // from product component
    function setFees(
        Fee memory productFee,
        Fee memory processingFee
    )
        external
        onlyOwner
        override
    {
        getProductService().setFees(productFee, processingFee);
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
        ISetup.PoolSetupInfo memory poolSetupInfo = $._pool.getSetupInfo();

        return ISetup.ProductSetupInfo(
            getToken(),
            $._tokenHandler,
            $._distributionNftId,
            $._poolNftId,
            distributionSetupInfo.distributionFee, 
            $._initialProductFee,
            $._initialProcessingFee,
            poolSetupInfo.poolFee, 
            poolSetupInfo.stakingFee, 
            poolSetupInfo.performanceFee,
            false,
            getWallet()
        );
    }

    function _getProductStorage() private pure returns (ProductStorage storage $) {
        assembly {
            $.slot := PRODUCT_STORAGE_LOCATION_V1
        }
    }
}
