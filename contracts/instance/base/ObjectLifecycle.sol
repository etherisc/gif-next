// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ObjectType, COMPONENT, BUNDLE, POLICY, REQUEST, RISK, CLAIM, PAYOUT, POOL, PRODUCT, DISTRIBUTION, DISTRIBUTOR, DISTRIBUTOR_TYPE, REFERRAL} from "../../type/ObjectType.sol";
import {StateId, INITIAL, ACTIVE, PAUSED, ARCHIVED, CLOSED, APPLIED, COLLATERALIZED, REVOKED, SUBMITTED, CONFIRMED, DECLINED, EXPECTED, PAID, FULFILLED, FAILED, CANCELLED} from "../../type/StateId.sol";
import {Lifecycle} from "../../shared/Lifecycle.sol";

contract ObjectLifecycle is
    Lifecycle
{
    constructor() {
        _setupLifecycle();
    }

    // in case of clone deployment
    // in the worst case it is save to call _setupLifecycle() twice
    function _initializeLifecycle() internal onlyInitializing
    {
        _setupLifecycle();
    }

    function _setupLifecycle()
        private
    {
        _setupBundleLifecycle();
        _setupComponentLifecycle();
        _setupPolicyLifecycle();
        _setupClaimAndPayoutLifecycle();
        _setupRiskLifecycle();
        _setupRequestLifecycle();
        _setUpPoolLifecycle();
        _setUpProductLifecycle();
        _setUpDistributionLifecycle();
    }

    function _setupComponentLifecycle() private {
        _initialState[COMPONENT()] = ACTIVE();
        _isValidTransition[COMPONENT()][ACTIVE()][PAUSED()] = true;
        _isValidTransition[COMPONENT()][PAUSED()][ACTIVE()] = true;
        _isValidTransition[COMPONENT()][PAUSED()][ARCHIVED()] = true;
    }

    function _setupBundleLifecycle() private {
        _initialState[BUNDLE()] = ACTIVE();
        _isValidTransition[BUNDLE()][ACTIVE()][PAUSED()] = true;
        _isValidTransition[BUNDLE()][ACTIVE()][CLOSED()] = true;
        _isValidTransition[BUNDLE()][PAUSED()][ACTIVE()] = true;
        _isValidTransition[BUNDLE()][PAUSED()][CLOSED()] = true;
    }

    function _setupPolicyLifecycle() private {
        _initialState[POLICY()] = APPLIED();
        _isValidTransition[POLICY()][APPLIED()][REVOKED()] = true;
        _isValidTransition[POLICY()][APPLIED()][DECLINED()] = true;
        _isValidTransition[POLICY()][APPLIED()][COLLATERALIZED()] = true;
        _isValidTransition[POLICY()][APPLIED()][ACTIVE()] = true;
        _isValidTransition[POLICY()][COLLATERALIZED()][ACTIVE()] = true;
        _isValidTransition[POLICY()][ACTIVE()][CLOSED()] = true;
    }

    function _setupClaimAndPayoutLifecycle() private {
        _initialState[CLAIM()] = SUBMITTED();
        _isValidTransition[CLAIM()][SUBMITTED()][CONFIRMED()] = true;
        _isValidTransition[CLAIM()][SUBMITTED()][DECLINED()] = true;
        _isValidTransition[CLAIM()][CONFIRMED()][CLOSED()] = true;

        _initialState[PAYOUT()] = EXPECTED();
        _isValidTransition[PAYOUT()][EXPECTED()][PAID()] = true;
    }

    function _setupRiskLifecycle() private {
        _initialState[RISK()] = ACTIVE();
        _isValidTransition[RISK()][ACTIVE()][PAUSED()] = true;
        _isValidTransition[RISK()][PAUSED()][ACTIVE()] = true;
        _isValidTransition[RISK()][PAUSED()][ARCHIVED()] = true;
    }

    function _setupRequestLifecycle() private {
        _initialState[REQUEST()] = ACTIVE();
        _isValidTransition[REQUEST()][ACTIVE()][FULFILLED()] = true;
        _isValidTransition[REQUEST()][ACTIVE()][FAILED()] = true;
        _isValidTransition[REQUEST()][FAILED()][FULFILLED()] = true;
        _isValidTransition[REQUEST()][ACTIVE()][CANCELLED()] = true;
    }

    // TODO why this is needed when _setupComponentLifecycle() exists ?!!
    function _setUpPoolLifecycle() private {
        _initialState[POOL()] = ACTIVE();
    }

    function _setUpProductLifecycle() private {
        _initialState[PRODUCT()] = ACTIVE();
    }

    function _setUpDistributionLifecycle() private {
        _initialState[DISTRIBUTION()] = ACTIVE();
        _initialState[DISTRIBUTOR()] = ACTIVE();
        _initialState[DISTRIBUTOR_TYPE()] = ACTIVE();
        _initialState[REFERRAL()] = ACTIVE();
    }

}
