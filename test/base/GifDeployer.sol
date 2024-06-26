// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";

// core contracts
import {Dip} from "../../contracts/mock/Dip.sol";
import {GIF_MANAGER_ROLE, GIF_ADMIN_ROLE} from "../../contracts/type/RoleId.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {IServiceAuthorization} from "../../contracts/authorization/IServiceAuthorization.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {RegistryAdmin} from "../../contracts/registry/RegistryAdmin.sol";
import {ReleaseRegistry} from "../../contracts/registry/ReleaseRegistry.sol";
import {Staking} from "../../contracts/staking/Staking.sol";
import {StakingManager} from "../../contracts/staking/StakingManager.sol";
import {StakingReader} from "../../contracts/staking/StakingReader.sol";
import {StakingStore} from "../../contracts/staking/StakingStore.sol";
import {TokenRegistry} from "../../contracts/registry/TokenRegistry.sol";

// service and proxy contracts
import {IService} from "../../contracts/shared/IService.sol";
import {
    ObjectType, ObjectTypeLib, 
    APPLICATION, BUNDLE, CLAIM, COMPONENT, DISTRIBUTION, INSTANCE, ORACLE, POLICY, POOL, PRICE, PRODUCT, REGISTRY, STAKING
} from "../../contracts/type/ObjectType.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {ProxyManager} from "../../contracts/shared/ProxyManager.sol";
import {SCHEDULED, DEPLOYING} from "../../contracts/type/StateId.sol";
import {VersionPart} from "../../contracts/type/Version.sol";

import {ApplicationService} from "../../contracts/product/ApplicationService.sol";
import {ApplicationServiceManager} from "../../contracts/product/ApplicationServiceManager.sol";
import {BundleService} from "../../contracts/pool/BundleService.sol";
import {BundleServiceManager} from "../../contracts/pool/BundleServiceManager.sol";
import {ClaimService} from "../../contracts/product/ClaimService.sol";
import {ClaimServiceManager} from "../../contracts/product/ClaimServiceManager.sol";
import {ComponentService} from "../../contracts/shared/ComponentService.sol";
import {ComponentServiceManager} from "../../contracts/shared/ComponentServiceManager.sol";
import {DistributionService} from "../../contracts/distribution/DistributionService.sol";
import {DistributionServiceManager} from "../../contracts/distribution/DistributionServiceManager.sol";
import {InstanceService} from "../../contracts/instance/InstanceService.sol";
import {InstanceServiceManager} from "../../contracts/instance/InstanceServiceManager.sol";
import {OracleService} from "../../contracts/oracle/OracleService.sol";
import {OracleServiceManager} from "../../contracts/oracle/OracleServiceManager.sol";
import {PolicyService} from "../../contracts/product/PolicyService.sol";
import {PolicyServiceManager} from "../../contracts/product/PolicyServiceManager.sol";
import {PoolService} from "../../contracts/pool/PoolService.sol";
import {PoolServiceManager} from "../../contracts/pool/PoolServiceManager.sol";
import {PricingService} from "../../contracts/product/PricingService.sol";
import {PricingServiceManager} from "../../contracts/product/PricingServiceManager.sol";
import {ProductService} from "../../contracts/product/ProductService.sol";
import {ProductServiceManager} from "../../contracts/product/ProductServiceManager.sol";
import {RegistryServiceManager} from "../../contracts/registry/RegistryServiceManager.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {StakingService} from "../../contracts/staking/StakingService.sol";
import {StakingServiceManager} from "../../contracts/staking/StakingServiceManager.sol";

