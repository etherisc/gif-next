// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {Test, console} from "../../lib/forge-std/src/Test.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ChainNft, IChainNft} from "../../contracts/registry/ChainNft.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";

import {ComponentOwnerService} from "../../contracts/instance/service/ComponentOwnerService.sol";
import {ProductService} from "../../contracts/instance/service/ProductService.sol";
import {PoolService} from "../../contracts/instance/service/PoolService.sol";

import {Instance} from "../../contracts/instance/Instance.sol";
//import {IInstance} from "../../contracts/instance/IInstance.sol";
import {IKeyValueStore} from "../../contracts/instance/base/IKeyValueStore.sol";
import {TokenHandler} from "../../contracts/instance/module/treasury/TokenHandler.sol";
import {TestProduct} from "../../contracts/test/TestProduct.sol";
import {TestPool} from "../../contracts/test/TestPool.sol";
import {USDC} from "../../contracts/test/Usdc.sol";

import {IPolicy} from "../../contracts/instance/module/policy/IPolicy.sol";
import {IPool} from "../../contracts/instance/module/pool/IPoolModule.sol";
import {NftId, NftIdLib, zeroNftId} from "../../contracts/types/NftId.sol";
import {UFixed, UFixedMathLib} from "../../contracts/types/UFixed.sol";
import {PRODUCT_OWNER_ROLE, POOL_OWNER_ROLE} from "../../contracts/types/RoleId.sol";

import {ObjectType, POLICY, BUNDLE, PRODUCT, POOL, INSTANCE, TOKEN, REGISTRY} from "../../contracts/types/ObjectType.sol";

