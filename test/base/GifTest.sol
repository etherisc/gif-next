// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Test, console} from "../../lib/forge-std/src/Test.sol";

import {AmountLib} from "../../contracts/type/Amount.sol";
import {VersionPart, VersionPartLib} from "../../contracts/type/Version.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {SecondsLib} from "../../contracts/type/Seconds.sol";
import {ObjectTypeLib, REGISTRY, TOKEN, SERVICE, INSTANCE, POOL, ORACLE, PRODUCT, DISTRIBUTION, BUNDLE, POLICY} from "../../contracts/type/ObjectType.sol";
import {Fee, FeeLib} from "../../contracts/type/Fee.sol";
import {
    GIF_MANAGER_ROLE,
    GIF_ADMIN_ROLE,
    ADMIN_ROLE,
    INSTANCE_OWNER_ROLE,
    PRODUCT_OWNER_ROLE, 
    ORACLE_OWNER_ROLE, 
    POOL_OWNER_ROLE, 
    DISTRIBUTION_OWNER_ROLE} from "../../contracts/type/RoleId.sol";
import {UFixed, UFixedLib} from "../../contracts/type/UFixed.sol";
import {Version} from "../../contracts/type/Version.sol";
import {RoleId} from "../../contracts/type/RoleId.sol";
import {StateId, INITIAL, SCHEDULED, DEPLOYING, ACTIVE} from "../../contracts/type/StateId.sol";

import {IAccessAdmin} from "../../contracts/shared/IAccessAdmin.sol";
import {IKeyValueStore} from "../../contracts/shared/IKeyValueStore.sol";
import {IService} from "../../contracts/shared/IService.sol";
import {IVersionable} from "../../contracts/shared/IVersionable.sol";
import {ProxyManager} from "../../contracts/shared/ProxyManager.sol";
import {TokenHandler} from "../../contracts/shared/TokenHandler.sol";
import {AccessManagerExtendedInitializeable} from "../../contracts/shared/AccessManagerExtendedInitializeable.sol";
import {AccessManagerExtendedWithDisableInitializeable} from "../../contracts/shared/AccessManagerExtendedWithDisableInitializeable.sol";
import {UpgradableProxyWithAdmin} from "../../contracts/shared/UpgradableProxyWithAdmin.sol";

import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {IRegistryService} from "../../contracts/registry/RegistryService.sol";
import {IServiceAuthorization} from "../../contracts/registry/IServiceAuthorization.sol";
import {RegistryServiceManager} from "../../contracts/registry/RegistryServiceManager.sol";
import {RegistryAdmin} from "../../contracts/registry/RegistryAdmin.sol";
import {ReleaseManager} from "../../contracts/registry/ReleaseManager.sol";
import {ServiceAuthorizationV3} from "../../contracts/registry/ServiceAuthorizationV3.sol";
import {ChainNft} from "../../contracts/registry/ChainNft.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {TokenRegistry} from "../../contracts/registry/TokenRegistry.sol";

import {IComponents} from "../../contracts/instance/module/IComponents.sol";
import {ComponentService} from "../../contracts/shared/ComponentService.sol";
import {ComponentServiceManager} from "../../contracts/shared/ComponentServiceManager.sol";
import {DistributionService} from "../../contracts/distribution/DistributionService.sol";
import {DistributionServiceManager} from "../../contracts/distribution/DistributionServiceManager.sol";
import {OracleService} from "../../contracts/oracle/OracleService.sol";
import {OracleServiceManager} from "../../contracts/oracle/OracleServiceManager.sol";
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

import {Staking} from "../../contracts/staking/Staking.sol";
import {StakingReader} from "../../contracts/staking/StakingReader.sol";
import {StakingManager} from "../../contracts/staking/StakingManager.sol";

import {InstanceAdmin} from "../../contracts/instance/InstanceAdmin.sol";
import {Instance} from "../../contracts/instance/Instance.sol";
import {InstanceReader} from "../../contracts/instance/InstanceReader.sol";
import {BundleManager} from "../../contracts/instance/BundleManager.sol";
import {InstanceStore} from "../../contracts/instance/InstanceStore.sol";

import {Dip} from "../../contracts/mock/Dip.sol";
import {Distribution} from "../../contracts/distribution/Distribution.sol";
import {Product} from "../../contracts/product/Product.sol";
import {Pool} from "../../contracts/pool/Pool.sol";
import {Usdc} from "../mock/Usdc.sol";
import {SimpleDistribution} from "../mock/SimpleDistribution.sol";
import {SimpleOracle} from "../mock/SimpleOracle.sol";
import {SimplePool} from "../mock/SimplePool.sol";
import {SimpleProduct} from "../mock/SimpleProduct.sol";

