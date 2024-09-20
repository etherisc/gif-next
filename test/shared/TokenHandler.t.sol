// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;


import {Amount, AmountLib} from "../../contracts/type/Amount.sol";
import {GifTest} from "../base/GifTest.sol";
import {TokenHandlerBase} from "../../contracts/shared/TokenHandler.sol";

contract TokenHandlerEx is TokenHandlerBase {

    constructor(
        address registry,
        address staking,
        address token
    )
        TokenHandlerBase(registry, staking, token)
    { }

    function approveMax() external {
        _approve(TOKEN, AmountLib.max());
    }

    function approve(Amount amount) external {
        _approve(TOKEN, amount);
    }

    function setWallet(address newWallet) external {
        _setWallet(newWallet);
    }

    function pullToken(address from, Amount amount) external {
        _pullToken(from, amount);
    }

    function pushToken(address to, Amount amount) external {
        _pushToken(to, amount);
    }
}


contract TokenHandlerTest is GifTest {

    TokenHandlerEx public tokenHandlerEx;
    Amount public amountZero = AmountLib.zero();

    function setUp() public override {
        super.setUp();

        tokenHandlerEx = new TokenHandlerEx(
            address(registry),
            address(staking),
            address(dip)
        );

        tokenHandlerEx.approveMax();
    }

    function test_tokenHandlerSetUp() public {

        assertEq(tokenHandlerEx.getWallet(), address(tokenHandlerEx), "unexpected staking wallet");
        assertEq(address(tokenHandlerEx.TOKEN()), address(dip), "staking token not dip");
        // assertEq(tokenHandlerEx.TOKEN().allowance(address(tokenHandlerEx), address(tokenHandlerEx)), type(uint256).max, "unexpected approval");
    }

    function test_tokenHandlerCollectTokenHappyCase() public {
        // GIVEN
        uint256 amountInt = 100;
        Amount amount = AmountLib.toAmount(amountInt);
        address sender = _makeAddrWithFunds("sender", amountInt);
        address tokenHandlerWallet = tokenHandlerEx.getWallet();
        _approveTokenHandlerFor(sender, amountInt);
        
        // THEN
        vm.expectEmit();
        emit TokenHandlerBase.LogTokenHandlerTokenTransfer(
            address(dip), 
            sender, 
            tokenHandlerWallet, 
            amount);

        // WHEN
        tokenHandlerEx.pullToken(sender, amount);
        
        // THEN
        assertEq(dip.balanceOf(sender), 0);
        assertEq(dip.balanceOf(tokenHandlerWallet), amountInt);
    }

    function test_tokenHandlerCollectTokens2() public {
        // GIVEN
        uint256 amountInt = 1;
        Amount amount = AmountLib.toAmount(amountInt);
        address sender = _makeAddrWithFunds("sender", amountInt);
        address tokenHandlerWallet = tokenHandlerEx.getWallet();
        _approveTokenHandlerFor(sender, amountInt);
        
        // THEN
        vm.expectEmit();
        emit TokenHandlerBase.LogTokenHandlerTokenTransfer(address(dip), sender, tokenHandlerWallet, amount);

        // WHEN
        tokenHandlerEx.pullToken(sender, amount);
        
        // THEN
        assertEq(dip.balanceOf(sender), 0);
        assertEq(dip.balanceOf(tokenHandlerWallet), amountInt);
    }

    function test_tokenHandlerCollectTokens3() public {
        // GIVEN
        uint256 amountInt = 100;
        Amount amount = AmountLib.toAmount(amountInt);
        address sender = _makeAddrWithFunds("sender", amountInt);
        _fundAddr(sender, 100);
        address tokenHandlerWallet = tokenHandlerEx.getWallet();
        _approveTokenHandlerFor(sender, amountInt);
        
        // THEN
        vm.expectEmit();
        emit TokenHandlerBase.LogTokenHandlerTokenTransfer(address(dip), sender, tokenHandlerWallet, amount);

        // WHEN
        tokenHandlerEx.pullToken(sender, amount);
        
        // THEN
        assertEq(dip.balanceOf(sender), 100);
        assertEq(dip.balanceOf(tokenHandlerWallet), amountInt);
    }

    function test_tokenHandlerAmountIsZero() public {
        // GIVEN
        uint256 amountInt = 0;
        Amount amount = AmountLib.toAmount(amountInt);
        address sender = _makeAddrWithFunds("sender", amountInt);
        _approveTokenHandlerFor(sender, amountInt);
        
        // THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenHandlerBase.ErrorTokenHandlerAmountIsZero.selector));

        // WHEN
        tokenHandlerEx.pullToken(sender, amount);
    }

    function test_tokenHandlerBalanceIsZero() public {
        // GIVEN
        uint256 amountInt = 100;
        Amount amount = AmountLib.toAmount(amountInt);
        address sender = _makeAddrWithFunds("sender", 0);
        _approveTokenHandlerFor(sender, 100);
        
        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            TokenHandlerBase.ErrorTokenHandlerBalanceTooLow.selector,
            address(dip), 
            sender,
            0,
            100
            ));

        // WHEN
        tokenHandlerEx.pullToken(sender, amount);
    }

    function test_tokenHandlerBalanceTooLow() public {
        // GIVEN
        uint256 amountInt = 100;
        Amount amount = AmountLib.toAmount(amountInt);
        address sender = _makeAddrWithFunds("sender", 99);
        _approveTokenHandlerFor(sender, 100);
        
        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            TokenHandlerBase.ErrorTokenHandlerBalanceTooLow.selector,
            address(dip), 
            sender,
            99,
            100
            ));

        // WHEN
        tokenHandlerEx.pullToken(sender, amount);
    }

    function test_tokenHandlerAllowanceIsZero() public {
        // GIVEN
        uint256 amountInt = 100;
        Amount amount = AmountLib.toAmount(amountInt);
        address sender = _makeAddrWithFunds("sender", 100);
        _approveTokenHandlerFor(sender, 0);

        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            TokenHandlerBase.ErrorTokenHandlerAllowanceTooSmall.selector,
            address(dip), 
            sender,
            address(tokenHandlerEx),
            0,
            100
            ));

        // WHEN
        tokenHandlerEx.pullToken(sender, amount);
    }

    function test_tokenHandlerAllowanceTooLow() public {
        // GIVEN
        uint256 amountInt = 100;
        Amount amount = AmountLib.toAmount(amountInt);
        address sender = _makeAddrWithFunds("sender", 100);
        _approveTokenHandlerFor(sender, 99);

        // THEN
        vm.expectRevert(abi.encodeWithSelector(
            TokenHandlerBase.ErrorTokenHandlerAllowanceTooSmall.selector,
            address(dip), 
            sender,
            address(tokenHandlerEx),
            99,
            100
            ));

        // WHEN
        tokenHandlerEx.pullToken(sender, amount);
    }

    function test_tokenHandlerPushToken() public {
        // GIVEN
        uint256 amountInt = 100;
        Amount amount = AmountLib.toAmount(amountInt);
        address sender = tokenHandlerEx.getWallet();
        address recipient = _makeAddrWithFunds("recipient", 0);
        _fundAndApprove(tokenHandlerEx, sender, amount, amount);

        // THEN
        vm.expectEmit();
        emit TokenHandlerBase.LogTokenHandlerTokenTransfer(address(dip), sender, recipient, amount);

        // WHEN
        tokenHandlerEx.pushToken(recipient, amount);
        
        // THEN
        assertEq(dip.balanceOf(sender), 0);
        assertEq(dip.balanceOf(recipient), amountInt);
    }

    function _preparePullAndPushTokenTest(uint256 amountInt)
        internal 
        returns (
            Amount pullAmount,
            Amount amount,
            address sender, 
            address wallet, 
            address recipient1, 
            address recipient2
        )
    {
        uint256 pullAmountInt = 3 * amountInt;
        pullAmount = AmountLib.toAmount(pullAmountInt);
        amount = AmountLib.toAmount(amountInt);

        sender = _makeAddrWithFunds("sender", pullAmountInt);
        wallet = tokenHandlerEx.getWallet();
        recipient1 = _makeAddrWithFunds("recipient1", 0);
        recipient2 = _makeAddrWithFunds("recipient2", 0);

        _approveTokenHandlerFor(sender, pullAmountInt);
    }

    function _fundAndApprove(TokenHandlerEx th, address sender, Amount amount, Amount approval) internal {

        vm.startPrank(tokenIssuer);
        dip.transfer(sender, amount.toInt());
        vm.stopPrank();

        vm.startPrank(sender);
        dip.approve(address(th), approval.toInt());
        vm.stopPrank();
    }

    function _makeAddrWithFunds(string memory name, uint256 amount) internal returns (address addr) {
        addr = makeAddr(name);

        vm.startPrank(tokenIssuer);
        dip.transfer(addr, amount);
        vm.stopPrank();
    }

    function _fundAddr(address addr, uint256 amount) internal {
        vm.startPrank(tokenIssuer);
        dip.transfer(addr, amount);
        vm.stopPrank();
    }

    function _approveTokenHandlerFor(address from, uint256 amount) internal {
        vm.startPrank(from);
        dip.approve(address(tokenHandlerEx), amount);
        vm.stopPrank();
    }
}
