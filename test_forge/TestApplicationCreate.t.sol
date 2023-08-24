// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import "../lib/forge-std/src/Test.sol";
import {console} from "../lib/forge-std/src/Script.sol";

import {DeployAll} from "../scripts/DeployAll.s.sol";

import {Registry} from "../contracts/registry/Registry.sol";
import {Instance} from "../contracts/instance/Instance.sol";
import {TestProduct} from "./mock/TestProduct.sol";
import {TestPool} from "./mock/TestPool.sol";

import {IPolicy} from "../contracts/instance/policy/IPolicy.sol";
import {IPool} from "../contracts/instance/pool/IPoolModule.sol";

contract TestApplicationCreate is Test {

    Registry registry;
    Instance instance;
    TestProduct product;
    TestPool pool;

    address instanceOwner = makeAddr("instanceOwner");
    address productOwner = makeAddr("productOwner");
    address poolOwner = makeAddr("poolOwner");
    address customer = makeAddr("customer");

    uint256 sumInsuredAmount = 1000*10**6;
    uint256 premiumAmount = 110*10**6;
    uint256 lifetime =365*24*3600;

    function setUp() external {
        DeployAll deployer = new DeployAll();
        (
            registry, 
            instance, 
            product,
            pool
        ) = deployer.run(
            instanceOwner,
            productOwner,
            poolOwner);
    }


    function testApplicationCreateSimple() public {

        uint256 policyNftId = product.applyForPolicy(
            sumInsuredAmount, 
            premiumAmount, 
            lifetime);

        assertEq(policyNftId, 4, "policy id not 4");
        assertEq(instance.getBundleNftForPolicy(policyNftId), 0, "bundle id not 0");

        IPolicy.PolicyInfo memory info = instance.getPolicyInfo(policyNftId);
        assertEq(info.nftId, policyNftId, "policy id differs");
        assertEq(uint(info.state), uint(IPolicy.PolicyState.Applied), "policy state not applied");

        assertEq(info.sumInsuredAmount, sumInsuredAmount, "wrong sum insured amount");
        assertEq(info.premiumAmount, premiumAmount, "wrong premium amount");
        assertEq(info.lifetime, lifetime, "wrong lifetime");

        assertEq(info.createdAt, block.timestamp, "wrong created at");
        assertEq(info.activatedAt, 0, "wrong activated at");
        assertEq(info.expiredAt, 0, "wrong expired at");
        assertEq(info.closedAt, 0, "wrong closed at");
    }


    function testApplicationCreateAndUnderwrite() public {

        uint256 policyNftId = product.applyForPolicy(
            sumInsuredAmount, 
            premiumAmount, 
            lifetime);

        IPool.PoolInfo memory poolInfoBefore = instance.getPoolInfo(pool.getNftId());

        product.underwrite(policyNftId);

        IPolicy.PolicyInfo memory info = instance.getPolicyInfo(policyNftId);
        assertEq(info.nftId, policyNftId, "policy id differs");
        assertEq(uint(info.state), uint(IPolicy.PolicyState.Active), "policy state not active/underwritten");

        assertEq(info.activatedAt, block.timestamp, "wrong activated at");
        assertEq(info.expiredAt, block.timestamp + info.lifetime, "wrong expired at");
        assertEq(info.closedAt, 0, "wrong closed at");

        IPool.PoolInfo memory poolInfoAfter = instance.getPoolInfo(pool.getNftId());
        assertEq(poolInfoAfter.nftId, 2, "wrong pool id");
        assertEq(poolInfoBefore.lockedCapital, 0, "capital locked not 0");
        assertEq(poolInfoAfter.lockedCapital, sumInsuredAmount, "capital locked not sum insured");

    }
}