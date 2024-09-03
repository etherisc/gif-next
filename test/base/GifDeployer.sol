// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";

import {IAccess} from "../../contracts/authorization/IAccess.sol";
import {IAccessAdmin} from "../../contracts/authorization/IAccessAdmin.sol";
import {IAuthorization} from "../../contracts/authorization/IAuthorization.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {IRelease} from "../../contracts/registry/IRelease.sol";
import {IServiceAuthorization} from "../../contracts/authorization/IServiceAuthorization.sol";

import {AmountLib} from "../../contracts/type/Amount.sol";
import {ObjectType, ObjectTypeLib} from "../../contracts/type/ObjectType.sol";
import {ChainNft} from "../../contracts/registry/ChainNft.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {ProxyManager} from "../../contracts/upgradeability/ProxyManager.sol";
import {SCHEDULED, DEPLOYING} from "../../contracts/type/StateId.sol";
import {VersionPart, VersionPartLib} from "../../contracts/type/Version.sol";
import {RegistryAuthorization} from "../../contracts/registry/RegistryAuthorization.sol";
import {RoleId} from "../../contracts/type/RoleId.sol";
import {StateIdLib} from "../../contracts/type/StateId.sol";
import {TimestampLib} from "../../contracts/type/Timestamp.sol";

// core contracts
import {Dip} from "../../contracts/mock/Dip.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {RegistryAdmin} from "../../contracts/registry/RegistryAdmin.sol";
import {ReleaseRegistry} from "../../contracts/registry/ReleaseRegistry.sol";
import {ReleaseAdmin} from "../../contracts/registry/ReleaseAdmin.sol";
import {Staking} from "../../contracts/staking/Staking.sol";
import {StakingManager} from "../../contracts/staking/StakingManager.sol";
import {StakingReader} from "../../contracts/staking/StakingReader.sol";
import {StakingStore} from "../../contracts/staking/StakingStore.sol";
import {TokenRegistry} from "../../contracts/registry/TokenRegistry.sol";

// service and proxy contracts
import {IService} from "../../contracts/shared/IService.sol";
import {AccountingService} from "../../contracts/accounting/AccountingService.sol";
import {AccountingServiceManager} from "../../contracts/accounting/AccountingServiceManager.sol";
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
import {RiskService} from "../../contracts/product/RiskService.sol";
import {RiskServiceManager} from "../../contracts/product/RiskServiceManager.sol";
import {RegistryServiceManager} from "../../contracts/registry/RegistryServiceManager.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {StakingService} from "../../contracts/staking/StakingService.sol";
import {StakingServiceManager} from "../../contracts/staking/StakingServiceManager.sol";

