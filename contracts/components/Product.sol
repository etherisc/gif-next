// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRisk} from "../instance/module/risk/IRisk.sol";
import {ITreasury} from "../instance/module/treasury/ITreasury.sol";
import {IProductService} from "../instance/service/IProductService.sol";
import {IProductComponent} from "./IProductComponent.sol";
import {NftId} from "../types/NftId.sol";
import {ObjectType, PRODUCT} from "../types/ObjectType.sol";
import {RiskId, RiskIdLib} from "../types/RiskId.sol";
import {StateId} from "../types/StateId.sol";
import {Timestamp} from "../types/Timestamp.sol";
import {Fee} from "../types/Fee.sol";
import {BaseComponent} from "./BaseComponent.sol";

contract Product is BaseComponent, IProductComponent {
    IProductService internal _productService;
    address internal _pool;
    Fee internal _initialPolicyFee;
    Fee internal _initialProcessingFee;

    constructor(
        address registry,
        NftId instanceNftid,
        address token,
        address pool,
        Fee memory policyFee,
        Fee memory processingFee
    ) BaseComponent(registry, instanceNftid, token) {
        // TODO add validation
        _productService = _instance.getProductService();
        _pool = pool;
        _initialPolicyFee = policyFee;
        _initialProcessingFee = processingFee;        
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

    function _getRiskState(RiskId id) internal view returns (StateId state) {
        return _instance.getRiskState(id);
    }

    function _createApplication(
        address applicationOwner,
        RiskId riskId,
        uint256 sumInsuredAmount,
        uint256 premiumAmount,
        uint256 lifetime,
        NftId bundleNftId
    ) internal returns (NftId nftId) {
        nftId = _productService.createApplication(
            applicationOwner,
            riskId,
            sumInsuredAmount,
            premiumAmount,
            lifetime,
            bundleNftId
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
        return _registry.getNftId(_pool);
    }

    // from product component
    function setFees(
        Fee memory policyFee,
        Fee memory processingFee
    )
        external
        onlyOwner
        override
    {
        _productService.setFees(policyFee, processingFee);
    }


    function getPolicyFee()
        external
        view
        override
        returns (Fee memory policyFee)
    {
        NftId productNftId = getNftId();
        if (address(_instance.getTokenHandler(productNftId)) != address(0)) {
            return _instance.getTreasuryInfo(productNftId).policyFee;
        } else {
            return _initialPolicyFee;
        }
    }

    function getProcessingFee()
        external
        view
        override
        returns (Fee memory processingFee)
    {
        NftId productNftId = getNftId();
        if (address(_instance.getTokenHandler(productNftId)) != address(0)) {
            return _instance.getTreasuryInfo(productNftId).processingFee;
        } else {
            return _initialProcessingFee;
        }
    }

    // from registerable
    function getType() public pure override returns (ObjectType) {
        return PRODUCT();
    }
}
