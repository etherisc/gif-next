// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IRisk} from "../instance/module/IRisk.sol";
import {ITreasury} from "../instance/module/ITreasury.sol";
import {IProductService} from "../instance/service/IProductService.sol";
import {IProductComponent} from "./IProductComponent.sol";
import {NftId, zeroNftId, NftIdLib} from "../types/NftId.sol";
import {ObjectType, PRODUCT} from "../types/ObjectType.sol";
import {ReferralId} from "../types/Referral.sol";
import {RiskId, RiskIdLib} from "../types/RiskId.sol";
import {StateId} from "../types/StateId.sol";
import {Timestamp} from "../types/Timestamp.sol";
import {Fee, FeeLib} from "../types/Fee.sol";
import {BaseComponent} from "./BaseComponent.sol";

import {IRegistry} from "../registry/IRegistry.sol";
import {IRegisterable} from "../shared/IRegisterable.sol";
import {Registerable} from "../shared/Registerable.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";

import {InstanceReader} from "../instance/InstanceReader.sol";
import {ISetup} from "../instance/module/ISetup.sol";
import {Pool} from "../components/Pool.sol";
import {Distribution} from "../components/Distribution.sol";

import {zeroNftId} from "../types/NftId.sol";

contract Product is BaseComponent, IProductComponent {
    using NftIdLib for NftId;

    IProductService internal _productService;
    Pool internal _pool;
    Distribution internal _distribution;
    Fee internal _initialProductFee;
    Fee internal _initialProcessingFee;

    NftId internal _poolNftId;
    NftId internal _distributionNftId;

    constructor(
        address registry,
        NftId instanceNftid,
        address token,
        bool isInterceptor,
        address pool,
        address distribution,
        Fee memory productFee,
        Fee memory processingFee,
        address initialOwner
    ) BaseComponent(registry, instanceNftid, token, PRODUCT(), isInterceptor, initialOwner) {
        // TODO add validation
        _productService = _instance.getProductService();
        _pool = Pool(pool);
        _distribution = Distribution(distribution);
        _initialProductFee = productFee;
        _initialProcessingFee = processingFee;  

        _poolNftId = getRegistry().getNftId(address(_pool));
        _distributionNftId = getRegistry().getNftId(address(_distribution));

        _registerInterface(type(IProductComponent).interfaceId);  
    }


    function calculatePremium(
        uint256 sumInsuredAmount,
        RiskId riskId,
        uint256 lifetime,
        bytes memory applicationData,
        ReferralId referralId,
        NftId bundleNftId
    )
        external 
        view 
        override 
        returns (uint256 premiumAmount)
    {
        (premiumAmount,,,,) = _productService.calculatePremium(
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
        _productService.createRisk(
            id,
            data
        );
    }

    function _updateRisk(
        RiskId id,
        bytes memory data
    ) internal {
        _productService.updateRisk(
            id,
            data
        );
    }

    function _updateRiskState(
        RiskId id,
        StateId state
    ) internal {
        _productService.updateRiskState(
            id,
            state
        );
    }

    function _getRiskInfo(RiskId id) internal view returns (IRisk.RiskInfo memory info) {
        return _instance.getInstanceReader().getRiskInfo(id);
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
        nftId = _productService.createApplication(
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
        _productService.underwrite(
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
        _productService.collectPremium(
            policyNftId, 
            activateAt);
    }

    function _activate(
        NftId policyNftId,
        Timestamp activateAt
    )
        internal
    {
        _productService.activate(
            policyNftId, 
            activateAt);
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
        _productService.setFees(productFee, processingFee);
    }

    function getSetupInfo() public view returns (ISetup.ProductSetupInfo memory setupInfo) {
        InstanceReader reader = _instance.getInstanceReader();
        return reader.getProductSetupInfo(getNftId());
    }

    // from IRegisterable

    function getInitialInfo() 
        public
        view 
        override (IRegisterable, Registerable)
        returns (IRegistry.ObjectInfo memory, bytes memory)
    {
        // from Registerable
        (
            IRegistry.ObjectInfo memory productInfo, 
            bytes memory data
        ) = super.getInitialInfo();
        
        // TODO read pool & distribution fees
        // 1) from pool -> the only option -> pool must be registered first?
        // 2) from instance -> all fees are set into instance at product registration which is ongoing here
        // checks are done in registryProduct() where THIS function is called
        //require(getRegistry().getObjectInfo(_poolNftId).objectType == POOL(), "POOL_NOT_REGISTERED");
        //require(getRegistry().getObjectInfo(_distributionNftId).objectType == DISTRIBUTION(), "DISTRIBUTION_NOT_REGISTERED");
        
        // from PoolComponent
        (
            , 
            bytes memory poolData
        ) = _pool.getInitialInfo();
        
        (
            ISetup.PoolSetupInfo memory poolSetupInfo
        )  = abi.decode(poolData, (ISetup.PoolSetupInfo));

        // from DistributionComponent
        (
            , 
            bytes memory distributionData
        ) = _distribution.getInitialInfo();

        (
            ISetup.DistributionSetupInfo memory distributionSetupInfo
        )  = abi.decode(distributionData, (ISetup.DistributionSetupInfo));

        return (
            productInfo,
            abi.encode(
                ISetup.ProductSetupInfo(
                    _token,
                    TokenHandler(address(_token)),
                    _distributionNftId,
                    _poolNftId,
                    distributionSetupInfo.distributionFee, 
                    _initialProductFee,
                    _initialProcessingFee,
                    poolSetupInfo.poolFee, 
                    poolSetupInfo.stakingFee, 
                    poolSetupInfo.performanceFee 
                )
            )
        );
    }
}
