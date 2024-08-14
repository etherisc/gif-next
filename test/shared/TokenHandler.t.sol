// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";

import {Amount, AmountLib} from "../../contracts/type/Amount.sol";
import {ComponentService} from "../../contracts/shared/ComponentService.sol";
import {Dip} from "../../contracts/mock/Dip.sol";
import {GifTest} from "../base/GifTest.sol";
import {IVersionable} from "../../contracts/upgradeability/IVersionable.sol";
import {Service} from "../../contracts/shared/Service.sol";
import {TokenHandler, TokenHandlerBase} from "../../contracts/shared/TokenHandler.sol";
import {Version, VersionLib} from "../../contracts/type/Version.sol";

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

    function pullAndPushToken(address from, Amount pullAmount, address to1, Amount pushAmount1, address to2, Amount pushAmount2) external {
        _pullAndPushToken(from, pullAmount, to1, pushAmount1, to2, pushAmount2);
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

    function test_tokenHandlerPullAndPushHappyCase() public {
        // GIVEN
        uint256 amountInt = 100;
        (
            Amount pullAmount,
            Amount amount,
            address sender, 
            address wallet, 
            address recipient1, 
            address recipient2
        ) = _preparePullAndPushTokenTest(amountInt);
        
        // THEN
        vm.expectEmit();
        emit TokenHandlerBase.LogTokenHandlerTokenTransfer(address(dip), sender, wallet, pullAmount);
        emit TokenHandlerBase.LogTokenHandlerTokenTransfer(address(dip), wallet, recipient1, amount);
        emit TokenHandlerBase.LogTokenHandlerTokenTransfer(address(dip), wallet, recipient2, amount);

        // WHEN
        tokenHandlerEx.pullAndPushToken(sender, pullAmount, recipient1, amount, recipient2, amount);
        
        // THEN
        assertEq(dip.balanceOf(sender), 0, "unexpected sender balance"  );
        assertEq(dip.balanceOf(wallet), amountInt, "unexpected wallet balance");
        assertEq(dip.balanceOf(recipient1), amountInt, "unexpected recipient1 balance");
        assertEq(dip.balanceOf(recipient2), amountInt, "unexpected recipient2 balance");
    }

    function test_tokenHandlerPullAndPushRecipient1Zero() public {
        uint256 amountInt = 100;
        (
            Amount pullAmount,
            Amount amount,
            address sender, 
            address wallet, 
            address recipient1, 
            address recipient2
        ) = _preparePullAndPushTokenTest(amountInt);
        
        // THEN
        vm.expectEmit();
        emit TokenHandlerBase.LogTokenHandlerTokenTransfer(address(dip), sender, wallet, pullAmount);
        emit TokenHandlerBase.LogTokenHandlerTokenTransfer(address(dip), wallet, recipient2, amount);

        // WHEN
        tokenHandlerEx.pullAndPushToken(sender, pullAmount, recipient1, amountZero, recipient2, amount);
        
        // THEN
        assertEq(dip.balanceOf(sender), 0, "unexpected sender balance"  );
        assertEq(dip.balanceOf(wallet), 2 * amountInt, "unexpected wallet balance");
        assertEq(dip.balanceOf(recipient1), 0, "unexpected recipient1 balance");
        assertEq(dip.balanceOf(recipient2), amountInt, "unexpected recipient2 balance");
    }


    function test_tokenHandlerPullAndPushRecipient2Zero() public {
        // GIVEN
        uint256 amountInt = 100;
        (
            Amount pullAmount,
            Amount amount,
            address sender, 
            address wallet, 
            address recipient1, 
            address recipient2
        ) = _preparePullAndPushTokenTest(amountInt);
        
        // THEN
        vm.expectEmit();
        emit TokenHandlerBase.LogTokenHandlerTokenTransfer(address(dip), sender, wallet, pullAmount);
        emit TokenHandlerBase.LogTokenHandlerTokenTransfer(address(dip), wallet, recipient1, amount);

        // WHEN
        tokenHandlerEx.pullAndPushToken(sender, pullAmount, recipient1, amount, recipient2, amountZero);
        
        // THEN
        assertEq(dip.balanceOf(sender), 0, "unexpected sender balance"  );
        assertEq(dip.balanceOf(wallet), 2 * amountInt, "unexpected wallet balance");
        assertEq(dip.balanceOf(recipient1), amountInt, "unexpected recipient1 balance");
        assertEq(dip.balanceOf(recipient2), 0, "unexpected recipient2 balance");
    }

    function test_tokenHandlerPullAndPushWalletZero() public {
        // GIVEN
        uint256 amountInt = 100;
        Amount amount1 = AmountLib.toAmount(2 * amountInt);
        (
            Amount pullAmount,
            Amount amount,
            address sender, 
            address wallet, 
            address recipient1, 
            address recipient2
        ) = _preparePullAndPushTokenTest(amountInt);
        
        // THEN
        vm.expectEmit();
        emit TokenHandlerBase.LogTokenHandlerTokenTransfer(address(dip), sender, wallet, pullAmount);
        emit TokenHandlerBase.LogTokenHandlerTokenTransfer(address(dip), wallet, recipient1, amount1);
        emit TokenHandlerBase.LogTokenHandlerTokenTransfer(address(dip), wallet, recipient2, amount);

        // WHEN
        tokenHandlerEx.pullAndPushToken(sender, pullAmount, recipient1, amount1, recipient2, amount);
        
        // THEN
        assertEq(dip.balanceOf(sender), 0, "unexpected sender balance"  );
        assertEq(dip.balanceOf(wallet), 0, "unexpected wallet balance");
        assertEq(dip.balanceOf(recipient1), 2 * amountInt, "unexpected recipient1 balance");
        assertEq(dip.balanceOf(recipient2), amountInt, "unexpected recipient2 balance");
    }

    function test_tokenHandlerPullAndPushWalletAllowanceTooSmall() public {
        // GIVEN
        uint256 amountInt = 100;
        (
            Amount pullAmount,
            Amount amount,
            address sender, 
            address wallet, 
            address recipient1, 
            address recipient2
        ) = _preparePullAndPushTokenTest(amountInt);

        _approveTokenHandlerFor(sender, amountInt * 2);

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenHandlerBase.ErrorTokenHandlerAllowanceTooSmall.selector,
                address(dip), 
                sender,
                address(tokenHandlerEx),
                200,
                300));

        // WHEN
        tokenHandlerEx.pullAndPushToken(sender, pullAmount, recipient1, amount, recipient2, amount);
    }

    function test_tokenHandlerPullAndPushWalletWalletsNotSame() public {
        // GIVEN
        uint256 amountInt = 100;
        (
            Amount pullAmount,
            Amount amount,
            address sender, 
            address wallet, 
            address recipient1, 
            address recipient2
        ) = _preparePullAndPushTokenTest(amountInt);

        // WHEN + THEN 1
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenHandlerBase.ErrorTokenHandlerWalletsNotDistinct.selector,
                wallet,
                wallet,
                recipient2));

        tokenHandlerEx.pullAndPushToken(sender, pullAmount, wallet, amount, recipient2, amount);

        // WHEN + THEN 2
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenHandlerBase.ErrorTokenHandlerWalletsNotDistinct.selector,
                wallet,
                recipient1,
                recipient1));

        tokenHandlerEx.pullAndPushToken(sender, pullAmount, recipient1, amount, recipient1, amount);

        // WHEN + THEN 3
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenHandlerBase.ErrorTokenHandlerWalletsNotDistinct.selector,
                wallet,
                recipient2,
                recipient2));

        tokenHandlerEx.pullAndPushToken(sender, pullAmount, recipient2, amount, recipient2, amount);
    }

    function test_tokenHandlerPullAndPushPushAmountTooLarge() public {
        // GIVEN
        uint256 amountInt = 100;
        Amount amountTooLarge = AmountLib.toAmount(3 * amountInt);
        Amount pushAmount = AmountLib.toAmount(4 * amountInt);
        (
            Amount pullAmount,
            Amount amount,
            address sender, 
            address wallet, 
            address recipient1, 
            address recipient2
        ) = _preparePullAndPushTokenTest(amountInt);

        _approveTokenHandlerFor(sender, amountInt * 2);

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenHandlerBase.ErrorTokenHandlerPushAmountsTooLarge.selector,
                pushAmount,
                pullAmount));

        // WHEN
        tokenHandlerEx.pullAndPushToken(sender, pullAmount, recipient1, amountTooLarge, recipient2, amount);
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

        vm.startPrank(registryOwner);
        dip.transfer(sender, amount.toInt());
        vm.stopPrank();

        vm.startPrank(sender);
        dip.approve(address(th), approval.toInt());
        vm.stopPrank();
    }

    function _makeAddrWithFunds(string memory name, uint256 amount) internal returns (address addr) {
        addr = makeAddr(name);

        vm.startPrank(registryOwner);
        dip.transfer(addr, amount);
        vm.stopPrank();
    }

    function _fundAddr(address addr, uint256 amount) internal {
        vm.startPrank(registryOwner);
        dip.transfer(addr, amount);
        vm.stopPrank();
    }

    function _approveTokenHandlerFor(address from, uint256 amount) internal {
        vm.startPrank(from);
        dip.approve(address(tokenHandlerEx), amount);
        vm.stopPrank();
    }
}
