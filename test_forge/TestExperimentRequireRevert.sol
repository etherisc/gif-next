// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {Test} from "../lib/forge-std/src/Test.sol";
import {console} from "../lib/forge-std/src/Script.sol";

import {Require} from "../contracts/experiment/errors/Require.sol";
import {Revert} from "../contracts/experiment/errors/Revert.sol";

contract TestExperimentRequireRevert is Test {

    Require rq;
    Revert rv;

    function setUp() external {
        rq = new Require();
        rv = new Revert();
    }

    function testExperiment_RR_RequireOK_S() public {
        assertTrue(rq.isAlargerThanBRequire_S(100));
    }

    function testExperiment_RR_RequireNOK_S() public {
        vm.expectRevert("ERROR:ABC-001");
        rq.isAlargerThanBRequire_S(10);
    }

    function testExperiment_RR_RequireOK_M() public {
        assertTrue(rq.isAlargerThanBRequire_M(100));
    }

    function testExperiment_RR_RequireNOK_M() public {
        vm.expectRevert("ERROR:ABC-002:A_IS_SMALLER");
        rq.isAlargerThanBRequire_M(10);
    }

    function testExperiment_RR_RequireOK_L() public {
        assertTrue(rq.isAlargerThanBRequire_L(100));
    }

    function testExperiment_RR_RequireNOK_L() public {
        vm.expectRevert("ERROR:ABC-003:A_IS_SMALLER_THAN_B");
        rq.isAlargerThanBRequire_L(10);
    }

    function testExperiment_RR_RevertOK_S() public {
        assertTrue(rv.isAlargerThanBRevert_S(100));
    }

    function testExperiment_RR_RevertNOK_S() public {
        vm.expectRevert(Revert.AsmallerThanB_S.selector);
        rv.isAlargerThanBRevert_S(10);
    }

    function testExperiment_RR_RevertOK_M() public {
        assertTrue(rv.isAlargerThanBRevert_M(100));
    }

    function testExperiment_RR_RevertNOK_M() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Revert.AsmallerThanB_M.selector,
                10));
        rv.isAlargerThanBRevert_M(10);
    }

    function testExperiment_RR_RevertOK_L() public {
        assertTrue(rv.isAlargerThanBRevert_L(100));
    }

    function testExperiment_RR_RevertNOK_L() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Revert.AsmallerThanB_L.selector,
                10, 
                42));
        rv.isAlargerThanBRevert_L(10);
    }
}