contract GifDeployer is Test {

    struct DeployedServiceInfo {
        NftId nftId;
        address service;
        address proxy;
    }

    RegistryServiceManager public registryServiceManager;
    RegistryService public registryService;
    NftId public registryServiceNftId;

    StakingServiceManager public stakingServiceManager;
    StakingService public stakingService;
    NftId public stakingServiceNftId;

    InstanceServiceManager public instanceServiceManager;
    InstanceService public instanceService;
    NftId public instanceServiceNftId;

    ComponentServiceManager public componentServiceManager;
    ComponentService public componentService;
    NftId public componentServiceNftId;

    DistributionServiceManager public distributionServiceManager;
    DistributionService public distributionService;
    NftId public distributionServiceNftId;

    PricingServiceManager public pricingServiceManager;
    PricingService public pricingService;
    NftId public pricingServiceNftId;

    BundleServiceManager public bundleServiceManager;
    BundleService public bundleService;
    NftId public bundleServiceNftId;

    PoolServiceManager public poolServiceManager;
    PoolService public poolService;
    NftId public poolServiceNftId;

    OracleServiceManager public oracleServiceManager;
    OracleService public oracleService;
    NftId public oracleServiceNftId;

    ProductServiceManager public productServiceManager;
    ProductService public productService;
    NftId public productServiceNftId;

    ClaimServiceManager public claimServiceManager;
    ClaimService public claimService;
    NftId public claimServiceNftId;

    ApplicationServiceManager public applicationServiceManager;
    ApplicationService public applicationService;
    NftId public applicationServiceNftId;

    PolicyServiceManager public policyServiceManager;
    PolicyService public policyService;
    NftId public policyServiceNftId;

    mapping(ObjectType domain => DeployedServiceInfo info) public serviceForDomain;


    function deployCore(
        address gifAdmin,
        address gifManager,
        address stakingOwner
    )
        public
        returns (
            IERC20Metadata dip,
            Registry registry,
            TokenRegistry tokenRegistry,
            ReleaseRegistry releaseRegistry,
            RegistryAdmin registryAdmin,
            StakingManager stakingManager,
            Staking staking
        )
    {
        vm.startPrank(gifManager);

        // 1) deploy dip token
        dip = new Dip();

        // 2) deploy registry admin
        registryAdmin = new RegistryAdmin();

        // 3) deploy registry
        address globalRegistry;
        registry = new Registry(registryAdmin, globalRegistry);

        // 4) deploy release manager
        releaseRegistry = new ReleaseRegistry(registry);

        // 5) deploy token registry
        tokenRegistry = new TokenRegistry(registry, dip);

        // 6) deploy staking reader
        StakingReader stakingReader = new StakingReader(registry);

        // 7) deploy staking store
        StakingStore stakingStore = new StakingStore(registry, stakingReader);

        // 8) deploy staking manager and staking component
        stakingManager = new StakingManager(
            address(registry),
            address(tokenRegistry),
            address(stakingStore),
            stakingOwner);
        staking = stakingManager.getStaking();

        // 9) initialize instance reader
        stakingReader.initialize(
            address(staking),
            address(stakingStore));

        // 10) intialize registry and register staking component
        registry.initialize(
            address(releaseRegistry),
            address(tokenRegistry),
            address(staking));
        staking.linkToRegisteredNftId();

        // 11) initialize registry admin
        // TODO Consider making it non permitted
        // no arguments
        // cmp deployed contracts codehashes with precalculated ones
        // check authority is the same
        // check registry is the same
        // whatever...
        // Consider: specific completeSetup can do specific checks and require specific initial state of deployed contracts
        // if state is different -> setup can not be completed...
        // state: owner/admin/manager
        // can be usefull for non permissioned deployment
        registryAdmin.completeSetup(
            registry,
            gifAdmin,
            gifManager);

        vm.stopPrank();
    }


    function deployRelease(
        ReleaseRegistry releaseRegistry,
        IServiceAuthorization serviceAuthorization,
        address gifAdmin,
        address gifManager
    )
        public
    {
        vm.startPrank(gifAdmin);
        releaseRegistry.createNextRelease();
        vm.stopPrank();

        vm.startPrank(gifManager);
        _deployReleaseServices(
            releaseRegistry,
            serviceAuthorization);
        vm.stopPrank();

        vm.startPrank(gifAdmin);
        releaseRegistry.activateNextRelease();
        vm.stopPrank();
    }


    function _deployReleaseServices(
        ReleaseRegistry releaseRegistry,
        IServiceAuthorization serviceAuthorization
    )
        internal
    {
        (
            address authority, 
            bytes32 salt
        ) = _prepareRelease(
            releaseRegistry, 
            serviceAuthorization);

        _deployAndRegisterServices(
            releaseRegistry,
            authority, 
            salt);
    }


    function _prepareRelease(
        ReleaseRegistry releaseRegistry,
        IServiceAuthorization serviceAuthorization
    )
        internal
        returns (
            address authority, 
            bytes32 salt
        )
    {
        // solhint-disable
        console.log("--- prepare release -----------------------------------------------");
        // solhint-enable

        // check release manager state before release preparation step
        assertEq(
            releaseRegistry.getState(releaseRegistry.getNextVersion()).toInt(), 
            SCHEDULED().toInt(), 
            "unexpected state for releaseRegistry after createNextRelease");

        // prepare release by providing the service authorization setup to the release manager
        VersionPart release;
        (
            authority, 
            release,
            salt
        ) = releaseRegistry.prepareNextRelease(
            serviceAuthorization,
            "0x1234");

        // check release manager state after release preparation step
        assertEq(
            releaseRegistry.getState(releaseRegistry.getNextVersion()).toInt(), 
            DEPLOYING().toInt(), 
            "unexpected state for releaseRegistry after prepareNextRelease");

        // solhint-disable
        console.log("release version", release.toInt());
        console.log("release salt", uint(salt));
        console.log("release access manager deployed at", authority);
        console.log("release services count", serviceAuthorization.getServiceDomains().length);
        console.log("release services remaining (before service registration)", releaseRegistry.getRemainingServicesToRegister());
        // solhint-enable
    }


    /// @dev Populates the service mapping by deploying all service proxies and service for gif release 3.
    function _deployAndRegisterServices(
        ReleaseRegistry releaseRegistry,
        address authority, 
        bytes32 salt
    )
        internal
    {
        address registryAddress = address(releaseRegistry.getRegistry());

        registryServiceManager = new RegistryServiceManager{salt: salt}(authority, registryAddress, salt);
        registryService = registryServiceManager.getRegistryService();
        registryServiceNftId = _registerService(releaseRegistry, registryServiceManager, registryService);

        stakingServiceManager = new StakingServiceManager{salt: salt}(authority, registryAddress, salt);
        stakingService = stakingServiceManager.getStakingService();
        stakingServiceNftId = _registerService(releaseRegistry, stakingServiceManager, stakingService);

        instanceServiceManager = new InstanceServiceManager{salt: salt}(authority, registryAddress, salt);
        instanceService = instanceServiceManager.getInstanceService();
        instanceServiceNftId = _registerService(releaseRegistry, instanceServiceManager, instanceService);

        // TODO figure out why this service manager deployment is different from the others
        componentServiceManager = new ComponentServiceManager(registryAddress);
        componentService = componentServiceManager.getComponentService();
        componentServiceNftId = _registerService(releaseRegistry, componentServiceManager, componentService);

        distributionServiceManager = new DistributionServiceManager{salt: salt}(authority, registryAddress, salt);
        distributionService = distributionServiceManager.getDistributionService();
        distributionServiceNftId = _registerService(releaseRegistry, distributionServiceManager, distributionService);

        pricingServiceManager = new PricingServiceManager{salt: salt}(authority, registryAddress, salt);
        pricingService = pricingServiceManager.getPricingService();
        pricingServiceNftId = _registerService(releaseRegistry, pricingServiceManager, pricingService);

        bundleServiceManager = new BundleServiceManager{salt: salt}(authority, registryAddress, salt);
        bundleService = bundleServiceManager.getBundleService();
        bundleServiceNftId = _registerService(releaseRegistry, bundleServiceManager, bundleService);

        poolServiceManager = new PoolServiceManager{salt: salt}(authority, registryAddress, salt);
        poolService = poolServiceManager.getPoolService();
        poolServiceNftId = _registerService(releaseRegistry, poolServiceManager, poolService);

        oracleServiceManager = new OracleServiceManager{salt: salt}(authority, registryAddress, salt);
        oracleService = oracleServiceManager.getOracleService();
        oracleServiceNftId = _registerService(releaseRegistry, oracleServiceManager, oracleService);

        productServiceManager = new ProductServiceManager{salt: salt}(authority, registryAddress, salt);
        productService = productServiceManager.getProductService(); 
        productServiceNftId = _registerService(releaseRegistry, productServiceManager, productService);

        claimServiceManager = new ClaimServiceManager{salt: salt}(authority, registryAddress, salt);
        claimService = claimServiceManager.getClaimService();
        claimServiceNftId = _registerService(releaseRegistry, claimServiceManager, claimService);

        applicationServiceManager = new ApplicationServiceManager{salt: salt}(authority, registryAddress, salt);
        applicationService = applicationServiceManager.getApplicationService();
        applicationServiceNftId = _registerService(releaseRegistry, applicationServiceManager, applicationService);

        policyServiceManager = new PolicyServiceManager{salt: salt}(authority, registryAddress, salt);
        policyService = policyServiceManager.getPolicyService();
        policyServiceNftId = _registerService(releaseRegistry, policyServiceManager, policyService);
    }


    function _registerService(
        ReleaseRegistry _releaseRegistry,
        ProxyManager _serviceManager,
        IService _service
    )
        internal
        returns (NftId serviceNftId)
    {
        // register service with release manager
        serviceNftId = _releaseRegistry.registerService(_service);
        _serviceManager.linkToProxy();

        // update service mapping
        ObjectType domain = _service.getDomain();
        serviceForDomain[domain] = DeployedServiceInfo({ 
            nftId: serviceNftId,
            service: address(_service), 
            proxy: address(_serviceManager) });

        // solhint-disable
        string memory domainName = ObjectTypeLib.toName(_service.getDomain());
        console.log("---", domainName, "service registered ----------------------------");
        console.log(domainName, "service proxy manager deployed at", address(_serviceManager));
        console.log(domainName, "service proxy manager linked to nft id", _serviceManager.getNftId().toInt());
        console.log(domainName, "service proxy manager owner", _serviceManager.getOwner());
        console.log(domainName, "service deployed at", address(_service));
        console.log(domainName, "service nft id", _service.getNftId().toInt());
        console.log(domainName, "service domain", _service.getDomain().toInt());
        console.log(domainName, "service owner", _service.getOwner());
        console.log(domainName, "service authority", _service.authority());
        console.log("release services remaining", _releaseRegistry.getRemainingServicesToRegister());
    }

    function eqObjectInfo(IRegistry.ObjectInfo memory a, IRegistry.ObjectInfo memory b) public returns (bool isSame) {

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

    function zeroObjectInfo() public pure returns (IRegistry.ObjectInfo memory) {
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

    function toBool(uint256 uintVal) public pure returns (bool boolVal)
    {
        assembly {
            boolVal := uintVal
        }
    }
}