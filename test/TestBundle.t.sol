// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../lib/forge-std/src/Test.sol";

import {Amount, AmountLib} from "../contracts/type/Amount.sol";
import {BasicPoolAuthorization} from "../contracts/pool/BasicPoolAuthorization.sol";
import {Fee, FeeLib} from "../contracts/type/Fee.sol";
import {IBundle} from "../contracts/instance/module/IBundle.sol";
import {IComponents} from "../contracts/instance/module/IComponents.sol";
import {IKeyValueStore} from "../contracts/shared/IKeyValueStore.sol";
import {ILifecycle} from "../contracts/shared/ILifecycle.sol";
import {Key32} from "../contracts/type/Key32.sol";
import {NftId, NftIdLib} from "../contracts/type/NftId.sol";
import {ObjectType, BUNDLE} from "../contracts/type/ObjectType.sol";
import {Pool} from "../contracts/pool/Pool.sol";
import {IPoolService} from "../contracts/pool/IPoolService.sol";
import {POOL_OWNER_ROLE, PUBLIC_ROLE} from "../contracts/type/RoleId.sol";
import {Seconds, SecondsLib} from "../contracts/type/Seconds.sol";
import {SimplePool} from "./mock/SimplePool.sol";
import {StateId, ACTIVE, PAUSED, CLOSED} from "../contracts/type/StateId.sol";
import {TimestampLib} from "../contracts/type/Timestamp.sol";
import {GifTest} from "./base/GifTest.sol";
import {UFixedLib} from "../contracts/type/UFixed.sol";

contract TestBundle is GifTest {


    /// @dev test staking of an existing bundle 
    function test_Bundle_stakeBundle() public {
        // GIVEN
        initialStakingFee = FeeLib.percentageFee(4);
        _prepareProduct(false);
        
        IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);

        vm.startPrank(investor);
        token.approve(address(pool.getTokenHandler()), 2000);

        Seconds lifetime = SecondsLib.toSeconds(604800);
        bundleNftId = pool.createBundle(
            FeeLib.zero(), 
            1000, 
            lifetime, 
            ""
        );
        vm.stopPrank();

        assertTrue(!bundleNftId.eqz(), "bundle nft id is zero");

        assertEq(token.balanceOf(poolComponentInfo.wallet), 1000, "pool wallet token balance not 1000");
        uint256 investorBalanceBefore = token.balanceOf(investor);

        assertEq(instanceReader.getBalanceAmount(poolNftId).toInt(), 1000, "pool balance not 1000");
        assertEq(instanceReader.getFeeAmount(poolNftId).toInt(), 40, "pool fees not 40");

        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), 960, "bundle balance not 960");
        assertEq(instanceReader.getFeeAmount(bundleNftId).toInt(), 0, "bundle fees 0");

        uint256 stakeAmount = 1000;
        Amount stakeAmt = AmountLib.toAmount(stakeAmount);
        Amount stakeNetAmt = AmountLib.toAmount(960);
        vm.startPrank(investor);

        // THEN - expect log event
        vm.expectEmit();
        emit IPoolService.LogPoolServiceBundleStaked(instanceNftId, poolNftId, bundleNftId, stakeAmt, stakeNetAmt);

        // WHEN - pool is staked with another 1000 tokens
        pool.stake(bundleNftId, stakeAmt);
        
        // THEN - assert all counters are updated
        assertEq(token.balanceOf(poolComponentInfo.wallet), 2000, "pool wallet token balance not 2000");
        assertEq(token.balanceOf(investor), investorBalanceBefore - stakeAmount, "investor token balance not 0");

        assertEq(instanceReader.getBalanceAmount(poolNftId).toInt(), 2000, "pool balance not 2000");
        assertEq(instanceReader.getFeeAmount(poolNftId).toInt(), 80, "pool fees not 80");

        assertEq(instanceReader.getBalanceAmount(bundleNftId).toInt(), 1920, "bundle balance not 1920");
        assertEq(instanceReader.getFeeAmount(bundleNftId).toInt(), 0, "bundle fees 0");
    }

    /// @dev test staking of an existing bundle 
    function test_Bundle_stakeBundle_allowanceTooSmall() public {
        // GIVEN
        initialStakingFee = FeeLib.percentageFee(4);
        _prepareProduct(false);
        
        IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);

        vm.startPrank(investor);
        token.approve(address(pool.getTokenHandler()), 1000);

        Seconds lifetime = SecondsLib.toSeconds(604800);
        bundleNftId = pool.createBundle(
            FeeLib.zero(), 
            1000, 
            lifetime, 
            ""
        );
        
        Amount stakeAmount = AmountLib.toAmount(1000);

        // THEN  
        vm.expectRevert(abi.encodeWithSelector(
            IPoolService.ErrorPoolServiceWalletAllowanceTooSmall.selector, 
            investor,
            address(pool.getTokenHandler()),
            0,
            1000
            ));

        // WHEN - pool is staked with another 1000 tokens
        pool.stake(bundleNftId, stakeAmount);
    }

    /// @dev test staking of an existing bundle 
    function test_Bundle_stakeBundle_amountIsZero() public {
        // GIVEN
        initialStakingFee = FeeLib.percentageFee(4);
        _prepareProduct(false);
        
        IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);

        vm.startPrank(investor);
        token.approve(address(pool.getTokenHandler()), 2000);

        Seconds lifetime = SecondsLib.toSeconds(604800);
        bundleNftId = pool.createBundle(
            FeeLib.zero(), 
            1000, 
            lifetime, 
            ""
        );
        
        Amount stakeAmount = AmountLib.toAmount(0);

        // THEN  
        vm.expectRevert(abi.encodeWithSelector(
            IPoolService.ErrorPoolServiceAmountIsZero.selector));

        // WHEN - pool is staked with another 1000 tokens
        pool.stake(bundleNftId, stakeAmount);
    }

    function _fundInvestor(uint256 amount) internal {
        vm.startPrank(registryOwner);
        token.transfer(investor, amount);
        vm.stopPrank();
    }

}
