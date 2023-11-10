pragma solidity 0.8.20;

import {Test, console} from "../../lib/forge-std/src/Test.sol";

import {IERC20Metadata} from "@openzeppelin5/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ChainNft, IChainNft} from "../../contracts/registry/ChainNft.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";

import {ComponentOwnerService} from "../../contracts/instance/service/ComponentOwnerService.sol";
import {DistributionService} from "../../contracts/instance/service/DistributionService.sol";
import {ProductService} from "../../contracts/instance/service/ProductService.sol";
import {PoolService} from "../../contracts/instance/service/PoolService.sol";

import {Instance} from "../../contracts/instance/Instance.sol";
import {IKeyValueStore} from "../../contracts/instance/base/IKeyValueStore.sol";
import {TokenHandler} from "../../contracts/instance/module/treasury/TokenHandler.sol";
import {TestProduct} from "../../contracts/test/TestProduct.sol";
import {TestPool} from "../../contracts/test/TestPool.sol";
import {TestDistribution} from "../../contracts/test/TestDistribution.sol";
import {USDC} from "../../contracts/test/Usdc.sol";

import {IPolicy} from "../../contracts/instance/module/policy/IPolicy.sol";
import {IPool} from "../../contracts/instance/module/pool/IPoolModule.sol";
import {NftId, NftIdLib, zeroNftId} from "../../contracts/types/NftId.sol";
import {REGISTRY, TOKEN, INSTANCE, POOL, PRODUCT, DISTRIBUTION, BUNDLE, POLICY} from "../../contracts/types/ObjectType.sol";
import {Fee, FeeLib} from "../../contracts/types/Fee.sol";
import {UFixed, UFixedMathLib} from "../../contracts/types/UFixed.sol";
import {PRODUCT_OWNER_ROLE, POOL_OWNER_ROLE, DISTRIBUTION_OWNER_ROLE} from "../../contracts/types/RoleId.sol";
import {Version} from "../../contracts/types/Version.sol";

import {ProxyDeployer} from "../../contracts/shared/Proxy.sol";
import {IVersionable} from "../../contracts/shared/IVersionable.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";