contract GifDeployer is Test {

    uint8 public constant GIF_RELEASE = 3;
    string public constant COMMIT_HASH = "1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a";

    struct DeployedServiceInfo {
        NftId nftId;
        address service;
        address proxy;
    }

    // global accounts
    address public globalRegistry = makeAddr("globalRegistry");
    address public registryOwner = makeAddr("registryOwner");
    address public stakingOwner = registryOwner;
    address public gifAdmin = registryOwner;
    address public gifManager = registryOwner;

    // deploy core
    IERC20Metadata public dip;
    Registry public registry;
    TokenRegistry public tokenRegistry;
    ReleaseRegistry public releaseRegistry;
    RegistryAdmin public registryAdmin;
    StakingManager public stakingManager;
    Staking public staking;

    address public registryAddress;
    ChainNft public chainNft;
    NftId public registryNftId;
    NftId public stakingNftId;
    StakingReader public stakingReader;

    // deploy release services
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

    RiskServiceManager public riskServiceManager;
    RiskService public riskService;
    NftId public riskServiceNftId;

    ClaimServiceManager public claimServiceManager;
    ClaimService public claimService;
    NftId public claimServiceNftId;

    ApplicationServiceManager public applicationServiceManager;
    ApplicationService public applicationService;
    NftId public applicationServiceNftId;

    PolicyServiceManager public policyServiceManager;
    PolicyService public policyService;
    NftId public policyServiceNftId;

    AccountingServiceManager public accountingServiceManager;
    AccountingService public accountingService;
    NftId public accountingServiceNftId;

    mapping(ObjectType domain => DeployedServiceInfo info) public serviceForDomain;


    function deployCore(
        address globalRegistry,
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
        // solhint-disable 
        vm.startPrank(gifManager);

        console.log("1) deploy dip token");
        dip = new Dip();

        console.log("2) deploy registry contracts");
        (
            registry,
            tokenRegistry,
            releaseRegistry,
            registryAdmin
        ) = _deployRegistry(dip);

        console.log("3) deploy staking contracts");
        (
            stakingManager,
            staking
        ) = _deployStaking(registry, tokenRegistry);

        console.log("4) complete setup for GIF core contracts");

        console.log("   a) initialize registry");
        registry.initialize(
            address(releaseRegistry),
            address(tokenRegistry),
            address(staking));

        console.log("   b) link staking to its registered nft id");
        staking.linkToRegisteredNftId();

        console.log("   c) complete registry admin setup");
        registryAdmin.completeSetup(
            address(registry),
            address(new RegistryAuthorization(COMMIT_HASH)),
            VersionPartLib.toVersionPart(GIF_RELEASE),
            gifAdmin,
            gifManager);

        console.log("GIF core contracts deployd and setup completed");

        vm.stopPrank();
        // solhint-disable enable
    }


    function _deployRegistry(IERC20Metadata dip)
        internal
        returns (
            Registry registry,
            TokenRegistry tokenRegistry,
            ReleaseRegistry releaseRegistry,
            RegistryAdmin registryAdmin
        )
    {

        console.log("   a) deploy registry admin");
        registryAdmin = new RegistryAdmin();

        console.log("   b) deploy registry");
        registry = new Registry(registryAdmin, globalRegistry);

        console.log("   c) deploy release registry");
        releaseRegistry = new ReleaseRegistry(registry);

        console.log("   d) deploy token registry");
        tokenRegistry = new TokenRegistry(registry, dip);
    }


    function _deployStaking(
        Registry registry,
        TokenRegistry tokenRegistry
    )
        internal 
        returns (
            StakingManager stakingManager,
            Staking staking
        )
    {
        console.log("   a) deploy staking reader");
        StakingReader stakingReader = new StakingReader(registry);

        console.log("   b) deploy staking store");
        StakingStore stakingStore = new StakingStore(registry, stakingReader);

        console.log("   c) deploy staking manager (including upgradeable staking)");
        stakingManager = new StakingManager(
            address(registry),
            address(tokenRegistry),
            address(stakingStore),
            stakingOwner,
            bytes32("")); // salt
        staking = stakingManager.getStaking();

        console.log("   d) initialize staking reader");
        stakingReader.initialize(
            address(staking),
            address(stakingStore));
    }


    function deployRelease(
        ReleaseRegistry releaseRegistry,
        IServiceAuthorization serviceAuthorization,
        address admin,
        address manager
    )
        public
    {
        vm.startPrank(admin);
        releaseRegistry.createNextRelease();
        vm.stopPrank();

        vm.startPrank(manager);
        _deployReleaseServices(
            releaseRegistry,
            serviceAuthorization);
        vm.stopPrank();

        vm.startPrank(admin);
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
        IAccessAdmin admin;
        (
            admin, 
            release,
            salt
        ) = releaseRegistry.prepareNextRelease(
            serviceAuthorization,
            "0x1234");

        authority = admin.authority();

        // check release manager state after release preparation step
        assertEq(
            releaseRegistry.getState(releaseRegistry.getNextVersion()).toInt(), 
            DEPLOYING().toInt(), 
            "unexpected state for releaseRegistry after prepareNextRelease");

        // solhint-disable
        console.log("release version", release.toInt());
        console.log("release salt", uint(salt));
        console.log("release admin deployed at", address(admin));
        console.log("release access manager deployed at", admin.authority());
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

        accountingServiceManager = new AccountingServiceManager{salt: salt}(authority, registryAddress, salt);
        accountingService = accountingServiceManager.getAccountingService();
        accountingServiceNftId = _registerService(releaseRegistry, accountingServiceManager, accountingService);

        componentServiceManager = new ComponentServiceManager{salt: salt}(authority, registryAddress, salt);
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

        riskServiceManager = new RiskServiceManager{salt: salt}(authority, registryAddress, salt);
        riskService = riskServiceManager.getRiskService(); 
        riskServiceNftId = _registerService(releaseRegistry, riskServiceManager, riskService);

        policyServiceManager = new PolicyServiceManager{salt: salt}(authority, registryAddress, salt);
        policyService = policyServiceManager.getPolicyService();
        policyServiceNftId = _registerService(releaseRegistry, policyServiceManager, policyService);

        claimServiceManager = new ClaimServiceManager{salt: salt}(authority, registryAddress, salt);
        claimService = claimServiceManager.getClaimService();
        claimServiceNftId = _registerService(releaseRegistry, claimServiceManager, claimService);

        applicationServiceManager = new ApplicationServiceManager{salt: salt}(authority, registryAddress, salt);
        applicationService = applicationServiceManager.getApplicationService();
        applicationServiceNftId = _registerService(releaseRegistry, applicationServiceManager, applicationService);

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

    function eqObjectInfo(IRegistry.ObjectInfo memory a, IRegistry.ObjectInfo memory b) public pure returns (bool isSame) {

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

    function eqReleaseInfo(IRelease.ReleaseInfo memory release_1, IRelease.ReleaseInfo memory release_2) public pure returns (bool isSame) {

        assertEq(release_1.state.toInt(), release_2.state.toInt(), "getReleaseInfo(version).state returned unexpected value");
        assertEq(release_1.version.toInt(), release_2.version.toInt(), "getReleaseInfo(version).version returned unexpected value");
        assertEq(release_1.salt, release_2.salt, "getReleaseInfo(version).salt returned unexpected value");
        assertEq(address(release_1.auth), address(release_2.auth), "getReleaseInfo(version).auth returned unexpected value");
        assertEq(release_1.activatedAt.toInt(), release_2.activatedAt.toInt(), "getReleaseInfo(version).activatedAt returned unexpected value");
        assertEq(release_1.disabledAt.toInt(), release_2.disabledAt.toInt(), "getReleaseInfo(version).disabledAt returned unexpected value");

        return (
            (release_1.state == release_2.state) &&
            (release_1.version == release_2.version) &&
            (release_1.salt == release_2.salt) &&
            (release_1.auth == release_2.auth) &&
            (release_1.activatedAt == release_2.activatedAt) &&
            (release_1.disabledAt == release_2.disabledAt)
        );
    }

    function zeroReleaseInfo() public pure returns (IRelease.ReleaseInfo memory) {
        return (
            IRelease.ReleaseInfo({
                state: StateIdLib.zero(),
                version: VersionPartLib.toVersionPart(0),
                salt: bytes32(0),
                auth: IServiceAuthorization(address(0)),
                releaseAdmin: address(0),
                activatedAt: TimestampLib.zero(),
                disabledAt: TimestampLib.zero()
            })
        );
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
    }


    function _printCoreSetup() internal view {
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


    function _printAuthz(
        IAccessAdmin aa,
        string memory aaName
    )
        internal
    {
        // solhint-disable no-console
        console.log("==========================================");
        console.log(aaName, registry.getObjectAddress(aa.getLinkedNftId()));
        console.log(aaName, "nft id", aa.getLinkedNftId().toInt());
        console.log(aaName, "owner", aa.getLinkedOwner());
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
}