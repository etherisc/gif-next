// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol"; 

import {NftId} from "../type/NftId.sol";
import {ObjectType, COMPONENT, BUNDLE, POLICY, RISK, CLAIM, PAYOUT} from "../type/ObjectType.sol";
import {StateId, ACTIVE, PAUSED, ARCHIVED, CLOSED, APPLIED, COLLATERALIZED, REVOKED, SUBMITTED, CONFIRMED, DECLINED, EXPECTED, PAID} from "../type/StateId.sol";
import {ILifecycle} from "./ILifecycle.sol";

contract Lifecycle is
    Initializable,
    ILifecycle
{
    mapping(ObjectType objectType => StateId initialState)
        private _initialState;

    mapping(ObjectType objectType => mapping(StateId stateFrom => mapping(StateId stateTo => bool isValid)))
        private _isValidTransition;

    function initializeLifecycle()
        public
        onlyInitializing
    {
        _setupBundleLifecycle();
        _setupComponentLifecycle();
        _setupPolicyLifecycle();
        _setupClaimAndPayoutLifecycle();
        _setupRiskLifecycle();
    }

    function hasLifecycle(
        ObjectType objectType
    )
        public
        view
        override
        returns (bool)
    {
        return _initialState[objectType].gtz();
    }

    function getInitialState(
        ObjectType objectType
    )
        public
        view
        returns (StateId)
    {
        return _initialState[objectType];
    }

    function checkTransition(
        ObjectType objectType,
        StateId fromId,
        StateId toId
    )
        public
        view
    {
        // return if no life cycle support
        if (_initialState[objectType].eqz()) {
            return;
        }

        // enforce valid state transition
        if (!_isValidTransition[objectType][fromId][toId]) {
            revert ErrorInvalidStateTransition(objectType, fromId, toId);
        }
    }

    function isValidTransition(
        ObjectType objectType,
        StateId fromId,
        StateId toId
    ) public view returns (bool) {
        return _isValidTransition[objectType][fromId][toId];
    }

    function _setupComponentLifecycle() internal {
        _initialState[COMPONENT()] = ACTIVE();
        _isValidTransition[COMPONENT()][ACTIVE()][PAUSED()] = true;
        _isValidTransition[COMPONENT()][PAUSED()][ACTIVE()] = true;
        _isValidTransition[COMPONENT()][PAUSED()][ARCHIVED()] = true;
    }

    function _setupBundleLifecycle() internal {
        _initialState[BUNDLE()] = ACTIVE();
        _isValidTransition[BUNDLE()][ACTIVE()][PAUSED()] = true;
        _isValidTransition[BUNDLE()][ACTIVE()][CLOSED()] = true;
        _isValidTransition[BUNDLE()][PAUSED()][ACTIVE()] = true;
        _isValidTransition[BUNDLE()][PAUSED()][CLOSED()] = true;
    }

    function _setupPolicyLifecycle() internal {
        _initialState[POLICY()] = APPLIED();
        _isValidTransition[POLICY()][APPLIED()][REVOKED()] = true;
        _isValidTransition[POLICY()][APPLIED()][DECLINED()] = true;
        _isValidTransition[POLICY()][APPLIED()][COLLATERALIZED()] = true;
        _isValidTransition[POLICY()][APPLIED()][ACTIVE()] = true;
        _isValidTransition[POLICY()][COLLATERALIZED()][ACTIVE()] = true;
        _isValidTransition[POLICY()][ACTIVE()][CLOSED()] = true;
    }

    function _setupClaimAndPayoutLifecycle() internal {
        _initialState[CLAIM()] = SUBMITTED();
        _isValidTransition[CLAIM()][SUBMITTED()][CONFIRMED()] = true;
        _isValidTransition[CLAIM()][SUBMITTED()][DECLINED()] = true;
        _isValidTransition[CLAIM()][CONFIRMED()][CLOSED()] = true;

        _initialState[PAYOUT()] = EXPECTED();
        _isValidTransition[PAYOUT()][EXPECTED()][PAID()] = true;
    }

    function _setupRiskLifecycle() internal {
        _initialState[RISK()] = ACTIVE();
        _isValidTransition[RISK()][ACTIVE()][PAUSED()] = true;
        _isValidTransition[RISK()][PAUSED()][ACTIVE()] = true;
        _isValidTransition[RISK()][PAUSED()][ARCHIVED()] = true;
    }
}
