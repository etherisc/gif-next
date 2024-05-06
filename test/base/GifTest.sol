// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Test, console} from "../../lib/forge-std/src/Test.sol";

import {VersionPartLib} from "../../contracts/type/Version.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {SecondsLib} from "../../contracts/type/Seconds.sol";
import {REGISTRY, TOKEN, SERVICE, INSTANCE, POOL, ORACLE, PRODUCT, DISTRIBUTION, BUNDLE, POLICY} from "../../contracts/type/ObjectType.sol";
import {Fee, FeeLib} from "../../contracts/type/Fee.sol";
import {
    GIF_MANAGER_ROLE,
    GIF_ADMIN_ROLE,
    ADMIN_ROLE,
    INSTANCE_OWNER_ROLE,
    PRODUCT_OWNER_ROLE, 
    POOL_OWNER_ROLE, 
    DISTRIBUTION_OWNER_ROLE} from "../../contracts/type/RoleId.sol";
import {UFixed, UFixedLib} from "../../contracts/type/UFixed.sol";
import {Version} from "../../contracts/type/Version.sol";

import {IVersionable} from "../../contracts/shared/IVersionable.sol";
import {ProxyManager} from "../../contracts/shared/ProxyManager.sol";
import {TokenHandler} from "../../contracts/shared/TokenHandler.sol";
import {AccessManagerUpgradeableInitializeable} from "../../contracts/shared/AccessManagerUpgradeableInitializeable.sol";

import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {IRegistryService} from "../../contracts/registry/RegistryService.sol";
import {RegistryServiceManager} from "../../contracts/registry/RegistryServiceManager.sol";
import {RegistryAccessManager} from "../../contracts/registry/RegistryAccessManager.sol";
import {ReleaseManager} from "../../contracts/registry/ReleaseManager.sol";
import {ChainNft} from "../../contracts/registry/ChainNft.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {TokenRegistry} from "../../contracts/registry/TokenRegistry.sol";

import {IComponents} from "../../contracts/instance/module/IComponents.sol";
import {ComponentService} from "../../contracts/shared/ComponentService.sol";
import {ComponentServiceManager} from "../../contracts/shared/ComponentServiceManager.sol";
import {DistributionService} from "../../contracts/distribution/DistributionService.sol";
import {DistributionServiceManager} from "../../contracts/distribution/DistributionServiceManager.sol";
import {ProductService} from "../../contracts/product/ProductService.sol";
import {ProductServiceManager} from "../../contracts/product/ProductServiceManager.sol";
import {PoolService} from "../../contracts/pool/PoolService.sol";
import {PoolServiceManager} from "../../contracts/pool/PoolServiceManager.sol";

import {ApplicationService} from "../../contracts/product/ApplicationService.sol";
import {ApplicationServiceManager} from "../../contracts/product/ApplicationServiceManager.sol";
import {PolicyService} from "../../contracts/product/PolicyService.sol";
import {PolicyServiceManager} from "../../contracts/product/PolicyServiceManager.sol";
import {ClaimService} from "../../contracts/product/ClaimService.sol";
import {ClaimServiceManager} from "../../contracts/product/ClaimServiceManager.sol";
import {BundleService} from "../../contracts/pool/BundleService.sol";
import {BundleServiceManager} from "../../contracts/pool/BundleServiceManager.sol";
import {PricingService} from "../../contracts/product/PricingService.sol";
import {PricingServiceManager} from "../../contracts/product/PricingServiceManager.sol";

import {InstanceService} from "../../contracts/instance/InstanceService.sol";
import {InstanceServiceManager} from "../../contracts/instance/InstanceServiceManager.sol";

import {Staking} from "../../contracts/staking/Staking.sol";
import {StakingReader} from "../../contracts/staking/StakingReader.sol";
import {StakingManager} from "../../contracts/staking/StakingManager.sol";
import {StakingService} from "../../contracts/staking/StakingService.sol";
import {StakingServiceManager} from "../../contracts/staking/StakingServiceManager.sol";

import {InstanceAccessManager} from "../../contracts/instance/InstanceAccessManager.sol";
import {Instance} from "../../contracts/instance/Instance.sol";
import {InstanceReader} from "../../contracts/instance/InstanceReader.sol";
import {BundleManager} from "../../contracts/instance/BundleManager.sol";
import {IKeyValueStore} from "../../contracts/shared/IKeyValueStore.sol";
import {InstanceStore} from "../../contracts/instance/InstanceStore.sol";

