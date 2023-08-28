// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import "../lib/forge-std/src/Test.sol";

import {DeployAll} from "../scripts/DeployAll.s.sol";

import {ChainNft} from "../contracts/registry/ChainNft.sol";
import {Registry} from "../contracts/registry/Registry.sol";
import {Instance} from "../contracts/instance/Instance.sol";
import {TestProduct} from "./mock/TestProduct.sol";
import {TestPool} from "./mock/TestPool.sol";

import {IPolicy} from "../contracts/instance/policy/IPolicy.sol";
import {IPool} from "../contracts/instance/pool/IPoolModule.sol";
import {NftId, NftIdLib} from "../contracts/types/NftId.sol";

contract TestGifBase is Test {
    using NftIdLib for NftId;

    ChainNft chainNft;
    Registry registry;
    Instance instance;
    TestProduct product;
    TestPool pool;

    address instanceOwner = makeAddr("instanceOwner");
    address productOwner = makeAddr("productOwner");
    address poolOwner = makeAddr("poolOwner");
    address customer = makeAddr("customer");
    address outsider = makeAddr("outsider");

    function setUp() public virtual {
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

        chainNft = ChainNft(registry.getNftAddress());
    }

    function assertNftId(NftId actualNftId, NftId expectedNftId, string memory message) public {
        if(block.chainid == 31337) {
            assertEq(actualNftId.toInt(), expectedNftId.toInt(), message);
        } else {
            console.log("chain not anvil, skipping assertNftId");
        }
    }

    function assertNftIdZero(NftId nftId, string memory message) public {
        if(block.chainid == 31337) {
            assertTrue(nftId.eqz(), message);
        } else {
            console.log("chain not anvil, skipping assertNftId");
        }
    }
}