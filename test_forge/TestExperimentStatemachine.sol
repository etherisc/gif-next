// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import "../lib/forge-std/src/Test.sol";
import {console} from "../lib/forge-std/src/Script.sol";

import {StateId, zeroStateId} from "../contracts/types/StateId.sol";
import {ISMEE} from "../contracts/experiment/statemachine/ISM.sol";
import {SimpleStateMachine} from "../contracts/experiment/statemachine/SimpleStateMachine.sol";

contract TestExperimentStatemachine is Test, ISMEE  {

    SimpleStateMachine internal statemachine;
    
    function setUp() external {
        statemachine = new SimpleStateMachine();
    }

    function testExperimentStatemachineInitialState() public {
        assertTrue(statemachine.getState() == statemachine.ACTIVE(), "not in state active");
    }

    function testExperimentStatemachineFromActiveToZero() public {
        assertTrue(statemachine.getState() == statemachine.ACTIVE(), "not in state active");

        StateId newState = zeroStateId();
        assertFalse(statemachine.isValidTransition(statemachine.getState(), newState));

        vm.expectRevert(
            abi.encodeWithSelector(
                ErrorStateChangeInvalid.selector,
                statemachine.getState(),
                newState));
        statemachine.changeToState(newState);
    }

    function testExperimentStatemachineFromActiveToActive() public {
        assertTrue(statemachine.getState() == statemachine.ACTIVE(), "not in state active");

        StateId newState = statemachine.ACTIVE();
        assertFalse(statemachine.isValidTransition(statemachine.getState(), newState));

        vm.expectRevert(
            abi.encodeWithSelector(
                ErrorStateChangeInvalid.selector,
                statemachine.getState(),
                newState));
        statemachine.changeToState(newState);
    }

    function testExperimentStatemachineFromActiveToArchived() public {
        assertTrue(statemachine.getState() == statemachine.ACTIVE(), "not in state active");

        StateId newState = statemachine.ARCHIVED();
        assertFalse(statemachine.isValidTransition(statemachine.getState(), newState));

        vm.expectRevert(
            abi.encodeWithSelector(
                ErrorStateChangeInvalid.selector,
                statemachine.getState(),
                newState));
        statemachine.changeToState(newState);
    }

    function testExperimentStatemachineFromActiveToPaused() public {
        assertTrue(statemachine.getState() == statemachine.ACTIVE(), "not in state active");

        vm.expectEmit();
        emit LogStateChanged(statemachine.ACTIVE(), statemachine.PAUSED());

        statemachine.changeToState(statemachine.PAUSED());
    }

    function testExperimentStatemachineFromPausedToZero() public {
        statemachine.changeToState(statemachine.PAUSED());
        assertTrue(statemachine.getState() == statemachine.PAUSED(), "not in state paused");

        StateId newState = zeroStateId();
        assertFalse(statemachine.isValidTransition(statemachine.getState(), newState));

        vm.expectRevert(
            abi.encodeWithSelector(
                ErrorStateChangeInvalid.selector,
                statemachine.getState(),
                newState));
        statemachine.changeToState(newState);
    }

    function testExperimentStatemachineFromPausedToActive() public {
        statemachine.changeToState(statemachine.PAUSED());
        assertTrue(statemachine.getState() == statemachine.PAUSED(), "not in state paused");

        vm.expectEmit();
        emit LogStateChanged(statemachine.PAUSED(), statemachine.ACTIVE());

        statemachine.changeToState(statemachine.ACTIVE());
    }

    function testExperimentStatemachineFromPausedToArchived() public {
        statemachine.changeToState(statemachine.PAUSED());
        assertTrue(statemachine.getState() == statemachine.PAUSED(), "not in state paused");

        vm.expectEmit();
        emit LogStateChanged(statemachine.PAUSED(), statemachine.ARCHIVED());

        statemachine.changeToState(statemachine.ARCHIVED());
    }
}
