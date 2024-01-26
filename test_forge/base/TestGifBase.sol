// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Test, console} from "../../lib/forge-std/src/Test.sol";

import {ChainNft} from "../../contracts/registry/ChainNft.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {TokenRegistry} from "../../contracts/registry/TokenRegistry.sol";

import {ComponentOwnerService} from "../../contracts/instance/service/ComponentOwnerService.sol";
import {DistributionService} from "../../contracts/instance/service/DistributionService.sol";
import {DistributionServiceManager} from "../../contracts/instance/service/DistributionServiceManager.sol";
import {ProductService} from "../../contracts/instance/service/ProductService.sol";
import {ProductServiceManager} from "../../contracts/instance/service/ProductServiceManager.sol";
import {PoolService} from "../../contracts/instance/service/PoolService.sol";
import {PoolServiceManager} from "../../contracts/instance/service/PoolServiceManager.sol";
import {InstanceService} from "../../contracts/instance/InstanceService.sol";
import {InstanceServiceManager} from "../../contracts/instance/InstanceServiceManager.sol";

import {AccessManagerSimple} from "../../contracts/instance/AccessManagerSimple.sol";
import {Instance} from "../../contracts/instance/Instance.sol";
import {InstanceReader} from "../../contracts/instance/InstanceReader.sol";
import {IKeyValueStore} from "../../contracts/instance/base/IKeyValueStore.sol";
import {TokenHandler} from "../../contracts/shared/TokenHandler.sol";
// import {TestProduct} from "../../contracts/test/TestProduct.sol";
// import {TestPool} from "../../contracts/test/TestPool.sol";
// import {TestDistribution} from "../../contracts/test/TestDistribution.sol";
import {Distribution} from "../../contracts/components/Distribution.sol";
import {Pool} from "../../contracts/components/Pool.sol";
import {Product} from "../../contracts/components/Product.sol";
import {USDC} from "../../contracts/test/Usdc.sol";

// import {IPolicy} from "../../contracts/instance/module/policy/IPolicy.sol";
// import {IPool} from "../../contracts/instance/module/pool/IPoolModule.sol";
import {NftId, NftIdLib, zeroNftId} from "../../contracts/types/NftId.sol";
import {REGISTRY, TOKEN, SERVICE, INSTANCE, POOL, ORACLE, PRODUCT, DISTRIBUTION, BUNDLE, POLICY} from "../../contracts/types/ObjectType.sol";
import {Fee, FeeLib} from "../../contracts/types/Fee.sol";
import {
    PRODUCT_OWNER_ROLE, 
    POOL_OWNER_ROLE, 
    DISTRIBUTION_OWNER_ROLE, 
    PRODUCT_REGISTRAR_ROLE, 
    POOL_REGISTRAR_ROLE, 
    DISTRIBUTION_REGISTRAR_ROLE, 
    POLICY_REGISTRAR_ROLE,
    DISTRIBUTION_SERVICE_ROLE,
    INSTANCE_SERVICE_ROLE,
    BUNDLE_REGISTRAR_ROLE} from "../../contracts/types/RoleId.sol";
