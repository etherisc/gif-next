// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Test, console} from "../../lib/forge-std/src/Test.sol";

import {Amount, AmountLib} from "../../contracts/type/Amount.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {SecondsLib} from "../../contracts/type/Seconds.sol";
import {Fee, FeeLib} from "../../contracts/type/Fee.sol";
import {UFixed, UFixedLib} from "../../contracts/type/UFixed.sol";
import {RoleId} from "../../contracts/type/RoleId.sol";
import {ACTIVE} from "../../contracts/type/StateId.sol";
import {Timestamp} from "../../contracts/type/Timestamp.sol";

import {IAccess} from "../../contracts/authorization/IAccess.sol";
import {IAccessAdmin} from "../../contracts/authorization/IAccessAdmin.sol";

import {BasicDistributionAuthorization} from "../../contracts/distribution/BasicDistributionAuthorization.sol";
import {BasicOracleAuthorization} from "../../contracts/oracle/BasicOracleAuthorization.sol";
import {BasicPoolAuthorization} from "../../contracts/pool/BasicPoolAuthorization.sol";
import {BasicProductAuthorization} from "../../contracts/product/BasicProductAuthorization.sol";

import {IServiceAuthorization} from "../../contracts/authorization/IServiceAuthorization.sol";
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
import {InstanceStore} from "../../contracts/instance/InstanceStore.sol";

import {Usdc} from "../mock/Usdc.sol";
import {SimpleDistribution} from "../../contracts/examples/unpermissioned/SimpleDistribution.sol";
import {SimpleOracle} from "../../contracts/examples/unpermissioned/SimpleOracle.sol";
import {SimplePool} from "../../contracts/examples/unpermissioned/SimplePool.sol";
import {SimpleProduct} from "../../contracts/examples/unpermissioned/SimpleProduct.sol";

