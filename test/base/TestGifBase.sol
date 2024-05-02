// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Test, console} from "../../lib/forge-std/src/Test.sol";

import {VersionPart, VersionPartLib} from "../../contracts/type/Version.sol";
import {NftId, NftIdLib, zeroNftId} from "../../contracts/type/NftId.sol";
import {REGISTRY, TOKEN, SERVICE, INSTANCE, POOL, ORACLE, PRODUCT, DISTRIBUTION, BUNDLE, POLICY} from "../../contracts/type/ObjectType.sol";
import {Fee, FeeLib} from "../../contracts/type/Fee.sol";
import {
    ADMIN_ROLE,
    INSTANCE_OWNER_ROLE,
    PRODUCT_OWNER_ROLE, 
    POOL_OWNER_ROLE, 
    DISTRIBUTION_OWNER_ROLE} from "../../contracts/type/RoleId.sol";
import {UFixed, UFixedLib} from "../../contracts/type/UFixed.sol";
import {Version} from "../../contracts/type/Version.sol";
import {RoleId} from "../../contracts/type/RoleId.sol";
import {zeroObjectType} from "../../contracts/type/ObjectType.sol";

import {IVersionable} from "../../contracts/shared/IVersionable.sol";
import {ProxyManager} from "../../contracts/shared/ProxyManager.sol";
import {TokenHandler} from "../../contracts/shared/TokenHandler.sol";
import {AccessManagerUpgradeableInitializeable} from "../../contracts/shared/AccessManagerUpgradeableInitializeable.sol";
import {UpgradableProxyWithAdmin} from "../../contracts/shared/UpgradableProxyWithAdmin.sol";

import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {IRegistryService} from "../../contracts/registry/RegistryService.sol";
import {RegistryServiceManager} from "../../contracts/registry/RegistryServiceManager.sol";
import {RegistryAccessManager} from "../../contracts/registry/RegistryAccessManager.sol";
import {ReleaseManager} from "../../contracts/registry/ReleaseManager.sol";
import {ChainNft} from "../../contracts/registry/ChainNft.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {TokenRegistry} from "../../contracts/registry/TokenRegistry.sol";

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
import {StakingService} from "../../contracts/staking/StakingService.sol";
import {StakingServiceManager} from "../../contracts/staking/StakingServiceManager.sol";

import {InstanceService} from "../../contracts/instance/InstanceService.sol";
import {InstanceServiceManager} from "../../contracts/instance/InstanceServiceManager.sol";

import {InstanceAccessManager} from "../../contracts/instance/InstanceAccessManager.sol";
import {Instance} from "../../contracts/instance/Instance.sol";
import {InstanceReader} from "../../contracts/instance/InstanceReader.sol";
import {BundleManager} from "../../contracts/instance/BundleManager.sol";
import {IKeyValueStore} from "../../contracts/instance/base/IKeyValueStore.sol";
import {InstanceStore} from "../../contracts/instance/InstanceStore.sol";

import {Distribution} from "../../contracts/distribution/Distribution.sol";
import {Product} from "../../contracts/product/Product.sol";
import {Pool} from "../../contracts/pool/Pool.sol";
import {Usdc} from "../mock/Usdc.sol";
import {SimpleDistribution} from "../mock/SimpleDistribution.sol";
import {SimplePool} from "../mock/SimplePool.sol";

