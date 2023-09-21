// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import "../lib/forge-std/src/Test.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {DeployAll} from "../scripts/DeployAll.s.sol";

import {IChainNft} from "../contracts/registry/ChainNft.sol";
import {Registry} from "../contracts/registry/Registry.sol";

import {ComponentOwnerService} from "../contracts/instance/service/ComponentOwnerService.sol";
import {ProductService} from "../contracts/instance/service/ProductService.sol";
import {PoolService} from "../contracts/instance/service/PoolService.sol";

import {Instance} from "../contracts/instance/Instance.sol";
import {TestProduct} from "../contracts/test/TestProduct.sol";
import {TestPool} from "../contracts/test/TestPool.sol";
import {USDC} from "./mock/Usdc.sol";

import {IPolicy} from "../contracts/instance/module/policy/IPolicy.sol";
import {IPool} from "../contracts/instance/module/pool/IPoolModule.sol";
import {NftId, NftIdLib} from "../contracts/types/NftId.sol";

contract TestGifBase is Test {
    using NftIdLib for NftId;

    IChainNft public chainNft;
    Registry public registry;
    IERC20Metadata public token;
    ComponentOwnerService public componentOwnerService;
    ProductService public productService;
    PoolService public poolService;
    Instance public instance;
    TestProduct public product;
    TestPool public pool;

    address public instanceOwner = makeAddr("instanceOwner");
    address public productOwner = makeAddr("productOwner");
    address public poolOwner = makeAddr("poolOwner");
    address public customer = makeAddr("customer");
    address public outsider = makeAddr("outsider");

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

        token = product.getToken();
        chainNft = registry.getChainNft();
    }

    function fundAccount(address account, uint256 amount) public {
        token.transfer(account, amount);
    }

    /// @dev Helper function to assert that a given NftId is equal to the expected NftId.
    function assertNftId(NftId actualNftId, NftId expectedNftId, string memory message) public {
        if(block.chainid == 31337) {
            assertEq(actualNftId.toInt(), expectedNftId.toInt(), message);
        } else {
            // solhint ignore
            // solhint-disable-next-line
            console.log("chain not anvil, skipping assertNftId");
        }
    }

    /// @dev Helper function to assert that a given NftId is equal to zero.
    function assertNftIdZero(NftId nftId, string memory message) public {
        if(block.chainid == 31337) {
            assertTrue(nftId.eqz(), message);
        } else {
            // solhint-disable-next-line
            console.log("chain not anvil, skipping assertNftId");
        }
    }
}