// solhint-disable-next-line max-states-count
contract TestGifBase is Test {

    // in full token units, value will be multiplied by 10 ** token.decimals()
    uint256 constant public DEFAULT_BUNDLE_CAPITALIZATION = 10 ** 5;

    // bundle lifetime is one year in seconds
    uint256 constant public DEFAULT_BUNDLE_LIFETIME = 365 * 24 * 3600;

    ProxyDeployer public registryProxyAdmin;
    Registry public registryImplementation;
    ChainNft public chainNft;
    Registry public registry;

    ProxyDeployer public registryServiceProxyAdmin;
    RegistryService public registryServiceImplementation;
    RegistryService public registryService;

    IERC20Metadata public token;

    //ProxyDeployer public componentOwnerServiceProxyAdmin;
    //ComponentOwnerService public componentOwnerServiceImplementation;
    ComponentOwnerService public componentOwnerService;

    //ProxyDeployer public distributionServiceProxyAdmin;
    //DistributionService public distributionServiceImplementation;    
    DistributionService public distributionService;

    //ProxyDeployer public productServiceProxyAdmin; 
    //ProductService public productServiceImplementation;
    ProductService public productService;

    //ProxyDeployer public poolServiceProxyAdmin; 
    //PoolService public poolServiceImplementation;
    PoolService public poolService;

    //ProxyDeployer public instanceProxyAdmin; 
    //Instance public instanceImplementation;
    Instance public instance;

    IKeyValueStore public keyValueStore;
    TestProduct public product;
    TestPool public pool;
    TestDistribution public distribution;
    TokenHandler public tokenHandler;

    address public registryAddress;
    NftId public registryNftId;
    NftId public bundleNftId;
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
        _deployRegistry();
        _deployRegistryService();
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

        // deploy distribution
        vm.startPrank(distributionOwner);
        _deployDistribution(distributionIsVerifying);
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
            initialBundleFee,
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

    function _deployRegistry() internal
    {
        registryProxyAdmin = new ProxyDeployer();
        registryImplementation = new Registry();

        bytes memory initializationData = bytes("");
        IVersionable versionable = registryProxyAdmin.deploy(address(registryImplementation), initializationData);
        
        registryAddress = address(versionable);
        registry = Registry(registryAddress);
        registryNftId = registry.getNftId();
        address chainNftAddress = address(registry.getChainNft());
        chainNft = ChainNft(chainNftAddress);

        /* solhint-disable */
        console.log("registry implementation deployed at", address(registryImplementation));  
        console.log("registry proxy admin deployed at", address(registryProxyAdmin));
        console.log("registry deployed at", address(registry));
        console.log("with protocol nft id", chainNft.PROTOCOL_NFT_ID());
        console.log("with global registry nft id", chainNft.GLOBAL_REGISTRY_ID());
        console.log("registry nft id", registry.getNftId().toInt());
        console.log("registry version", registry.getVersion().toInt());
        /* solhint-enable */
    }

    function _deployRegistryService() internal
    {
        registryServiceProxyAdmin = new ProxyDeployer();
        registryServiceImplementation = new RegistryService();

        bytes memory initializationData = abi.encode(registry, registryNftId);
        IVersionable versionable = registryServiceProxyAdmin.deploy(address(registryServiceImplementation), initializationData);
        address registryServiceAddress = address(versionable);

        registryService = RegistryService(registryServiceAddress); 
        (IRegistry.ObjectInfo memory info, ) = registryService.getInitialInfo();
        
        registry.register(info);
        registry.approve(registryService.getNftId(), INSTANCE());
        registry.approve(registryService.getNftId(), PRODUCT());
        registry.approve(registryService.getNftId(), POOL());
        registry.approve(registryService.getNftId(), DISTRIBUTION());

        /* solhint-disable */
        console.log("service name", registryService.NAME());
        console.log("service implementation deployed at", address(registryServiceImplementation));  
        console.log("service proxy admin deployed at", address(registryServiceProxyAdmin));
        console.log("service deployed at", address(registryService));
        console.log("service nft id", registryService.getNftId().toInt());
        console.log("service version", registryService.getVersion().toInt());
        console.log("service allowance is set to INSTANCE, PRODUCT, POOL and DISTRIBUTION");
        /* solhint-enable */
    }


    function _deployServices() internal 
    {
        //--- component owner service ---------------------------------//
        /*componentOwnerServiceProxyAdmin = new ProxyDeployer();
        componentOwnerServiceImplementation = new ComponentOwnerService();
        bytes memory initializationData = abi.encode(registry, registryNftId, registryOwner);
        IVersionable versionable = componentOwnerServiceProxyAdmin.deploy(address(componentOwnerServiceImplementation), initializationData);
        address componentOwnerServiceAddress = address(versionable);
        
        componentOwnerService = ComponentOwnerService(componentOwnerServiceAddress);*/
        componentOwnerService = new ComponentOwnerService(registryAddress, registryNftId, registryOwner);
        (IRegistry.ObjectInfo memory info, ) = componentOwnerService.getInitialInfo();

        registry.register(info);

        /* solhint-disable */
        console.log("service name", componentOwnerService.NAME());
        //console.log("service implementation deployed at", address(componentOwnerServiceImplementation));  
        //console.log("service proxy admin deployed at", address(componentOwnerServiceProxyAdmin));
        console.log("service deployed at", address(componentOwnerService));
        console.log("service nft id", componentOwnerService.getNftId().toInt());
        //console.log("service version", componentOwnerService.getVersion().toInt());
        /* solhint-enable */

        //--- distribution service ---------------------------------//
        /*distributionServiceProxyAdmin = new ProxyDeployer();
        distributionServiceImplementation = new DistributionService();
        //initializationData = abi.encode(registry, registryNftId, registryOwner);
        versionable = distributionServiceProxyAdmin.deploy(address(distributionServiceImplementation), initializationData);
        address  distributionServiceAddress = address(versionable);

        distributionService = DistributionService(distributionServiceAddress);*/
        distributionService = new DistributionService(registryAddress, registryNftId, registryOwner);

        (info, ) = distributionService.getInitialInfo();

        registry.register(info);

        /* solhint-disable */
        console.log("service name", distributionService.NAME());
        //console.log("service implementation deployed at", address(distributionServiceImplementation));  
        //console.log("service proxy admin deployed at", address(distributionServiceProxyAdmin));
        console.log("service deployed at", address(distributionService));
        console.log("service nft id", distributionService.getNftId().toInt());
        //console.log("service version", distributionService.getVersion().toInt());
        /* solhint-enable */

        //--- product service ---------------------------------//
        /*productServiceProxyAdmin = new ProxyDeployer();
        productServiceImplementation = new ProductService();
        //initializationData = abi.encode(registry, registryNftId, registryOwner);
        versionable = productServiceProxyAdmin.deploy(address(productServiceImplementation), initializationData);
        address  productServiceAddress = address(versionable);

        productService = ProductService(productServiceAddress);*/
        productService = new ProductService(registryAddress, registryNftId, registryOwner);

        (info, ) = productService.getInitialInfo();
        registry.register(info);
        registry.approve(productService.getNftId(), POLICY());

        /* solhint-disable */
        console.log("service name", productService.NAME());
        //console.log("service implementation deployed at", address(productServiceImplementation));  
        //console.log("service proxy admin deployed at", address(productServiceProxyAdmin));
        console.log("service deployed at", address(productService));
        console.log("service nft id", productService.getNftId().toInt());
        //console.log("service version", productService.getVersion().toInt());
        console.log("service allowance is set to POLICY");
        /* solhint-enable */

        //--- pool service ---------------------------------//
        /*poolServiceProxyAdmin = new ProxyDeployer();
        poolServiceImplementation = new PoolService();
        //initializationData = abi.encode(registry, registryNftId, registryOwner);
        versionable = poolServiceProxyAdmin.deploy(address(poolServiceImplementation), initializationData);
        address  poolServiceAddress = address(versionable);

        poolService = PoolService(poolServiceAddress);*/
        poolService = new PoolService(registryAddress, registryNftId, registryOwner);

        (info, ) = poolService.getInitialInfo();
        registry.register(info);
        registry.approve(poolService.getNftId(), BUNDLE());

        /* solhint-disable */
        console.log("service name", poolService.NAME());
        //console.log("service implementation deployed at", address(poolServiceImplementation));  
        //console.log("service proxy admin deployed at", address(poolServiceProxyAdmin));
        console.log("service deployed at", address(poolService));
        console.log("service nft id", poolService.getNftId().toInt());
        //console.log("service version", poolService.getVersion().toInt());
        console.log("service allowance is set to BUNDLE");
        /* solhint-enable */
    }


    function _deployInstance() internal {
        /*instanceProxyAdmin = new ProxyDeployer();
        instanceImplementation = new Instance();

        bytes memory initializationData = abi.encode(registry, registryNftId);
        IVersionable versionable = instanceProxyAdmin.deploy(address(instanceImplementation), initializationData);
        address instanceAddress = address(versionable);

        instance = Instance(instanceAddress);*/
        instance = new Instance(registryAddress, registryNftId, instanceOwner);

        keyValueStore = instance.getKeyValueStore();

        registryService.registerInstance(instance);

        /* solhint-disable */
        //console.log("instance implementation deployed at", address(instanceImplementation));  
        //console.log("instance proxy admin deployed at", address(instanceProxyAdmin));
        console.log("instance deployed at", address(instance));
        console.log("instance nft id", instance.getNftId().toInt());
        //console.log("instance version", instance.getVersion().toInt());
        /* solhint-enable */

        instance.grantRole(PRODUCT_OWNER_ROLE(), productOwner);
        instance.grantRole(POOL_OWNER_ROLE(), poolOwner);
        instance.grantRole(DISTRIBUTION_OWNER_ROLE(), distributionOwner);
        // solhint-disable-next-line
        console.log("product pool, and distribution roles granted");
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
        console.log("token NFT id", tokenNftId.toInt());
        // solhint-disable-next-line
        console.log("token deployed at", usdcAddress);
    }


    function _deployPool(
        bool isVerifying,
        UFixed collateralizationLevel
    )
        internal
    {
        Fee memory stakingFee = FeeLib.zeroFee();
        Fee memory performanceFee = FeeLib.zeroFee();

        pool = new TestPool(
            address(registry), 
            instance.getNftId(), 
            address(token),
            isVerifying,
            collateralizationLevel,
            initialPoolFee,
            stakingFee,
            performanceFee,
            poolOwner);

        registryService.registerPool(pool);

        uint256 nftId = pool.getNftId().toInt();
        uint256 state = instance.getState(pool.getNftId().toKey32(POOL())).toInt();
        // solhint-disable-next-line
        console.log("pool deployed at", address(pool));
        // solhint-disable-next-line
        console.log("pool nftId", nftId, "state", state);
    }


    function _deployDistribution(
        bool isVerifying
    )
        internal
    {
        Fee memory distributionFee = FeeLib.percentageFee(15);
        distribution = new TestDistribution(
            address(registry), 
            instance.getNftId(), 
            address(token),
            isVerifying,
            initialDistributionFee,
            distributionOwner);

        registryService.registerDistribution(distribution);

        uint256 nftId = distribution.getNftId().toInt();
        uint256 state = instance.getState(distribution.getNftId().toKey32(DISTRIBUTION())).toInt();
        // solhint-disable-next-line
        console.log("distribution deployed at", address(pool));
        // solhint-disable-next-line
        console.log("distribution nftId", nftId, "state", state);
    }


    function _deployProduct() internal {
        Fee memory processingFee = instance.getZeroFee();

        product = new TestProduct(
            address(registry), 
            instance.getNftId(), 
            address(token), 
            address(pool),
            address(distribution),
            initialProductFee,
            processingFee,
            productOwner);

        registryService.registerProduct(product);

        uint256 nftId = product.getNftId().toInt();
        uint256 state = instance.getState(product.getNftId().toKey32(PRODUCT())).toInt();
        tokenHandler = instance.getTokenHandler(product.getNftId());
        // solhint-disable-next-line
        console.log("product deployed at", address(product));
        // solhint-disable-next-line
        console.log("product nftId", nftId, "state", state);
        // solhint-disable-next-line
        console.log("product token handler deployed at", address(tokenHandler));
    }

    function _createBundle(
        Fee memory fee,
        uint256 amount,
        uint256 lifetime
    ) 
        internal
    {
        bundleNftId = pool.createBundle(
            fee,
            amount,
            lifetime,
            "");

        // solhint-disable-next-line
        console.log("bundle fundet with", amount);
        // solhint-disable-next-line
        console.log("bundle nft id", bundleNftId.toInt());
    }

}