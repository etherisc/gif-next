pragma solidity 0.8.20;

import {Test, console} from "../../lib/forge-std/src/Test.sol";

import {IERC20Metadata} from "@openzeppelin5/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ChainNft, IChainNft} from "../../contracts/registry/ChainNft.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";

// import {Instance} from "../../contracts/instance/Instance.sol";
import {IKeyValueStore} from "../../contracts/instance/base/IKeyValueStore.sol";
// import {TestProduct} from "../../contracts/test/TestProduct.sol";
// import {TestPool} from "../../contracts/test/TestPool.sol";
// import {TestDistribution} from "../../contracts/test/TestDistribution.sol";
import {USDC} from "../../contracts/test/Usdc.sol";

import {NftId, NftIdLib, zeroNftId} from "../../contracts/types/NftId.sol";
import {REGISTRY, TOKEN, SERVICE, INSTANCE, POOL, ORACLE, PRODUCT, DISTRIBUTION, BUNDLE, POLICY} from "../../contracts/types/ObjectType.sol";
import {Fee, FeeLib} from "../../contracts/types/Fee.sol";
import {UFixed, UFixedMathLib} from "../../contracts/types/UFixed.sol";
import {Version} from "../../contracts/types/Version.sol";

import {ProxyManager} from "../../contracts/shared/ProxyManager.sol";
import {IVersionable} from "../../contracts/shared/IVersionable.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {IRegistryService} from "../../contracts/registry/RegistryService.sol";
import {RegistryServiceManager} from "../../contracts/registry/RegistryServiceManager.sol";

