// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";

import {Amount, AmountLib} from "../../contracts/type/Amount.sol";
import {Dip} from "../../contracts/mock/Dip.sol";
import {Test} from "../../lib/forge-std/src/Test.sol";
import {TokenHandler} from "../../contracts/shared/TokenHandler.sol";


contract TokenHandlerTest is Test {
    Dip public dip;
    TokenHandler public tokenHandler;
    AccessManager public accessManager;

    function setUp() public {
        dip = new Dip();
        
        accessManager = new AccessManager(address(this));

        // FIXME: use a real authority for testing
        tokenHandler = new TokenHandler(address(dip), address(accessManager));

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = TokenHandler.collectTokens.selector;
        selectors[1] = TokenHandler.collectTokensThreeRecipients.selector;
        selectors[2] = TokenHandler.distributeTokens.selector;

        accessManager.setTargetFunctionRole(address(tokenHandler), selectors, type(uint64).max);
    }

    function test_TokenHandler_getToken() public {
        assertEq(address(dip), address(tokenHandler.getToken()));
    }

    function test_TokenHandler_collectTokens() public {
        // GIVEN
        uint256 amountInt = 100;
        Amount amount = AmountLib.toAmount(amountInt);
        address sender = _makeAddrWithFunds("sender", amountInt);
        address recipient = _makeAddrWithFunds("recipient", 0);
        _approveTokenHandler(sender, amountInt);
        
        // THEN
        vm.expectEmit();
        emit TokenHandler.LogTokenHandlerTokenTransfer(address(dip), sender, recipient, amountInt);

        // WHEN
        tokenHandler.collectTokens(sender, recipient, amount);
        
        // THEN
        assertEq(dip.balanceOf(sender), 0);
        assertEq(dip.balanceOf(recipient), amountInt);
    }

    function test_TokenHandler_collectTokens2() public {
        // GIVEN
        uint256 amountInt = 1;
        Amount amount = AmountLib.toAmount(amountInt);
        address sender = _makeAddrWithFunds("sender", amountInt);
        address recipient = _makeAddrWithFunds("recipient", 0);
        _approveTokenHandler(sender, amountInt);
        
        // THEN
        vm.expectEmit();
        emit TokenHandler.LogTokenHandlerTokenTransfer(address(dip), sender, recipient, amountInt);

        // WHEN
        tokenHandler.collectTokens(sender, recipient, amount);
        
        // THEN
        assertEq(dip.balanceOf(sender), 0);
        assertEq(dip.balanceOf(recipient), amountInt);
    }

    function test_TokenHandler_collectTokens3() public {
        // GIVEN
        uint256 amountInt = 100;
        Amount amount = AmountLib.toAmount(amountInt);
        address sender = _makeAddrWithFunds("sender", amountInt);
        _fundAddr(sender, 100);
        address recipient = _makeAddrWithFunds("recipient", 0);
        _approveTokenHandler(sender, amountInt);
        
        // THEN
        vm.expectEmit();
        emit TokenHandler.LogTokenHandlerTokenTransfer(address(dip), sender, recipient, amountInt);

        // WHEN
        tokenHandler.collectTokens(sender, recipient, amount);
        
        // THEN
        assertEq(dip.balanceOf(sender), 100);
        assertEq(dip.balanceOf(recipient), amountInt);
    }

    function test_TokenHandler_amountIsZero() public {
        // GIVEN
        uint256 amountInt = 0;
        Amount amount = AmountLib.toAmount(amountInt);
        address sender = _makeAddrWithFunds("sender", amountInt);
        address recipient = _makeAddrWithFunds("recipient", 0);
        _approveTokenHandler(sender, amountInt);
        
        // THEN
        vm.expectRevert(abi.encodeWithSelector(TokenHandler.ErrorTokenHandlerAmountIsZero.selector));

        // WHEN
        tokenHandler.collectTokens(sender, recipient, amount);
    }

    function test_TokenHandler_balanceIsZero() public {
        // GIVEN
        uint256 amountInt = 100;
        Amount amount = AmountLib.toAmount(amountInt);
        address sender = _makeAddrWithFunds("sender", 0);
        address recipient = _makeAddrWithFunds("recipient", 0);
        _approveTokenHandler(sender, 100);
        
        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            TokenHandler.ErrorTokenHandlerBalanceTooLow.selector,
            address(dip), 
            sender,
            0,
            100
            ));

        // WHEN
        tokenHandler.collectTokens(sender, recipient, amount);
    }

    function test_TokenHandler_balanceTooLow() public {
        // GIVEN
        uint256 amountInt = 100;
        Amount amount = AmountLib.toAmount(amountInt);
        address sender = _makeAddrWithFunds("sender", 99);
        address recipient = _makeAddrWithFunds("recipient", 0);
        _approveTokenHandler(sender, 100);
        
        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            TokenHandler.ErrorTokenHandlerBalanceTooLow.selector,
            address(dip), 
            sender,
            99,
            100
            ));

        // WHEN
        tokenHandler.collectTokens(sender, recipient, amount);
    }

    function test_TokenHandler_allowanceIsZero() public {
        // GIVEN
        uint256 amountInt = 100;
        Amount amount = AmountLib.toAmount(amountInt);
        address sender = _makeAddrWithFunds("sender", 100);
        address recipient = _makeAddrWithFunds("recipient", 0);
        
        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            TokenHandler.ErrorTokenHandlerAllowanceTooSmall.selector,
            address(dip), 
            sender,
            address(tokenHandler),
            0,
            100
            ));

        // WHEN
        tokenHandler.collectTokens(sender, recipient, amount);
    }

    function test_TokenHandler_collectTokens_3rcpt() public {
        // GIVEN
        uint256 amountInt = 100;
        Amount amount = AmountLib.toAmount(amountInt);
        address sender = _makeAddrWithFunds("sender", amountInt * 3);
        address recipient1 = _makeAddrWithFunds("recipient1", 0);
        address recipient2 = _makeAddrWithFunds("recipient2", 0);
        address recipient3 = _makeAddrWithFunds("recipient3", 0);

        _approveTokenHandler(sender, amountInt * 3);
        
        // THEN
        vm.expectEmit();
        emit TokenHandler.LogTokenHandlerTokenTransfer(address(dip), sender, recipient1, amountInt);
        vm.expectEmit();
        emit TokenHandler.LogTokenHandlerTokenTransfer(address(dip), sender, recipient2, amountInt);
        vm.expectEmit();
        emit TokenHandler.LogTokenHandlerTokenTransfer(address(dip), sender, recipient3, amountInt);

        // WHEN
        tokenHandler.collectTokensThreeRecipients(sender, recipient1, amount, recipient2, amount, recipient3, amount);
        
        // THEN
        assertEq(dip.balanceOf(sender), 0);
        assertEq(dip.balanceOf(recipient1), amountInt);
        assertEq(dip.balanceOf(recipient2), amountInt);
        assertEq(dip.balanceOf(recipient3), amountInt);
    }

    function test_TokenHandler_collectTokens_3rcpt_amt1IsZero() public {
        // GIVEN
        uint256 amountInt = 100;
        Amount amount = AmountLib.toAmount(amountInt);
        address sender = _makeAddrWithFunds("sender", amountInt * 3);
        address recipient1 = _makeAddrWithFunds("recipient1", 0);
        address recipient2 = _makeAddrWithFunds("recipient2", 0);
        address recipient3 = _makeAddrWithFunds("recipient3", 0);

        _approveTokenHandler(sender, amountInt * 3);
        
        // WHEN
        tokenHandler.collectTokensThreeRecipients(sender, recipient1, AmountLib.zero(), recipient2, amount, recipient3, amount);
        
        // THEN
        assertEq(dip.balanceOf(sender), 100);
        assertEq(dip.balanceOf(recipient1), 0);
        assertEq(dip.balanceOf(recipient2), amountInt);
        assertEq(dip.balanceOf(recipient3), amountInt);
    }


    function test_TokenHandler_collectTokens_3rcpt_amt2IsZero() public {
        // GIVEN
        uint256 amountInt = 100;
        Amount amount = AmountLib.toAmount(amountInt);
        address sender = _makeAddrWithFunds("sender", amountInt * 3);
        address recipient1 = _makeAddrWithFunds("recipient1", 0);
        address recipient2 = _makeAddrWithFunds("recipient2", 0);
        address recipient3 = _makeAddrWithFunds("recipient3", 0);

        _approveTokenHandler(sender, amountInt * 3);
        
        // WHEN
        tokenHandler.collectTokensThreeRecipients(sender, recipient1, amount, recipient2, AmountLib.zero(), recipient3, amount);
        
        // THEN
        assertEq(dip.balanceOf(sender), 100);
        assertEq(dip.balanceOf(recipient1), amountInt);
        assertEq(dip.balanceOf(recipient2), 0);
        assertEq(dip.balanceOf(recipient3), amountInt);
    }

    function test_TokenHandler_collectTokens_3rcpt_amt3IsZero() public {
        // GIVEN
        uint256 amountInt = 100;
        Amount amount = AmountLib.toAmount(amountInt);
        address sender = _makeAddrWithFunds("sender", amountInt * 3);
        address recipient1 = _makeAddrWithFunds("recipient1", 0);
        address recipient2 = _makeAddrWithFunds("recipient2", 0);
        address recipient3 = _makeAddrWithFunds("recipient3", 0);

        _approveTokenHandler(sender, amountInt * 3);
        
        // WHEN
        tokenHandler.collectTokensThreeRecipients(sender, recipient1, amount, recipient2, amount, recipient3, AmountLib.zero());
        
        // THEN
        assertEq(dip.balanceOf(sender), 100);
        assertEq(dip.balanceOf(recipient1), amountInt);
        assertEq(dip.balanceOf(recipient2), amountInt);
        assertEq(dip.balanceOf(recipient3), 0);
    }

    function test_TokenHandler_collectTokens_3rcpt_allowanceTooSmall() public {
        // GIVEN
        uint256 amountInt = 100;
        Amount amount = AmountLib.toAmount(amountInt);
        address sender = _makeAddrWithFunds("sender", amountInt * 3);
        address recipient1 = _makeAddrWithFunds("recipient1", 0);
        address recipient2 = _makeAddrWithFunds("recipient2", 0);
        address recipient3 = _makeAddrWithFunds("recipient3", 0);

        _approveTokenHandler(sender, amountInt * 2);
        
        vm.expectRevert(abi.encodeWithSelector(
            TokenHandler.ErrorTokenHandlerAllowanceTooSmall.selector,
            address(dip), 
            sender,
            address(tokenHandler),
            200,
            300
            ));

        // WHEN
        tokenHandler.collectTokensThreeRecipients(sender, recipient1, amount, recipient2, amount, recipient3, amount);
    }

    function test_TokenHandler_collectTokens_3rcpt_rcptEqual1() public {
        // GIVEN
        uint256 amountInt = 100;
        Amount amount = AmountLib.toAmount(amountInt);
        address sender = _makeAddrWithFunds("sender", amountInt * 3);
        address recipient1 = _makeAddrWithFunds("recipient1", 0);
        address recipient2 = _makeAddrWithFunds("recipient2", 0);
        address recipient3 = _makeAddrWithFunds("recipient3", 0);

        _approveTokenHandler(sender, amountInt * 3);
        
        vm.expectRevert(abi.encodeWithSelector(
            TokenHandler.ErrorTokenHandlerRecipientWalletsMustBeDistinct.selector,
            recipient1,
            recipient1,
            recipient3
            ));

        // WHEN
        tokenHandler.collectTokensThreeRecipients(sender, recipient1, amount, recipient1, amount, recipient3, amount);
    }

        function test_TokenHandler_collectTokens_3rcpt_rcptEqual2() public {
        // GIVEN
        uint256 amountInt = 100;
        Amount amount = AmountLib.toAmount(amountInt);
        address sender = _makeAddrWithFunds("sender", amountInt * 3);
        address recipient1 = _makeAddrWithFunds("recipient1", 0);
        address recipient2 = _makeAddrWithFunds("recipient2", 0);
        address recipient3 = _makeAddrWithFunds("recipient3", 0);

        _approveTokenHandler(sender, amountInt * 3);
        
        vm.expectRevert(abi.encodeWithSelector(
            TokenHandler.ErrorTokenHandlerRecipientWalletsMustBeDistinct.selector,
            recipient1,
            recipient2,
            recipient1
            ));

        // WHEN
        tokenHandler.collectTokensThreeRecipients(sender, recipient1, amount, recipient2, amount, recipient1, amount);
    }

        function test_TokenHandler_collectTokens_3rcpt_rcptEqual3() public {
        // GIVEN
        uint256 amountInt = 100;
        Amount amount = AmountLib.toAmount(amountInt);
        address sender = _makeAddrWithFunds("sender", amountInt * 3);
        address recipient1 = _makeAddrWithFunds("recipient1", 0);
        address recipient2 = _makeAddrWithFunds("recipient2", 0);
        address recipient3 = _makeAddrWithFunds("recipient3", 0);

        _approveTokenHandler(sender, amountInt * 3);
        
        vm.expectRevert(abi.encodeWithSelector(
            TokenHandler.ErrorTokenHandlerRecipientWalletsMustBeDistinct.selector,
            recipient1,
            recipient2,
            recipient2
            ));

        // WHEN
        tokenHandler.collectTokensThreeRecipients(sender, recipient1, amount, recipient2, amount, recipient2, amount);
    }

    function test_TokenHandler_allowanceTooSmall() public {
        // GIVEN
        uint256 amountInt = 100;
        Amount amount = AmountLib.toAmount(amountInt);
        address sender = _makeAddrWithFunds("sender", 100);
        address recipient = _makeAddrWithFunds("recipient", 0);
        _approveTokenHandler(sender, 50);
        
        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            TokenHandler.ErrorTokenHandlerAllowanceTooSmall.selector,
            address(dip), 
            sender,
            address(tokenHandler),
            50,
            100
            ));

        // WHEN
        tokenHandler.collectTokens(sender, recipient, amount);
    }

    function test_TokenHandler_distributeTokens() public {
        // GIVEN
        uint256 amountInt = 100;
        Amount amount = AmountLib.toAmount(amountInt);
        address sender = _makeAddrWithFunds("sender", amountInt);
        address recipient = _makeAddrWithFunds("recipient", 0);
        _approveTokenHandler(sender, amountInt);
        
        // THEN
        vm.expectEmit();
        emit TokenHandler.LogTokenHandlerTokenTransfer(address(dip), sender, recipient, amountInt);

        // WHEN
        tokenHandler.distributeTokens(sender, recipient, amount);
        
        // THEN
        assertEq(dip.balanceOf(sender), 0);
        assertEq(dip.balanceOf(recipient), amountInt);
    }

    function _makeAddrWithFunds(string memory name, uint256 amount) internal returns (address) {
        address addr = makeAddr(name);
        dip.transfer(addr, amount);
        return addr;
    }

    function _fundAddr(address addr, uint256 amount) internal {
        dip.transfer(addr, amount);
    }

    function _approveTokenHandler(address from, uint256 amount) internal {
        vm.startPrank(from);
        dip.approve(address(tokenHandler), amount);
        vm.stopPrank();
    }
}