import {UFixed, UFixedLib} from "../../contracts/types/UFixed.sol";
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

    RegistryServiceManager public registryServiceManager;
    AccessManager accessManager;
    RegistryService public registryService;
    Registry public registry;
    ChainNft public chainNft;
    TokenRegistry public tokenRegistry;

    IERC20Metadata public token;

    InstanceServiceManager public instanceServiceManager;
    InstanceService public instanceService;
    NftId public instanceServiceNftId;
    ComponentOwnerService public componentOwnerService;
    DistributionServiceManager public distributionServiceManager;
    DistributionService public distributionService;
    NftId public distributionServiceNftId;
    ProductServiceManager public productServiceManager;
    ProductService public productService;
    NftId public productServiceNftId;
    PoolServiceManager public poolServiceManager;
    PoolService public poolService;
    NftId public poolServiceNftId;

    AccessManagerSimple masterInstanceAccessManager;
    Instance masterInstance;
    NftId masterInstanceNftId;
    InstanceReader masterInstanceReader;

    AccessManagerSimple instanceAccessManager;
    Instance public instance;
    NftId public instanceNftId;
    InstanceReader public instanceReader;

    IKeyValueStore public keyValueStore;
    // TestProduct public product;
    // TestPool public pool;
    // TestDistribution public distribution;
    Distribution public distribution;
    NftId public distributionNftId;
    Pool public pool;
    NftId public poolNftId;
    Product public product;
    NftId public productNftId;
    TokenHandler public tokenHandler;

    address public registryAddress;
    NftId public registryNftId;
    NftId public bundleNftId;
    uint256 public initialCapitalAmount;

    address public registryOwner = makeAddr("registryOwner");
    address public masterInstanceOwner = makeAddr("masterInstanceOwner");
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
    UFixed poolCollateralizationLevelIs100 = UFixedLib.toUFixed(1);

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
        _configureAccessManagerRoles();
        _deployServices();
        _configureServiceAuthorizations();
        vm.stopPrank();

        vm.startPrank(masterInstanceOwner);
        _deployMasterInstance();
        vm.stopPrank();

        vm.startPrank(registryOwner);
        _deployToken();
        vm.stopPrank();

        // deploy instance
        vm.startPrank(instanceOwner);
        _createInstance();
        vm.stopPrank();

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

    function _deployRegistryServiceAndRegistry() internal
    {
        accessManager = new AccessManager(registryOwner);
        registryServiceManager = new RegistryServiceManager(address(accessManager));
        registryService = registryServiceManager.getRegistryService();

        IRegistry registry_ = registryService.getRegistry();
        registryAddress = address(registry_);
        registry = Registry(registryAddress);
        registryNftId = registry.getNftId(address(registry));
        address chainNftAddress = address(registry.getChainNft());
        chainNft = ChainNft(chainNftAddress);

        tokenRegistry = new TokenRegistry();
        tokenRegistry.linkToNftOwnable(registryAddress);

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
        console.log("token registry", address(tokenRegistry));
        /* solhint-enable */
    }

    function _configureAccessManagerRoles() internal
    {
        bytes4[] memory functionSelector = new bytes4[](1);
        functionSelector[0] = RegistryService.registerProduct.selector;

        accessManager.setTargetFunctionRole(
            address(registryService), 
            functionSelector, 
            PRODUCT_REGISTRAR_ROLE().toInt());

        functionSelector[0] = RegistryService.registerPool.selector;

        accessManager.setTargetFunctionRole(
            address(registryService), 
            functionSelector, 
            POOL_REGISTRAR_ROLE().toInt());

        functionSelector[0] = RegistryService.registerDistribution.selector;

        accessManager.setTargetFunctionRole(
            address(registryService), 
            functionSelector, 
            DISTRIBUTION_REGISTRAR_ROLE().toInt());

        functionSelector[0] = RegistryService.registerPolicy.selector;

        accessManager.setTargetFunctionRole(
            address(registryService), 
            functionSelector, 
            POLICY_REGISTRAR_ROLE().toInt());

        functionSelector[0] = RegistryService.registerBundle.selector;

        accessManager.setTargetFunctionRole(
            address(registryService), 
            functionSelector, 
            BUNDLE_REGISTRAR_ROLE().toInt());
    }

    function _deployServices() internal 
    {
        // --- instance service ---------------------------------//
        // TODO manager can not use registryService.registerService() in constructor
        // because it have no role / have no nft
        instanceServiceManager = new InstanceServiceManager(address(registry));
        instanceService = instanceServiceManager.getInstanceService();
        // temporal solution, register in separate tx
        registryService.registerService(instanceService);
        instanceServiceNftId = registry.getNftId(address(instanceService));


        // solhint-disable 
        console.log("instanceService name", instanceService.getName());
        console.log("instanceService deployed at", address(instanceService));
        console.log("instanceService nft id", instanceService.getNftId().toInt());
        // solhint-enable 

        // --- distribution service ---------------------------------//
        distributionServiceManager = new DistributionServiceManager(address(registry));
        distributionService = distributionServiceManager.getDistributionService();
        registryService.registerService(distributionService);
        distributionServiceNftId = registry.getNftId(address(distributionService));

        // solhint-disable 
        console.log("distributionService name", distributionService.getName());
        console.log("distributionService deployed at", address(distributionService));
        console.log("distributionService nft id", distributionService.getNftId().toInt());
        // solhint-enable

        // --- pool service ---------------------------------//
        poolServiceManager = new PoolServiceManager(address(registry));
        poolService = poolServiceManager.getPoolService();
        registryService.registerService(poolService);
        poolServiceNftId = registry.getNftId(address(poolService));

        // solhint-disable
        console.log("poolService name", poolService.getName());
        console.log("poolService deployed at", address(poolService));
        console.log("poolService nft id", poolService.getNftId().toInt());
        // solhint-enable

        // --- product service ---------------------------------//
        productServiceManager = new ProductServiceManager(address(registry));
        productService = productServiceManager.getProductService();
        registryService.registerService(productService);
        productServiceNftId = registry.getNftId(address(productService));

        // solhint-disable
        console.log("productService name", productService.getName());
        console.log("productService deployed at", address(productService));
        console.log("productService nft id", productService.getNftId().toInt());
        // solhint-enable

        // //--- component owner service ---------------------------------//
        // componentOwnerService = new ComponentOwnerService(registryAddress, registryNftId, registryOwner); 
        // registryService.registerService(componentOwnerService);
        // assertTrue(componentOwnerService.getNftId().gtz(), "component owner service registration failure");

        // accessManager.grantRole(PRODUCT_REGISTRAR_ROLE().toInt(), address(componentOwnerService), 0);
        // accessManager.grantRole(POOL_REGISTRAR_ROLE().toInt(), address(componentOwnerService), 0);
        // accessManager.grantRole(DISTRIBUTION_REGISTRAR_ROLE().toInt(), address(componentOwnerService), 0);

        // /* solhint-disable */
        // console.log("service name", componentOwnerService.NAME());
        // console.log("service deployed at", address(componentOwnerService));
        // console.log("service nft id", componentOwnerService.getNftId().toInt());
        // /* solhint-enable */
    }

    function _configureServiceAuthorizations() internal 
    {
        // grant DISTRIBUTION_REGISTRAR_ROLE to distribution service
        // allow role DISTRIBUTION_REGISTRAR_ROLE to call registerDistribution on registry service
        accessManager.grantRole(DISTRIBUTION_REGISTRAR_ROLE().toInt(), address(distributionService), 0);
        bytes4[] memory registryServiceRegisterDistributionSelectors = new bytes4[](1);
        registryServiceRegisterDistributionSelectors[0] = registryService.registerDistribution.selector;
        accessManager.setTargetFunctionRole(
            address(registryService),
            registryServiceRegisterDistributionSelectors, 
            DISTRIBUTION_REGISTRAR_ROLE().toInt());

        // grant POOL_REGISTRAR_ROLE to pool service
        // allow role POOL_REGISTRAR_ROLE to call registerPool on registry service
        accessManager.grantRole(POOL_REGISTRAR_ROLE().toInt(), address(poolService), 0);
        bytes4[] memory registryServiceRegisterPoolSelectors = new bytes4[](1);
        registryServiceRegisterPoolSelectors[0] = registryService.registerPool.selector;
        accessManager.setTargetFunctionRole(
            address(registryService),
            registryServiceRegisterPoolSelectors, 
            POOL_REGISTRAR_ROLE().toInt());

        // grant BUNDLE_REGISTRAR_ROLE to pool service
        // allow role BUNDLE_REGISTRAR_ROLE to call registerBundle on registry service
        accessManager.grantRole(BUNDLE_REGISTRAR_ROLE().toInt(), address(poolService), 0);
        bytes4[] memory registryServiceRegisterBundleSelectors = new bytes4[](1);
        registryServiceRegisterBundleSelectors[0] = registryService.registerBundle.selector;
        accessManager.setTargetFunctionRole(
            address(registryService),
            registryServiceRegisterBundleSelectors, 
            BUNDLE_REGISTRAR_ROLE().toInt());

        // grant PRODUCT_REGISTRAR_ROLE to product service
        // allow role PRODUCT_REGISTRAR_ROLE to call registerProduct on registry service
        accessManager.grantRole(PRODUCT_REGISTRAR_ROLE().toInt(), address(productService), 0);
        bytes4[] memory registryServiceRegisterProductSelectors = new bytes4[](2);
        registryServiceRegisterProductSelectors[0] = registryService.registerProduct.selector;
        registryServiceRegisterProductSelectors[1] = registryService.registerPolicy.selector;
        accessManager.setTargetFunctionRole(
            address(registryService),
            registryServiceRegisterProductSelectors, 
            PRODUCT_REGISTRAR_ROLE().toInt());
    }

    function _deployMasterInstance() internal 
    {
        masterInstanceAccessManager = new AccessManagerSimple(masterInstanceOwner);
        masterInstance = new Instance(address(masterInstanceAccessManager), address(registry), registryNftId);
        ( IRegistry.ObjectInfo memory masterInstanceObjectInfo, ) = registryService.registerInstance(masterInstance);
        masterInstanceNftId = masterInstanceObjectInfo.nftId;
        masterInstanceReader = new InstanceReader(address(registry), masterInstanceNftId);
        
        // solhint-disable
        console.log("master instance deployed at", address(masterInstance));
        console.log("master instance nft id", masterInstanceNftId.toInt());
        // solhint-enable

        instanceService.setAccessManagerMaster(address(masterInstanceAccessManager));
        instanceService.setInstanceMaster(address(masterInstance));
        instanceService.setInstanceReaderMaster(address(masterInstanceReader));
    }


    function _createInstance() internal {
        ( 
            instanceAccessManager, 
            instance,
            instanceNftId,
            instanceReader
        ) = instanceService.createInstanceClone();

        
        // solhint-disable-next-line
        console.log("instance deployed at", address(instance));
        // solhint-disable-next-line
        console.log("instance nft id", instanceNftId.toInt());
        // solhint-disable-next-line
        console.log("instance access manager deployed at", address(instanceAccessManager));
        // solhint-disable-next-line
        console.log("instance reader deployed at", address(instanceReader));
    }

    function _deployToken() internal {
        USDC usdc  = new USDC();
        address usdcAddress = address(usdc);

        tokenRegistry.setActive(usdcAddress, registry.getMajorVersion(), true);
        token = usdc;

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
        // Fee memory stakingFee = FeeLib.zeroFee();
        // Fee memory performanceFee = FeeLib.zeroFee();

        // pool = new TestPool(
        //     address(registry), 
        //     instance.getNftId(), 
        //     address(token),
        //     false, // isInterceptor
        //     isVerifying,
        //     collateralizationLevel,
        //     initialPoolFee,
        //     stakingFee,
        //     performanceFee,
        //     poolOwner);

        // componentOwnerService.registerPool(pool);

        // uint256 nftId = pool.getNftId().toInt();
        // uint256 state = instance.getState(pool.getNftId().toKey32(POOL())).toInt();
        // // solhint-disable-next-line
        // console.log("pool deployed at", address(pool));
        // // solhint-disable-next-line
        // console.log("pool nftId", nftId, "state", state);
    // }


    // function _deployDistribution(
    //     bool isVerifying
    // )
    //     internal
    // {
        // Fee memory distributionFee = FeeLib.percentageFee(15);
        // distribution = new TestDistribution(
        //     address(registry), 
        //     instance.getNftId(), 
        //     address(token),
        //     isVerifying,
        //     initialDistributionFee,
        //     distributionOwner);

        // componentOwnerService.registerDistribution(distribution);

        // uint256 nftId = distribution.getNftId().toInt();
        // uint256 state = instance.getState(distribution.getNftId().toKey32(DISTRIBUTION())).toInt();
        // // solhint-disable-next-line
        // console.log("distribution deployed at", address(pool));
        // // solhint-disable-next-line
        // console.log("distribution nftId", nftId, "state", state);
    // }


    // function _deployProduct() internal {
        // Fee memory processingFee = FeeLib.zeroFee();

        // product = new TestProduct(
        //     address(registry), 
        //     instance.getNftId(), 
        //     address(token), 
        //     false, // isInterceptor
        //     address(pool),
        //     address(distribution),
        //     initialProductFee,
        //     processingFee,
        //     productOwner);

        // componentOwnerService.registerProduct(product);
        //registryService.registerComponent(product, PRODUCT());

        // uint256 nftId = product.getNftId().toInt();
        // uint256 state = instance.getState(product.getNftId().toKey32(PRODUCT())).toInt();
        // // tokenHandler = instance.getTokenHandler(product.getNftId());
        // // solhint-disable-next-line
        // console.log("product deployed at", address(product));
        // // solhint-disable-next-line
        // console.log("product nftId", nftId, "state", state);
        // // solhint-disable-next-line
        // console.log("product token handler deployed at", address(tokenHandler));
    // }

    // function _createBundle(
    //     Fee memory fee,
    //     uint256 amount,
    //     uint256 lifetime
    // ) 
    //     internal
    // {
        // bundleNftId = pool.createBundle(
        //     fee,
        //     amount,
        //     lifetime,
        //     "");

    //     // solhint-disable-next-line
    //     console.log("bundle fundet with", amount);
    //     // solhint-disable-next-line
    //     console.log("bundle nft id", bundleNftId.toInt());
    // }
    
    function _prepareDistributionAndPool() internal {
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(DISTRIBUTION_OWNER_ROLE().toInt(), distributionOwner, 0);
        instanceAccessManager.grantRole(POOL_OWNER_ROLE().toInt(), poolOwner, 0);
        vm.stopPrank();

        vm.startPrank(distributionOwner);
        distribution = new Distribution(
            address(registry),
            instanceNftId,
            address(token),
            false,
            FeeLib.zeroFee(),
            distributionOwner
        );
        distributionNftId = distributionService.register(address(distribution));
        vm.stopPrank();

        vm.startPrank(poolOwner);
        pool = new Pool(
            address(registry),
            instanceNftId,
            address(token),
            false,
            false,
            UFixedLib.toUFixed(1),
            FeeLib.zeroFee(),
            FeeLib.zeroFee(),
            FeeLib.zeroFee(),
            poolOwner
        );
        poolNftId = poolService.register(address(pool));
        vm.stopPrank();
    }

}