import {GifDeployer} from "./GifDeployer.sol";


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
    ReleaseRegistry public releaseRegistry;
    TokenRegistry public tokenRegistry;

    StakingManager public stakingManager;
    Staking public staking;
    StakingReader public stakingReader;
    NftId public stakingNftId;

    AccessManagerCloneable public masterAccessManager;
    InstanceAdmin public masterInstanceAdmin;
    address public instanceAuthorizationV3; //InstanceAuthorizationV3
    BundleSet public masterBundleSet;
    InstanceStore public masterInstanceStore;
    Instance public masterInstance;
    NftId public masterInstanceNftId;
    InstanceReader public masterInstanceReader;

    InstanceAdmin public instanceAdmin;
    BundleSet public instanceBundleSet;
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

    address public registryAddress;
    NftId public registryNftId;
    NftId public bundleNftId;
    uint256 public initialCapitalAmount;

    address constant public NFT_LOCK_ADDRESS = address(0x1);

    address public globalRegistry = makeAddr("globalRegistry");
    address public registryOwner = makeAddr("registryOwner");
    address public stakingOwner = registryOwner;
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

        // create an instance (cloned from master instance)
        vm.startPrank(instanceOwner);
        _createInstance();
        vm.stopPrank();

        // print full authz setup
        _printAuthz(registryAdmin, "registry");
        _printAuthz(instance.getInstanceAdmin(), "instance");
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
            releaseRegistry,
            registryAdmin,
            stakingManager,
            staking
        ) = deployCore(
            globalRegistry,
            gifAdmin,
            gifManager,
            stakingOwner);

        // obtain some references
        registryAddress = address(registry);
        chainNft = ChainNft(registry.getChainNftAddress());
        registryNftId = registry.getNftIdForAddress(registryAddress);
        stakingNftId = registry.getNftIdForAddress(address(staking));
        stakingReader = staking.getStakingReader();

        // solhint-disable
        console.log("registry deployed at", address(registry));
        console.log("registry owner", registryOwner);

        console.log("token registry deployed at", address(tokenRegistry));
        console.log("release manager deployed at", address(releaseRegistry));

        console.log("registry access manager deployed:", address(registryAdmin));
        console.log("registry access manager authority", registryAdmin.authority());

        console.log("staking manager deployed at", address(stakingManager));

        console.log("staking nft id", registry.getNftIdForAddress(address(staking)).toInt());
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
            releaseRegistry, 
            serviceAuthorization, 
            gifAdmin, 
            gifManager);

        assertEq(releaseRegistry.getState(releaseRegistry.getLatestVersion()).toInt(), ACTIVE().toInt(), "unexpected state for releaseRegistry after activateNextRelease");
    }

    function _deployMasterInstance() internal 
    {
        // create instance supporting contracts
        instanceAuthorizationV3 = address(new InstanceAuthorizationV3());
        masterInstanceAdmin = new InstanceAdmin(instanceAuthorizationV3);
        masterInstanceStore = new InstanceStore();
        masterBundleSet = new BundleSet();
        masterInstanceReader = new InstanceReader();

        // crate instance
        masterInstance = new Instance();
        masterInstance.initialize(
            masterInstanceAdmin,
            masterInstanceStore,
            masterBundleSet,
            masterInstanceReader,
            registry,
            registryOwner);

        // retrieve master access manager from instance
        masterAccessManager = AccessManagerCloneable(
            masterInstanceAdmin.authority());

        // sets master instance address in instance service
        // instance service is now ready to create cloned instances
        masterInstanceNftId = instanceService.setAndRegisterMasterInstance(address(masterInstance));

        // MUST be set after instance is set up and registered
        masterInstanceAdmin.initializeInstanceAuthorization(address(masterInstance));

        // lock master instance nft
        chainNft.transferFrom(registryOwner, NFT_LOCK_ADDRESS, masterInstanceNftId.toInt());

        // solhint-disable
        console.log("master instance deployed at", address(masterInstance));
        console.log("master instance nft id", masterInstanceNftId.toInt());
        console.log("master oz access manager deployed at", address(masterInstance.authority()));
        console.log("master instance access manager deployed at", address(masterInstanceAdmin));
        console.log("master instance reader deployed at", address(masterInstanceReader));
        console.log("master bundle manager deployed at", address(masterBundleSet));
        console.log("master instance store deployed at", address(masterInstanceStore));
        // solhint-enable
    }


    function _createInstance() internal {
        ( 
            instance,
            instanceNftId
        ) = instanceService.createInstance();

        instanceAdmin = instance.getInstanceAdmin();
        instanceReader = instance.getInstanceReader();
        instanceStore = instance.getInstanceStore();
        instanceBundleSet = instance.getBundleSet();
        instanceStore = instance.getInstanceStore();
        
        // solhint-disable
        console.log("cloned instance deployed at", address(instance));
        console.log("cloned instance nft id", instanceNftId.toInt());
        console.log("cloned oz access manager deployed at", instance.authority());
        console.log("cloned instance reader deployed at", address(instanceReader));
        console.log("cloned bundle manager deployed at", address(instanceBundleSet));
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

    function _prepareProduct() internal {
        _prepareProduct(true);
        _printAuthz(instanceAdmin, "instanceWithProduct");
    }


    function _prepareProduct(bool createBundle) internal {

        (
            product, 
            productNftId
        ) = _deployAndRegisterNewSimpleProduct("SimpleProduct");

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

        vm.startPrank(registryOwner);
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
            address(registry),
            instanceNftId,
            new BasicProductAuthorization(name),
            productOwner, // initial owner
            address(token),
            false, // is interceptor
            true, // has distribution
            1 // number of oracles in product cluster
        );
        vm.stopPrank();

        // solhint-disable-next-line
        console.log("product address", address(newProduct));

        // instance owner registeres product with instance (and registry)
        vm.startPrank(instanceOwner);
        newNftId = instance.registerProduct(address(newProduct));
        vm.stopPrank();

        // token handler only becomes available after registration
        vm.startPrank(productOwner);
        newProduct.approveTokenHandler(AmountLib.max());
        vm.stopPrank();

        // solhint-disable-next-line
        console.log("product nft id", newNftId.toInt());
    }

    function _preparePool() internal {

        // solhint-disable-next-line
        console.log("--- deploy and register simple pool");

        vm.startPrank(poolOwner);
        pool = new SimplePool(
            address(registry),
            productNftId,
            address(token),
            new BasicPoolAuthorization("SimplePool"),
            poolOwner
        );
        vm.stopPrank();

        poolNftId = _registerComponent(product, address(pool), "pool");

        // token handler only becomes available after registration
        vm.startPrank(poolOwner);
        pool.approveTokenHandler(AmountLib.max());
        vm.stopPrank();
    }


    function _prepareDistribution() internal {

        // solhint-disable-next-line
        console.log("--- deploy and register simple distribution");

        vm.startPrank(distributionOwner);
        distribution = new SimpleDistribution(
            address(registry),
            productNftId,
            new BasicDistributionAuthorization("SimpleDistribution"),
            distributionOwner,
            address(token));
        vm.stopPrank();

        distributionNftId = _registerComponent(product, address(distribution), "distribution");

        // token handler only becomes available after registration
        vm.startPrank(distributionOwner);
        distribution.approveTokenHandler(AmountLib.max());
        vm.stopPrank();
    }


    function _prepareOracle() internal {

        // deploy and register oracle
        // solhint-disable-next-line
        console.log("--- deploy and register simple oracle");

        vm.startPrank(oracleOwner);
        oracle = new SimpleOracle(
            address(registry),
            productNftId,
            new BasicOracleAuthorization("SimpleOracle"),
            oracleOwner,
            address(token));
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

        // solhint-disable-next-line
        console.log(componentName, "nft id", componentNftId.toInt());
    }


    function _printAuthz(
        IAccessAdmin aa,
        string memory aaName
    )
        internal
    {
        // solhint-disable no-console
        console.log("==========================================");
        console.log(aaName, "admin authorization");
        console.log(aaName, "admin contract:", address(aa));
        console.log(aaName, "admin authority:", aa.authority());

        uint256 roles = aa.roles();
        uint256 targets = aa.targets();

        console.log("------------------------------------------");
        console.log("roles", aa.roles());
        // solhint-enable

        for(uint256 i = 0; i < aa.roles(); i++) {
            _printRoleMembers(aa, aa.getRoleId(i));
        }

        // solhint-disable no-console
        console.log("------------------------------------------");
        console.log("targets", aa.targets());
        // solhint-enable

        for(uint256 i = 0; i < aa.targets(); i++) {
            _printTarget(aa, aa.getTargetAddress(i));
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
                    IAccess.FunctionInfo memory func,
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

    function assertEq(Amount amount1, Amount amount2, string memory message) internal {
        assertEq(amount1.toInt(), amount2.toInt(), message);
    }

    function assertEq(NftId nftId1, NftId nftId2, string memory message) internal {
        assertTrue(nftId1.eq(nftId2), message);
    }

    function assertEq(Timestamp ts1, Timestamp ts2, string memory message) internal {
        assertEq(ts1.toInt(), ts2.toInt(), message);
    }
}