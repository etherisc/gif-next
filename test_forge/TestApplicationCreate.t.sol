// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {TestGifBase} from "./TestGifBase.sol";
import {IPolicy} from "../contracts/instance/policy/IPolicy.sol";
import {IPool} from "../contracts/instance/pool/IPoolModule.sol";
import {APPLIED, ACTIVE} from "../contracts/types/StateId.sol";
import {NftId, toNftId} from "../contracts/types/NftId.sol";

contract TestApplicationCreate is TestGifBase {
    uint256 sumInsuredAmount = 1000 * 10 ** 6;
    uint256 premiumAmount = 110 * 10 ** 6;
    uint256 lifetime = 365 * 24 * 3600;

    function testApplicationCreateSimple() public {
        vm.prank(customer);
        NftId policyNftId = product.applyForPolicy(
            sumInsuredAmount,
            premiumAmount,
            lifetime
        );

        assertNftId(policyNftId, toNftId(53133705), "policy id not 53133705");
        assertEq(
            registry.getOwner(policyNftId),
            customer,
            "customer not policy owner"
        );
        assertNftIdZero(
            instance.getBundleNftForPolicy(policyNftId),
            "bundle id not 0"
        );

        IPolicy.PolicyInfo memory info = instance.getPolicyInfo(policyNftId);
        assertNftId(info.nftId, policyNftId, "policy id differs");
        assertEq(info.state.toInt(), APPLIED().toInt(), "policy state not applied");

        assertEq(info.sumInsuredAmount, sumInsuredAmount, "wrong sum insured amount");
        assertEq(info.premiumAmount, premiumAmount, "wrong premium amount");
        assertEq(info.lifetime, lifetime, "wrong lifetime");

        assertEq(info.createdAt, block.timestamp, "wrong created at");
        assertEq(info.activatedAt, 0, "wrong activated at");
        assertEq(info.expiredAt, 0, "wrong expired at");
        assertEq(info.closedAt, 0, "wrong closed at");
    }

    function testApplicationCreateAndUnderwrite() public {
        vm.prank(customer);
        NftId policyNftId = product.applyForPolicy(
            sumInsuredAmount,
            premiumAmount,
            lifetime
        );

        IPool.PoolInfo memory poolInfoBefore = instance.getPoolInfo(
            pool.getNftId()
        );

        product.underwrite(policyNftId);

        IPolicy.PolicyInfo memory info = instance.getPolicyInfo(policyNftId);
        assertNftId(info.nftId, policyNftId, "policy id differs");
        assertEq(info.state.toInt(), ACTIVE().toInt(), "policy state not active/underwritten");

        assertEq(info.activatedAt, block.timestamp, "wrong activated at");
        assertEq(
            info.expiredAt,
            block.timestamp + info.lifetime,
            "wrong expired at"
        );
        assertEq(info.closedAt, 0, "wrong closed at");

        IPool.PoolInfo memory poolInfoAfter = instance.getPoolInfo(pool.getNftId());
        assertEq(poolInfoAfter.nftId.toInt(), 33133705, "pool id not 33133705");
        assertEq(poolInfoBefore.lockedCapital, 0, "capital locked not 0");
        assertEq(
            poolInfoAfter.lockedCapital,
            sumInsuredAmount,
            "capital locked not sum insured"
        );
    }
}
