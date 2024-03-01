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

import {TokenHandler} from "../shared/TokenHandler.sol";

import {InstanceReader} from "../instance/InstanceReader.sol";
import {ISetup} from "../instance/module/ISetup.sol";
import {Pool} from "../components/Pool.sol";
import {Distribution} from "../components/Distribution.sol";

abstract contract Product is Component, IProductComponent {
    using NftIdLib for NftId;

    IPolicyService internal _policyService;
    Pool internal _pool;
    Distribution internal _distribution;
    Fee internal _initialProductFee;
    Fee internal _initialProcessingFee;
    TokenHandler internal _tokenHandler;

    NftId internal _poolNftId;
    NftId internal _distributionNftId;

    constructor(
        address registry,
        NftId instanceNftid,
        string memory name,
        address token,
        bool isInterceptor,
        address pool,
        address distribution,
        Fee memory productFee,
        Fee memory processingFee,
        address initialOwner,
        bytes memory data
    ) Component (
        registry, 
        instanceNftid, 
        name, 
        token, 
        PRODUCT(), 
        isInterceptor, 
        initialOwner, 
        data
    ) {
        // TODO add validation
        _policyService = getInstance().getPolicyService(); 
        _pool = Pool(pool);
        _distribution = Distribution(distribution);
        _initialProductFee = productFee;
        _initialProcessingFee = processingFee;  

        _tokenHandler = new TokenHandler(token);

        _poolNftId = getRegistry().getNftId(address(_pool));
        _distributionNftId = getRegistry().getNftId(address(_distribution));

        _registerInterface(type(IProductComponent).interfaceId);  
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
        (premiumAmount,,,,) = _policyService.calculatePremium(
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
    ) internal returns (NftId nftId) {
        nftId = _policyService.createApplication(
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
        _policyService.underwrite(
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
        _policyService.collectPremium(
            policyNftId, 
            activateAt);
    }

    function _activate(
        NftId policyNftId,
        Timestamp activateAt
    )
        internal
    {
        _policyService.activate(
            policyNftId, 
            activateAt);
    }

    function _close(
        NftId policyNftId
    )
        internal
    {
        _policyService.close(policyNftId);
    }

    function getPoolNftId() external view override returns (NftId poolNftId) {
        return getRegistry().getNftId(address(_pool));
    }

    function getDistributionNftId() external view override returns (NftId distributionNftId) {
        return getRegistry().getNftId(address(_distribution));
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
        ISetup.DistributionSetupInfo memory distributionSetupInfo = _distribution.getSetupInfo();
        ISetup.PoolSetupInfo memory poolSetupInfo = _pool.getSetupInfo();

        return ISetup.ProductSetupInfo(
            getToken(),
            _tokenHandler,
            _distributionNftId,
            _poolNftId,
            distributionSetupInfo.distributionFee, 
            _initialProductFee,
            _initialProcessingFee,
            poolSetupInfo.poolFee, 
            poolSetupInfo.stakingFee, 
            poolSetupInfo.performanceFee,
            false,
            getWallet()
        );
    }
}
