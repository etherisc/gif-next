// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";

import {IAccess} from "../../contracts/authorization/IAccess.sol";
import {IAccessAdmin} from "../../contracts/authorization/IAccessAdmin.sol";
import {IServiceAuthorization} from "../../contracts/authorization/IServiceAuthorization.sol";

import {Amount, AmountLib} from "../../contracts/type/Amount.sol";
import {ChainId, ChainIdLib} from "../../contracts/type/ChainId.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {SecondsLib} from "../../contracts/type/Seconds.sol";
import {Fee, FeeLib} from "../../contracts/type/Fee.sol";
import {UFixed, UFixedLib} from "../../contracts/type/UFixed.sol";
import {RoleId} from "../../contracts/type/RoleId.sol";
import {ACTIVE} from "../../contracts/type/StateId.sol";
import {Timestamp} from "../../contracts/type/Timestamp.sol";
import {VersionPart, VersionPartLib} from "../../contracts/type/Version.sol";

import {BasicOracleAuthorization} from "../../contracts/oracle/BasicOracleAuthorization.sol";
import {BasicProductAuthorization} from "../../contracts/product/BasicProductAuthorization.sol";
import {SimpleDistributionAuthorization} from "../../contracts/examples/unpermissioned/SimpleDistributionAuthorization.sol";
import {SimplePoolAuthorization} from "../../contracts/examples/unpermissioned/SimplePoolAuthorization.sol";
import {RegistryAdmin} from "../../contracts/registry/RegistryAdmin.sol";
import {ReleaseRegistry} from "../../contracts/registry/ReleaseRegistry.sol";
import {ServiceAuthorizationV3} from "../../contracts/registry/ServiceAuthorizationV3.sol";
import {ChainNft} from "../../contracts/registry/ChainNft.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {TokenRegistry} from "../../contracts/registry/TokenRegistry.sol";

import {IComponents} from "../../contracts/instance/module/IComponents.sol";
import {IProductComponent} from "../../contracts/product/IProductComponent.sol";

import {Staking} from "../../contracts/staking/Staking.sol";
import {StakingReader} from "../../contracts/staking/StakingReader.sol";
import {StakingManager} from "../../contracts/staking/StakingManager.sol";

import {AccessManagerCloneable} from "../../contracts/authorization/AccessManagerCloneable.sol";
import {IInstance} from "../../contracts/instance/IInstance.sol";
import {InstanceAdmin} from "../../contracts/instance/InstanceAdmin.sol";
import {InstanceAuthorizationV3} from "../../contracts/instance/InstanceAuthorizationV3.sol";
import {Instance} from "../../contracts/instance/Instance.sol";
import {InstanceReader} from "../../contracts/instance/InstanceReader.sol";
import {BundleSet} from "../../contracts/instance/BundleSet.sol";
import {RiskSet} from "../../contracts/instance/RiskSet.sol";
import {InstanceStore} from "../../contracts/instance/InstanceStore.sol";
import {ProductStore} from "../../contracts/instance/ProductStore.sol";

import {Usdc} from "../mock/Usdc.sol";
import {SimpleDistribution} from "../../contracts/examples/unpermissioned/SimpleDistribution.sol";
import {SimpleOracle} from "../../contracts/examples/unpermissioned/SimpleOracle.sol";
import {SimplePool} from "../../contracts/examples/unpermissioned/SimplePool.sol";
import {SimpleProduct} from "../../contracts/examples/unpermissioned/SimpleProduct.sol";

import {GifDeployer} from "./GifDeployer.sol";


