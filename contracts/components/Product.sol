// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IRisk} from "../instance/module/risk/IRisk.sol";
import {ITreasury} from "../instance/module/treasury/ITreasury.sol";
import {IProductService} from "../instance/service/IProductService.sol";
import {IProductComponent} from "./IProductComponent.sol";
import {NftId, zeroNftId} from "../types/NftId.sol";
import {ObjectType, PRODUCT} from "../types/ObjectType.sol";
import {ReferralId} from "../types/ReferralId.sol";
import {RiskId, RiskIdLib} from "../types/RiskId.sol";
import {StateId} from "../types/StateId.sol";
import {Timestamp} from "../types/Timestamp.sol";
import {Fee, FeeLib} from "../types/Fee.sol";
import {BaseComponent} from "./BaseComponent.sol";

import {IRegistry} from "../registry/IRegistry.sol";
import {IRegisterable} from "../shared/IRegisterable.sol";
import {Registerable} from "../shared/Registerable.sol";

import {IPool} from "../instance/module/pool/IPoolModule.sol";
import {Pool} from "../components/Pool.sol";

contract Product is BaseComponent, IProductComponent {
    IProductService internal _productService;
    Pool internal _pool;
    address internal _distribution;
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
        _distribution = distribution;
        _initialProductFee = productFee;
        _initialProcessingFee = processingFee;  

        _poolNftId = getRegistry().getNftId(address(_pool));
        _distributionNftId = getRegistry().getNftId(_distribution);

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

    function _setRiskInfo(
        RiskId id,
        IRisk.RiskInfo memory info
    ) internal {
        _productService.setRiskInfo(
            id,
            info
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
        return _instance.getRiskInfo(id);
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
        return getRegistry().getNftId(_distribution);
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

    // TODO delete, call instance intead
    function getProductFee()
        external
        view
        override
        returns (Fee memory productFee)
    {
        NftId productNftId = getNftId();
        if (_instance.hasTreasuryInfo(productNftId)) {
            return _instance.getTreasuryInfo(productNftId).productFee;
        } else {
            return _initialProductFee;
        }
    }

    function getProcessingFee()
        external
        view
        override
        returns (Fee memory processingFee)
    {
        NftId productNftId = getNftId();
        if (_instance.hasTreasuryInfo(productNftId)) {
            return _instance.getTreasuryInfo(productNftId).processingFee;
        } else {
            return _initialProcessingFee;
        }
    }

    // from IRegisterable

    // TODO used only once, occupies space
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
            IRegistry.ObjectInfo memory poolInfo, 
            bytes memory poolData
        ) = _pool.getInitialInfo();

        (
            /*IPool.PoolInfo memory info*/,
            /*address wallet*/,
            /*IERC20Metadata token*/,
            Fee memory initialPoolFee,
            Fee memory initialStakingFee,
            Fee memory initialPerformanceFee
        )  = abi.decode(poolData, (IPool.PoolInfo, address, IERC20Metadata, Fee, Fee, Fee));

        // TODO from DistributionComponent

        return (
            productInfo,
            abi.encode(
                ITreasury.TreasuryInfo(
                    _poolNftId,
                    _distributionNftId,
                    _token,
                    _initialProductFee,
                    _initialProcessingFee,
                    initialPoolFee,
                    initialStakingFee,
                    initialPerformanceFee,
                    FeeLib.zeroFee()//_instance.getDistributionFee(_distributionNftId)
                ),
                _wallet
            )
        );
    }
}
