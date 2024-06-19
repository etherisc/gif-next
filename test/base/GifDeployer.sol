// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {CreateXScript} from "../../lib/createx-forge/script/CreateXScript.sol";
import {ICreateX} from "../../lib/createx-forge/script/ICreateX.sol";

//import {AccessManagerExtendedWithDisableInitializeable} from "../../contracts/shared/AccessManagerExtendedWithDisableInitializeable.sol"; 


// core contracts
import {Dip} from "../../contracts/mock/Dip.sol";
import {GIF_MANAGER_ROLE, GIF_ADMIN_ROLE} from "../../contracts/type/RoleId.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {IServiceAuthorization} from "../../contracts/registry/IServiceAuthorization.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
//import {GlobalRegistry} from "../../contracts/registry/GlobalRegistry.sol";
import {RegistryAdmin} from "../../contracts/registry/RegistryAdmin.sol";
import {ReleaseManager} from "../../contracts/registry/ReleaseManager.sol";
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


// create:                        new_address =       keccak256(sender, senderNonce);
// create2:                       new_address =       keccak256(0xFF, sender, salt, keccak256(creatinCode + arguments);
// Create3:          create2      new_proxy_address = keccak256(0xFF, sender, salt, keccak256(proxyCode));
//                   create       new_address =       keccak256(new_proxy_address, 1); // 1 is initial nonce of proxy contract address, 
// with createX
// In permissioned mode salt contains sender address thus deployment depends on sender AND createX
// In non permissioned mode deployment depends only on createX address
// msg.sender in constructor will refer to createX
// deployCreate2():  create2      new_address =       keccak256(0xFF, createXAddress, salt, keccak256(creatinCode + arguments) );
// deployCreate3():  create2      new_proxy_address = keccak256(0xFF, createXAddress, salt, keccak256(proxyCode));
//                   create       new_address =       keccak256(new_proxy_address, 1);

