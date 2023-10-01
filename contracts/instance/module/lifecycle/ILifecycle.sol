// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {ObjectType} from "../../../types/ObjectType.sol";
import {StateId, toStateId, zeroStateId} from "../../../types/StateId.sol";
import {NftId} from "../../../types/NftId.sol";

interface ILifecycle {
    // event LogComponentStateChanged(
    //     NftId nftId,
    //     ObjectType objectType,
    //     StateId fromStateId,
    //     StateId toStateId
    // );
    // event LogBundleStateChanged(
    //     NftId nftId,
    //     StateId fromStateId,
    //     StateId toStateId
    // );
    // event LogPolicyStateChanged(
    //     NftId nftId,
    //     StateId fromStateId,
    //     StateId toStateId
    // );
    // event LogClaimStateChanged(NftId nftId, ClaimId claimId, StateId fromStateId, StateId toStateId);
    // event LogPayoutStateChanged(NftId nftId, ClaimId claimId, PayoutId payoutId, StateId fromStateId, StateId toStateId);

    error ErrorNoLifecycle(NftId nftId, ObjectType objectType);
    error ErrorInvalidStateTransition(
        NftId nftId,
        ObjectType objectType,
        StateId fromStateId,
        StateId toStateId
    );
}

interface ILifecycleModule is ILifecycle {
    function getInitialState(
        ObjectType objectType
    ) external view returns (StateId);

    function isValidTransition(
        ObjectType objectType,
        StateId fromId,
        StateId toId
    ) external view returns (bool);
}
