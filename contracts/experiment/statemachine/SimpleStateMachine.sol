// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {StateId, toStateId} from "../../types/StateId.sol";
import {SM} from "./SM.sol";

contract SimpleStateMachine is SM {

    uint8 public constant STATE_ACTIVE = 10;
    uint8 public constant STATE_PAUSED = 20;
    uint8 public constant STATE_ARCHIVED = 30;

    constructor() {
        addTransition(ACTIVE(), PAUSED());
        addTransition(PAUSED(), ACTIVE());
        addTransition(PAUSED(), ARCHIVED());

        setInitialState(ACTIVE());
    }

    function ACTIVE() public pure returns(StateId stateId) { return toStateId(STATE_ACTIVE); }
    function PAUSED() public pure returns(StateId stateId) { return toStateId(STATE_PAUSED); }
    function ARCHIVED() public pure returns(StateId stateId) { return toStateId(STATE_ARCHIVED); }
}
