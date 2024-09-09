// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol"; 

import {COMPONENT, BUNDLE, POLICY, REQUEST, RISK, CLAIM, PAYOUT, POOL, PREMIUM, PRODUCT, DISTRIBUTION, DISTRIBUTOR, DISTRIBUTOR_TYPE, REFERRAL, FEE} from "../../type/ObjectType.sol";
import {ACTIVE, PAUSED, ARCHIVED, CLOSED, APPLIED, COLLATERALIZED, REVOKED, SUBMITTED, CONFIRMED, DECLINED, EXPECTED, PAID, FULFILLED, FAILED, CANCELLED} from "../../type/StateId.sol";
import {Lifecycle} from "../../shared/Lifecycle.sol";

contract ObjectLifecycle is
    Lifecycle,
    Initializable
{
    function _initializeLifecycle() internal onlyInitializing
    {
        _setupLifecycle();
    }

    function _setupLifecycle()
        internal
        override
    {
        _setupBundleLifecycle();
        _setupComponentLifecycle();
        _setupPolicyLifecycle();
        _setupPremiumLifecycle();
        _setupClaimLifecycle();
        _setupPayoutLifecycle();
        _setupRiskLifecycle();
        _setupRequestLifecycle();

        // setup dummy lifecycles to manage with key value store 
        _setUpPoolLifecycle();
        _setUpProductLifecycle();
        _setUpDistributionLifecycle();
    }

    function _setupComponentLifecycle() private {
        setInitialState(COMPONENT(), ACTIVE());
        setStateTransition(COMPONENT(), ACTIVE(), PAUSED());
        setStateTransition(COMPONENT(), PAUSED(), ACTIVE());
        setStateTransition(COMPONENT(), PAUSED(), ARCHIVED());
    }

    function _setupBundleLifecycle() private {
        setInitialState(BUNDLE(), ACTIVE());
        setStateTransition(BUNDLE(), ACTIVE(), CLOSED());
    }

    function _setupPolicyLifecycle() private {
        setInitialState(POLICY(), APPLIED());
        setStateTransition(POLICY(), APPLIED(), REVOKED());
        setStateTransition(POLICY(), APPLIED(), DECLINED());
        setStateTransition(POLICY(), APPLIED(), COLLATERALIZED());
        setStateTransition(POLICY(), COLLATERALIZED(), CLOSED());
    }

    function _setupPremiumLifecycle() private {
        setInitialState(PREMIUM(), EXPECTED());
        setStateTransition(PREMIUM(), EXPECTED(), PAID());
    }

    function _setupClaimLifecycle() private {
        setInitialState(CLAIM(), SUBMITTED());
        setStateTransition(CLAIM(), SUBMITTED(), REVOKED());
        setStateTransition(CLAIM(), SUBMITTED(), CONFIRMED());
        setStateTransition(CLAIM(), SUBMITTED(), DECLINED());
        setStateTransition(CLAIM(), CONFIRMED(), CLOSED());
        setStateTransition(CLAIM(), CONFIRMED(), CANCELLED());
    }

    function _setupPayoutLifecycle() private {
        setInitialState(PAYOUT(), EXPECTED());
        setStateTransition(PAYOUT(), EXPECTED(), PAID());
        setStateTransition(PAYOUT(), EXPECTED(), CANCELLED());
    }

    function _setupRiskLifecycle() private {
        setInitialState(RISK(), ACTIVE());
        setStateTransition(RISK(), ACTIVE(), CLOSED());
    }

    function _setupRequestLifecycle() private {
        setInitialState(REQUEST(), ACTIVE());
        setStateTransition(REQUEST(), ACTIVE(), FULFILLED());
        setStateTransition(REQUEST(), ACTIVE(), FAILED());
        setStateTransition(REQUEST(), FAILED(), FULFILLED());
        setStateTransition(REQUEST(), ACTIVE(), CANCELLED());
    }

    // dummy lifecycle only
    function _setUpPoolLifecycle() private {
        setInitialState(POOL(), ACTIVE());
    }

    // dummy lifecycle only
    function _setUpProductLifecycle() private {
        setInitialState(PRODUCT(), ACTIVE());
        setInitialState(FEE(), ACTIVE());
    }

    // dummy lifecycles only
    function _setUpDistributionLifecycle() private {
        setInitialState(DISTRIBUTION(), ACTIVE());
        setInitialState(DISTRIBUTOR(), ACTIVE());
        setInitialState(DISTRIBUTOR_TYPE(), ACTIVE());
        setInitialState(REFERRAL(), ACTIVE());
    }
}