import {ReleaseConfig} from "./ReleaseConfig.sol";


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
    StakingService public stakingService;
    NftId public stakingServiceNftId;
    StakingServiceManager public stakingServiceManager;

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

    address constant public NFT_LOCK_ADDRESS = address(0x1);
    address public registryOwner = makeAddr("registryOwner");
    address public instanceOwner = makeAddr("instanceOwner");
    address public productOwner = makeAddr("productOwner");
    address public poolOwner = makeAddr("poolOwner");
    address public distributionOwner = makeAddr("distributionOwner");
    address public customer = makeAddr("customer");
    address public customer2 = makeAddr("customer2");
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

        // deploy registry, services, master instance and token
        vm.startPrank(registryOwner);
        _deployRegistry();
        _deployAndRegisterServices();
        vm.stopPrank();

        vm.startPrank(registryOwner);
        _deployMasterInstance();
        vm.stopPrank();

        vm.startPrank(address(registryOwner)); 
        _deployAndActivateToken();
        vm.stopPrank();

        // create an instance (cloned from master instance)
        vm.startPrank(instanceOwner);
        _createInstance();
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

    function _deployRegistry() internal
    {
        registryAccessManager = new RegistryAccessManager();

        releaseManager = new ReleaseManager(
            registryAccessManager,
            VersionPartLib.toVersionPart(3));

        registryAddress = address(releaseManager.getRegistry());
        registry = Registry(registryAddress);
        registryNftId = registry.getNftId(address(registry)); 

        address chainNftAddress = registry.getChainNftAddress();
        chainNft = ChainNft(chainNftAddress);

        // solhint-disable
        tokenRegistry = new TokenRegistry(registryAddress);

        registryAccessManager.initialize(registryOwner, registryOwner, address(releaseManager), address(tokenRegistry));

        /* solhint-disable */
        console.log("protocol nft id", chainNft.PROTOCOL_NFT_ID());
        console.log("global registry nft id", chainNft.GLOBAL_REGISTRY_ID());
        console.log("registry nft id", registry.getNftId(address(registry)).toInt());

        console.log("registry deployed at", address(registry));
        console.log("registry owner (opt 1)", registry.ownerOf(address(registry)));
        console.log("registry owner (opt 2)", registry.getOwner());

        console.log("registry access manager deployed at", address(registryAccessManager));
        console.log("registry access manager authority", registryAccessManager.authority());

        console.log("release manager deployed at", address(releaseManager));
        console.log("release manager authority", releaseManager.authority());

        console.log("token registry deployed at", address(tokenRegistry));
        console.log("token registry linked to nft", tokenRegistry.getNftId().toInt());
        console.log("token registry linked owner", tokenRegistry.getOwner());
        /* solhint-enable */
    }

    function _deployAndRegisterServices() internal 
    {
        bytes32 salt = "0x1234";
        VersionPart version = VersionPartLib.toVersionPart(3);

        ReleaseConfig config = new ReleaseConfig(
            releaseManager,
            registryOwner,
            version,
            salt);

        (
            address[] memory serviceAddrs,
            RoleId[][] memory serviceRoles,
            RoleId[][] memory functionRoles,
            bytes4[][][] memory selectors
        ) = config.getConfig();

        releaseManager.createNextRelease();

        (
            address releaseAccessManager, 
            VersionPart releaseVersion,
            bytes32 releaseSalt
        ) = releaseManager.prepareNextRelease(serviceAddrs, serviceRoles, functionRoles, selectors, salt);

        salt = releaseSalt;

        // solhint-disable
        console.log("release version", releaseVersion.toInt());
        console.log("release salt", uint(releaseSalt));
        console.log("release access manager deployed at", address(releaseAccessManager));
        console.log("release services count", serviceAddrs.length);
        // solhint-enable

        // --- registry service ---------------------------------//
        registryServiceManager = new RegistryServiceManager{salt: salt}(releaseAccessManager, registryAddress, salt);
        registryService = registryServiceManager.getRegistryService();
        releaseManager.registerService(registryService); 

        // solhint-disable
        console.log("registry service proxy manager deployed at", address(registryServiceManager));
        console.log("registry service proxy manager linked to nft id", registryServiceManager.getNftId().toInt());
        console.log("registry service proxy manager owner", registryServiceManager.getOwner());
        console.log("registry service deployed at", address(registryService));
        console.log("registry service nft id", registryService.getNftId().toInt());
        console.log("registry service domain", registryService.getDomain().toInt());
        console.log("registry service owner", registryService.getOwner());
        console.log("registry service authority", registryService.authority());
        // solhint-enable

        // --- instance service ---------------------------------//
        instanceServiceManager = new InstanceServiceManager{salt: salt}(releaseAccessManager, registryAddress, salt);
        instanceService = instanceServiceManager.getInstanceService();
        instanceServiceNftId = releaseManager.registerService(instanceService);

        // solhint-disable 
        console.log("instance service proxy manager deployed at", address(instanceServiceManager));
        console.log("instance service proxy manager linked to nft id", instanceServiceManager.getNftId().toInt());
        console.log("instance service proxy manager owner", instanceServiceManager.getOwner());
        console.log("instance service deployed at", address(instanceService));
        console.log("instance service nft id", instanceService.getNftId().toInt());
        console.log("instance service domain", instanceService.getDomain().toInt());
        console.log("instance service owner", instanceService.getOwner());
        console.log("instance service authority", instanceService.authority());
        // solhint-enable

        // --- distribution service ---------------------------------//
        distributionServiceManager = new DistributionServiceManager{salt: salt}(releaseAccessManager, registryAddress, salt);
        distributionService = distributionServiceManager.getDistributionService();
        distributionServiceNftId = releaseManager.registerService(distributionService);

        // solhint-disable
        console.log("distribution service proxy manager deployed at", address(distributionServiceManager));
        console.log("distribution service proxy manager linked to nft id", distributionServiceManager.getNftId().toInt());
        console.log("distribution service proxy manager owner", distributionServiceManager.getOwner());
        console.log("distribution service deployed at", address(distributionService));
        console.log("distribution service nft id", distributionService.getNftId().toInt());
        console.log("distribution service domain", distributionService.getDomain().toInt());
        console.log("distribution service owner", distributionService.getOwner());
        console.log("distribution service authority", distributionService.authority());
        // solhint-enable

        // --- pricing service ---------------------------------//
        pricingServiceManager = new PricingServiceManager{salt: salt}(releaseAccessManager, registryAddress, salt);
        pricingService = pricingServiceManager.getPricingService();
        pricingServiceNftId = releaseManager.registerService(pricingService);

        // solhint-disable
        console.log("pricing service proxy manager deployed at", address(pricingServiceManager));
        console.log("pricing service proxy manager linked to nft id", pricingServiceManager.getNftId().toInt());
        console.log("pricing service proxy manager owner", pricingServiceManager.getOwner());
        console.log("pricing service deployed at", address(pricingService));
        console.log("pricing service nft id", pricingService.getNftId().toInt());
        console.log("pricing service domain", pricingService.getDomain().toInt());
        console.log("pricing service owner", pricingService.getOwner());
        console.log("pricing service authority", pricingService.authority());
        // solhint-enable

        // --- bundle service ---------------------------------//
        bundleServiceManager = new BundleServiceManager{salt: salt}(releaseAccessManager, registryAddress, salt);
        bundleService = bundleServiceManager.getBundleService();
        bundleServiceNftId = releaseManager.registerService(bundleService);

        // solhint-disable
        console.log("bundle service proxy manager deployed at", address(bundleServiceManager));
        console.log("bundle service proxy manager linked to nft id", bundleServiceManager.getNftId().toInt());
        console.log("bundle service proxy manager owner", bundleServiceManager.getOwner());
        console.log("bundle service deployed at", address(bundleService));
        console.log("bundle service nft id", bundleService.getNftId().toInt());
        console.log("bundle service domain", bundleService.getDomain().toInt());
        console.log("bundle service owner", bundleService.getOwner());
        console.log("bundle service authority", bundleService.authority());
        // solhint-enable

        // --- pool service ---------------------------------//
        poolServiceManager = new PoolServiceManager{salt: salt}(releaseAccessManager, registryAddress, salt);
        poolService = poolServiceManager.getPoolService();
        poolServiceNftId = releaseManager.registerService(poolService);

        // solhint-disable
        console.log("pool service proxy manager deployed at", address(poolServiceManager));
        console.log("pool service proxy manager linked to nft id", poolServiceManager.getNftId().toInt());
        console.log("pool service proxy manager owner", poolServiceManager.getOwner());
        console.log("pool service deployed at", address(poolService));
        console.log("pool service nft id", poolService.getNftId().toInt());
        console.log("pool service domain", poolService.getDomain().toInt());
        console.log("pool service owner", poolService.getOwner());
        console.log("pool service authority", poolService.authority());
        // solhint-enable

        // --- product service ---------------------------------//
        productServiceManager = new ProductServiceManager{salt: salt}(releaseAccessManager, registryAddress, salt);
        productService = productServiceManager.getProductService();
        productServiceNftId = releaseManager.registerService(productService);

        // solhint-disable
        console.log("product service proxy manager deployed at", address(productServiceManager));
        console.log("product service proxy manager linked to nft id", productServiceManager.getNftId().toInt());
        console.log("product service proxy manager owner", productServiceManager.getOwner());
        console.log("product service deployed at", address(productService));
        console.log("product service nft id", productService.getNftId().toInt());
        console.log("product service domain", productService.getDomain().toInt());
        console.log("product service owner", productService.getOwner());
        console.log("product service authority", productService.authority());
        // solhint-enable

        // MUST follow bundle service registration 
        // --- claim service ---------------------------------//
        claimServiceManager = new ClaimServiceManager{salt: salt}(releaseAccessManager, registryAddress, salt);
        claimService = claimServiceManager.getClaimService();
        claimServiceNftId = releaseManager.registerService(claimService);

        // solhint-disable
        console.log("claim service proxy manager deployed at", address(claimServiceManager));
        console.log("claim service proxy manager linked to nft id", claimServiceManager.getNftId().toInt());
        console.log("claim service proxy manager owner", claimServiceManager.getOwner());
        console.log("claim service deployed at", address(claimService));
        console.log("claim service nft id", claimService.getNftId().toInt());
        console.log("claim service domain", claimService.getDomain().toInt());
        console.log("claim service owner", claimService.getOwner());
        console.log("claim service authority", claimService.authority());
        // solhint-enable

        // --- application service ---------------------------------//
        applicationServiceManager = new ApplicationServiceManager{salt: salt}(releaseAccessManager, registryAddress, salt);
        applicationService = applicationServiceManager.getApplicationService();
        applicationServiceNftId = releaseManager.registerService(applicationService);

        // solhint-disable
        console.log("application service proxy manager deployed at", address(applicationServiceManager));
        console.log("application service proxy manager linked to nft id", applicationServiceManager.getNftId().toInt());
        console.log("application service proxy manager owner", applicationServiceManager.getOwner());
        console.log("application service deployed at", address(applicationService));
        console.log("application service nft id", applicationService.getNftId().toInt());
        console.log("application service domain", applicationService.getDomain().toInt());
        console.log("application service owner", applicationService.getOwner());
        console.log("application service authority", applicationService.authority());
        // solhint-enable

        // --- policy service ---------------------------------//
        policyServiceManager = new PolicyServiceManager{salt: salt}(releaseAccessManager, registryAddress, salt);
        policyService = policyServiceManager.getPolicyService();
        policyServiceNftId = releaseManager.registerService(policyService);

        // solhint-disable
        console.log("policy service proxy manager deployed at", address(policyServiceManager));
        console.log("policy service proxy manager linked to nft id", policyServiceManager.getNftId().toInt());
        console.log("policy service proxy manager owner", policyServiceManager.getOwner());
        console.log("policy service deployed at", address(policyService));
        console.log("policy service nft id", policyService.getNftId().toInt());
        console.log("policy service domain", policyService.getDomain().toInt());
        console.log("policy service owner", policyService.getOwner());
        console.log("policy service authority", policyService.authority());
        // solhint-enable

        // --- stacking service ---------------------------------//
        stakingServiceManager = new StakingServiceManager{salt: salt}(releaseAccessManager, registryAddress, salt);
        stakingService = stakingServiceManager.getStakingService();
        stakingServiceNftId = releaseManager.registerService(stakingService); 

        // solhint-disable
        console.log("stacking service proxy manager deployed at", address(stakingServiceManager));
        console.log("stacking service proxy manager linked to nft id", stakingServiceManager.getNftId().toInt());
        console.log("stacking service proxy manager owner", stakingServiceManager.getOwner());
        console.log("stacking service deployed at", address(stakingService));
        console.log("stacking service nft id", stakingService.getNftId().toInt());
        console.log("stacking service domain", stakingService.getDomain().toInt());
        console.log("stacking service owner", stakingService.getOwner());
        console.log("stacking service authority", stakingService.authority());
        // solhint-enable

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
        instanceBundleManager = instance.getBundleManager();
        instanceStore = instance.getInstanceStore();
        
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

    function _deployAndActivateToken() internal {
        Usdc Usdc  = new Usdc();
        address UsdcAddress = address(Usdc);
        token = Usdc;

        // solhint-disable-next-line
        console.log("token deployed at", UsdcAddress);

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
            FeeLib.zeroFee(),
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
            UFixedLib.toUFixed(1),
            poolOwner
        );

        poolNftId = poolService.register(address(pool));
        pool.approveTokenHandler(type(uint256).max);
        vm.stopPrank();
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

        poolNftId = poolService.register(address(pool));
        vm.stopPrank();
    }

    function zeroObjectInfo() internal pure returns (IRegistry.ObjectInfo memory) {
        return (
            IRegistry.ObjectInfo(
                zeroNftId(),
                zeroNftId(),
                zeroObjectType(),
                false,
                address(0),
                address(0),
                bytes("")
            )
        );
    }

    function eqObjectInfo(IRegistry.ObjectInfo memory a, IRegistry.ObjectInfo memory b) internal returns (bool isSame) {

        assertEq(a.nftId.toInt(), b.nftId.toInt(), "getObjectInfo(address).nftId returned unexpected value");
        assertEq(a.parentNftId.toInt(), b.parentNftId.toInt(), "getObjectInfo(address).parentNftId returned unexpected value");
        assertEq(a.objectType.toInt(), b.objectType.toInt(), "getObjectInfo(address).objectType returned unexpected value");
        assertEq(a.objectAddress, b.objectAddress, "getObjectInfo(address).objectAddress returned unexpected value");
        assertEq(a.initialOwner, b.initialOwner, "getObjectInfo(address).initialOwner returned unexpected value");
        assertEq(a.data.length, b.data.length, "getObjectInfo(address).data.length returned unexpected value");
        assertEq(keccak256(a.data), keccak256(b.data), "getObjectInfo(address).data returned unexpected value");
        return (
            (a.nftId == b.nftId) &&
            (a.parentNftId == b.parentNftId) &&
            (a.objectType == b.objectType) &&
            (a.objectAddress == b.objectAddress) &&
            (a.initialOwner == b.initialOwner) &&
            (a.data.length == b.data.length) &&
            keccak256(a.data) == keccak256(b.data)
        );
    }

    function toBool(uint256 uintVal) internal pure returns (bool boolVal)
    {
        assembly {
            boolVal := uintVal
        }
    }

}