contract GifDeployer is CreateXScript, Test {

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


    struct GifCore {
        address accessManagerAddress;
        //AccessManagerExtendedWithDisableInitializeable accessManager;
        AccessManager accessManager;
        address adminAddress;
        RegistryAdmin admin;
        address registryAddress;
        Registry registry;
        address releaseManagerAddress;
        ReleaseManager releaseManager;
        address tokenRegistryAddress;
        TokenRegistry tokenRegistry;
        address stakingReaderAddress;
        StakingReader stakingReader;
        address stakingStoreAddress;
        StakingStore stakingStore;
        address stakingManagerAddress;
        StakingManager stakingManager;
        address stakingImplAddress;
        address stakingAddress;
        Staking staking;
    }

    // TODO have to split mainnet and non mainnet?
    // TODO !!! try permissionless deployment
    // non mainnet deployment
    function deployCore(
        address gifAdmin, // deployer
        address gifManager,
        address stakingOwner,
        bytes32 salt
    )
        public
        withCreateX
        returns (
            Registry registry,
            ReleaseManager releaseManager,
            TokenRegistry tokenRegistry,
            StakingManager stakingManager
        )
    {
        vm.startPrank(gifManager);
        // 0) compute salt for permissioned deploymnet
        address deployer = gifAdmin;
        // [0..19] - deployer address, [20] - cross-chain redeploy protection, [21..31] - salt
        bytes32 permissionedSalt = bytes32(abi.encodePacked(bytes20(uint160(deployer)), bytes1(hex"00"), salt));
        console.log("salt", uint(permissionedSalt));

        // 1) compute core addresses
        // actual salt used by CreateX
        bytes32 createXSalt = keccak256(abi.encodePacked(uint256(uint160(deployer)), permissionedSalt));
        console.log("createX salt", uint(createXSalt));
        assert(createXSalt == 0x7165ca6aca15ea6d19512e46c047a49afece9ace7c9d8a13c0835d2dfaa23aa3);
        GifCore memory core = computeCoreAddresses(createXSalt, stakingOwner);

        // 2) deploy registry
        core.registry = _deployRegistry(
            core, 
            stakingOwner,
            permissionedSalt
        );

        // 3) deploy registry admin
        (
            core.admin,
            core.accessManager
        ) = _deployAdmin(
            core, 
            //gifAdmin, 
            //gifManager, 
            permissionedSalt
        );

        // 4) deploy release manager
        core.releaseManager = _deployReleaseManager(
            core,
            permissionedSalt);

        // 5) deploy dip token and token registry
        // TODO Dip token deployment: can have differernt addresses on different chains????
        //IERC20Metadata dip = new Dip();
        {
        address dipAddress = CreateX.deployCreate2(permissionedSalt, type(Dip).creationCode);
        core.tokenRegistry = _deployTokenRegistry(
            core,
            dipAddress,
            permissionedSalt);
        }
        // 6) deploy staking reader
        core.stakingReader = _deployStakingReader(
            core,
            permissionedSalt);

        // 7) deploy staking store
        core.stakingStore = _deployStakingStore(
            core,
            permissionedSalt);

        // 8) deploy staking manager and staking component
        (
            core.stakingManager,
            core.staking
        ) = _deployStakingManager(
            core,
            stakingOwner, 
            permissionedSalt);

        // 9) Enable access to core contracts
        // cmp deployed contracts codehashes with precalculated ones
        // check authority is the same
        // check registry is the same
        // whatever...
        // Consider: specific completeSetup can do specific checks and require specific initial state of deployed contracts
        // if state is different -> setup can not be completed...
        // state: owner/admin/manager
        // can be usefull for non permissioned deployment
        // TODO when deployed with createX -> deployer is createX -> ErrorNotDeployer
        core.admin.completeSetup(
            core.registry,
            gifAdmin, 
            gifManager
        );

        vm.stopPrank();

        registry = core.registry;
        tokenRegistry = core.tokenRegistry;
        releaseManager = core.releaseManager;
        stakingManager = core.stakingManager;
    }

    function computeCoreAddresses(bytes32 salt, address stakingOwner) public 
        returns (GifCore memory core)
    {
        core.adminAddress = CreateX.computeCreate2Address(salt, keccak256(type(RegistryAdmin).creationCode));
        core.accessManagerAddress = CreateX.computeCreateAddress(core.adminAddress, 1);
        core.registryAddress = CreateX.computeCreate2Address(salt, keccak256(type(Registry).creationCode));
        core.releaseManagerAddress = CreateX.computeCreate2Address(salt, keccak256(type(ReleaseManager).creationCode));
        core.tokenRegistryAddress = CreateX.computeCreate2Address(salt, keccak256(type(TokenRegistry).creationCode));
        core.stakingReaderAddress = CreateX.computeCreate2Address(salt,keccak256(type(StakingReader).creationCode));
        core.stakingStoreAddress = CreateX.computeCreate2Address(salt, keccak256(type(StakingStore).creationCode));

        // TODO deploying with proxy manager sort of mimics create3 pattern
        //      you first do create2 (deploy proxy manager) then create (arbitrary number of creates, deploy implementation & proxy)
        // Non of core contracts addresses are dependend on staking manager address
        // thus their addresses can be used in staking manager constructor
        bytes memory initCode = abi.encodePacked(
        type(StakingManager).creationCode, 
            abi.encode(
                core.registryAddress, 
                core.tokenRegistryAddress, 
                core.stakingStoreAddress, 
                stakingOwner
        ));
        core.stakingManagerAddress = CreateX.computeCreate2Address(salt, keccak256(initCode));
        core.stakingImplAddress = CreateX.computeCreateAddress(core.stakingManagerAddress, 1);
        core.stakingAddress = CreateX.computeCreateAddress(core.stakingManagerAddress, 2);
    }

    function _deployAdmin(GifCore memory core, /*address gifAdmin, address gifManager,*/ bytes32 salt) 
        internal 
        returns (RegistryAdmin admin, AccessManager accessManager) 
    {
        /*
        bytes memory initCode = abi.encodePacked(type(RegistryAdmin).creationCode);//, salt));// exctract deployer from salt?
        bytes memory data = abi.encodePacked(
            RegistryAdmin.initialize.selector,
            abi.encode( 
                core.registryAddress, 
                gifAdmin, 
                gifManager
            )
        );
        ICreateX.Values memory values = ICreateX.Values(0, 0);
        admin = RegistryAdmin(CreateX.deployCreate2AndInit(salt, initCode, data, values));
        accessManager = AccessManagerExtendedWithDisableInitializeable(admin.authority());
        */

        admin = RegistryAdmin(CreateX.deployCreate2(salt, type(RegistryAdmin).creationCode));
        accessManager = AccessManager(admin.authority());

        assertEq(address(accessManager), core.accessManagerAddress, "deployed access manager address differs from predicted one");
        assertEq(address(admin), core.adminAddress, "deployed admin address differs from predicted one");
        //console.log("core access manager deployed at", address(core.accessManager));
        //console.log("core admin deployed at", address(core.admin));
    }


    function _deployRegistry(GifCore memory core, address stakingOwner, bytes32 salt) 
        internal 
        returns (Registry registry) 
    {
        bytes memory initCode = type(Registry).creationCode;
        bytes memory data = abi.encodePacked(
            Registry.initialize.selector, 
            abi.encode(
                core.accessManagerAddress,
                core.adminAddress,
                core.releaseManagerAddress,
                core.tokenRegistryAddress,
                core.stakingAddress,
                stakingOwner,
                keccak256(type(Registry).creationCode),
                salt
            )
        );
        ICreateX.Values memory values = ICreateX.Values(0, 0);
        registry = Registry(CreateX.deployCreate2AndInit(
            salt, 
            initCode, 
            data, 
            values
        ));

        assertEq(address(registry), core.registryAddress, "deployed registry address differs from predicted one");
        //console.log("core registry deployed at", address(registry));
    }
/*
    function _deployGlobalRegistry(address registryAdmin, address initializeOwner, bytes32 salt) internal returns (GlobalRegistry) {
        //globalRegistry = new GlobalRegistry(registryAdmin, initializeOwner);
        bytes memory initCode = abi.encodePacked(
            type(GlobalRegistry).creationCode, 
            abi.encode(registryAdmin, initializeOwner));//, salt));// exctract deployer from salt?
        return GlobalRegistry(CreateX.deployCreate2(salt, initCode));
    }
*/
    function _deployReleaseManager(GifCore memory core, bytes32 salt) internal returns (ReleaseManager releaseManager) {
        bytes memory initCode = abi.encodePacked(type(ReleaseManager).creationCode);
        bytes memory data = abi.encodePacked(
            ReleaseManager.initialize.selector, 
            abi.encode(core.registryAddress)
        );
        ICreateX.Values memory values = ICreateX.Values(0, 0);
        releaseManager = ReleaseManager(CreateX.deployCreate2AndInit({
            salt: salt, 
            initCode: initCode, 
            data: data, 
            values: values
        }));

        assertEq(address(releaseManager), core.releaseManagerAddress, "deployed release manager address differs from predicted one");
        //console.log("core release manager deployed at", address(releaseManager));
    }

    function _deployTokenRegistry(GifCore memory core, address dip, bytes32 salt) internal returns (TokenRegistry tokenRegistry) {
        bytes memory initCode = abi.encodePacked(type(TokenRegistry).creationCode);
        bytes memory data = abi.encodePacked(
            TokenRegistry.initialize.selector, 
            abi.encode(
                core.registryAddress, 
                dip
            )
        );
        ICreateX.Values memory values = ICreateX.Values(0, 0);
        tokenRegistry = TokenRegistry(CreateX.deployCreate2AndInit({
            salt: salt, 
            initCode: initCode, 
            data: data, 
            values: values
        }));

        assertEq(address(tokenRegistry), core.tokenRegistryAddress, "deployed token registry address differs from predicted one");
        //console.log("core token registry deployed at", address(core.tokenRegistry));
    }

    function _deployStakingReader(GifCore memory core, bytes32 salt) internal returns (StakingReader stakingReader) {
        bytes memory initCode = abi.encodePacked(type(StakingReader).creationCode);
        bytes memory data = abi.encodePacked(
            StakingReader.initialize.selector, 
            abi.encode(
                core.registryAddress, 
                core.stakingAddress, 
                core.stakingStoreAddress
            )
        );
        ICreateX.Values memory values = ICreateX.Values(0, 0);
        stakingReader = StakingReader(CreateX.deployCreate2AndInit({
            salt: salt, 
            initCode: initCode, 
            data: data, 
            values: values
        }));

        assertEq(address(stakingReader), core.stakingReaderAddress, "deployed staking reader address differs from predicted one");
        //console.log("staking reader deployed at", address(core.stakingReader));
    }

    function _deployStakingStore(GifCore  memory core, bytes32 salt) internal returns (StakingStore stakingStore) {
        bytes memory initCode = abi.encodePacked(type(StakingStore).creationCode);
        bytes memory data = abi.encodePacked(
            StakingStore.initialize.selector, 
            abi.encode(
                core.registryAddress, 
                core.stakingReaderAddress
            )
        );
        ICreateX.Values memory values = ICreateX.Values(0, 0);
        stakingStore = StakingStore(CreateX.deployCreate2AndInit({
            salt: salt, 
            initCode: initCode, 
            data: data, 
            values: values
        }));

        assertEq(address(stakingStore), core.stakingStoreAddress, "deployed staking store address differs from predicted one");
        //console.log("staking store deployed at", address(core.stakingStore));
    }

    function _deployStakingManager(GifCore memory core, address stakingOwner, bytes32 salt) 
        internal 
        returns (StakingManager stakingManager, Staking staking) 
    {
        bytes memory initCode = abi.encodePacked(
            type(StakingManager).creationCode, 
            abi.encode(
                core.registryAddress, 
                core.tokenRegistryAddress, 
                core.stakingStoreAddress, 
                stakingOwner
        ));
        stakingManager = StakingManager(CreateX.deployCreate2(salt, initCode));
        stakingManager.linkToProxy();

        staking = stakingManager.getStaking();
        staking.linkToRegisteredNftId();

        assertEq(address(stakingManager), core.stakingManagerAddress, "deployed staking manager address differs from predicted one");
        assertEq(address(staking), core.stakingAddress, "deployed staking address differs from predicted one");
        //console.log("staking manager deployed at", address(core.stakingManager));
        //console.log("staking deployed at", address(core.staking));
    }


    function deployRelease(
        ReleaseManager releaseManager,
        IServiceAuthorization serviceAuthorization,
        address gifAdmin,
        address gifManager
    )
        public
    {
        vm.startPrank(gifAdmin);
        releaseManager.createNextRelease();
        vm.stopPrank();

        vm.startPrank(gifManager);
        _deployReleaseServices(
            releaseManager,
            serviceAuthorization);
        vm.stopPrank();

        vm.startPrank(gifAdmin);
        releaseManager.activateNextRelease();
        vm.stopPrank();
    }


    function _deployReleaseServices(
        ReleaseManager releaseManager,
        IServiceAuthorization serviceAuthorization
    )
        internal
    {
        (
            address authority, 
            bytes32 salt
        ) = _prepareRelease(
            releaseManager, 
            serviceAuthorization);

        _deployAndRegisterServices(
            releaseManager,
            authority, 
            salt);
    }


    function _prepareRelease(
        ReleaseManager releaseManager,
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
            releaseManager.getState().toInt(), 
            SCHEDULED().toInt(), 
            "unexpected state for releaseManager after createNextRelease");

        // prepare release by providing the service authorization setup to the release manager
        VersionPart release;
        (
            authority, 
            release,
            salt
        ) = releaseManager.prepareNextRelease(
            serviceAuthorization,
            "0x1234");

        // check release manager state after release preparation step
        assertEq(
            releaseManager.getState().toInt(), 
            DEPLOYING().toInt(), 
            "unexpected state for releaseManager after prepareNextRelease");

        // solhint-disable
        console.log("release version", release.toInt());
        console.log("release salt", uint(salt));
        console.log("release access manager deployed at", authority);
        console.log("release services count", serviceAuthorization.getServiceDomains().length);
        console.log("release services remaining (before service registration)", releaseManager.getRemainingServicesToRegister());
        // solhint-enable
    }


    /// @dev Populates the service mapping by deploying all service proxies and service for gif release 3.
    function _deployAndRegisterServices(
        ReleaseManager releaseManager,
        address authority, 
        bytes32 salt
    )
        internal
    {
        address registryAddress = address(releaseManager.getRegistry());

        registryServiceManager = new RegistryServiceManager{salt: salt}(authority, registryAddress, salt);
        registryService = registryServiceManager.getRegistryService();
        registryServiceNftId = _registerService(releaseManager, registryServiceManager, registryService);

        stakingServiceManager = new StakingServiceManager{salt: salt}(authority, registryAddress, salt);
        stakingService = stakingServiceManager.getStakingService();
        stakingServiceNftId = _registerService(releaseManager, stakingServiceManager, stakingService);

        instanceServiceManager = new InstanceServiceManager{salt: salt}(authority, registryAddress, salt);
        instanceService = instanceServiceManager.getInstanceService();
        instanceServiceNftId = _registerService(releaseManager, instanceServiceManager, instanceService);

        // TODO figure out why this service manager deployment is different from the others
        componentServiceManager = new ComponentServiceManager(registryAddress);
        componentService = componentServiceManager.getComponentService();
        componentServiceNftId = _registerService(releaseManager, componentServiceManager, componentService);

        distributionServiceManager = new DistributionServiceManager{salt: salt}(authority, registryAddress, salt);
        distributionService = distributionServiceManager.getDistributionService();
        distributionServiceNftId = _registerService(releaseManager, distributionServiceManager, distributionService);

        pricingServiceManager = new PricingServiceManager{salt: salt}(authority, registryAddress, salt);
        pricingService = pricingServiceManager.getPricingService();
        pricingServiceNftId = _registerService(releaseManager, pricingServiceManager, pricingService);

        bundleServiceManager = new BundleServiceManager{salt: salt}(authority, registryAddress, salt);
        bundleService = bundleServiceManager.getBundleService();
        bundleServiceNftId = _registerService(releaseManager, bundleServiceManager, bundleService);

        poolServiceManager = new PoolServiceManager{salt: salt}(authority, registryAddress, salt);
        poolService = poolServiceManager.getPoolService();
        poolServiceNftId = _registerService(releaseManager, poolServiceManager, poolService);

        oracleServiceManager = new OracleServiceManager{salt: salt}(authority, registryAddress, salt);
        oracleService = oracleServiceManager.getOracleService();
        oracleServiceNftId = _registerService(releaseManager, oracleServiceManager, oracleService);

        productServiceManager = new ProductServiceManager{salt: salt}(authority, registryAddress, salt);
        productService = productServiceManager.getProductService(); 
        productServiceNftId = _registerService(releaseManager, productServiceManager, productService);

        claimServiceManager = new ClaimServiceManager{salt: salt}(authority, registryAddress, salt);
        claimService = claimServiceManager.getClaimService();
        claimServiceNftId = _registerService(releaseManager, claimServiceManager, claimService);

        applicationServiceManager = new ApplicationServiceManager{salt: salt}(authority, registryAddress, salt);
        applicationService = applicationServiceManager.getApplicationService();
        applicationServiceNftId = _registerService(releaseManager, applicationServiceManager, applicationService);

        policyServiceManager = new PolicyServiceManager{salt: salt}(authority, registryAddress, salt);
        policyService = policyServiceManager.getPolicyService();
        policyServiceNftId = _registerService(releaseManager, policyServiceManager, policyService);
    }


    function _registerService(
        ReleaseManager _releaseManager,
        ProxyManager _serviceManager,
        IService _service
    )
        internal
        returns (NftId serviceNftId)
    {
        // register service with release manager
        serviceNftId = _releaseManager.registerService(_service);
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
        console.log("release services remaining", _releaseManager.getRemainingServicesToRegister());
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