// solhint-disable-next-line max-states-count
contract TestGifBase is Test {

    // in full token units, value will be multiplied by 10 ** token.decimals()
    uint256 constant public DEFAULT_BUNDLE_CAPITALIZATION = 10 ** 5;

    // bundle lifetime is one year in seconds
    uint256 constant public DEFAULT_BUNDLE_LIFETIME = 365 * 24 * 3600;

    ChainNft public chainNft;
    Registry public registry;
    IERC20Metadata public token;
    ComponentOwnerService public componentOwnerService;
    ProductService public productService;
    PoolService public poolService;
    Instance public instance;
    IKeyValueStore public keyValueStore;
    TestProduct public product;
    TestPool public pool;
    TokenHandler public tokenHandler;

    address public registryAddress;
    NftId public registryNftId;
    NftId public bundleNftId;
    uint256 public initialCapitalAmount;

    address public registryOwner = makeAddr("registryOwner");
    address public instanceOwner = makeAddr("instanceOwner");
    address public productOwner = makeAddr("productOwner");
    address public poolOwner = makeAddr("poolOwner");
    address public customer = makeAddr("customer");
    address public investor = makeAddr("investor");
    address public outsider = makeAddr("outsider");

    string private _checkpointLabel;
    uint256 private _checkpointGasLeft = 1; // Start the slot warm.

    function setUp() public virtual {
        bool poolIsVerifying = true;
        UFixed poolCollateralizationLevelIs100 = UFixedMathLib.toUFixed(1);

        _setUp(
            poolIsVerifying,
            poolCollateralizationLevelIs100,
            DEFAULT_BUNDLE_CAPITALIZATION,
            DEFAULT_BUNDLE_LIFETIME);
    }

    function _setUp(
        bool poolIsVerifying,
        UFixed poolCollateralizationLevel,
        uint256 initialBundleCapitalization,
        uint256 bundleLifetime
    )
        internal
        virtual
    {
        // solhint-disable-next-line
        console.log("tx origin", tx.origin);

        // deploy registry, nft, services and token
        vm.startPrank(registryOwner);
        _deployRegistry(registryOwner);
        _deployServices();
        _deployToken();
        vm.stopPrank();

        // deploy instance
        vm.startPrank(instanceOwner);
        _deployInstance();
        vm.stopPrank();

        // deploy pool
        vm.startPrank(poolOwner);
        _deployPool(poolIsVerifying, poolCollateralizationLevel);
        vm.stopPrank();

        // deploy product
        vm.startPrank(productOwner);
        _deployProduct();
        vm.stopPrank();

        // fund investor
        initialCapitalAmount = initialBundleCapitalization * 10 ** token.decimals();

        vm.prank(registryOwner);
        token.transfer(investor, initialCapitalAmount);

        // approve capital and create bundle
        vm.startPrank(investor);
        token.approve(address(tokenHandler), initialCapitalAmount);

        _createBundle(
            initialCapitalAmount,
            bundleLifetime);
        vm.stopPrank();
    }

    function fundAccount(address account, uint256 amount) public {
        token.transfer(account, amount);

        token.approve(address(tokenHandler), amount);
    }

    /// @dev Helper function to assert that a given NftId is equal to the expected NftId.
    function assertNftId(NftId actualNftId, NftId expectedNftId, string memory message) public {
        if(block.chainid == 31337) {
            assertEq(actualNftId.toInt(), expectedNftId.toInt(), message);
        } else {
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

    function _startMeasureGas(string memory label) internal virtual {
        _checkpointLabel = label;
        _checkpointGasLeft = gasleft();
    }


    function _stopMeasureGas() internal virtual {
        // Subtract 100 to account for the warm SLOAD in startMeasuringGas.
        uint256 gasDelta = _checkpointGasLeft - gasleft() - 100;
        string memory message = string(abi.encodePacked(_checkpointLabel, " gas"));
        // solhint-disable-next-line
        console.log(message, gasDelta);
    }

    function _deployRegistry(address registryNftOwner) internal {
        registry = new Registry();
        //ChainNft nft = new ChainNft(address(registry));

        registry.initialize(registryNftOwner);
        registryAddress = address(registry);
        registryNftId = registry.getNftId();

        // solhint-disable-next-line
        console.log("nft deployed at", address(registry.getChainNft()));
        // solhint-disable-next-line
        console.log("registry deployed at", address(registry));
        console.log("registry NFT id", registryNftId.toInt());
    }


    function _deployServices() internal {
        componentOwnerService = new ComponentOwnerService(
            registryAddress, registryNftId);
        registry.register(componentOwnerService.getInitialInfo());

        registry.approve(componentOwnerService.getNftId(), PRODUCT(), INSTANCE());
        registry.approve(componentOwnerService.getNftId(), POOL(), INSTANCE());
        registry.approve(componentOwnerService.getNftId(), INSTANCE(), REGISTRY());

        console.log("component owner service deployed at", address(componentOwnerService));
        console.log("component owner service NFT id", componentOwnerService.getNftId().toInt());
        console.log("component owner service name", componentOwnerService.NAME());

        productService = new ProductService(
            registryAddress, registryNftId);
        registry.register(productService.getInitialInfo());

        registry.approve(productService.getNftId(), POLICY(), PRODUCT());

        console.log("product service deployed at", address(productService));
        console.log("product service NFT id", productService.getNftId().toInt());
        console.log("product service name", productService.NAME());
        

        poolService = new PoolService(
            registryAddress, registryNftId);
        registry.register(poolService.getInitialInfo());

        registry.approve(poolService.getNftId(), BUNDLE(), POOL());

        console.log("pool service deployed at", address(poolService));
        console.log("pool service NFT id", poolService.getNftId().toInt());
        console.log("pool service name", poolService.NAME());
    }


    function _deployInstance() internal {
        instance = new Instance(
            address(registry), 
            registry.getNftId());

        keyValueStore = instance.getKeyValueStore();

        // solhint-disable-next-line
        console.log("instance deployed at", address(instance));

        componentOwnerService.registerInstance(instance);
        // solhint-disable-next-line
        console.log("instance nft id", instance.getNftId().toInt());

        instance.grantRole(PRODUCT_OWNER_ROLE(), productOwner);
        instance.grantRole(POOL_OWNER_ROLE(), poolOwner);
        // solhint-disable-next-line
        console.log("product and pool roles granted");
    }


    function _deployToken() internal {
        USDC usdc  = new USDC();
        address usdcAddress = address(usdc);
        token = IERC20Metadata(usdcAddress);

        NftId tokenNftId = registry.register(IRegistry.ObjectInfo(
                zeroNftId(),
                registry.getNftId(),
                TOKEN(),
                usdcAddress,
                registryOwner,
                ""
            )
        );
        // solhint-disable-next-line
        console.log("token deployed at", usdcAddress);
        console.log("token NFT id", tokenNftId.toInt());
    }


    function _deployPool(
        bool isVerifying,
        UFixed collateralizationLevel
    )
        internal
    {
        pool = new TestPool(
            address(registry), 
            instance.getNftId(), 
            address(token),
            isVerifying,
            collateralizationLevel);

        componentOwnerService.registerPool(pool);
        // solhint-disable-next-line
        console.log("pool deployed at", address(pool));
        console.log("pool NFT id", pool.getNftId().toInt());
    }


    function _deployProduct() internal {
        product = new TestProduct(address(registry), instance.getNftId(), address(token), address(pool));
        componentOwnerService.registerProduct(product);

        tokenHandler = instance.getTokenHandler(product.getNftId());

        // solhint-disable-next-line
        console.log("product deployed at", address(product));
        console.log("product NFT id", product.getNftId().toInt());
        // solhint-disable-next-line
        console.log("token handler deployed at", address(tokenHandler));
    }

    function _createBundle(
        uint256 amount,
        uint256 lifetime
    ) 
        internal
    {
        bundleNftId = pool.createBundle(
            amount,
            lifetime,
            "");

        // solhint-disable-next-line
        console.log("bundle fundet with", amount);
        // solhint-disable-next-line
        console.log("bundle nft id", bundleNftId.toInt());
    }

}