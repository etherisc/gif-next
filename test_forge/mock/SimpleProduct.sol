// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Product} from "../../contracts/components/Product.sol";
import {RiskId} from "../../contracts/types/RiskId.sol";
import {IRisk} from "../../contracts/instance/module/IRisk.sol";
import {StateId} from "../../contracts/types/StateId.sol";
import {Fee} from "../../contracts/types/Fee.sol";
import {NftId} from "../../contracts/types/NftId.sol";
import {ReferralId} from "../../contracts/types/Referral.sol";
import {Timestamp} from "../../contracts/types/Timestamp.sol";
import {RoleId, RoleIdLib} from "../../contracts/types/RoleId.sol";

uint64 constant SPECIAL_ROLE_INT = 11111;

contract SimpleProduct is Product {

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
    ) Product(
        registry,
        instanceNftid,
        token,
        isInterceptor,
        pool,
        distribution,
        productFee,
        processingFee,
        initialOwner
    ) {
    }

    function getName() public pure override returns (string memory) {
        return "SimpleProduct";
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
        uint256 sumInsuredAmount,
        uint256 lifetime,
        bytes memory applicationData,
        NftId bundleNftId,
        ReferralId referralId
    ) public returns (NftId nftId) {
        return _createApplication(
            applicationOwner,
            riskId,
            sumInsuredAmount,
            lifetime,
            applicationData,
            bundleNftId,
            referralId
        );
    }

    function underwrite(
        NftId policyNftId,
        bool requirePremiumPayment,
        Timestamp activateAt
    ) public {
        _underwrite(policyNftId, requirePremiumPayment, activateAt);
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

    function doSomethingSpecial() 
        public 
        onlyInstanceRole(SPECIAL_ROLE_INT)
        returns (bool) 
    {
        return true;
    }

    function doWhenNotLocked() 
        public 
        isNotLocked
        returns (bool) 
    {
        return true;
    }

}