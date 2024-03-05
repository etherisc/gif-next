// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Test, console} from "../../lib/forge-std/src/Test.sol";

import {VersionPartLib} from "../../contracts/types/Version.sol";

import {ChainNft} from "../../contracts/registry/ChainNft.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {TokenRegistry} from "../../contracts/registry/TokenRegistry.sol";

import {DistributionService} from "../../contracts/instance/service/DistributionService.sol";
import {DistributionServiceManager} from "../../contracts/instance/service/DistributionServiceManager.sol";
import {ProductService} from "../../contracts/instance/service/ProductService.sol";
import {ProductServiceManager} from "../../contracts/instance/service/ProductServiceManager.sol";
import {PoolService} from "../../contracts/instance/service/PoolService.sol";
import {PoolServiceManager} from "../../contracts/instance/service/PoolServiceManager.sol";
import {PolicyService} from "../../contracts/instance/service/PolicyService.sol";
import {PolicyServiceManager} from "../../contracts/instance/service/PolicyServiceManager.sol";
import {BundleService} from "../../contracts/instance/service/BundleService.sol";
import {BundleServiceManager} from "../../contracts/instance/service/BundleServiceManager.sol";
import {InstanceService} from "../../contracts/instance/InstanceService.sol";
import {InstanceServiceManager} from "../../contracts/instance/InstanceServiceManager.sol";
import {BundleManager} from "../../contracts/instance/BundleManager.sol";

import {InstanceAccessManager} from "../../contracts/instance/InstanceAccessManager.sol";
import {Instance} from "../../contracts/instance/Instance.sol";
import {InstanceReader} from "../../contracts/instance/InstanceReader.sol";
import {IKeyValueStore} from "../../contracts/instance/base/IKeyValueStore.sol";
import {TokenHandler} from "../../contracts/shared/TokenHandler.sol";
import {Distribution} from "../../contracts/components/Distribution.sol";
import {Product} from "../../contracts/components/Product.sol";
import {USDC} from "../../contracts/test/Usdc.sol";
import {SimpleDistribution} from "../mock/SimpleDistribution.sol";
import {SimplePool} from "../mock/SimplePool.sol";

// import {IPolicy} from "../../contracts/instance/module/policy/IPolicy.sol";
// import {IPool} from "../../contracts/instance/module/pool/IPoolModule.sol";
import {NftId, NftIdLib, zeroNftId} from "../../contracts/types/NftId.sol";
import {REGISTRY, TOKEN, SERVICE, INSTANCE, POOL, ORACLE, PRODUCT, DISTRIBUTION, BUNDLE, POLICY} from "../../contracts/types/ObjectType.sol";
import {Fee, FeeLib} from "../../contracts/types/Fee.sol";
import {
    ADMIN_ROLE,
    PRODUCT_OWNER_ROLE, 
    POOL_OWNER_ROLE, 
    DISTRIBUTION_OWNER_ROLE} from "../../contracts/types/RoleId.sol";
import {UFixed, UFixedLib} from "../../contracts/types/UFixed.sol";
import {Version} from "../../contracts/types/Version.sol";

import {ProxyManager} from "../../contracts/shared/ProxyManager.sol";
import {IVersionable} from "../../contracts/shared/IVersionable.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {IRegistryService} from "../../contracts/registry/RegistryService.sol";
import {RegistryServiceManager} from "../../contracts/registry/RegistryServiceManager.sol";
import {RegistryAccessManager} from "../../contracts/registry/RegistryAccessManager.sol";
import {ReleaseManager} from "../../contracts/registry/ReleaseManager.sol";


