// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId} from "../../../types/NftId.sol";
import {ObjectType, PRODUCT, ORACLE, POOL, BUNDLE, POLICY} from "../../../types/ObjectType.sol";
import {StateId, ACTIVE, PAUSED, ARCHIVED, CLOSED, APPLIED, REVOKED, DECLINED} from "../../../types/StateId.sol";
import {ILifecycleModule} from "./ILifecycle.sol";

contract LifecycleModule is ILifecycleModule {
    mapping(ObjectType objectType => StateId initialState)
        private _initialState;

    mapping(ObjectType objectType => mapping(StateId stateFrom => mapping(StateId stateTo => bool isValid)))
        private _isValidTransition;

    constructor() {
        _setupComponentLifecycle(PRODUCT());
        _setupComponentLifecycle(ORACLE());
        _setupComponentLifecycle(POOL());

        _setupBundleLifecycle();
        _setupPolicyLifecycle();
    }

    function checkAndLogTransition(
        NftId nftId,
        ObjectType objectType,
        StateId fromId,
        StateId toId
    ) public returns (StateId) // add only currentcontract? would that work?
    {
        if (!_isValidTransition[objectType][fromId][toId]) {
            revert ErrorInvalidStateTransition(nftId, objectType, fromId, toId);
        }

        if (objectType == POLICY()) {
            emit LogPolicyStateChanged(nftId, fromId, toId);
        } else if (objectType == BUNDLE()) {
            emit LogBundleStateChanged(nftId, fromId, toId);
        } else if (
            objectType == PRODUCT() ||
            objectType == ORACLE() ||
            objectType == POOL()
        ) {
            emit LogComponentStateChanged(nftId, objectType, fromId, toId);
        } else {
            revert ErrorNoLifecycle(nftId, objectType);
        }

        return toId;
    }

    function getInitialState(
        ObjectType objectType
    ) public view returns (StateId) {
        return _initialState[objectType];
    }

    function isValidTransition(
        ObjectType objectType,
        StateId fromId,
        StateId toId
    ) public view returns (bool) {
        return _isValidTransition[objectType][fromId][toId];
    }

    function _setupComponentLifecycle(ObjectType objectType) internal {
        _initialState[objectType] = ACTIVE();
        _isValidTransition[objectType][ACTIVE()][PAUSED()] = true;
        _isValidTransition[objectType][PAUSED()][ACTIVE()] = true;
        _isValidTransition[objectType][PAUSED()][ARCHIVED()] = true;
    }

    function _setupBundleLifecycle() internal {
        _initialState[BUNDLE()] = ACTIVE();
        _isValidTransition[BUNDLE()][ACTIVE()][PAUSED()] = true;
        _isValidTransition[BUNDLE()][PAUSED()][ACTIVE()] = true;
        _isValidTransition[BUNDLE()][PAUSED()][CLOSED()] = true;
    }

    function _setupPolicyLifecycle() internal {
        _initialState[POLICY()] = APPLIED();
        _isValidTransition[POLICY()][APPLIED()][REVOKED()] = true;
        _isValidTransition[POLICY()][APPLIED()][DECLINED()] = true;
        _isValidTransition[POLICY()][APPLIED()][ACTIVE()] = true;
        _isValidTransition[POLICY()][ACTIVE()][CLOSED()] = true;
    }
}