// solhint-disable-next-line max-states-count
contract GifTest is GifDeployer {

    // default customer token balance in full token units, value will be multiplied by 10 ** token.decimals()
    uint256 constant public DEFAULT_CUSTOMER_FUNDS = 1000;

    // in full token units, value will be multiplied by 10 ** token.decimals()
    uint256 constant public DEFAULT_BUNDLE_CAPITALIZATION = 10 ** 5;

    // bundle lifetime is one year in seconds
    uint256 constant public DEFAULT_BUNDLE_LIFETIME = 365 * 24 * 3600;

    ChainId public currentChainId;
    IERC20Metadata public token;

    AccessManagerCloneable public masterAccessManager;
    InstanceAdmin public masterInstanceAdmin;
    InstanceAuthorizationV3 public instanceAuthorizationV3;
    BundleSet public masterBundleSet;
    RiskSet public masterRiskSet;
    InstanceStore public masterInstanceStore;
    ProductStore public masterProductStore;
    Instance public masterInstance;
    NftId public masterInstanceNftId;
    InstanceReader public masterInstanceReader;

    InstanceAdmin public instanceAdmin;
    BundleSet public instanceBundleSet;
    RiskSet public instanceRiskSet;
    InstanceStore public instanceStore;
    IInstance public instance;
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

    NftId public bundleNftId;
    uint256 public initialCapitalAmount;

    address constant public NFT_LOCK_ADDRESS = address(0x1);

    address public instanceOwner = makeAddr("instanceOwner");
    address public productOwner = makeAddr("productOwner");
    address public oracleOwner = makeAddr("oracleOwner");
    address public poolOwner = makeAddr("poolOwner");
    address public distributionOwner = makeAddr("distributionOwner");
    address public distributor = makeAddr("distributor");
    address public customer = makeAddr("customer");
    address public customer2 = makeAddr("customer2");
    address public investor = makeAddr("investor");
    address public staker = makeAddr("staker");
    address public staker2 = makeAddr("staker2");
    address public outsider = makeAddr("outsider");

    uint8 initialProductFeePercentage = 2;
    uint8 initialPoolFeePercentage = 3;
    uint8 initialStakingFeePercentage = 0;
    uint8 initialBundleFeePercentage = 0;
    uint8 initialDistributionFeePercentage = 20;
    uint8 initialMinDistributionOwnerFeePercentage = 2;

    Fee public initialProductFee = FeeLib.percentageFee(initialProductFeePercentage);
    Fee public initialPoolFee = FeeLib.percentageFee(initialPoolFeePercentage);
    Fee public initialStakingFee = FeeLib.percentageFee(initialStakingFeePercentage);
    Fee public initialBundleFee = FeeLib.percentageFee(initialBundleFeePercentage);
    Fee public initialDistributionFee = FeeLib.percentageFee(initialDistributionFeePercentage);
    Fee public initialMinDistributionOwnerFee = FeeLib.percentageFee(initialMinDistributionOwnerFeePercentage);

    bool public poolIsVerifying = true;
    bool public distributionIsVerifying = true;
    UFixed poolCollateralizationLevelIs100 = UFixedLib.toUFixed(1);

    string private _checkpointLabel;
    uint256 private _checkpointGasLeft = 1; // Start the slot warm.

    function setUp() public virtual {
        vm.warp(10000);
        _setUp();
    }

    function _setUp()
        internal
        virtual
    {
        currentChainId = ChainIdLib.current();

        // solhint-disable
        console.log("=== GifTest starting =======================================");
        console.log("=== deploying core =========================================");
        // solhint-enable
        _deployCore();

        // solhint-disable-next-line
        console.log("=== deploying release ======================================");
        _deployAndRegisterServices();

        // solhint-disable-next-line
        console.log("=== register token =========================================");
        _deployRegisterAndActivateToken();

        // solhint-disable-next-line
        console.log("=== deploying master instance ==============================");
        _deployMasterInstance();

        // solhint-disable-next-line
        console.log("=== create instance ========================================");
        _createInstance();

        // solhint-disable-next-line
        console.log("=== GifTest setup complete =================================");

        // registry authz setup
        _printAuthz(registryAdmin, "registry");
    }

    /// @dev Helper function to assert that a given NftId is equal to the expected NftId.
    function assertNftId(NftId actualNftId, NftId expectedNftId, string memory message) public view {
        if(block.chainid == 31337) {
            assertEq(actualNftId.toInt(), expectedNftId.toInt(), message);
        } else {
            // solhint-disable-next-line
            console.log("chain not anvil, skipping assertNftId");
        }
    }

    /// @dev Helper function to assert that a given NftId is equal to zero.
    function assertNftIdZero(NftId nftId, string memory message) public view {
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


    function _deployAndRegisterServices()
        internal 
    {
        IServiceAuthorization serviceAuthorization = new ServiceAuthorizationV3("85b428cbb5185aee615d101c2554b0a58fb64810");

        deployRelease(
            releaseRegistry, 
            serviceAuthorization);

        VersionPart latestRelease = registry.getLatestRelease();
        assertEq(releaseRegistry.getState(latestRelease).toInt(), ACTIVE().toInt(), "unexpected state for releaseRegistry after activateNextRelease");

        // set staking service
        vm.prank(stakingOwner);
        staking.setStakingService(latestRelease);
    }

    function _deployMasterInstance() internal 
    {
        vm.startPrank(gifManager);

        // create instance supporting contracts
        masterAccessManager = new AccessManagerCloneable();
        masterInstanceAdmin = new InstanceAdmin(address(masterAccessManager));
        masterInstanceStore = new InstanceStore();
        masterProductStore = new ProductStore();
        masterBundleSet = new BundleSet();
        masterRiskSet = new RiskSet();
        masterInstanceReader = new InstanceReader();

        // crate instance
        masterInstance = new Instance();
        masterInstance.initialize(
            IInstance.InstanceContracts({
                instanceAdmin: masterInstanceAdmin,
                instanceStore: masterInstanceStore,
                productStore: masterProductStore,
                bundleSet: masterBundleSet,
                riskSet: masterRiskSet,
                instanceReader: masterInstanceReader
            }),
            gifManager,
            false);

        // sets master instance address in instance service
        // instance service is now ready to create cloned instances
        masterInstanceNftId = instanceService.setAndRegisterMasterInstance(address(masterInstance));

        // setup roles, targets and function grantings
        instanceAuthorizationV3 = new InstanceAuthorizationV3();
        masterInstanceAdmin.completeSetup(
            address(instanceAuthorizationV3),
            address(masterInstance));

        require(address(masterInstanceAdmin.getRegistry()) == address(registry), "unexpected master instance registry");
        require(masterInstanceAdmin.getRelease().toInt() == 3, "unexpected master instance release");

        // MUST be set after instance is set up and registered
        // lock master instance nft
        chainNft.transferFrom(gifManager, NFT_LOCK_ADDRESS, masterInstanceNftId.toInt());

        vm.stopPrank();

        // solhint-disable
        console.log("master instance deployed at", address(masterInstance));
        console.log("master instance nft id", masterInstanceNftId.toInt());
        console.log("master instance owner", masterInstance.getOwner());
        console.log("master oz access manager deployed at", address(masterInstance.authority()));
        console.log("master instance access manager deployed at", address(masterInstanceAdmin));
        console.log("master instance reader deployed at", address(masterInstanceReader));
        console.log("master bundle set deployed at", address(masterBundleSet));
        console.log("master risk set deployed at", address(masterRiskSet));
        console.log("master instance store deployed at", address(masterInstanceStore));
        // solhint-enable
    }


    function _createInstance() internal {

        vm.startPrank(instanceOwner);

        ( 
            instance,
            instanceNftId
        ) = instanceService.createInstance(false);

        instanceAdmin = instance.getInstanceAdmin();
        instanceReader = instance.getInstanceReader();
        instanceStore = instance.getInstanceStore();
        instanceBundleSet = instance.getBundleSet();
        instanceRiskSet = instance.getRiskSet();
        instanceStore = instance.getInstanceStore();

        vm.stopPrank();
        
        // solhint-disable
        console.log("cloned instance deployed at", address(instance));
        console.log("cloned instance nft id", instanceNftId.toInt());
        console.log("cloned instance owner", instance.getOwner());
        console.log("cloned oz access manager deployed at", instance.authority());
        console.log("cloned instance reader deployed at", address(instanceReader));
        console.log("cloned bundle set deployed at", address(instanceBundleSet));
        console.log("cloned risk set deployed at", address(instanceRiskSet));
        console.log("cloned instance store deployed at", address(instanceStore));
        // solhint-enable
    }

    function _deployRegisterAndActivateToken() internal {

        vm.prank(tokenIssuer);
        token = new Usdc();

        vm.startPrank(gifManager);

        VersionPart release = registry.getLatestRelease();

        // dip
        tokenRegistry.setActiveForVersion(
            currentChainId, address(dip), release, true);

        // usdc
        // TODO continue here : tokenRegistry need to call staktint to add registered tokens there
        tokenRegistry.registerToken(address(token));
        tokenRegistry.setActiveForVersion(
            currentChainId, address(token), release, true);

        vm.stopPrank();

        // solhint-disable
        console.log("token (usdc) deployed at", address(token));
        console.log("token (dip) deployed at", address(dip));
        // solhint-enable
    }

    function _prepareProduct() internal {
        _prepareProductWithParams(
            "SimpleProduct",
            _getSimpleProductInfo(),
            true, // create bundle
            false); // print authz
    }


    function _prepareProduct(bool createBundle) internal {
        _prepareProductWithParams(
            "SimpleProduct",
            _getSimpleProductInfo(),
            createBundle,
            false); // print authz
    }


    function _prepareProductWithParams(
        string memory name,
        IComponents.ProductInfo memory productInfo,
        bool createBundle,
        bool printAuthz
    )
        internal
    {

        (
            product, 
            productNftId
        ) = _deployAndRegisterNewSimpleProduct(name);

        _preparePool();
        _prepareDistribution();
        _prepareOracle();

        // setup some meaningful distribution fees
        vm.startPrank(distributionOwner);
        distribution.setFees(
            initialDistributionFee, 
            initialMinDistributionOwnerFee);
        vm.stopPrank();
        
        vm.startPrank(poolOwner);
        pool.setFees(
            initialPoolFee, 
            initialStakingFee, 
            FeeLib.zero());
        vm.stopPrank();

        vm.startPrank(tokenIssuer);
        token.transfer(investor, DEFAULT_BUNDLE_CAPITALIZATION * 10**token.decimals());
        token.transfer(customer, DEFAULT_CUSTOMER_FUNDS * 10**token.decimals());
        vm.stopPrank();

        if (createBundle) {
            vm.startPrank(investor);
            IComponents.ComponentInfo memory poolComponentInfo = instanceReader.getComponentInfo(poolNftId);
            token.approve(address(poolComponentInfo.tokenHandler), DEFAULT_BUNDLE_CAPITALIZATION * 10**token.decimals());

            (bundleNftId,) = SimplePool(address(pool)).createBundle(
                initialBundleFee, 
                DEFAULT_BUNDLE_CAPITALIZATION * 10**token.decimals(), 
                SecondsLib.toSeconds(DEFAULT_BUNDLE_LIFETIME), 
                ""
            );
            vm.stopPrank();
        }

        if (printAuthz) {
            _printAuthz(instance.getInstanceAdmin(), "instance");
        }
    }

    function _deployAndRegisterNewSimpleProduct(string memory name)
        internal
        returns (
            SimpleProduct newProduct,
            NftId newNftId
        )
    {
        // solhint-disable-next-line
        console.log("--- deploy and register simple product");

        // product owner deploys product
        vm.startPrank(productOwner);
        newProduct = new SimpleProduct(
            instanceNftId,
            "SimpleProduct",
            _getSimpleProductInfo(),
            _getSimpleFeeInfo(),
            new BasicProductAuthorization(name),
            productOwner // initial owner
        );
        vm.stopPrank();

        // solhint-disable-next-line
        console.log("product address", address(newProduct));

        // instance owner registeres product with instance (and registry)
        vm.startPrank(instanceOwner);
        newNftId = instance.registerProduct(address(newProduct), address(token));
        vm.stopPrank();

        // solhint-disable
        console.log("product nft id", newNftId.toInt());
        console.log("product parent nft id", registry.getParentNftId(newNftId).toInt());
        // solhint-enable
    }


    function _getSimpleProductInfo()
        internal
        pure
        returns (IComponents.ProductInfo memory productInfo)
    {
        return IComponents.ProductInfo({
            isProcessingFundedClaims: false,
            isInterceptingPolicyTransfers: false,
            hasDistribution: true,
            expectedNumberOfOracles: 1,
            numberOfOracles: 0,
            poolNftId: NftIdLib.zero(),
            distributionNftId: NftIdLib.zero(),
            oracleNftId: new NftId[](1)
        });
    }

    function _getSimpleFeeInfo()
        internal
        pure
        returns (IComponents.FeeInfo memory feeInfo)
    {
        return IComponents.FeeInfo({
            productFee: FeeLib.zero(),
            processingFee: FeeLib.zero(),
            distributionFee: FeeLib.zero(),
            minDistributionOwnerFee: FeeLib.zero(),
            poolFee: FeeLib.zero(),
            stakingFee: FeeLib.zero(),
            performanceFee: FeeLib.zero()
        });
    }


    function _preparePool() internal {

        // solhint-disable-next-line
        console.log("--- deploy and register simple pool");

        vm.startPrank(poolOwner);
        pool = new SimplePool(
            productNftId,
            _getDefaultSimplePoolInfo(),
            new SimplePoolAuthorization("SimplePool"),
            poolOwner
        );
        vm.stopPrank();
        poolNftId = _registerComponent(product, address(pool), "pool");
    }

    function _getDefaultSimplePoolInfo() internal view returns (IComponents.PoolInfo memory) {
        return IComponents.PoolInfo({
            maxBalanceAmount: AmountLib.max(),
            isInterceptingBundleTransfers: false,
            isProcessingConfirmedClaims: false,
            isExternallyManaged: false,
            isVerifyingApplications: false,
            collateralizationLevel: UFixedLib.one(),
            retentionLevel: UFixedLib.one()});
    }

    function _prepareDistribution() internal {

        // solhint-disable-next-line
        console.log("--- deploy and register simple distribution");

        vm.startPrank(distributionOwner);
        distribution = new SimpleDistribution(
            productNftId,
            new SimpleDistributionAuthorization("SimpleDistribution"),
            distributionOwner);
        vm.stopPrank();
        distributionNftId = _registerComponent(product, address(distribution), "distribution");
    }


    function _prepareOracle() internal {

        // deploy and register oracle
        // solhint-disable-next-line
        console.log("--- deploy and register simple oracle");

        vm.startPrank(oracleOwner);
        oracle = new SimpleOracle(
            productNftId,
            new BasicOracleAuthorization("SimpleOracle", COMMIT_HASH),
            oracleOwner);
        vm.stopPrank();
        oracleNftId = _registerComponent(product, address(oracle), "oracle");
    }

    function _registerComponent(IProductComponent prd, address component, string memory componentName) internal returns (NftId componentNftId) {
        return _registerComponent(productOwner, prd, component, componentName);
    }

    function _registerComponent(address owner, IProductComponent prd, address component, string memory componentName) internal returns (NftId componentNftId) {
        // solhint-disable-next-line
        console.log(componentName, "component at", address(component));

        // product owner registeres oracle with instance (and registry)
        vm.startPrank(owner);
        componentNftId = prd.registerComponent(component);
        vm.stopPrank();

        // solhint-disable
        console.log(componentName, "nft id", componentNftId.toInt());
        console.log(componentName, "parent nft id", registry.getParentNftId(componentNftId).toInt());
        // solhint-enable
    }

    function assertEq(Amount amount1, Amount amount2, string memory message) internal {
        assertEq(amount1.toInt(), amount2.toInt(), message);
    }

    function assertEq(NftId nftId1, NftId nftId2, string memory message) internal {
        assertTrue(nftId1.eq(nftId2), message);
    }

    function assertEq(Timestamp ts1, Timestamp ts2, string memory message) internal pure {
        assertEq(ts1.toInt(), ts2.toInt(), message);
    }
}