// solhint-disable-next-line max-states-count
contract TestGifBase is Test {

    // in full token units, value will be multiplied by 10 ** token.decimals()
    uint256 constant public DEFAULT_BUNDLE_CAPITALIZATION = 10 ** 5;

    // bundle lifetime is one year in seconds
    uint256 constant public DEFAULT_BUNDLE_LIFETIME = 365 * 24 * 3600;

    RegistryAccessManager registryAccessManager;
    ReleaseManager public releaseManager;
    RegistryServiceManager public registryServiceManager;
    RegistryService public registryService;
    Registry public registry;
    ChainNft public chainNft;
    TokenRegistry public tokenRegistry;

    IERC20Metadata public token;

    InstanceServiceManager public instanceServiceManager;
    InstanceService public instanceService;
    NftId public instanceServiceNftId;
    DistributionServiceManager public distributionServiceManager;
    DistributionService public distributionService;
    NftId public distributionServiceNftId;
    ProductServiceManager public productServiceManager;
    ProductService public productService;
    NftId public productServiceNftId;
    PoolServiceManager public poolServiceManager;
    PoolService public poolService;
    NftId public poolServiceNftId;
    PolicyServiceManager public policyServiceManager;
    PolicyService public policyService;
    NftId public policyServiceNftId;
    BundleServiceManager public bundleServiceManager;
    BundleService public bundleService;
    NftId public bundleServiceNftId;

    InstanceAccessManager masterInstanceAccessManager;
    BundleManager masterBundleManager;
    Instance masterInstance;
    NftId masterInstanceNftId;
    InstanceReader masterInstanceReader;

    InstanceAccessManager instanceAccessManager;
    BundleManager instanceBundleManager;
    Instance public instance;
    NftId public instanceNftId;
    InstanceReader public instanceReader;

    IKeyValueStore public keyValueStore;
    // TestProduct public product;
    // TestPool public pool;
    // TestDistribution public distribution;
    Distribution public distribution;
    NftId public distributionNftId;
    SimplePool public pool;
    NftId public poolNftId;
    Product public product;
    NftId public productNftId;
    TokenHandler public tokenHandler;

    address public registryAddress;
    NftId public registryNftId;
    NftId public bundleNftId;
    uint256 public initialCapitalAmount;

    address constant public MASTER_INSTANCE_OWNER = address(0x1);
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
        _deployAndRegisterServices();
        vm.stopPrank();

        vm.startPrank(registryOwner);
        _deployMasterInstance();
        vm.stopPrank();

        vm.startPrank(address(registryOwner)); 
        _deployAndActivateToken();
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
        registryAccessManager = new RegistryAccessManager(registryOwner);

        releaseManager = new ReleaseManager(
            registryAccessManager,
            VersionPartLib.toVersionPart(3));

        registryAddress = address(releaseManager.getRegistry());
        registry = Registry(registryAddress);
        registryNftId = registry.getNftId(address(registry)); 

        address chainNftAddress = address(registry.getChainNft());
        chainNft = ChainNft(chainNftAddress);

        tokenRegistry = new TokenRegistry();

        registryAccessManager.initialize(address(releaseManager), address(tokenRegistry));

        registryServiceManager = new RegistryServiceManager(
            registryAccessManager.authority(),
            registryAddress
        );        
        
        registryService = registryServiceManager.getRegistryService();

        releaseManager.createNextRelease();

        releaseManager.registerRegistryService(registryService);

        // TODO it is also linking to registry
        // TODO links to _initial version instead _latest
        //registryServiceManager.linkToNftOwnable(registryAddress);// links to initial registry service
        //tokenRegistry.linkToNftOwnable(registryAddress);// links to initial registry service

        
        /* solhint-disable */
        console.log("registry deployed at", address(registry));
        console.log("protocol nft id", chainNft.PROTOCOL_NFT_ID());
        console.log("global registry nft id", chainNft.GLOBAL_REGISTRY_ID());
        console.log("registry nft id", registry.getNftId(address(registry)).toInt());

        console.log("registry owner", address(registryOwner));
        console.log("registry access manager", address(registryAccessManager));
        console.log("registry access manager authority", registryAccessManager.authority());
        console.log("release manager", address(releaseManager));
        console.log("release manager authority", releaseManager.authority());
        console.log("registry service proxy manager", address(registryServiceManager));
        console.log("registry service proxy manager linked to nft", registryServiceManager.getNftId().toInt());
        console.log("registry service proxy manager owner", registryServiceManager.getOwner());
        console.log("registry service", address(registryService));
        console.log("registry service nft", registryService.getNftId().toInt());
        console.log("registry service authority", registryService.authority());
        console.log("registry service owner", registryService.getOwner());
        console.log("registry", address(registry));
        console.log("registry nft", registry.getNftId(address(registry)).toInt());
        console.log("registry owner (opt 1)", registry.ownerOf(address(registry)));
        console.log("registry owner (opt 2)", registry.getOwner());
        console.log("token registry", address(tokenRegistry));
        console.log("token registry linked to nft", tokenRegistry.getNftId().toInt());
        console.log("token registry linked owner", tokenRegistry.getOwner());        
        /* solhint-enable */
    }

    function _deployAndRegisterServices() internal 
    {
        // --- instance service ---------------------------------//
        // TODO manager can not use releaseManager.registerService() in constructor
        // because it have no role / have no nft
        instanceServiceManager = new InstanceServiceManager(address(registry));
        instanceService = instanceServiceManager.getInstanceService();
        // temporal solution, register in separate tx
        releaseManager.registerService(instanceService);
        instanceServiceNftId = registry.getNftId(address(instanceService));


        // solhint-disable 
        console.log("instanceService domain", instanceService.getDomain().toInt());
        console.log("instanceService deployed at", address(instanceService));
        console.log("instanceService nft id", instanceService.getNftId().toInt());
        // solhint-enable 

        // --- distribution service ---------------------------------//
        distributionServiceManager = new DistributionServiceManager(address(registry));
        distributionService = distributionServiceManager.getDistributionService();
        releaseManager.registerService(distributionService);
        distributionServiceNftId = registry.getNftId(address(distributionService));

        // solhint-disable 
        console.log("distributionService domain", distributionService.getDomain().toInt());
        console.log("distributionService deployed at", address(distributionService));
        console.log("distributionService nft id", distributionService.getNftId().toInt());
        // solhint-enable

        // --- pool service ---------------------------------//
        poolServiceManager = new PoolServiceManager(address(registry));
        poolService = poolServiceManager.getPoolService();
        releaseManager.registerService(poolService);
        poolServiceNftId = registry.getNftId(address(poolService));

        // solhint-disable
        console.log("poolService domain", poolService.getDomain().toInt());
        console.log("poolService deployed at", address(poolService));
        console.log("poolService nft id", poolService.getNftId().toInt());
        // solhint-enable

        // --- product service ---------------------------------//
        productServiceManager = new ProductServiceManager(address(registry));
        productService = productServiceManager.getProductService();
        releaseManager.registerService(productService);
        productServiceNftId = registry.getNftId(address(productService));

        // solhint-disable
        console.log("productService domain", productService.getDomain().toInt());
        console.log("productService deployed at", address(productService));
        console.log("productService nft id", productService.getNftId().toInt());
        // solhint-enable

        // --- bundle service ---------------------------------//
        bundleServiceManager = new BundleServiceManager(address(registry));
        bundleService = bundleServiceManager.getBundleService();
        releaseManager.registerService(bundleService);
        bundleServiceNftId = registry.getNftId(address(bundleService));

        // solhint-disable
        console.log("bundleService domain", bundleService.getDomain().toInt());
        console.log("bundleService deployed at", address(bundleService));
        console.log("bundleService nft id", bundleService.getNftId().toInt());
        // solhint-enable

        // MUST follow bundle service registration 
        // --- policy service ---------------------------------//
        policyServiceManager = new PolicyServiceManager(address(registry));
        policyService = policyServiceManager.getPolicyService();
        releaseManager.registerService(policyService);
        policyServiceNftId = registry.getNftId(address(policyService));

        // solhint-disable
        console.log("policyService domain", policyService.getDomain().toInt());
        console.log("policyService deployed at", address(policyService));
        console.log("policyService nft id", policyService.getNftId().toInt());
        // solhint-enable

        // activate initial release -> activated upon last service registration
        releaseManager.activateNextRelease();

        registryServiceManager.linkToNftOwnable(registryAddress);// links to latest registry service
        tokenRegistry.linkToNftOwnable(registryAddress);// links to to latest registry service
    }

    function _deployMasterInstance() internal 
    {
        masterInstanceAccessManager = new InstanceAccessManager();
        masterInstanceAccessManager.initialize(registryOwner);
        
        masterInstance = new Instance();
        masterInstance.initialize(address(masterInstanceAccessManager), address(registry), registryNftId, registryOwner);
        
        masterInstanceReader = new InstanceReader();
        masterInstanceReader.initialize(address(registry), address(masterInstance));
        masterInstance.setInstanceReader(masterInstanceReader);
        
        masterBundleManager = new BundleManager();
        masterBundleManager.initialize(address(masterInstanceAccessManager), address(registry), address(masterInstance));
        masterInstance.setBundleManager(masterBundleManager);

        // revoke ADMIN_ROLE from registryOwner. token is already owned by 0x1
        masterInstanceAccessManager.revokeRole(ADMIN_ROLE(), address(registryOwner));
        
        masterInstanceNftId = instanceService.setAndRegisterMasterInstance(
            address(masterInstanceAccessManager), 
            address(masterInstance), 
            address(masterInstanceReader), 
            address(masterBundleManager));

        chainNft.transferFrom(registryOwner, MASTER_INSTANCE_OWNER, masterInstanceNftId.toInt());

        // solhint-disable
        console.log("master instance deployed at", address(masterInstance));
        console.log("master instance nft id", masterInstanceNftId.toInt());
        // solhint-enable
    }


    function _createInstance() internal {
        ( 
            instanceAccessManager, 
            instance,
            instanceNftId,
            instanceReader,
            instanceBundleManager
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

    function _deployAndActivateToken() internal {
        USDC usdc  = new USDC();
        address usdcAddress = address(usdc);
        token = usdc;

        // solhint-disable-next-line
        console.log("token deployed at", usdcAddress);

        tokenRegistry.setActive(address(token), registry.getLatestVersion(), true);
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
        instanceAccessManager.grantRole(DISTRIBUTION_OWNER_ROLE(), distributionOwner);
        instanceAccessManager.grantRole(POOL_OWNER_ROLE(), poolOwner);
        vm.stopPrank();

        vm.startPrank(distributionOwner);
        distribution = new SimpleDistribution(
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
        pool = new SimplePool(
            address(registry),
            instanceNftId,
            address(token),
            false,
            false,
            UFixedLib.toUFixed(1),
            poolOwner
        );
        poolNftId = poolService.register(address(pool));
        vm.stopPrank();
    }

}