// solhint-disable-next-line max-states-count
contract TestGifBase is Test {

    // in full token units, value will be multiplied by 10 ** token.decimals()
    uint256 constant public DEFAULT_BUNDLE_CAPITALIZATION = 10 ** 5;

    // bundle lifetime is one year in seconds
    uint256 constant public DEFAULT_BUNDLE_LIFETIME = 365 * 24 * 3600;

    ProxyManager public registryProxyAdmin;
    Registry public registryImplementation;
    ChainNft public chainNft;
    Registry public registry;

    RegistryServiceManager public registryServiceManager;
    ProxyManager public registryServiceProxyAdmin;
    RegistryService public registryServiceImplementation;
    RegistryService public registryService;

    IERC20Metadata public token;

    // ComponentOwnerService public componentOwnerService;
    // DistributionService public distributionService;
    // ProductService public productService;
    // PoolService public poolService;

    // Instance public instance;

    // IKeyValueStore public keyValueStore;
    // TestProduct public product;
    // TestPool public pool;
    // TestDistribution public distribution;
    // TokenHandler public tokenHandler;

    address public registryAddress;
    NftId public registryNftId;
    // NftId public bundleNftId;
    uint256 public initialCapitalAmount;

    address public registryOwner = makeAddr("registryOwner");
    address public instanceOwner = makeAddr("instanceOwner");
    address public productOwner = makeAddr("productOwner");
    address public poolOwner = makeAddr("poolOwner");
    address public distributionOwner = makeAddr("distributionOwner");
    address public customer = makeAddr("customer");
    address public investor = makeAddr("investor");
    address public outsider = makeAddr("outsider");

    uint8 initialProductFeePercentage = 2;
    uint8 initialPoolFeePercentage = 3;
    uint8 initialBundleFeePercentage = 4;
    uint8 initialDistributionFeePercentage = 10;

    Fee public initialProductFee = FeeLib.percentageFee(initialProductFeePercentage);
    Fee public initialPoolFee = FeeLib.percentageFee(initialPoolFeePercentage);
    Fee public initialBundleFee = FeeLib.percentageFee(initialBundleFeePercentage);
    Fee public initialDistributionFee = FeeLib.percentageFee(initialDistributionFeePercentage);

    bool poolIsVerifying = true;
    bool distributionIsVerifying = true;
    UFixed poolCollateralizationLevelIs100 = UFixedMathLib.toUFixed(1);

    string private _checkpointLabel;
    uint256 private _checkpointGasLeft = 1; // Start the slot warm.

    function setUp() public virtual {
        _setUp(
            poolCollateralizationLevelIs100,
            DEFAULT_BUNDLE_CAPITALIZATION,
            DEFAULT_BUNDLE_LIFETIME);
    }

    function _setUp(
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
        _deployRegistryServiceAndRegistry();
        // _deployServices();
        _deployToken();
        vm.stopPrank();

        // deploy instance
        // vm.startPrank(instanceOwner);
        // _deployInstance();
        // vm.stopPrank();

        // // deploy pool
        // bool poolIsInterceptor = false;
        // vm.startPrank(poolOwner);
        // _deployPool(poolIsInterceptor, poolIsVerifying, poolCollateralizationLevel);
        // vm.stopPrank();

        // // deploy distribution
        // vm.startPrank(distributionOwner);
        // _deployDistribution(distributionIsVerifying);
        // vm.stopPrank();

        // // deploy product
        // vm.startPrank(productOwner);
        // _deployProduct();
        // vm.stopPrank();

        // // fund investor
        // initialCapitalAmount = initialBundleCapitalization * 10 ** token.decimals();

        // vm.prank(registryOwner);
        // token.transfer(investor, initialCapitalAmount);

        // // approve capital and create bundle
        // // TODO registration of components is not going through corresponding services yet -> thus product is registered in Registry but not in Instance -> tokenHandler is 0
        // vm.startPrank(investor);
        // token.approve(address(tokenHandler), initialCapitalAmount);

        // _createBundle(
        //     initialBundleFee,
        //     initialCapitalAmount,
        //     bundleLifetime);
        // vm.stopPrank();
    }

    // function fundAccount(address account, uint256 amount) public {
    //     token.transfer(account, amount);

    //     token.approve(address(tokenHandler), amount);
    // }

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

    function _deployRegistryServiceAndRegistry() internal
    {
        registryServiceManager = new RegistryServiceManager();
        registryService = registryServiceManager.getRegistryService();

        IRegistry registry_ = registryService.getRegistry();
        registryAddress = address(registry_);
        registry = Registry(registryAddress);
        registryNftId = registry.getNftId(address(registry));
        address chainNftAddress = address(registry.getChainNft());
        chainNft = ChainNft(chainNftAddress);

        /* solhint-disable */
        console.log("registry deployed at", address(registry));
        console.log("protocol nft id", chainNft.PROTOCOL_NFT_ID());
        console.log("global registry nft id", chainNft.GLOBAL_REGISTRY_ID());
        console.log("registry nft id", registry.getNftId(address(registry)).toInt());

        console.log("registry owner", address(registryOwner));
        console.log("registry service manager", address(registryServiceManager));
        console.log("registry service manager nft", registryServiceManager.getNftId().toInt());
        console.log("registry service manager owner", registryServiceManager.getOwner());
        console.log("registry service", address(registryService));
        console.log("registry service nft", registryService.getNftId().toInt());
        console.log("registry service owner", registryService.getOwner());
        console.log("registry", address(registry));
        console.log("registry nft", registry.getNftId(address(registry)).toInt());
        console.log("registry owner (opt 1)", registry.ownerOf(address(registry)));
        console.log("registry owner (opt 2)", registry.getOwner());
        /* solhint-enable */
    }


    // function _deployServices() internal 
    // {
    //     //--- component owner service ---------------------------------//
        
    //     componentOwnerService = new ComponentOwnerService(registryAddress, registryNftId, registryOwner); 
    //     registryService.registerService(componentOwnerService);
    //     assertTrue(componentOwnerService.getNftId().gtz(), "component owner service registration failure");

    //     registry.approve(componentOwnerService.getNftId(), PRODUCT(), INSTANCE());
    //     registry.approve(componentOwnerService.getNftId(), POOL(), INSTANCE());
    //     registry.approve(componentOwnerService.getNftId(), DISTRIBUTION(), INSTANCE());
    //     registry.approve(componentOwnerService.getNftId(), ORACLE(), INSTANCE());

    //     /* solhint-disable */
    //     console.log("service name", componentOwnerService.NAME());
    //     console.log("service deployed at", address(componentOwnerService));
    //     console.log("service nft id", componentOwnerService.getNftId().toInt());
    //     /* solhint-enable */

    //     //--- distribution service ---------------------------------//
        
    //     distributionService = new DistributionService(registryAddress, registryNftId, registryOwner);
    //     registryService.registerService(distributionService);

    //     /* solhint-disable */
    //     console.log("service name", distributionService.NAME());
    //     console.log("service deployed at", address(distributionService));
    //     console.log("service nft id", distributionService.getNftId().toInt());
    //     /* solhint-enable */

    //     //--- product service ---------------------------------//

    //     productService = new ProductService(registryAddress, registryNftId, registryOwner);
    //     registryService.registerService(productService);
    //     registry.approve(productService.getNftId(), POLICY(), PRODUCT());

    //     /* solhint-disable */
    //     console.log("service name", productService.NAME());
    //     console.log("service deployed at", address(productService));
    //     console.log("service nft id", productService.getNftId().toInt());
    //     console.log("service allowance is set to POLICY");
    //     /* solhint-enable */

    //     //--- pool service ---------------------------------//
        
    //     poolService = new PoolService(registryAddress, registryNftId, registryOwner);
    //     registryService.registerService(poolService);
    //     registry.approve(poolService.getNftId(), BUNDLE(), POOL());

    //     /* solhint-disable */
    //     console.log("service name", poolService.NAME());
    //     console.log("service deployed at", address(poolService));
    //     console.log("service nft id", poolService.getNftId().toInt());
    //     console.log("service allowance is set to BUNDLE");
    //     /* solhint-enable */
    // }


    // function _deployInstance() internal {
    //     /*instanceProxyAdmin = new ProxyDeployer();
    //     instanceImplementation = new Instance();

    //     bytes memory initializationData = abi.encode(registry, registryNftId);
    //     IVersionable versionable = instanceProxyAdmin.deploy(address(instanceImplementation), initializationData);
    //     address instanceAddress = address(versionable);

    //     instance = Instance(instanceAddress);*/
    //     instance = new Instance(registryAddress, registryNftId, instanceOwner);

    //     registryService.registerInstance(instance);

    //     keyValueStore = instance.getKeyValueStore();


    //     /* solhint-disable */
    //     //console.log("instance implementation deployed at", address(instanceImplementation));  
    //     //console.log("instance proxy admin deployed at", address(instanceProxyAdmin));
    //     console.log("instance deployed at", address(instance));
    //     console.log("instance nft id", instance.getNftId().toInt());
    //     //console.log("instance version", instance.getVersion().toInt());
    //     /* solhint-enable */

    //     instance.grantRole(PRODUCT_OWNER_ROLE(), productOwner);
    //     instance.grantRole(POOL_OWNER_ROLE(), poolOwner);
    //     instance.grantRole(DISTRIBUTION_OWNER_ROLE(), distributionOwner);
    //     // solhint-disable-next-line
    //     console.log("product pool, and distribution roles granted");
    // }


    function _deployToken() internal {
        USDC usdc  = new USDC();
        address usdcAddress = address(usdc);
        token = IERC20Metadata(usdcAddress);

        NftId tokenNftId = registryService.registerToken(usdcAddress);
        // solhint-disable-next-line
        console.log("token NFT id", tokenNftId.toInt());
        // solhint-disable-next-line
        console.log("token deployed at", usdcAddress);
    }


    // function _deployPool(
    //     bool isInterceptor,
    //     bool isVerifying,
    //     UFixed collateralizationLevel
    // )
    //     internal
    // {
    //     Fee memory stakingFee = FeeLib.zeroFee();
    //     Fee memory performanceFee = FeeLib.zeroFee();

    //     pool = new TestPool(
    //         address(registry), 
    //         instance.getNftId(), 
    //         address(token),
    //         false, // isInterceptor
    //         isVerifying,
    //         collateralizationLevel,
    //         initialPoolFee,
    //         stakingFee,
    //         performanceFee,
    //         poolOwner);

    //     componentOwnerService.register(pool, POOL());

    //     uint256 nftId = pool.getNftId().toInt();
    //     uint256 state = instance.getState(pool.getNftId().toKey32(POOL())).toInt();
    //     // solhint-disable-next-line
    //     console.log("pool deployed at", address(pool));
    //     // solhint-disable-next-line
    //     console.log("pool nftId", nftId, "state", state);
    // }


    // function _deployDistribution(
    //     bool isVerifying
    // )
    //     internal
    // {
    //     Fee memory distributionFee = FeeLib.percentageFee(15);
    //     distribution = new TestDistribution(
    //         address(registry), 
    //         instance.getNftId(), 
    //         address(token),
    //         isVerifying,
    //         initialDistributionFee,
    //         distributionOwner);

    //     componentOwnerService.register(distribution, DISTRIBUTION());

    //     uint256 nftId = distribution.getNftId().toInt();
    //     uint256 state = instance.getState(distribution.getNftId().toKey32(DISTRIBUTION())).toInt();
    //     // solhint-disable-next-line
    //     console.log("distribution deployed at", address(pool));
    //     // solhint-disable-next-line
    //     console.log("distribution nftId", nftId, "state", state);
    // }


    // function _deployProduct() internal {
    //     Fee memory processingFee = instance.getZeroFee();

    //     product = new TestProduct(
    //         address(registry), 
    //         instance.getNftId(), 
    //         address(token), 
    //         false, // isInterceptor
    //         address(pool),
    //         address(distribution),
    //         initialProductFee,
    //         processingFee,
    //         productOwner);

    //     componentOwnerService.register(product, PRODUCT());
    //     //registryService.registerComponent(product, PRODUCT());

    //     uint256 nftId = product.getNftId().toInt();
    //     uint256 state = instance.getState(product.getNftId().toKey32(PRODUCT())).toInt();
    //     tokenHandler = instance.getTokenHandler(product.getNftId());
    //     // solhint-disable-next-line
    //     console.log("product deployed at", address(product));
    //     // solhint-disable-next-line
    //     console.log("product nftId", nftId, "state", state);
    //     // solhint-disable-next-line
    //     console.log("product token handler deployed at", address(tokenHandler));
    // }

    // function _createBundle(
    //     Fee memory fee,
    //     uint256 amount,
    //     uint256 lifetime
    // ) 
    //     internal
    // {
    //     bundleNftId = pool.createBundle(
    //         fee,
    //         amount,
    //         lifetime,
    //         "");

    //     // solhint-disable-next-line
    //     console.log("bundle fundet with", amount);
    //     // solhint-disable-next-line
    //     console.log("bundle nft id", bundleNftId.toInt());
    // }

}