import {Dip} from "../../contracts/mock/Dip.sol";
import {Distribution} from "../../contracts/distribution/Distribution.sol";
import {Product} from "../../contracts/product/Product.sol";
import {Pool} from "../../contracts/pool/Pool.sol";
import {Usdc} from "../mock/Usdc.sol";
import {SimpleDistribution} from "../mock/SimpleDistribution.sol";
import {SimplePool} from "../mock/SimplePool.sol";
import {SimpleProduct} from "../mock/SimpleProduct.sol";

// solhint-disable-next-line max-states-count
contract GifTest is Test {

    // default customer token balance in full token units, value will be multiplied by 10 ** token.decimals()
    uint256 DEFAULT_CUSTOMER_FUNDS = 1000;

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
    IERC20Metadata public dip;

    InstanceServiceManager public instanceServiceManager;
    InstanceService public instanceService;

    StakingServiceManager public stakingServiceManager;
    StakingService public stakingService;
    NftId public stakingServiceNftId;
    StakingManager public stakingManager;
    Staking public staking;
    StakingReader public stakingReader;
    NftId public stakingNftId;

    NftId public instanceServiceNftId;

    ComponentServiceManager public componentServiceManager;
    ComponentService public componentService;
    NftId public componentServiceNftId;

    DistributionServiceManager public distributionServiceManager;
    DistributionService public distributionService;
    NftId public distributionServiceNftId;
    ProductServiceManager public productServiceManager;
    ProductService public productService;
    NftId public productServiceNftId;
    PoolServiceManager public poolServiceManager;
    PoolService public poolService;
    NftId public poolServiceNftId;

    ApplicationServiceManager public applicationServiceManager;
    ApplicationService public applicationService;
    NftId public applicationServiceNftId;
    PolicyServiceManager public policyServiceManager;
    PolicyService public policyService;
    NftId public policyServiceNftId;
    ClaimServiceManager public claimServiceManager;
    ClaimService public claimService;
    NftId public claimServiceNftId;
    PricingService public pricingService;
    NftId public pricingServiceNftId;
    PricingServiceManager public pricingServiceManager;

    BundleServiceManager public bundleServiceManager;
    BundleService public bundleService;
    NftId public bundleServiceNftId;

    AccessManagerUpgradeableInitializeable public masterOzAccessManager;
    InstanceAccessManager public masterInstanceAccessManager;
    BundleManager public masterBundleManager;
    InstanceStore public masterInstanceStore;
    Instance public masterInstance;
    NftId public masterInstanceNftId;
    InstanceReader public masterInstanceReader;

    AccessManagerUpgradeableInitializeable public ozAccessManager;
    InstanceAccessManager public instanceAccessManager;
    BundleManager public instanceBundleManager;
    InstanceStore public instanceStore;
    Instance public instance;
    NftId public instanceNftId;
    InstanceReader public instanceReader;

    SimpleDistribution public distribution;
    NftId public distributionNftId;
    SimplePool public pool;
    NftId public poolNftId;
    SimpleProduct public product;
    NftId public productNftId;

    address public registryAddress;
    NftId public registryNftId;
    NftId public bundleNftId;
    uint256 public initialCapitalAmount;

    address constant public NFT_LOCK_ADDRESS = address(0x1);
    address public registryOwner = makeAddr("registryOwner");
    address public stakingOwner = registryOwner;
    address public instanceOwner = makeAddr("instanceOwner");
    address public productOwner = makeAddr("productOwner");
    address public poolOwner = makeAddr("poolOwner");
    address public distributionOwner = makeAddr("distributionOwner");
    address public customer = makeAddr("customer");
    address public customer2 = makeAddr("customer2");
    address public investor = makeAddr("investor");
    address public staker = makeAddr("staker");
    address public staker2 = makeAddr("staker2");
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

        // deploy dip
        vm.startPrank(registryOwner);
        dip = new Dip();
        vm.stopPrank();

        // deploy registry, services, master instance and token
        vm.startPrank(registryOwner);
        _deployRegistryServiceAndRegistry();
        _deployAndRegisterServices();
        vm.stopPrank();

        vm.startPrank(registryOwner);
        _deployMasterInstance();
        vm.stopPrank();

        vm.startPrank(address(registryOwner)); 
        _deployRegisterAndActivateToken();
        vm.stopPrank();

        // create an instance (cloned from master instance)
        vm.startPrank(instanceOwner);
        _createInstance();
        vm.stopPrank();
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

    function equalStrings(string memory s1, string memory s2) internal pure returns (bool) {
        return equalBytes(bytes(s1), bytes(s2));
    }

    function equalBytes(bytes memory b1, bytes memory b2) internal pure returns (bool) {
        return keccak256(b1) == keccak256(b2);
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
        // 1) deploy registry access manager
        // grants GIF_ADMIN_ROLE to registry owner as registryOwner is transaction sender
        // grants GIF_MANAGER_ROLE to registry owner via contructor argument
        registryAccessManager = new RegistryAccessManager(registryOwner);

        (bool isAdmin,) = registryAccessManager.getAccessManager().hasRole(GIF_ADMIN_ROLE().toInt(), registryOwner);
        require(isAdmin, "gif admin role missing");
        (bool isManager,) = registryAccessManager.getAccessManager().hasRole(GIF_MANAGER_ROLE().toInt(), registryOwner);
        require(isManager, "gif manager role missing");

        // solhint-disable
        console.log("registry owner", registryOwner);
        console.log("registry access manager deployed:", address(registryAccessManager));
        console.log("registry access manager authority", registryAccessManager.authority());
        // solhint-enable

        // 2) deploy release manager (registry/chain nft)
        // internally deploys the registry
        // internally deploys the token registry
        // bi-directionally links registry and token registry
        releaseManager = new ReleaseManager(
            registryAccessManager,
            VersionPartLib.toVersionPart(3),
            address(dip));

        registryAddress = releaseManager.getRegistryAddress();
        registry = Registry(registryAddress);

        registryNftId = registry.getNftId(address(registry));
        address chainNftAddress = registry.getChainNftAddress();
        chainNft = ChainNft(chainNftAddress);
        tokenRegistry = TokenRegistry(registry.getTokenRegistryAddress());

        assertEq(address(tokenRegistry.getDipToken()), address(dip), "unexpected dip address");

        // solhint-disable
        console.log("protocol nft id", chainNft.PROTOCOL_NFT_ID());
        console.log("global registry nft id", chainNft.GLOBAL_REGISTRY_ID());

        console.log("registry nft id", registry.getNftId(address(registry)).toInt());
        console.log("registry deployed at", address(registry));
        console.log("registry owner (opt 1)", registry.ownerOf(address(registry)));
        console.log("registry owner (opt 2)", registry.getOwner());

        console.log("release manager deployed at", address(releaseManager));
        console.log("release manager authority", releaseManager.authority());
        // solhint-enable

        // 3) initialize access rights for registry access manager
        registryAccessManager.initialize(address(releaseManager), address(tokenRegistry));

        // solhint-disable
        console.log("token registry deployed at", address(tokenRegistry));
        console.log("registry access manager initialized", address(registryAccessManager));
        // solhint-enable

        // 4) deploy staking contract
        stakingOwner = registryOwner;
        stakingManager = new StakingManager(
            registryAccessManager.authority(),
            address(registry));
        staking = stakingManager.getStaking();
        stakingReader = staking.getStakingReader();

        // solhint-disable
        console.log("stakingManager deployed at", address(stakingManager));
        console.log("staking deployed at", address(staking));
        console.log("staking reader deployed at", address(stakingReader));

        // 5) register staking contract
        stakingNftId = releaseManager.registerStaking(
            address(staking),
            stakingOwner);

        console.log("staking nft id", registry.getNftId(address(staking)).toInt());
        console.log("staking deployed at", address(staking));
        console.log("staking owner (opt 1)", registry.ownerOf(address(staking)));
        console.log("staking owner (opt 2)", staking.getOwner());
        // solhint-enable

        // 6) deploy registry service
        registryServiceManager = new RegistryServiceManager(
            registryAccessManager.authority(),
            registryAddress
        );        
        registryService = registryServiceManager.getRegistryService();
        
        // 7) create first gif release
        // registry owner has GIF_ADMIN_ROLE
        releaseManager.createNextRelease();

        // 8) start gif release deploy with registration of registry service
        // registry service always needs to be registered first when deploying a new gif release
        releaseManager.registerRegistryService(registryService);
        registryServiceManager.linkOwnershipToServiceNft();

        tokenRegistry.linkToRegistryService();

        /* solhint-disable */
        console.log("token registry linked to nft", tokenRegistry.getNftId().toInt());
        console.log("token registry linked owner", tokenRegistry.getOwner());

        console.log("registry service proxy manager deployed at", address(registryServiceManager));
        console.log("registry service proxy manager linked to nft", registryServiceManager.getNftId().toInt());
        console.log("registry service proxy manager owner", registryServiceManager.getOwner());

        console.log("registry service deployed at", address(registryService));
        console.log("registry service nft", registryService.getNftId().toInt());
        console.log("registry service owner", registryService.getOwner());
        console.log("registry service authority", registryService.authority());
        /* solhint-enable */
    }

    function _deployAndRegisterServices() internal 
    {
        // --- staking service ---------------------------------//
        stakingServiceManager = new StakingServiceManager(
            address(registry));

        // staking registered with registry in staking service manager
        stakingNftId = staking.getNftId();
        stakingService = stakingServiceManager.getStakingService();

        // register instance service with registry
        stakingServiceNftId = releaseManager.registerService(stakingService);

        // solhint-disable 
        console.log("stakingService deployed at", address(stakingService));
        console.log("stakingService domain", stakingService.getDomain().toInt());
        console.log("stakingService nft id", stakingServiceNftId.toInt());
        // solhint-enable

        // --- instance service ---------------------------------//
        instanceServiceManager = new InstanceServiceManager(address(registry));
        instanceService = instanceServiceManager.getInstanceService();

        // register instance service with registry
        instanceServiceNftId = releaseManager.registerService(instanceService);

        // solhint-disable 
        console.log("instanceService domain", instanceService.getDomain().toInt());
        console.log("instanceService deployed at", address(instanceService));
        console.log("instanceService nft id", instanceServiceNftId.toInt());
        // solhint-enable

        // --- component service ---------------------------------//
        componentServiceManager = new ComponentServiceManager(address(registry));
        componentService = componentServiceManager.getComponentService();
        componentServiceNftId = releaseManager.registerService(componentService);

        // solhint-disable 
        console.log("componentService domain", componentService.getDomain().toInt());
        console.log("componentService deployed at", address(componentService));
        console.log("componentService nft id", componentService.getNftId().toInt());
        // solhint-enable

        // --- distribution service ---------------------------------//
        distributionServiceManager = new DistributionServiceManager(address(registry));
        distributionService = distributionServiceManager.getDistributionService();
        distributionServiceNftId = releaseManager.registerService(distributionService);

        // solhint-disable 
        console.log("distributionService domain", distributionService.getDomain().toInt());
        console.log("distributionService deployed at", address(distributionService));
        console.log("distributionService nft id", distributionService.getNftId().toInt());
        // solhint-enable

        // --- pricing service ---------------------------------//
        // TODO chicken and egg problem, pricing service needs distribution service to be registered and vice versa
        // option 1: do not store service references localy, in services
        // option 2: do not use isValidReferal in  pricing service
        pricingServiceManager = new PricingServiceManager(address(registry));
        pricingService = pricingServiceManager.getPricingService();
        pricingServiceNftId = releaseManager.registerService(pricingService);

        // solhint-disable
        console.log("pricingService domain", pricingService.getDomain().toInt());
        console.log("pricingService deployed at", address(pricingService));
        console.log("pricingService nft id", pricingService.getNftId().toInt());
        // solhint-enable

        // --- bundle service ---------------------------------//
        bundleServiceManager = new BundleServiceManager(address(registry));
        bundleService = bundleServiceManager.getBundleService();
        bundleServiceNftId = releaseManager.registerService(bundleService);

        // solhint-disable
        console.log("bundleService domain", bundleService.getDomain().toInt());
        console.log("bundleService deployed at", address(bundleService));
        console.log("bundleService nft id", bundleService.getNftId().toInt());
        // solhint-enable

        // --- pool service ---------------------------------//
        poolServiceManager = new PoolServiceManager(address(registry));
        poolService = poolServiceManager.getPoolService();
        poolServiceNftId = releaseManager.registerService(poolService);

        // solhint-disable
        console.log("poolService domain", poolService.getDomain().toInt());
        console.log("poolService deployed at", address(poolService));
        console.log("poolService nft id", poolService.getNftId().toInt());
        // solhint-enable

        // --- product service ---------------------------------//
        productServiceManager = new ProductServiceManager(address(registry));
        productService = productServiceManager.getProductService();
        productServiceNftId = releaseManager.registerService(productService);

        // solhint-disable
        console.log("productService domain", productService.getDomain().toInt());
        console.log("productService deployed at", address(productService));
        console.log("productService nft id", productService.getNftId().toInt());
        // solhint-enable

        // MUST follow bundle service registration 
        // --- claim service ---------------------------------//
        claimServiceManager = new ClaimServiceManager(address(registry));
        claimService = claimServiceManager.getClaimService();
        claimServiceNftId = releaseManager.registerService(claimService);

        // solhint-disable
        console.log("claimService domain", claimService.getDomain().toInt());
        console.log("claimService deployed at", address(claimService));
        console.log("claimService nft id", claimService.getNftId().toInt());
        // solhint-enable

        // --- application service ---------------------------------//
        applicationServiceManager = new ApplicationServiceManager(address(registry));
        applicationService = applicationServiceManager.getApplicationService();
        applicationServiceNftId = releaseManager.registerService(applicationService);

        // solhint-disable
        console.log("applicationService domain", applicationService.getDomain().toInt());
        console.log("applicationService deployed at", address(applicationService));
        console.log("applicationService nft id", applicationService.getNftId().toInt());
        // solhint-enable

        // --- policy service ---------------------------------//
        policyServiceManager = new PolicyServiceManager(address(registry));
        policyService = policyServiceManager.getPolicyService();
        policyServiceNftId = releaseManager.registerService(policyService);

        // solhint-disable
        console.log("policyService domain", policyService.getDomain().toInt());
        console.log("policyService deployed at", address(policyService));
        console.log("policyService nft id", policyService.getNftId().toInt());
        // solhint-enable

        // activate initial release -> activated upon last service registration
        releaseManager.activateNextRelease();
    }

    function _deployMasterInstance() internal 
    {
        masterOzAccessManager = new AccessManagerUpgradeableInitializeable();
        // grants registryOwner ADMIN_ROLE
        masterOzAccessManager.initialize(registryOwner);
        
        masterInstance = new Instance();
        masterInstance.initialize(
            address(masterOzAccessManager),
            address(registry),
            registryOwner);

        // MUST be initialized and set before instance reader
        masterInstanceStore = new InstanceStore();
        masterInstanceStore.initialize(address(masterInstance));
        masterInstance.setInstanceStore(masterInstanceStore);
        assert(masterInstance.getInstanceStore() == masterInstanceStore);

        masterInstanceReader = new InstanceReader();
        masterInstanceReader.initialize(address(masterInstance));
        masterInstance.setInstanceReader(masterInstanceReader);
        
        masterBundleManager = new BundleManager();
        masterBundleManager.initialize(address(masterInstance));
        masterInstance.setBundleManager(masterBundleManager);

        masterInstanceAccessManager = new InstanceAccessManager();
        masterOzAccessManager.grantRole(ADMIN_ROLE().toInt(), address(masterInstanceAccessManager), 0);
        masterInstanceAccessManager.initialize(address(masterInstance));
        masterInstance.setInstanceAccessManager(masterInstanceAccessManager);

        // sets master instance address in instance service
        // instance service is now ready to create cloned instances
        masterInstanceNftId = instanceService.setAndRegisterMasterInstance(address(masterInstance));

        chainNft.transferFrom(registryOwner, NFT_LOCK_ADDRESS, masterInstanceNftId.toInt());

        // revoke ADMIN_ROLE from all members
        masterInstanceAccessManager.revokeRole(ADMIN_ROLE(), address(masterInstanceAccessManager));
        masterOzAccessManager.renounceRole(ADMIN_ROLE().toInt(), registryOwner);

        // solhint-disable
        console.log("master instance deployed at", address(masterInstance));
        console.log("master instance nft id", masterInstanceNftId.toInt());
        console.log("master oz access manager deployed at", address(masterOzAccessManager));
        console.log("master instance access manager deployed at", address(masterInstanceAccessManager));
        console.log("master instance reader deployed at", address(masterInstanceReader));
        console.log("master bundle manager deployed at", address(masterBundleManager));
        console.log("master instance store deployed at", address(masterInstanceStore));
        // solhint-enable
    }


    function _createInstance() internal {
        ( 
            instance,
            instanceNftId
        ) = instanceService.createInstanceClone();

        instanceAccessManager = instance.getInstanceAccessManager();
        ozAccessManager = AccessManagerUpgradeableInitializeable(instance.authority());
        instanceReader = instance.getInstanceReader();
        instanceStore = instance.getInstanceStore();
        instanceBundleManager = instance.getBundleManager();
        
        // solhint-disable
        console.log("cloned instance deployed at", address(instance));
        console.log("cloned instance nft id", instanceNftId.toInt());
        console.log("cloned oz access manager deployed at", address(ozAccessManager));
        console.log("cloned instance access manager deployed at", address(instanceAccessManager));
        console.log("cloned instance reader deployed at", address(instanceReader));
        console.log("cloned bundle manager deployed at", address(instanceBundleManager));
        console.log("cloned instance store deployed at", address(instanceStore));
        // solhint-enable
    }

    function _deployRegisterAndActivateToken() internal {
        token = new Usdc();

        // usdc
        tokenRegistry.registerToken(address(token));
        tokenRegistry.setActiveForVersion(block.chainid, address(token), registry.getLatestVersion(), true);

        // solhint-disable
        console.log("token (usdc) deployed at", address(token));
        console.log("token (dip) deployed at", address(dip));
        // solhint-enable
    }


    // function _deployPool(
    //     bool isInterceptor,
    //     bool isVerifying,
    //     UFixed collateralizationLevel
    // )
    //     internal
    // {
        // Fee memory stakingFee = FeeLib.zero();
        // Fee memory performanceFee = FeeLib.zero();

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
        // Fee memory processingFee = FeeLib.zero();

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

    function _prepareProduct() internal {
        _prepareProduct(true);
    }

    function _prepareProduct(bool createBundle) internal {
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(PRODUCT_OWNER_ROLE(), productOwner);
        vm.stopPrank();

        _prepareDistributionAndPool();

        vm.startPrank(productOwner);
        product = new SimpleProduct(
            address(registry),
            instanceNftId,
            productOwner,
            address(token),
            false,
            address(pool), 
            address(distribution)
        );
        
        product.register();
        productNftId = product.getNftId();
        vm.stopPrank();

        // solhint-disable
        console.log("product nft id", productNftId.toInt());
        console.log("product component at", address(product));
        // solhint-enable

        vm.startPrank(registryOwner);
        token.transfer(investor, DEFAULT_BUNDLE_CAPITALIZATION * 10**token.decimals());
        token.transfer(customer, DEFAULT_CUSTOMER_FUNDS * 10**token.decimals());
        vm.stopPrank();

        if (createBundle) {
            vm.startPrank(investor);
            IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);
            token.approve(address(poolComponentInfo.tokenHandler), DEFAULT_BUNDLE_CAPITALIZATION * 10**token.decimals());

            bundleNftId = SimplePool(address(pool)).createBundle(
                FeeLib.zero(), 
                DEFAULT_BUNDLE_CAPITALIZATION * 10**token.decimals(), 
                SecondsLib.toSeconds(DEFAULT_BUNDLE_LIFETIME), 
                ""
            );
            vm.stopPrank();
        }
    }


    function _prepareDistributionAndPool() internal {
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(DISTRIBUTION_OWNER_ROLE(), distributionOwner);
        instanceAccessManager.grantRole(POOL_OWNER_ROLE(), poolOwner);
        vm.stopPrank();

        vm.startPrank(distributionOwner);
        distribution = new SimpleDistribution(
            address(registry),
            instanceNftId,
            distributionOwner,
            address(token));

        distribution.register();
        distributionNftId = distribution.getNftId();
        vm.stopPrank();

        // solhint-disable
        console.log("distribution nft id", distributionNftId.toInt());
        console.log("distribution component at", address(distribution));
        // solhint-enable

        vm.startPrank(poolOwner);
        pool = new SimplePool(
            address(registry),
            instanceNftId,
            address(token),
            false,
            false,
            UFixedLib.toUFixed(1),
            UFixedLib.toUFixed(1),
            poolOwner
        );

        pool.register();
        poolNftId = pool.getNftId();
        pool.approveTokenHandler(type(uint256).max);
        vm.stopPrank();

        // solhint-disable
        console.log("pool nft id", poolNftId.toInt());
        console.log("pool component at", address(pool));
        // solhint-enable
    }


    function _preparePool() internal {
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(POOL_OWNER_ROLE(), poolOwner);
        vm.stopPrank();

        vm.startPrank(poolOwner);
        pool = new SimplePool(
            address(registry),
            instanceNftId,
            address(token),
            false,
            false,
            UFixedLib.toUFixed(1),
            UFixedLib.toUFixed(1),
            poolOwner
        );
        pool.register();
        poolNftId = pool.getNftId();
        pool.approveTokenHandler(type(uint256).max);
        vm.stopPrank();

        // solhint-disable
        console.log("pool nft id", poolNftId.toInt());
        console.log("pool component at", address(pool));
        // solhint-enable
    }

}