import {GifDeployer} from "./GifDeployer.sol";
import {GifTestReleaseConfig} from "./GifTestReleaseConfig.sol";

// solhint-disable-next-line max-states-count
contract GifTest is GifDeployer {

    // default customer token balance in full token units, value will be multiplied by 10 ** token.decimals()
    uint256 DEFAULT_CUSTOMER_FUNDS = 1000;

    // in full token units, value will be multiplied by 10 ** token.decimals()
    uint256 constant public DEFAULT_BUNDLE_CAPITALIZATION = 10 ** 5;

    // bundle lifetime is one year in seconds
    uint256 constant public DEFAULT_BUNDLE_LIFETIME = 365 * 24 * 3600;

    IERC20Metadata public dip;
    IERC20Metadata public token;

    RegistryAdmin registryAdmin;
    Registry public registry;
    ChainNft public chainNft;
    ReleaseManager public releaseManager;
    TokenRegistry public tokenRegistry;

    StakingManager public stakingManager;
    Staking public staking;
    StakingReader public stakingReader;
    NftId public stakingNftId;

    // RegistryServiceManager public registryServiceManager;
    // RegistryService public registryService;
    // NftId public registryServiceNftId;

    // StakingServiceManager public stakingServiceManager;
    // StakingService public stakingService;
    // NftId public stakingServiceNftId;

    // InstanceServiceManager public instanceServiceManager;
    // InstanceService public instanceService;
    // NftId public instanceServiceNftId;

    // ComponentServiceManager public componentServiceManager;
    // ComponentService public componentService;
    // NftId public componentServiceNftId;

    // DistributionServiceManager public distributionServiceManager;
    // DistributionService public distributionService;
    // NftId public distributionServiceNftId;

    // OracleServiceManager public oracleServiceManager;
    // OracleService public oracleService;
    // NftId public oracleServiceNftId;

    // ProductServiceManager public productServiceManager;
    // ProductService public productService;
    // NftId public productServiceNftId;

    // PoolServiceManager public poolServiceManager;
    // PoolService public poolService;
    // NftId public poolServiceNftId;

    // ApplicationServiceManager public applicationServiceManager;
    // ApplicationService public applicationService;
    // NftId public applicationServiceNftId;

    // PolicyServiceManager public policyServiceManager;
    // PolicyService public policyService;
    // NftId public policyServiceNftId;

    // ClaimServiceManager public claimServiceManager;
    // ClaimService public claimService;
    // NftId public claimServiceNftId;

    // PricingService public pricingService;
    // PricingServiceManager public pricingServiceManager;
    // NftId public pricingServiceNftId;

    // BundleServiceManager public bundleServiceManager;
    // BundleService public bundleService;
    // NftId public bundleServiceNftId;

    AccessManagerExtendedInitializeable public masterInstanceAccessManager;
    InstanceAdmin public masterInstanceAdmin;
    BundleManager public masterBundleManager;
    InstanceStore public masterInstanceStore;
    Instance public masterInstance;
    NftId public masterInstanceNftId;
    InstanceReader public masterInstanceReader;

    AccessManagerExtendedInitializeable public instanceAccessManager;
    InstanceAdmin public instanceAdmin;
    BundleManager public instanceBundleManager;
    InstanceStore public instanceStore;
    Instance public instance;
    NftId public instanceNftId;
    InstanceReader public instanceReader;

    SimpleDistribution public distribution;
    NftId public distributionNftId;
    SimpleOracle public oracle;
    NftId public oracleNftId;
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
    address public oracleOwner = makeAddr("oracleOwner");
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

        address gifAdmin = registryOwner;
        address gifManager = registryOwner;

        // deploy registry, services, master instance and token
        _deployCore(gifAdmin, gifManager);
        _deployAndRegisterServices(gifAdmin, gifManager);

        vm.startPrank(registryOwner);
        _deployMasterInstance();
        vm.stopPrank();

        vm.startPrank(address(registryOwner)); 
        _deployRegisterAndActivateToken();
        vm.stopPrank();

        // TODO move to end of this function once instance reg is fixed
        // print full authz setup
        _printAuthz();

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

    function _deployCore(
        address gifAdmin,
        address gifManager
    )
        internal
    {
        (
            dip,
            registry,
            tokenRegistry,
            releaseManager,
            registryAdmin,
            stakingManager,
            staking
        ) = deployCore(
            gifAdmin,
            gifManager,
            stakingOwner);

        // obtain some references
        registryAddress = address(registry);
        chainNft = ChainNft(registry.getChainNftAddress());
        registryNftId = registry.getNftId(registryAddress);
        stakingNftId = registry.getNftId(address(staking));
        stakingReader = staking.getStakingReader();

        // solhint-disable
        console.log("registry deployed at", address(registry));
        console.log("registry owner", registryOwner);

        console.log("token registry deployed at", address(tokenRegistry));
        console.log("release manager deployed at", address(releaseManager));

        console.log("registry access manager deployed:", address(registryAdmin));
        console.log("registry access manager authority", registryAdmin.authority());

        console.log("staking manager deployed at", address(stakingManager));

        console.log("staking nft id", registry.getNftId(address(staking)).toInt());
        console.log("staking deployed at", address(staking));
        console.log("staking owner (opt 1)", registry.ownerOf(address(staking)));
        console.log("staking owner (opt 2)", staking.getOwner());
        // solhint-enable
    }


    function _deployAndRegisterServices(
        address gifAdmin,
        address gifManager
    )
        internal 
    {
        IServiceAuthorization serviceAuthorization = new ServiceAuthorizationV3("85b428cbb5185aee615d101c2554b0a58fb64810");

        deployRelease(
            releaseManager, 
            serviceAuthorization, 
            gifAdmin, 
            gifManager);

        assertEq(releaseManager.getState().toInt(), ACTIVE().toInt(), "unexpected state for releaseManager after activateNextRelease");
    }

    function _deployMasterInstance() internal 
    {
        masterInstanceAccessManager = new AccessManagerExtendedInitializeable();
        // grants registryOwner ADMIN_ROLE
        masterInstanceAccessManager.initialize(registryOwner);
        
        masterInstance = new Instance();
        masterInstance.initialize(
            address(masterInstanceAccessManager),
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

        masterInstanceAdmin = new InstanceAdmin();
        masterInstanceAccessManager.grantRole(ADMIN_ROLE().toInt(), address(masterInstanceAdmin), 0);
        masterInstanceAdmin.initialize(address(masterInstance));
        masterInstance.setInstanceAdmin(masterInstanceAdmin);

        // sets master instance address in instance service
        // instance service is now ready to create cloned instances
        masterInstanceNftId = instanceService.setAndRegisterMasterInstance(address(masterInstance));

        // lock master instance nft
        chainNft.transferFrom(registryOwner, NFT_LOCK_ADDRESS, masterInstanceNftId.toInt());

        // revoke ADMIN_ROLE from all members
        masterInstanceAccessManager.revokeRole(ADMIN_ROLE().toInt(), address(masterInstanceAdmin));
        masterInstanceAccessManager.renounceRole(ADMIN_ROLE().toInt(), registryOwner);

        // solhint-disable
        console.log("master instance deployed at", address(masterInstance));
        console.log("master instance nft id", masterInstanceNftId.toInt());
        console.log("master oz access manager deployed at", address(masterInstanceAccessManager));
        console.log("master instance access manager deployed at", address(masterInstanceAdmin));
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

        instanceAdmin = instance.getInstanceAdmin();
        instanceAccessManager = AccessManagerExtendedInitializeable(instance.authority());
        instanceReader = instance.getInstanceReader();
        instanceStore = instance.getInstanceStore();
        instanceBundleManager = instance.getBundleManager();
        instanceStore = instance.getInstanceStore();
        
        // solhint-disable
        console.log("cloned instance deployed at", address(instance));
        console.log("cloned instance nft id", instanceNftId.toInt());
        console.log("cloned oz access manager deployed at", address(instanceAccessManager));
        console.log("cloned instance access manager deployed at", address(instanceAdmin));
        console.log("cloned instance reader deployed at", address(instanceReader));
        console.log("cloned bundle manager deployed at", address(instanceBundleManager));
        console.log("cloned instance store deployed at", address(instanceStore));
        // solhint-enable
    }

    function _deployRegisterAndActivateToken() internal {
        // dip
        tokenRegistry.setActiveForVersion(
            block.chainid, 
            address(dip), 
            registry.getLatestVersion(), true);

        // usdc
        token = new Usdc();
        tokenRegistry.registerToken(address(token));
        tokenRegistry.setActiveForVersion(
            block.chainid, 
            address(token), 
            registry.getLatestVersion(), true);

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
        instanceAccessManager.grantRole(PRODUCT_OWNER_ROLE().toInt(), productOwner, 0);
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

        // grant component owner roles
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(ORACLE_OWNER_ROLE().toInt(), oracleOwner, 0);
        instanceAccessManager.grantRole(DISTRIBUTION_OWNER_ROLE().toInt(), distributionOwner, 0);
        instanceAccessManager.grantRole(POOL_OWNER_ROLE().toInt(), poolOwner, 0);
        vm.stopPrank();

        // deploy and register distribution
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

        // deploy and register pool
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
        pool.approveTokenHandler(AmountLib.max());
        vm.stopPrank();

        // solhint-disable
        console.log("pool nft id", poolNftId.toInt());
        console.log("pool component at", address(pool));
        // solhint-enable

        // deploy and register oracle
        vm.startPrank(oracleOwner);
        oracle = new SimpleOracle(
            address(registry),
            instanceNftId,
            oracleOwner,
            address(token));

        oracle.register();
        oracleNftId = oracle.getNftId();
        vm.stopPrank();

        // solhint-disable
        console.log("oracle nft id", oracleNftId.toInt());
        console.log("oracle component at", address(oracle));
        // solhint-enable
    }


    function _preparePool() internal {
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(POOL_OWNER_ROLE().toInt(), poolOwner, 0);
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
        pool.approveTokenHandler(AmountLib.max());
        vm.stopPrank();

        // solhint-disable
        console.log("pool nft id", poolNftId.toInt());
        console.log("pool component at", address(pool));
        // solhint-enable
    }


    function _printAuthz() internal {
        console.log("registry admin deployed:", address(registryAdmin));
        console.log("registry admin authority", registryAdmin.authority());

        uint256 roles = registryAdmin.roles();
        uint256 targets = registryAdmin.targets();

        console.log("==========================================");
        console.log("roles", registryAdmin.roles());
        // solhint-enable

        for(uint256 i = 0; i < registryAdmin.roles(); i++) {
            _printRoleMembers(registryAdmin, registryAdmin.getRoleId(i));
        }

        // solhint-disable no-console
        console.log("==========================================");
        console.log("targets", registryAdmin.targets());
        // solhint-enable

        for(uint256 i = 0; i < registryAdmin.targets(); i++) {
            _printTarget(registryAdmin, registryAdmin.getTargetAddress(i));
        }
    }


    function _printRoleMembers(IAccessAdmin aa, RoleId roleId) internal {
        IAccessAdmin.RoleInfo memory info = aa.getRoleInfo(roleId);
        uint256 members = aa.roleMembers(roleId);

        // solhint-disable no-console
        console.log("role", info.name.toString(), "id", roleId.toInt()); 

        if (members > 0) {
            for(uint i = 0; i < members; i++) {
                address memberAddress = aa.getRoleMember(roleId, i);
                string memory targetName = "(not target)";
                if (aa.targetExists(memberAddress)) {
                    targetName = aa.getTargetInfo(memberAddress).name.toString();
                }

                console.log("-", i, aa.getRoleMember(roleId, i), targetName);
            }
        } else {
            console.log("- no role members");
        }

        console.log("");
        // solhint-enable
    }

    function _printTarget(IAccessAdmin aa, address target) internal view {
        IAccessAdmin.TargetInfo memory info = aa.getTargetInfo(target);

        // solhint-disable no-console
        uint256 functions = aa.authorizedFunctions(target);
        console.log("target", info.name.toString(), "address", target);

        if (functions > 0) {
            for(uint256 i = 0; i < functions; i++) {
                (
                    IAccessAdmin.Function memory func,
                    RoleId roleId
                ) = aa.getAuthorizedFunction(target, i);
                string memory role = aa.getRoleInfo(roleId).name.toString();

                console.log("-", i, string(abi.encodePacked(func.name.toString(), "(): role ", role,":")), roleId.toInt());
            }
        } else {
            console.log("- no authorized functions");
        }

        console.log("");
        // solhint-enable
    }


    function zeroObjectInfo() internal pure returns (IRegistry.ObjectInfo memory) {
        return (
            IRegistry.ObjectInfo(
                NftIdLib.zero(),
                NftIdLib.zero(),
                ObjectTypeLib.zero(),
                false,
                address(0),
                address(0),
                bytes("")
            )
        );
    }
}