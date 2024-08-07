// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {FoundryRandom} from "foundry-random/FoundryRandom.sol";
import {console} from "../../lib/forge-std/src/Test.sol";

import {VersionPart, VersionPartLib} from "../../contracts/type/Version.sol";
import {StateIdLib, SCHEDULED, DEPLOYING, DEPLOYED, SKIPPED, ACTIVE, PAUSED} from "../../contracts/type/StateId.sol";
import {TimestampLib, gteTimestamp} from "../../contracts/type/Timestamp.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {RoleId, RoleIdLib} from "../../contracts/type/RoleId.sol";
import {ObjectType, RELEASE, REGISTRY, PRODUCT} from "../../contracts/type/ObjectType.sol";

import {ILifecycle} from "../../contracts/shared/Lifecycle.sol";
import {IService} from "../../contracts/shared/IService.sol";

import {IAccessAdmin} from "../../contracts/authorization/IAccessAdmin.sol";
import {IServiceAuthorization} from "../../contracts/authorization/IServiceAuthorization.sol";
import {AccessManagerCloneable} from "../../contracts/authorization/AccessManagerCloneable.sol";

import {RegistryAdmin} from "../../contracts/registry/RegistryAdmin.sol";
import {ReleaseAdmin} from "../../contracts/registry/ReleaseAdmin.sol";
import {IRegistry} from "../../contracts/registry/Registry.sol";
import {ReleaseRegistry} from "../../contracts/registry/ReleaseRegistry.sol";
import {ChainNft} from "../../contracts/registry/ChainNft.sol";

import {GifDeployer} from "../base/GifDeployer.sol";

import {ServiceAuthorizationMock, ServiceAuthorizationMockWithRegistryService} from "../mock/ServiceAuthorizationMock.sol";
import {NftOwnableMock} from "../mock/NftOwnableMock.sol";
import {ServiceMock, ServiceMockWithRegistryDomainV3, ServiceMockWithRegistryDomainV4, ServiceMockWithRegistryDomainV5} from "../mock/ServiceMock.sol";

contract ReleaseRegistryConcreteTest is GifDeployer, FoundryRandom {

    // keep identical to ReleaseRegistry events
    event LogReleaseCreation(VersionPart version, bytes32 salt); 
    event LogReleaseActivation(VersionPart version);
    event LogReleaseDisabled(VersionPart version);
    event LogReleaseEnabled(VersionPart version);

    // keep identical to IRegistry events
    event LogServiceRegistration(VersionPart majorVersion, ObjectType serviceDomain);

    address public globalRegistry = makeAddr("globalRegistry"); // address of global registry when not on mainnet
    address public gifAdmin = makeAddr("gifAdmin");
    address public gifManager = makeAddr("gifManager");
    address public stakingOwner = makeAddr("stakingOwner");
    address public outsider = makeAddr("outsider");

    RegistryAdmin registryAdmin;
    IRegistry registry;
    ChainNft chainNft;
    ReleaseRegistry releaseRegistry;
    NftId registryNftId;

    function setUp() public virtual
    {
        (
            ,//dip,
            registry,
            ,//tokenRegistry,
            releaseRegistry,
            registryAdmin,
            //stakingManager,
            ,//staking
        ) = deployCore(
            globalRegistry,
            gifAdmin,
            gifManager,
            stakingOwner);

        chainNft = ChainNft(registry.getChainNftAddress());
        registryNftId = registry.getNftId();
    }

    function _prepareServiceWithRegistryDomain(VersionPart releaseVersion, ReleaseAdmin releaseAdmin)
         public
         returns (IService service)
    {
        if(releaseVersion.toInt() == 3) {
            service = new ServiceMockWithRegistryDomainV3(
                NftIdLib.zero(), 
                registryNftId, 
                false, // isInterceptor
                gifManager,
                releaseAdmin.authority());
        } else if(releaseVersion.toInt() == 4) {
            service = new ServiceMockWithRegistryDomainV4(
                NftIdLib.zero(), 
                registryNftId, 
                false, // isInterceptor
                gifManager,
                releaseAdmin.authority());
        } else if(releaseVersion.toInt() == 5) {
            service = new ServiceMockWithRegistryDomainV5(
                NftIdLib.zero(), 
                registryNftId, 
                false, // isInterceptor
                gifManager,
                releaseAdmin.authority());
        }
    }

    function _checkReleaseInfo(IRegistry.ReleaseInfo memory info) public view 
    {
        if(info.state == SCHEDULED()) {
            assertTrue(info.version.toInt() >= 3, "Test error: unexpected version #1");
            assertTrue(info.salt == bytes32(0), "Test error: unexpected salt #1");
            assertTrue(address(info.auth) == address(0), "Test error: unexpected auth #1");
            assertTrue(info.activatedAt.eqz(), "Test error: unexpected activatedAt #1");
            assertTrue(info.disabledAt.eqz(), "Test error: unexpected disabledAt #1");
        } else if (info.state == DEPLOYING() || info.state == DEPLOYED()) {
            assertTrue(info.version.toInt() >= 3, "Test error: unexpected version #2");
            assertTrue(info.salt != bytes32(0), "Test error: unexpected salt #2");
            assertTrue(address(info.auth) != address(0), "Test error: unexpected auth #2");
            assertTrue(info.auth.getRelease() == info.version, "Test error: unexpected auth version #1");
            assertTrue(info.auth.getServiceDomains().length > 0, "Test error: unexpected auth domain num #1");
            assertTrue(info.activatedAt.eqz(), "Test error: unexpected activatedAt #2");
            assertTrue(info.disabledAt.eqz(), "Test error: unexpected disabledAt #2");
        } else if (info.state == ACTIVE()) {
            assertTrue(info.version.toInt() >= 3, "Test error: unexpected version #3");
            assertTrue(info.salt != bytes32(0), "Test error: unexpected salt #3");
            assertTrue(address(info.auth) != address(0), "Test error: unexpected auth #3");
            assertTrue(info.auth.getRelease() == info.version, "Test error: unexpected auth version #2");
            assertTrue(info.auth.getServiceDomains().length > 0, "Test error: unexpected auth domain num #2");
            assertTrue(gteTimestamp(TimestampLib.blockTimestamp(), info.activatedAt), "Test error: unexpected activatedAt #3");
            assertTrue(info.disabledAt.eqz(), "Test error: unexpected disabledAt #3");
        } else if (info.state == PAUSED()) {
            assertTrue(info.version.toInt() >= 3, "Test error: unexpected version #4");
            assertTrue(info.salt != bytes32(0), "Test error: unexpected salt #4");
            assertTrue(address(info.auth) != address(0), "Test error: unexpected auth #4");
            assertTrue(info.auth.getRelease() == info.version, "Test error: unexpected auth version #3");
            assertTrue(info.auth.getServiceDomains().length > 0, "Test error: unexpected auth domain num #3");
            assertTrue(gteTimestamp(TimestampLib.blockTimestamp(), info.activatedAt), "Test error: unexpected activatedAt #4");
            assertTrue(gteTimestamp(TimestampLib.blockTimestamp(), info.disabledAt), "Test error: unexpected disabledAt #4");
            assertTrue(gteTimestamp(info.disabledAt, info.activatedAt), "Test error: disabledAt < activatedAt #4");
        } else if (info.state == SKIPPED()) {
            assertTrue(info.version.toInt() >= 3, "Test error: unexpected version #5");
            // salt can have any values
            if(address(info.auth) != address(0)) {
                assertTrue(info.auth.getRelease() == info.version, "Test error: unexpected auth version #4");
                assertTrue(info.auth.getServiceDomains().length > 0, "Test error: unexpected auth domain num #4");
            }
            assertTrue(info.activatedAt.eqz(), "Test error: unexpected activatedAt #5");
            assertTrue(info.disabledAt.eqz(), "Test error: unexpected disabledAt #5");
        } else if (info.state == StateIdLib.zero()) {
            assertTrue(info.version.toInt() == 0, "Test error: unexpected version #6");
            assertTrue(info.salt == bytes32(0), "Test error: unexpected salt #6");
            assertTrue(address(info.auth) == address(0), "Test error: unexpected auth #6");
            assertTrue(info.activatedAt.eqz(), "Test error: unexpected activatedAt #6");
            assertTrue(info.disabledAt.eqz(), "Test error: unexpected disabledAt #6");
        } else {
            console.log("Unexpected state ", info.state.toInt());
            assertTrue(false, "Test error: unexpected state");
        }        
    }

    // assert by version getters
    function _assert_releaseRegistry_getters(VersionPart version, IRegistry.ReleaseInfo memory info) public view
    {
        _checkReleaseInfo(info);

        assertEq(releaseRegistry.isActiveRelease(version), (info.activatedAt.gtz() && info.disabledAt.eqz()), "isActiveRelease() return unxpected value");
        assertTrue(eqReleaseInfo(releaseRegistry.getReleaseInfo(version), info), "getReleaseInfo() return unxpected value");  
        assertEq(releaseRegistry.getState(version).toInt(), info.state.toInt(), "getState() return unexpected value #1");
        assertEq(address(releaseRegistry.getServiceAuthorization(version)), address(info.auth), "getServiceAuthorization() return unexpected value #1");    
    }

    function test_releaseRegistry_setUp() public view
    {
        for(uint i = 0; i <= releaseRegistry.INITIAL_GIF_VERSION() + 1; i++) {
            _assert_releaseRegistry_getters(VersionPartLib.toVersionPart(i), zeroReleaseInfo());
        }

        assertEq(releaseRegistry.releases(), 0, "releases() return unexpected value");
        assertEq(releaseRegistry.getNextVersion().toInt(), releaseRegistry.INITIAL_GIF_VERSION() - 1, "getNextVersion() return unexpected value");
        assertEq(releaseRegistry.getLatestVersion().toInt(), 0, "getLatestVersion() return unexpected value");

        assertEq(releaseRegistry.getRemainingServicesToRegister(), 0, "getRemainingServicesToRegister() return unexpected value");

        assertEq(releaseRegistry.getRegistryAdmin(), address(registryAdmin), "getRegistryAdmin() return unexpected value");
        assertEq(address(releaseRegistry.getRegistry()), address(registry), "getRegistry() return unexpected value");
    }

    //------------------------ create release ------------------------//

    function test_releaseRegistry_createRelease_byNotAuthorizedCaller() public
    {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, gifManager));
        vm.prank(gifManager);
        releaseRegistry.createNextRelease();

        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, stakingOwner));
        vm.prank(stakingOwner);
        VersionPart version = releaseRegistry.createNextRelease();

        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, outsider));
        vm.prank(outsider);
        releaseRegistry.createNextRelease();
    }

    function test_releaseRegistry_createRelease_createInitialReleaseHappyCase() public
    {
        VersionPart newReleaseVersion = VersionPartLib.toVersionPart(releaseRegistry.INITIAL_GIF_VERSION());
        VersionPart previousReleaseVersion = VersionPartLib.toVersionPart(releaseRegistry.INITIAL_GIF_VERSION() - 1);

        // pre checks
        _assert_releaseRegistry_getters(previousReleaseVersion, zeroReleaseInfo());
        _assert_releaseRegistry_getters(newReleaseVersion, zeroReleaseInfo());

        assertEq(releaseRegistry.releases(), 0, "releases() return unexpected value #1");
        assertEq(releaseRegistry.getNextVersion().toInt(), previousReleaseVersion.toInt(), "getNextVersion() return unexpected value #1");
        assertEq(releaseRegistry.getLatestVersion().toInt(), 0, "getLatestVersion() return unexpected value #1");

        // create release
        vm.prank(gifAdmin);
        VersionPart version = releaseRegistry.createNextRelease();

        // post checks
        assertEq(version.toInt(), newReleaseVersion.toInt(), "createNextRelease() return unexpected value");

        _assert_releaseRegistry_getters(
            newReleaseVersion,
            IRegistry.ReleaseInfo(
                    SCHEDULED(),
                    newReleaseVersion,
                    bytes32(0),
                    IServiceAuthorization(address(0)),
                    IAccessAdmin(address(0)),
                    TimestampLib.zero(),
                    TimestampLib.zero()
                ));
        _assert_releaseRegistry_getters(previousReleaseVersion, zeroReleaseInfo());
        
        assertEq(releaseRegistry.releases(), 1, "releases() return unexpected value #2");
        assertEq(releaseRegistry.getNextVersion().toInt(), newReleaseVersion.toInt(), "getNextVersion() return unexpected value #2");
        assertEq(releaseRegistry.getLatestVersion().toInt(), 0, "getLatestVersion() return unexpected value #2");

        // check latest version
        assertEq(version.toInt(), releaseRegistry.getVersion(0).toInt(), "getReleaseVersion() return unexpected value");
        assertEq(releaseRegistry.getReleaseInfo(version).state.toInt(), SCHEDULED().toInt(), "getReleaseInfo() not SCHEDULED");
        assertEq(releaseRegistry.isActiveRelease(version), false, "isActiveRelease() returned unexpected value");
    }

    function test_releaseRegistry_createRelease_whenReleaseScheduledHappyCase() public 
    {
        VersionPart nextVersion = VersionPartLib.toVersionPart(releaseRegistry.INITIAL_GIF_VERSION());
        VersionPart prevVersion = VersionPartLib.toVersionPart(releaseRegistry.INITIAL_GIF_VERSION() - 1);
        IRegistry.ReleaseInfo memory nextReleaseInfo;
        IRegistry.ReleaseInfo memory prevReleaseInfo;

        for(uint i = 0; i <= 10; i++) 
        {
            // create - skip
            vm.prank(gifAdmin);
            VersionPart createdVersion = releaseRegistry.createNextRelease();

            nextReleaseInfo.state = SCHEDULED();
            nextReleaseInfo.version = nextVersion;
            if(i > 0) {
                prevReleaseInfo.state = SKIPPED();
            }

            // check create
            assertEq(createdVersion.toInt(), nextVersion.toInt(), "createNextRelease() return unexpected value");

            _assert_releaseRegistry_getters(nextVersion, nextReleaseInfo);
            _assert_releaseRegistry_getters(prevVersion, prevReleaseInfo);

            assertEq(releaseRegistry.releases(), i + 1, "releases() return unexpected value #1");
            assertEq(releaseRegistry.getNextVersion().toInt(), nextReleaseInfo.version.toInt(), "getNextVersion() return unexpected value #1");
            assertEq(releaseRegistry.getLatestVersion().toInt(), 0, "getLatestVersion() return unexpected value #1");

            // check latest version
            assertEq(createdVersion.toInt(), releaseRegistry.getVersion(i).toInt(), "getReleaseVersion() return unexpected value");
            assertEq(releaseRegistry.getReleaseInfo(createdVersion).state.toInt(), SCHEDULED().toInt(), "getReleaseInfo() not SCHEDULED");
            assertEq(releaseRegistry.isActiveRelease(createdVersion), false, "isActiveRelease() returned unexpected value");
            
            prevVersion = nextVersion;
            nextVersion = VersionPartLib.toVersionPart(nextVersion.toInt() + 1);
            prevReleaseInfo = nextReleaseInfo;
            nextReleaseInfo = zeroReleaseInfo();
        }
    }

    function test_releaseRegistry_createRelease_whenReleaseDeployingHappyCase() public 
    {
        VersionPart nextVersion = VersionPartLib.toVersionPart(releaseRegistry.INITIAL_GIF_VERSION());
        VersionPart prevVersion = VersionPartLib.toVersionPart(releaseRegistry.INITIAL_GIF_VERSION() - 1);
        IRegistry.ReleaseInfo memory nextReleaseInfo;
        IRegistry.ReleaseInfo memory prevReleaseInfo;

        for(uint i = 0; i <= 10; i++) 
        {
            vm.prank(gifAdmin);
            VersionPart createdVersion = releaseRegistry.createNextRelease();

            {
                // create - skip
                nextReleaseInfo.state = SCHEDULED();
                nextReleaseInfo.version = nextVersion;
                if(i > 0) {
                    prevReleaseInfo.state = SKIPPED();

                    assertTrue(AccessManagerCloneable(prevReleaseInfo.admin.authority()).isLocked(), "isLocked() return unexpected value");
                }

                // check create
                assertEq(createdVersion.toInt(), nextVersion.toInt(), "createNextRelease() return unexpected value");

                _assert_releaseRegistry_getters(nextVersion, nextReleaseInfo);
                _assert_releaseRegistry_getters(prevVersion, prevReleaseInfo);

                assertEq(releaseRegistry.releases(), i + 1, "releases() return unexpected value #1");
                assertEq(releaseRegistry.getNextVersion().toInt(), nextReleaseInfo.version.toInt(), "getNextVersion() return unexpected value #1");
                assertEq(releaseRegistry.getLatestVersion().toInt(), 0, "getLatestVersion() return unexpected value #1");

                // check latest version
                assertEq(createdVersion.toInt(), releaseRegistry.getVersion(i).toInt(), "getReleaseVersion() return unexpected value");
                assertEq(releaseRegistry.getReleaseInfo(createdVersion).state.toInt(), SCHEDULED().toInt(), "getReleaseInfo() not SCHEDULED");
                assertEq(releaseRegistry.isActiveRelease(createdVersion), false, "isActiveRelease() returned unexpected value");
            }

            {
                // prepare
                IServiceAuthorization nextAuthMock = new ServiceAuthorizationMockWithRegistryService(nextVersion);
                bytes32 nextSalt = bytes32(randomNumber(type(uint256).max)); 

                vm.expectEmit(address(releaseRegistry));
                emit LogReleaseCreation(nextVersion, nextSalt);

                vm.prank(gifManager);
                (
                    IAccessAdmin preparedAdmin, 
                    VersionPart preparedVersion, 
                    bytes32 preparedSalt
                ) = releaseRegistry.prepareNextRelease(nextAuthMock, nextSalt);

                nextReleaseInfo.state = DEPLOYING();
                nextReleaseInfo.salt = nextSalt;
                nextReleaseInfo.auth = nextAuthMock;
                nextReleaseInfo.admin = preparedAdmin;

                // check prepare
                // TODO more release admin checks
                // precalculate address and compare with prepared admin address
                // precalculate and compare release access manager from prepared address
                assertEq(preparedVersion.toInt(), nextVersion.toInt(), "prepareNextRelease() return unexpected releaseVersion");
                assertEq(preparedSalt, nextSalt, "prepareNextRelease() return unexpected releaseSalt");
                assertTrue(AccessManagerCloneable(nextReleaseInfo.admin.authority()).isLocked(), "isLocked() return unexpected value");
                if(i > 0) {
                    assertTrue(AccessManagerCloneable(prevReleaseInfo.admin.authority()).isLocked(), "isLocked() return unexpected value");
                }

                _assert_releaseRegistry_getters(nextVersion, nextReleaseInfo);
                _assert_releaseRegistry_getters(prevVersion, prevReleaseInfo);

                assertEq(releaseRegistry.releases(), i + 1, "releases() return unexpected value #2");
                assertEq(releaseRegistry.getNextVersion().toInt(), nextReleaseInfo.version.toInt(), "getNextVersion() return unexpected value #2");
                assertEq(releaseRegistry.getLatestVersion().toInt(), 0, "getLatestVersion() return unexpected value #2");

                // check latest version
                assertEq(createdVersion.toInt(), releaseRegistry.getVersion(i).toInt(), "getReleaseVersion() return unexpected value");
                assertEq(releaseRegistry.getReleaseInfo(createdVersion).state.toInt(), DEPLOYING().toInt(), "getReleaseInfo() not DEPLOYING");
                assertEq(releaseRegistry.isActiveRelease(createdVersion), false, "isActiveRelease() returned unexpected value");
            }

            prevVersion = nextVersion;
            nextVersion = VersionPartLib.toVersionPart(nextVersion.toInt() + 1);
            prevReleaseInfo = nextReleaseInfo;
            nextReleaseInfo = zeroReleaseInfo();
        }  
    }

    function test_releaseRegistry_createRelease_whenReleaseDeployedHappyCase() public 
    {
        VersionPart nextVersion = VersionPartLib.toVersionPart(releaseRegistry.INITIAL_GIF_VERSION());
        VersionPart prevVersion = VersionPartLib.toVersionPart(releaseRegistry.INITIAL_GIF_VERSION() - 1);
        IRegistry.ReleaseInfo memory nextReleaseInfo;
        IRegistry.ReleaseInfo memory prevReleaseInfo;

        IService service;

        for(uint i = 0; i <= 2; i++) 
        {
            vm.prank(gifAdmin);
            VersionPart createdVersion = releaseRegistry.createNextRelease();

            {
                // create - skip
                nextReleaseInfo.state = SCHEDULED();
                nextReleaseInfo.version = nextVersion;
                if(i > 0) {
                    prevReleaseInfo.state = SKIPPED();

                    assertTrue(AccessManagerCloneable(prevReleaseInfo.admin.authority()).isLocked(), "isLocked() return unexpected value");
                }

                // check create
                assertEq(createdVersion.toInt(), nextVersion.toInt(), "createNextRelease() return unexpected value");
                if(i > 0) {
                    assertTrue(AccessManagerCloneable(prevReleaseInfo.admin.authority()).isLocked(), "isLocked() return unexpected value");
                }

                _assert_releaseRegistry_getters(nextVersion, nextReleaseInfo);
                _assert_releaseRegistry_getters(prevVersion, prevReleaseInfo);

                assertEq(releaseRegistry.releases(), i + 1, "releases() return unexpected value #1");
                assertEq(releaseRegistry.getNextVersion().toInt(), nextReleaseInfo.version.toInt(), "getNextVersion() return unexpected value #1");
                assertEq(releaseRegistry.getLatestVersion().toInt(), 0, "getLatestVersion() return unexpected value #1");

                // check latest version
                assertEq(createdVersion.toInt(), releaseRegistry.getVersion(i).toInt(), "getReleaseVersion() return unexpected value");
                assertEq(releaseRegistry.getReleaseInfo(createdVersion).state.toInt(), SCHEDULED().toInt(), "getReleaseInfo() not DEPLOYING");
                assertEq(releaseRegistry.isActiveRelease(createdVersion), false, "isActiveRelease() returned unexpected value");
            }

            {
                // prepare
                IServiceAuthorization nextAuthMock = new ServiceAuthorizationMockWithRegistryService(nextVersion);
                bytes32 nextSalt = bytes32(randomNumber(type(uint256).max)); 

                vm.prank(gifManager);
                (
                    IAccessAdmin preparedAdmin, 
                    VersionPart preparedVersion, 
                    bytes32 preparedSalt
                ) = releaseRegistry.prepareNextRelease(nextAuthMock, nextSalt);

                nextReleaseInfo.state = DEPLOYING();
                nextReleaseInfo.salt = nextSalt;
                nextReleaseInfo.auth = nextAuthMock;
                nextReleaseInfo.admin = preparedAdmin;

                // check prepare
                assertEq(preparedVersion.toInt(), nextVersion.toInt(), "prepareNextRelease() return unexpected releaseVersion");
                assertEq(preparedSalt, nextSalt, "prepareNextRelease() return unexpected releaseSalt");
                assertTrue(AccessManagerCloneable(nextReleaseInfo.admin.authority()).isLocked(), "isLocked() return unexpected value");
                if(i > 0) {
                    assertTrue(AccessManagerCloneable(prevReleaseInfo.admin.authority()).isLocked(), "isLocked() return unexpected value");
                }

                _assert_releaseRegistry_getters(nextVersion, nextReleaseInfo);
                _assert_releaseRegistry_getters(prevVersion, prevReleaseInfo);

                assertEq(releaseRegistry.releases(), i + 1, "releases() return unexpected value #2");
                assertEq(releaseRegistry.getNextVersion().toInt(), nextReleaseInfo.version.toInt(), "getNextVersion() return unexpected value #2");
                assertEq(releaseRegistry.getLatestVersion().toInt(), 0, "getLatestVersion() return unexpected value #2");

                // check latest version
                assertEq(createdVersion.toInt(), releaseRegistry.getVersion(i).toInt(), "getReleaseVersion() return unexpected value");
                assertEq(releaseRegistry.getReleaseInfo(createdVersion).state.toInt(), DEPLOYING().toInt(), "getReleaseInfo() not DEPLOYING");
                assertEq(releaseRegistry.isActiveRelease(createdVersion), false, "isActiveRelease() returned unexpected value");
            }

            {
                // deploy (register all(1) services)
                service = _prepareServiceWithRegistryDomain(nextReleaseInfo.version, ReleaseAdmin(address(nextReleaseInfo.admin)));
                assertFalse(registry.isRegisteredService(address(service)), "isRegisteredService() return unexpected value #1");

                uint256 expectedNftId = chainNft.getNextTokenId();

                // TODO add AccessAdmin logs
                vm.expectEmit(address(registry));
                emit LogServiceRegistration(nextVersion, REGISTRY());

                vm.prank(gifManager);
                NftId serviceNftId = releaseRegistry.registerService(service);

                nextReleaseInfo.state = DEPLOYED();
                RoleId expectedServiceRoleId = RoleIdLib.roleForTypeAndVersion(REGISTRY(), nextVersion);

                // check registration
                assertEq(serviceNftId.toInt(), expectedNftId, "registerService() return unexpected value");
                assertTrue(AccessManagerCloneable(nextReleaseInfo.admin.authority()).isLocked(), "isLocked() return unexpected value");
                assertTrue(nextReleaseInfo.admin.hasRole(address(service), expectedServiceRoleId), "hasRole() return unexpected value");
                assertTrue(nextReleaseInfo.admin.targetExists(address(service)), "targetExists() return unexpected value");
                assertTrue(registry.isRegisteredService(address(service)), "isRegisteredService() return unexpected value #2");
                assertFalse(registryAdmin.targetExists(address(service)), "targetExists() return unexpected value");

                _assert_releaseRegistry_getters(nextVersion, nextReleaseInfo);
                _assert_releaseRegistry_getters(prevVersion, prevReleaseInfo);

                assertEq(releaseRegistry.releases(), i + 1, "releases() return unexpected value #3");
                assertEq(releaseRegistry.getNextVersion().toInt(), nextReleaseInfo.version.toInt(), "getNextVersion() return unexpected value #3");
                assertEq(releaseRegistry.getLatestVersion().toInt(), 0, "getLatestVersion() return unexpected value #3");

                // check latest version
                assertEq(createdVersion.toInt(), releaseRegistry.getVersion(i).toInt(), "getReleaseVersion() return unexpected value");
                assertEq(releaseRegistry.getReleaseInfo(createdVersion).state.toInt(), DEPLOYED().toInt(), "getReleaseInfo() not DEPLOYED");
                assertEq(releaseRegistry.isActiveRelease(createdVersion), false, "isActiveRelease() returned unexpected value");
            }

            prevVersion = nextVersion;
            nextVersion = VersionPartLib.toVersionPart(nextVersion.toInt() + 1);
            prevReleaseInfo = nextReleaseInfo;
            nextReleaseInfo = zeroReleaseInfo();
        }
    }

    function test_releaseRegistry_createRelease_whenReleaseActiveHappyCase() public 
    {
        VersionPart nextVersion = VersionPartLib.toVersionPart(releaseRegistry.INITIAL_GIF_VERSION());
        VersionPart prevVersion = VersionPartLib.toVersionPart(releaseRegistry.INITIAL_GIF_VERSION() - 1);
        IRegistry.ReleaseInfo memory nextReleaseInfo;
        IRegistry.ReleaseInfo memory prevReleaseInfo;

        IService service;

        for(uint i = 0; i <= 2; i++) 
        {
            vm.prank(gifAdmin);
            VersionPart createdVersion = releaseRegistry.createNextRelease();

            {
                 // create - skip
                nextReleaseInfo.state = SCHEDULED();
                nextReleaseInfo.version = nextVersion;

                // check create
                assertEq(createdVersion.toInt(), nextVersion.toInt(), "createNextRelease() return unexpected value");
                if(i > 0) {
                    assertFalse(AccessManagerCloneable(prevReleaseInfo.admin.authority()).isLocked(), "isLocked() return unexpected value");
                }

                _assert_releaseRegistry_getters(nextVersion, nextReleaseInfo);
                _assert_releaseRegistry_getters(prevVersion, prevReleaseInfo);

                assertEq(releaseRegistry.releases(), i + 1, "releases() return unexpected value #1");
                assertEq(releaseRegistry.getNextVersion().toInt(), nextReleaseInfo.version.toInt(), "getNextVersion() return unexpected value #1");
                assertEq(releaseRegistry.getLatestVersion().toInt(), prevReleaseInfo.version.toInt(), "getLatestVersion() return unexpected value #1");
            }

            {
                // prepare
                IServiceAuthorization nextAuthMock = new ServiceAuthorizationMockWithRegistryService(nextVersion);
                bytes32 nextSalt = bytes32(randomNumber(type(uint256).max)); 

                vm.prank(gifManager);
                (
                    IAccessAdmin preparedAdmin, 
                    VersionPart preparedVersion, 
                    bytes32 preparedSalt
                ) = releaseRegistry.prepareNextRelease(nextAuthMock, nextSalt);

                nextReleaseInfo.state = DEPLOYING();
                nextReleaseInfo.salt = nextSalt;
                nextReleaseInfo.auth = nextAuthMock;
                nextReleaseInfo.admin = preparedAdmin;

                // check prepare
                assertEq(preparedVersion.toInt(), nextVersion.toInt(), "prepareNextRelease() return unexpected releaseVersion");
                assertEq(preparedSalt, nextSalt, "prepareNextRelease() return unexpected releaseSalt");
                assertTrue(AccessManagerCloneable(nextReleaseInfo.admin.authority()).isLocked(), "isLocked() return unexpected value");
                if(i > 0) {
                    assertFalse(AccessManagerCloneable(prevReleaseInfo.admin.authority()).isLocked(), "isLocked() return unexpected value");
                }

                _assert_releaseRegistry_getters(nextVersion, nextReleaseInfo);
                _assert_releaseRegistry_getters(prevVersion, prevReleaseInfo);

                assertEq(releaseRegistry.releases(), i + 1, "releases() return unexpected value #2");
                assertEq(releaseRegistry.getNextVersion().toInt(), nextReleaseInfo.version.toInt(), "getNextVersion() return unexpected value #2");
                assertEq(releaseRegistry.getLatestVersion().toInt(), prevReleaseInfo.version.toInt(), "getLatestVersion() return unexpected value #2");
            }

            {
                // deploy (register all(1) services)
                service = _prepareServiceWithRegistryDomain(nextReleaseInfo.version, ReleaseAdmin(address(nextReleaseInfo.admin)));
                assertFalse(registry.isRegisteredService(address(service)), "isRegisteredService() return unexpected value #1");

                uint256 expectedNftId = chainNft.getNextTokenId();

                // TODO add AccessAdmin logs
                vm.expectEmit(address(registry));
                emit LogServiceRegistration(nextVersion, REGISTRY());

                vm.prank(gifManager);
                NftId serviceNftId = releaseRegistry.registerService(service);

                nextReleaseInfo.state = DEPLOYED();
                RoleId expectedServiceRoleId = RoleIdLib.roleForTypeAndVersion(REGISTRY(), nextVersion);

                // check registration
                assertEq(serviceNftId.toInt(), expectedNftId, "registerService() return unexpected value");
                assertTrue(AccessManagerCloneable(nextReleaseInfo.admin.authority()).isLocked(), "isLocked() return unexpected value");
                assertTrue(nextReleaseInfo.admin.hasRole(address(service), expectedServiceRoleId), "hasRole() return unexpected value");
                assertTrue(nextReleaseInfo.admin.targetExists(address(service)), "targetExists() return unexpected value");
                assertTrue(registry.isRegisteredService(address(service)), "isRegisteredService() return unexpected value #2");
                assertFalse(registryAdmin.targetExists(address(service)), "targetExists() return unexpected value");

                _assert_releaseRegistry_getters(nextVersion, nextReleaseInfo);
                _assert_releaseRegistry_getters(prevVersion, prevReleaseInfo);

                assertEq(releaseRegistry.releases(), i + 1, "releases() return unexpected value #3");
                assertEq(releaseRegistry.getNextVersion().toInt(), nextReleaseInfo.version.toInt(), "getNextVersion() return unexpected value #3");
                assertEq(releaseRegistry.getLatestVersion().toInt(), prevReleaseInfo.version.toInt(), "getLatestVersion() return unexpected value #3");
            }

            {
                // activate
                vm.expectEmit(address(releaseRegistry));
                emit LogReleaseActivation(nextVersion);

                // TODO add AccessAdmin logs

                vm.prank(gifAdmin);
                releaseRegistry.activateNextRelease();

                nextReleaseInfo.state = ACTIVE();
                nextReleaseInfo.activatedAt = TimestampLib.blockTimestamp();
                RoleId expectedServiceRoleIdForAllVersions = RoleIdLib.roleForTypeAndAllVersions(REGISTRY());

                // check activation
                assertFalse(AccessManagerCloneable(nextReleaseInfo.admin.authority()).isLocked(), "isLocked() return unexpected value");
                assertTrue(registryAdmin.hasRole(address(service), expectedServiceRoleIdForAllVersions), "hasRole() return unexpected value");

                _assert_releaseRegistry_getters(nextVersion, nextReleaseInfo);
                _assert_releaseRegistry_getters(prevVersion, prevReleaseInfo);

                assertEq(releaseRegistry.releases(), i + 1, "releases() return unexpected value #4");
                assertEq(releaseRegistry.getNextVersion().toInt(), nextReleaseInfo.version.toInt(), "getNextVersion() return unexpected value #4");
                assertEq(releaseRegistry.getLatestVersion().toInt(), nextReleaseInfo.version.toInt(), "getLatestVersion() return unexpected value #4");

                // check latest version
                assertEq(createdVersion.toInt(), releaseRegistry.getVersion(i).toInt(), "getReleaseVersion() return unexpected value");
                assertEq(releaseRegistry.getReleaseInfo(createdVersion).state.toInt(), ACTIVE().toInt(), "getReleaseInfo() not ACTIVE");
                assertEq(releaseRegistry.isActiveRelease(createdVersion), true, "isActiveRelease() returned unexpected value");
            }

            prevVersion = nextVersion;
            nextVersion = VersionPartLib.toVersionPart(nextVersion.toInt() + 1);
            prevReleaseInfo = nextReleaseInfo;
            nextReleaseInfo = zeroReleaseInfo();
        }        
    }

    function test_releaseRegistry_createRelease_whenReleasePausedHappyCase() public 
    {
        VersionPart nextVersion = VersionPartLib.toVersionPart(releaseRegistry.INITIAL_GIF_VERSION());
        VersionPart prevVersion = VersionPartLib.toVersionPart(releaseRegistry.INITIAL_GIF_VERSION() - 1);
        IRegistry.ReleaseInfo memory nextReleaseInfo;
        IRegistry.ReleaseInfo memory prevReleaseInfo;

        IService service;

        for(uint i = 0; i <= 2; i++) 
        {
            {
                // create - skip
                vm.prank(gifAdmin);
                VersionPart createdVersion = releaseRegistry.createNextRelease();

                nextReleaseInfo.state = SCHEDULED();
                nextReleaseInfo.version = nextVersion;

                // check create
                assertEq(createdVersion.toInt(), nextVersion.toInt(), "createNextRelease() return unexpected value");
                if(i > 0) {
                    assertTrue(AccessManagerCloneable(prevReleaseInfo.admin.authority()).isLocked(), "isLocked() return unexpected value");
                }

                _assert_releaseRegistry_getters(nextVersion, nextReleaseInfo);
                _assert_releaseRegistry_getters(prevVersion, prevReleaseInfo);

                assertEq(releaseRegistry.releases(), i + 1, "releases() return unexpected value #1");
                assertEq(releaseRegistry.getNextVersion().toInt(), nextReleaseInfo.version.toInt(), "getNextVersion() return unexpected value #1");
                assertEq(releaseRegistry.getLatestVersion().toInt(), prevReleaseInfo.version.toInt(), "getLatestVersion() return unexpected value #1");
            }

            {
                // prepare
                IServiceAuthorization nextAuthMock = new ServiceAuthorizationMockWithRegistryService(nextVersion);
                bytes32 nextSalt = bytes32(randomNumber(type(uint256).max)); 

                vm.prank(gifManager);
                (
                    IAccessAdmin preparedAdmin, 
                    VersionPart preparedVersion, 
                    bytes32 preparedSalt
                ) = releaseRegistry.prepareNextRelease(nextAuthMock, nextSalt);

                nextReleaseInfo.state = DEPLOYING();
                nextReleaseInfo.salt = nextSalt;
                nextReleaseInfo.auth = nextAuthMock;
                nextReleaseInfo.admin = preparedAdmin;

                // check prepare
                assertEq(preparedVersion.toInt(), nextVersion.toInt(), "prepareNextRelease() return unexpected releaseVersion");
                assertEq(preparedSalt, nextSalt, "prepareNextRelease() return unexpected releaseSalt");
                assertTrue(AccessManagerCloneable(nextReleaseInfo.admin.authority()).isLocked(), "isLocked() return unexpected value");
                if(i > 0) {
                    assertTrue(AccessManagerCloneable(prevReleaseInfo.admin.authority()).isLocked(), "isLocked() return unexpected value");
                }

                _assert_releaseRegistry_getters(nextVersion, nextReleaseInfo);
                _assert_releaseRegistry_getters(prevVersion, prevReleaseInfo);

                assertEq(releaseRegistry.releases(), i + 1, "releases() return unexpected value #2");
                assertEq(releaseRegistry.getNextVersion().toInt(), nextReleaseInfo.version.toInt(), "getNextVersion() return unexpected value #2");
                assertEq(releaseRegistry.getLatestVersion().toInt(), prevReleaseInfo.version.toInt(), "getLatestVersion() return unexpected value #2");
            }

            {
                // deploy (register all(1) services)
                service = _prepareServiceWithRegistryDomain(nextReleaseInfo.version, ReleaseAdmin(address(nextReleaseInfo.admin)));
                assertFalse(registry.isRegisteredService(address(service)), "isRegisteredService() return unexpected value #1");

                uint256 expectedNftId = chainNft.getNextTokenId();

                // TODO add AccessAdmin logs
                vm.expectEmit(address(registry));
                emit LogServiceRegistration(nextVersion, REGISTRY());

                vm.prank(gifManager);
                NftId serviceNftId = releaseRegistry.registerService(service);

                nextReleaseInfo.state = DEPLOYED();
                RoleId expectedServiceRoleId = RoleIdLib.roleForTypeAndVersion(REGISTRY(), nextVersion);

                // check registration
                assertEq(serviceNftId.toInt(), expectedNftId, "registerService() return unexpected value");
                assertTrue(AccessManagerCloneable(nextReleaseInfo.admin.authority()).isLocked(), "isLocked() return unexpected value");
                assertTrue(nextReleaseInfo.admin.hasRole(address(service), expectedServiceRoleId), "hasRole() return unexpected value");   
                assertTrue(nextReleaseInfo.admin.targetExists(address(service)), "targetExists() return unexpected value");
                assertTrue(registry.isRegisteredService(address(service)), "isRegisteredService() return unexpected value #2");
                assertFalse(registryAdmin.targetExists(address(service)), "targetExists() return unexpected value");

                _assert_releaseRegistry_getters(nextVersion, nextReleaseInfo);
                _assert_releaseRegistry_getters(prevVersion, prevReleaseInfo);

                assertEq(releaseRegistry.releases(), i + 1, "releases() return unexpected value #3");
                assertEq(releaseRegistry.getNextVersion().toInt(), nextReleaseInfo.version.toInt(), "getNextVersion() return unexpected value #3");
                assertEq(releaseRegistry.getLatestVersion().toInt(), prevReleaseInfo.version.toInt(), "getLatestVersion() return unexpected value #3");
            }

            {
                // activate release
                vm.expectEmit(address(releaseRegistry));
                emit LogReleaseActivation(nextVersion);

                // TODO add AccessAdmin logs?

                vm.prank(gifAdmin);
                releaseRegistry.activateNextRelease();

                nextReleaseInfo.state = ACTIVE();
                nextReleaseInfo.activatedAt = TimestampLib.blockTimestamp();
                RoleId expectedServiceRoleIdForAllVersions = RoleIdLib.roleForTypeAndAllVersions(REGISTRY());

                // check activation 
                assertFalse(AccessManagerCloneable(nextReleaseInfo.admin.authority()).isLocked(), "isLocked() return unexpected value");
                assertTrue(registryAdmin.hasRole(address(service), expectedServiceRoleIdForAllVersions), "hasRole() return unexpected value");
                
                _assert_releaseRegistry_getters(nextVersion, nextReleaseInfo);
                _assert_releaseRegistry_getters(prevVersion, prevReleaseInfo);

                assertEq(releaseRegistry.releases(), i + 1, "releases() return unexpected value #4");
                assertEq(releaseRegistry.getNextVersion().toInt(), nextReleaseInfo.version.toInt(), "getNextVersion() return unexpected value #4");
                assertEq(releaseRegistry.getLatestVersion().toInt(), nextReleaseInfo.version.toInt(), "getLatestVersion() return unexpected value #4");
            }

            {
                // pause
                vm.expectEmit(address(releaseRegistry));
                emit LogReleaseDisabled(nextVersion);

                vm.prank(gifAdmin);
                releaseRegistry.setActive(nextVersion, false);

                nextReleaseInfo.state = PAUSED();
                nextReleaseInfo.disabledAt = TimestampLib.blockTimestamp();

                // check pause
                assertTrue(AccessManagerCloneable(nextReleaseInfo.admin.authority()).isLocked(), "isLocked() return unexpected value");
                assertTrue(gteTimestamp(nextReleaseInfo.disabledAt, prevReleaseInfo.disabledAt), "Test error: nextPauseTimestamp <= prevPauseTimestamp");

                _assert_releaseRegistry_getters(nextVersion, nextReleaseInfo);
                _assert_releaseRegistry_getters(prevVersion, prevReleaseInfo);

                assertEq(releaseRegistry.releases(), i + 1, "releases() return unexpected value #4");
                assertEq(releaseRegistry.getNextVersion().toInt(), nextReleaseInfo.version.toInt(), "getNextVersion() return unexpected value #4");
                assertEq(releaseRegistry.getLatestVersion().toInt(), nextReleaseInfo.version.toInt(), "getLatestVersion() return unexpected value #4");
            }

            prevVersion = nextVersion;
            nextVersion = VersionPartLib.toVersionPart(nextVersion.toInt() + 1);
            prevReleaseInfo = nextReleaseInfo;
            nextReleaseInfo = zeroReleaseInfo();
        }  
    }

    function test_releaseRegistry_createRelease_whenReleaseUnpausedHappaCase() public
    {
        VersionPart nextVersion = VersionPartLib.toVersionPart(releaseRegistry.INITIAL_GIF_VERSION());
        VersionPart prevVersion = VersionPartLib.toVersionPart(releaseRegistry.INITIAL_GIF_VERSION() - 1);
        IRegistry.ReleaseInfo memory nextReleaseInfo;
        IRegistry.ReleaseInfo memory prevReleaseInfo;

        IService service;

        for(uint i = 0; i <= 2; i++) 
        {
            {
                // create - skip
                vm.prank(gifAdmin);
                VersionPart createdVersion = releaseRegistry.createNextRelease();

                nextReleaseInfo.state = SCHEDULED();
                nextReleaseInfo.version = nextVersion;

                // check create
                assertEq(createdVersion.toInt(), nextVersion.toInt(), "createNextRelease() return unexpected value");
                if(i > 0) {
                    assertFalse(AccessManagerCloneable(prevReleaseInfo.admin.authority()).isLocked(), "isLocked() return unexpected value");
                }

                _assert_releaseRegistry_getters(nextVersion, nextReleaseInfo);
                _assert_releaseRegistry_getters(prevVersion, prevReleaseInfo);

                assertEq(releaseRegistry.releases(), i + 1, "releases() return unexpected value #1");
                assertEq(releaseRegistry.getNextVersion().toInt(), nextReleaseInfo.version.toInt(), "getNextVersion() return unexpected value #1");
                assertEq(releaseRegistry.getLatestVersion().toInt(), prevReleaseInfo.version.toInt(), "getLatestVersion() return unexpected value #1");
            }

            {
                // prepare
                IServiceAuthorization nextAuthMock = new ServiceAuthorizationMockWithRegistryService(nextVersion);
                bytes32 nextSalt = bytes32(randomNumber(type(uint256).max)); 

                vm.prank(gifManager);
                (
                    IAccessAdmin preparedAdmin, 
                    VersionPart preparedVersion, 
                    bytes32 preparedSalt
                ) = releaseRegistry.prepareNextRelease(nextAuthMock, nextSalt);

                nextReleaseInfo.state = DEPLOYING();
                nextReleaseInfo.salt = nextSalt;
                nextReleaseInfo.auth = nextAuthMock;
                nextReleaseInfo.admin = preparedAdmin;

                // check prepare
                assertEq(preparedVersion.toInt(), nextVersion.toInt(), "prepareNextRelease() return unexpected releaseVersion");
                assertEq(preparedSalt, nextSalt, "prepareNextRelease() return unexpected releaseSalt");
                assertTrue(AccessManagerCloneable(nextReleaseInfo.admin.authority()).isLocked(), "isLocked() return unexpected value");
                if(i > 0) {
                    assertFalse(AccessManagerCloneable(prevReleaseInfo.admin.authority()).isLocked(), "isLocked() return unexpected value");
                }

                _assert_releaseRegistry_getters(nextVersion, nextReleaseInfo);
                _assert_releaseRegistry_getters(prevVersion, prevReleaseInfo);

                assertEq(releaseRegistry.releases(), i + 1, "releases() return unexpected value #2");
                assertEq(releaseRegistry.getNextVersion().toInt(), nextReleaseInfo.version.toInt(), "getNextVersion() return unexpected value #2");
                assertEq(releaseRegistry.getLatestVersion().toInt(), prevReleaseInfo.version.toInt(), "getLatestVersion() return unexpected value #2");
            }

            {
                // deploy (register all(1) services)
                service = _prepareServiceWithRegistryDomain(nextReleaseInfo.version, ReleaseAdmin(address(nextReleaseInfo.admin)));
                assertFalse(registry.isRegisteredService(address(service)), "isRegisteredService() return unexpected value #1");

                uint256 expectedNftId = chainNft.getNextTokenId();

                // TODO add AccessAdmin logs
                vm.expectEmit(address(registry));
                emit LogServiceRegistration(nextVersion, REGISTRY());

                vm.prank(gifManager);
                NftId serviceNftId = releaseRegistry.registerService(service);

                nextReleaseInfo.state = DEPLOYED();
                RoleId expectedServiceRoleId = RoleIdLib.roleForTypeAndVersion(REGISTRY(), nextVersion);

                // check registration
                assertEq(serviceNftId.toInt(), expectedNftId, "registerService() return unexpected value");
                assertTrue(AccessManagerCloneable(nextReleaseInfo.admin.authority()).isLocked(), "isLocked() return unexpected value");
                assertTrue(nextReleaseInfo.admin.hasRole(address(service), expectedServiceRoleId), "hasRole() return unexpected value");   
                assertTrue(nextReleaseInfo.admin.targetExists(address(service)), "targetExists() return unexpected value");
                assertTrue(registry.isRegisteredService(address(service)), "isRegisteredService() return unexpected value #2");
                assertFalse(registryAdmin.targetExists(address(service)), "targetExists() return unexpected value");

                _assert_releaseRegistry_getters(nextVersion, nextReleaseInfo);
                _assert_releaseRegistry_getters(prevVersion, prevReleaseInfo);

                assertEq(releaseRegistry.releases(), i + 1, "releases() return unexpected value #3");
                assertEq(releaseRegistry.getNextVersion().toInt(), nextReleaseInfo.version.toInt(), "getNextVersion() return unexpected value #3");
                assertEq(releaseRegistry.getLatestVersion().toInt(), prevReleaseInfo.version.toInt(), "getLatestVersion() return unexpected value #3");
            }

            {
                // activate release
                vm.expectEmit(address(releaseRegistry));
                emit LogReleaseActivation(nextVersion);

                // TODO add AccessAdmin logs?

                vm.prank(gifAdmin);
                releaseRegistry.activateNextRelease();

                nextReleaseInfo.state = ACTIVE();
                nextReleaseInfo.activatedAt = TimestampLib.blockTimestamp();
                RoleId expectedServiceRoleIdForAllVersions = RoleIdLib.roleForTypeAndAllVersions(REGISTRY());

                // check activation 
                assertFalse(AccessManagerCloneable(nextReleaseInfo.admin.authority()).isLocked(), "isLocked() return unexpected value");
                assertTrue(registryAdmin.hasRole(address(service), expectedServiceRoleIdForAllVersions), "hasRole() return unexpected value");
                
                _assert_releaseRegistry_getters(nextVersion, nextReleaseInfo);
                _assert_releaseRegistry_getters(prevVersion, prevReleaseInfo);

                assertEq(releaseRegistry.releases(), i + 1, "releases() return unexpected value #4");
                assertEq(releaseRegistry.getNextVersion().toInt(), nextReleaseInfo.version.toInt(), "getNextVersion() return unexpected value #4");
                assertEq(releaseRegistry.getLatestVersion().toInt(), nextReleaseInfo.version.toInt(), "getLatestVersion() return unexpected value #4");
            }

            {
                // pause
                vm.expectEmit(address(releaseRegistry));
                emit LogReleaseDisabled(nextVersion);

                vm.prank(gifAdmin);
                releaseRegistry.setActive(nextVersion, false);

                nextReleaseInfo.state = PAUSED();
                nextReleaseInfo.disabledAt = TimestampLib.blockTimestamp();

                // check pause
                assertTrue(AccessManagerCloneable(nextReleaseInfo.admin.authority()).isLocked(), "isLocked() return unexpected value");
                assertTrue(gteTimestamp(nextReleaseInfo.disabledAt, prevReleaseInfo.disabledAt), "Test error: nextPauseTimestamp <= prevPauseTimestamp");

                _assert_releaseRegistry_getters(nextVersion, nextReleaseInfo);
                _assert_releaseRegistry_getters(prevVersion, prevReleaseInfo);

                assertEq(releaseRegistry.releases(), i + 1, "releases() return unexpected value #4");
                assertEq(releaseRegistry.getNextVersion().toInt(), nextReleaseInfo.version.toInt(), "getNextVersion() return unexpected value #4");
                assertEq(releaseRegistry.getLatestVersion().toInt(), nextReleaseInfo.version.toInt(), "getLatestVersion() return unexpected value #4");
            }

            {
                // unpause
                vm.expectEmit(address(releaseRegistry));
                emit LogReleaseEnabled(nextVersion);

                vm.prank(gifAdmin);
                releaseRegistry.setActive(nextVersion, true);

                nextReleaseInfo.state = ACTIVE();
                nextReleaseInfo.disabledAt = TimestampLib.zero();

                // check unpause
                assertFalse(AccessManagerCloneable(nextReleaseInfo.admin.authority()).isLocked(), "isLocked() return unexpected value");

                _assert_releaseRegistry_getters(nextVersion, nextReleaseInfo);
                _assert_releaseRegistry_getters(prevVersion, prevReleaseInfo);

                assertEq(releaseRegistry.releases(), i + 1, "releases() return unexpected value #4");
                assertEq(releaseRegistry.getNextVersion().toInt(), nextReleaseInfo.version.toInt(), "getNextVersion() return unexpected value #4");
                assertEq(releaseRegistry.getLatestVersion().toInt(), nextReleaseInfo.version.toInt(), "getLatestVersion() return unexpected value #4");           
            }

            prevVersion = nextVersion;
            nextVersion = VersionPartLib.toVersionPart(nextVersion.toInt() + 1);
            prevReleaseInfo = nextReleaseInfo;
            nextReleaseInfo = zeroReleaseInfo();
        }       
    }

    //------------------------ prepare release ------------------------//

    function test_releaseRegistry_prepareRelease_byNotAuthorizedCaller() public 
    {
        VersionPart releaseVersion = VersionPartLib.toVersionPart(releaseRegistry.INITIAL_GIF_VERSION());
        ServiceAuthorizationMockWithRegistryService serviceAuth = new ServiceAuthorizationMockWithRegistryService(releaseVersion);

        vm.prank(gifAdmin);
        releaseRegistry.createNextRelease();

        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, gifAdmin));
        vm.prank(gifAdmin);
        releaseRegistry.prepareNextRelease(serviceAuth, "0x1234");

        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, stakingOwner));
        vm.prank(stakingOwner);
        releaseRegistry.prepareNextRelease(serviceAuth, "0x1234");

        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, outsider));
        vm.prank(outsider);
        releaseRegistry.prepareNextRelease(serviceAuth, "0x1234");
    }

    function test_releaseRegistry_prepareRelease_whenInitialReleaseNotCreated() public
    {
        VersionPart expectedVersion = VersionPartLib.toVersionPart(releaseRegistry.INITIAL_GIF_VERSION());
        ServiceAuthorizationMockWithRegistryService serviceAuth = new ServiceAuthorizationMockWithRegistryService(expectedVersion);
        bytes32 salt = "0x1234";

        vm.expectRevert(abi.encodeWithSelector(
            ILifecycle.ErrorFromStateMissmatch.selector,
            address(releaseRegistry),
            RELEASE(),
            StateIdLib.zero(),
            SCHEDULED()
        ));
        vm.prank(gifManager);
        releaseRegistry.prepareNextRelease(serviceAuth, salt);        
    }

    function test_releaseRegistry_prepareRelease_initialReleaseHappyCase() public
    {
        VersionPart expectedVersion = VersionPartLib.toVersionPart(releaseRegistry.INITIAL_GIF_VERSION());
        ServiceAuthorizationMockWithRegistryService serviceAuth = new ServiceAuthorizationMockWithRegistryService(expectedVersion);
        bytes32 salt = "0x1234";

        vm.prank(gifAdmin);
        releaseRegistry.createNextRelease();

        vm.expectEmit(address(releaseRegistry));
        emit LogReleaseCreation(expectedVersion, salt);

        vm.prank(gifManager);
        (
            IAccessAdmin preparedAdmin, 
            VersionPart preparedVersion, 
            bytes32 preparedSalt
        ) = releaseRegistry.prepareNextRelease(serviceAuth, salt);

        // TODO check release admin in better
        assertTrue(address(preparedAdmin) != address(0), "prepareNextRelease() return unexpected authority");
        assertEq(preparedVersion.toInt(), expectedVersion.toInt(), "prepareNextRelease() return unexpected releaseVersion");
        assertEq(preparedSalt, salt, "prepareNextRelease() return unexpected releaseSalt");

        _assert_releaseRegistry_getters(
            expectedVersion,
            IRegistry.ReleaseInfo(
                    DEPLOYING(),
                    preparedVersion,
                    preparedSalt,
                    serviceAuth,
                    preparedAdmin,
                    TimestampLib.zero(),
                    TimestampLib.zero()
                ));
        _assert_releaseRegistry_getters(
            VersionPartLib.toVersionPart(releaseRegistry.INITIAL_GIF_VERSION() - 1),
            zeroReleaseInfo());

        assertEq(releaseRegistry.releases(), 1, "releases() return unexpected value");
        assertEq(releaseRegistry.getNextVersion().toInt(), expectedVersion.toInt(), "getNextVersion() return unexpected value");
        assertEq(releaseRegistry.getLatestVersion().toInt(), 0, "getLatestVersion() return unexpected value");
    }

    function test_releaseRegistry_prepareRelease_whenReleaseScheduledHappyCase() public
    {
        // Equivalent to test_releaseRegistry_createRelease_whenReleaseDeployingHappyCase()
        // create release
        // prepare release
        // loop
    }

    function test_releaseRegistry_prepareRelease_whenReleaseDeploying() public 
    {
        for(uint i = 0; i <= 2; i++) 
        {
            // create
            vm.prank(gifAdmin);
            VersionPart createdVersion = releaseRegistry.createNextRelease();

            // prepare
            ServiceAuthorizationMockWithRegistryService serviceAuth = new ServiceAuthorizationMockWithRegistryService(createdVersion);
            bytes32 salt = bytes32(randomNumber(type(uint256).max)); 

            vm.prank(gifManager);
            releaseRegistry.prepareNextRelease(serviceAuth, salt);

            vm.expectRevert(abi.encodeWithSelector(
                ILifecycle.ErrorFromStateMissmatch.selector,
                address(releaseRegistry), 
                RELEASE(), 
                DEPLOYING(), 
                SCHEDULED()
            ));
            vm.prank(gifManager);
            releaseRegistry.prepareNextRelease(serviceAuth, salt);
        }
    }

    function test_releaseRegistry_prepareRelease_whenReleaseDeployed() public
    {
        for(uint i = 0; i <= 2; i++) 
        {
            // create - skip
            vm.prank(gifAdmin);
            VersionPart createdVersion = releaseRegistry.createNextRelease();

            // prepare
            IServiceAuthorization authMock = new ServiceAuthorizationMockWithRegistryService(createdVersion);
            bytes32 salt = bytes32(randomNumber(type(uint256).max)); 

            IAccessAdmin preparedAdmin;
            vm.prank(gifManager);
            (preparedAdmin,,) = releaseRegistry.prepareNextRelease(authMock, salt);

            // deploy (register all(1) services)
            IService service = _prepareServiceWithRegistryDomain(createdVersion, ReleaseAdmin(address(preparedAdmin)));

            vm.prank(gifManager);
            releaseRegistry.registerService(service);

            // prepare with revert
            authMock = new ServiceAuthorizationMockWithRegistryService(createdVersion);
            salt = bytes32(randomNumber(type(uint256).max)); 

            vm.expectRevert(abi.encodeWithSelector(
                ILifecycle.ErrorFromStateMissmatch.selector,
                address(releaseRegistry), 
                RELEASE(), 
                DEPLOYED(), 
                SCHEDULED()
            ));

            vm.prank(gifManager);
            releaseRegistry.prepareNextRelease(authMock, salt);

            vm.stopPrank();
        }
    }

    function test_releaseRegistry_prepareRelease_whenReleaseActive() public
    {
        for(uint i = 0; i <= 2; i++) 
        {
            // create - skip
            vm.prank(gifAdmin);
            VersionPart createdVersion = releaseRegistry.createNextRelease();

            // prepare
            IServiceAuthorization authMock = new ServiceAuthorizationMockWithRegistryService(createdVersion);
            bytes32 salt = bytes32(randomNumber(type(uint256).max)); 

            IAccessAdmin preparedAdmin;
            vm.prank(gifManager);
            (preparedAdmin,,) = releaseRegistry.prepareNextRelease(authMock, salt);

            // deploy (register all(1) services)
            IService service = _prepareServiceWithRegistryDomain(createdVersion, ReleaseAdmin(address(preparedAdmin)));

            vm.prank(gifManager);
            releaseRegistry.registerService(service);

            // activate
            vm.prank(gifAdmin);
            releaseRegistry.activateNextRelease();

            // prepare with revert
            authMock = new ServiceAuthorizationMockWithRegistryService(createdVersion);
            salt = bytes32(randomNumber(type(uint256).max)); 

            vm.expectRevert(abi.encodeWithSelector(
                ILifecycle.ErrorFromStateMissmatch.selector,
                address(releaseRegistry), 
                RELEASE(), 
                ACTIVE(), 
                SCHEDULED()
            ));
            vm.prank(gifManager);
            releaseRegistry.prepareNextRelease(authMock, salt);
        }
    }

    function test_releaseRegistry_prepareRelease_whenReleasePaused() public
    {
        for(uint i = 0; i <= 2; i++) 
        {
            // create - skip
            vm.prank(gifAdmin);
            VersionPart createdVersion = releaseRegistry.createNextRelease();

            // prepare
            IServiceAuthorization authMock = new ServiceAuthorizationMockWithRegistryService(createdVersion);
            bytes32 salt = bytes32(randomNumber(type(uint256).max)); 

            IAccessAdmin preparedAdmin;
            vm.prank(gifManager);
            (preparedAdmin,,) = releaseRegistry.prepareNextRelease(authMock, salt);

            // deploy (register all(1) services)
            IService service = _prepareServiceWithRegistryDomain(createdVersion, ReleaseAdmin(address(preparedAdmin)));

            vm.prank(gifManager);
            releaseRegistry.registerService(service);

            // activate
            vm.prank(gifAdmin);
            releaseRegistry.activateNextRelease();

            // pause
            vm.prank(gifAdmin);
            releaseRegistry.setActive(createdVersion, false);

            // prepare with revert
            authMock = new ServiceAuthorizationMockWithRegistryService(createdVersion);
            salt = bytes32(randomNumber(type(uint256).max));

            vm.expectRevert(abi.encodeWithSelector(
                ILifecycle.ErrorFromStateMissmatch.selector,
                address(releaseRegistry), 
                RELEASE(), 
                PAUSED(), 
                SCHEDULED()
            ));
            vm.prank(gifManager);
            releaseRegistry.prepareNextRelease(authMock, salt);
        }
    }

    function test_releaseRegistry_prepareRelease_whenReleaseScheduled_withZeroServiceAuth() public
    {
        vm.prank(gifAdmin);
        releaseRegistry.createNextRelease();

        vm.expectRevert();
        vm.prank(gifManager);
        releaseRegistry.prepareNextRelease(IServiceAuthorization(address(0)), "0x1234");
    }

    /*
    // TODO need mocks with fallback function
    function test_releaseRegistry_prepareRelease_whenReleaseScheduled_withServiceAuthWithoutIERC165() public
    {
        FallbackMock fallbackMock = new FallbackMock();
        FallbackMockWithReturn fallbackMockWithReturn = new FallbackMockWithReturn();
        Usdc usdc = new Usdc();

        vm.prank(gifAdmin);
        releaseRegistry.createNextRelease();

        // EOA
        vm.expectRevert(bytes(""));
        vm.prank(gifManager);
        releaseRegistry.prepareNextRelease(IServiceAuthorization(outsider), "0x1234");

        // contract without IERC165 and fallback 
        vm.expectRevert(bytes(""));
        vm.prank(gifManager);
        releaseRegistry.prepareNextRelease(IServiceAuthorization(address(usdc)), "0x1234");

        // contract without IERC165 but with fallback
        vm.expectRevert(bytes(""));
        vm.prank(gifManager);
        releaseRegistry.prepareNextRelease(IServiceAuthorization(address(fallbackMock)), "0x1234");

        // contract without IERC165 but with fallback with return (returns "1")
        vm.expectRevert(bytes(""));
        vm.prank(gifManager);
        releaseRegistry.prepareNextRelease(IServiceAuthorization(address(fallbackMockWithReturn)), "0x1234");
    }
    */
    function test_releaseRegistry_prepareRelease_whenReleaseScheduled_withServiceAuthWithIERC165() public
    {
        NftOwnableMock mock = new NftOwnableMock(address(registry));

        vm.prank(gifAdmin);
        releaseRegistry.createNextRelease();

        vm.expectRevert(abi.encodeWithSelector(
            ReleaseRegistry.ErrorReleaseRegistryNotServiceAuth.selector, 
            (address(mock))
        ));
        vm.prank(gifManager);
        releaseRegistry.prepareNextRelease(IServiceAuthorization(address(mock)), "0x1234");
    }

    function test_releaseRegistry_prepareRelease_whenReleaseScheduled_withServiceAuthVersionTooSmall() public
    {
        uint256 createdReleases = randomNumber(2, 10);
        uint256 releaseVersion = releaseRegistry.INITIAL_GIF_VERSION() + createdReleases;

        for(uint i = 0; i <= createdReleases; i++) {
            vm.prank(gifAdmin);
            releaseRegistry.createNextRelease();
        }

        for(uint i = 0; i < releaseVersion; i++) 
        {
            VersionPart tooSmallVersion = VersionPartLib.toVersionPart(i);
            ObjectType[] memory domains = new ObjectType[](1);
            domains[0] = PRODUCT();
            IServiceAuthorization auth = new ServiceAuthorizationMock(tooSmallVersion, domains);
            vm.expectRevert(abi.encodeWithSelector(
                ReleaseRegistry.ErrorReleaseRegistryServiceAuthVersionMismatch.selector, 
                auth, 
                releaseVersion, 
                tooSmallVersion
            ));
            vm.prank(gifManager);
            releaseRegistry.prepareNextRelease(auth, "0x1234");
        }

        // check prepareRelease() works for the releaseVersion
    }

    function test_releaseRegistry_prepareRelease_whenReleaseScheduled_withServiceAuthVersionTooBig() public
    {
        uint256 createdReleases = randomNumber(1, 10);
        uint256 releaseVersion = releaseRegistry.INITIAL_GIF_VERSION() + createdReleases;

        vm.startPrank(gifAdmin);

        for(uint i = 0; i <= createdReleases; i++) {
            releaseRegistry.createNextRelease();
        }

        vm.stopPrank();
        vm.startPrank(gifManager);

        for(uint i = releaseVersion + 1; i < releaseVersion + 5; i++) 
        {
            VersionPart tooBigVersion = VersionPartLib.toVersionPart(i);
            ServiceAuthorizationMockWithRegistryService auth = new ServiceAuthorizationMockWithRegistryService(tooBigVersion);
            vm.expectRevert(abi.encodeWithSelector(
                ReleaseRegistry.ErrorReleaseRegistryServiceAuthVersionMismatch.selector, 
                auth, 
                releaseVersion, 
                tooBigVersion));
            releaseRegistry.prepareNextRelease(auth, "0x1234");
        }

        // check prepareRelease() works for the releaseVersion

        vm.stopPrank();        
    }

    function test_releaseRegistry_prepareRelease_whenReleaseScheduled_withServiceAuthDomainCountZero() public 
    {
        VersionPart version = VersionPartLib.toVersionPart(releaseRegistry.INITIAL_GIF_VERSION());
        ObjectType[] memory domains = new ObjectType[](0);
        ServiceAuthorizationMock serviceAuth = new ServiceAuthorizationMock(version, domains);

        vm.prank(gifAdmin);
        releaseRegistry.createNextRelease();

        vm.expectRevert(abi.encodeWithSelector(
            ReleaseRegistry.ErrorReleaseRegistryServiceAuthDomainsZero.selector, 
            serviceAuth, 
            version
        ));
        vm.prank(gifManager);
        releaseRegistry.prepareNextRelease(serviceAuth, "0x1234");
    }

    //------------------------ register service ------------------------//

    function test_releaseRegistry_registerService_byNotAuthorizedCaller() public
    {
        IService service;
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, gifAdmin));
        vm.prank(gifAdmin);
        releaseRegistry.registerService(service);

        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, stakingOwner));
        vm.prank(stakingOwner);
        releaseRegistry.registerService(service);

        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, outsider));
        vm.prank(outsider);
        releaseRegistry.registerService(service);
    }

    function test_releaseRegistry_registerService_whenInitialReleaseNotCreated() public
    {
        vm.startPrank(gifManager);
        ServiceMock serviceMock = new ServiceMock(
            NftIdLib.zero(), 
            registryNftId, 
            false, // isInterceptor
            gifManager,
            address(0));

        vm.expectRevert(abi.encodeWithSelector(
            ILifecycle.ErrorFromStateMissmatch.selector,
            address(releaseRegistry), 
            RELEASE(), 
            StateIdLib.zero(), 
            DEPLOYING()
        ));
        releaseRegistry.registerService(serviceMock);

        vm.stopPrank();
    }

    function test_releaseRegistry_registerService_whenReleaseScheduled() public
    {
        for(uint i = 0; i <= 2; i++) 
        {
            // create - skip
            vm.prank(gifAdmin);
            releaseRegistry.createNextRelease();

            ServiceMock serviceMock = new ServiceMock(
                NftIdLib.zero(), 
                registryNftId, 
                false, // isInterceptor
                gifManager,
                address(0));

            // register with revert
            vm.expectRevert(abi.encodeWithSelector(
                ILifecycle.ErrorFromStateMissmatch.selector,
                address(releaseRegistry), 
                RELEASE(), 
                SCHEDULED(), 
                DEPLOYING()
            ));
            vm.prank(gifManager);
            releaseRegistry.registerService(serviceMock);
        }
    }

    function test_releaseRegistry_registerService_whenReleaseDeployingHappyCase() public
    {
        // Equivalent to test_releaseRegistry_createRelease_whenReleaseDeployedHappyCase()
        // create release
        // prepare release
        // register service
        // loop
    }

    function test_releaseRegistry_registerService_whenReleaseDeploying_registerLastServiceHappyCase() public
    {
        // the first registration

        // check DEPLOYING after the first registration

        // check second registration is ok

        // check DEPLOYING after second registration

        // check the last registration is ok

        // check DEPLOYED after the last registration
    }

    function test_releaserRegistry_registerService_whenReleaseDeploying_withServiceVersionTooSmall() public
    {
        uint initialVersionInt = releaseRegistry.INITIAL_GIF_VERSION();

        VersionPart releaseVersion;
        for(uint i = 0; i <= 2; i++) 
        {
            // create - skip
            vm.prank(gifAdmin);
            releaseVersion = releaseRegistry.createNextRelease();
        }

        // prepare the last created
        IServiceAuthorization nextAuthMock = new ServiceAuthorizationMockWithRegistryService(releaseVersion);
        bytes32 nextSalt = bytes32(randomNumber(type(uint256).max)); 

        vm.prank(gifManager);
        (IAccessAdmin releaseAdmin,,) = releaseRegistry.prepareNextRelease(nextAuthMock, nextSalt);

        for(uint i = 0; i < 2; i++)
        {
            // register with revert
            VersionPart serviceVersion = VersionPartLib.toVersionPart(initialVersionInt + i);
            IService service = _prepareServiceWithRegistryDomain(serviceVersion, ReleaseAdmin(address(releaseAdmin)));
            vm.expectRevert(abi.encodeWithSelector(
                ReleaseRegistry.ErrorReleaseRegistryServiceVersionMismatch.selector, 
                service, 
                serviceVersion,
                releaseVersion
            ));
            vm.prank(gifManager);
            releaseRegistry.registerService(service);
        }
    }

    function test_releaseRegistry_registerService_whenReleaseDeploying_withServiceVersionTooBig() public
    {
        uint initialVersionInt = releaseRegistry.INITIAL_GIF_VERSION();

        // create initial
        vm.prank(gifAdmin);
        VersionPart releaseVersion = releaseRegistry.createNextRelease();

        // prepare initial
        IServiceAuthorization nextAuthMock = new ServiceAuthorizationMockWithRegistryService(releaseVersion);
        bytes32 nextSalt = bytes32(randomNumber(type(uint256).max)); 

        vm.prank(gifManager);
        (IAccessAdmin releaseAdmin,,) = releaseRegistry.prepareNextRelease(nextAuthMock, nextSalt);

        for(uint i = 1; i <= 2; i++)
        {
            // register with revert
            VersionPart serviceVersion = VersionPartLib.toVersionPart(initialVersionInt + i);
            IService service = _prepareServiceWithRegistryDomain(serviceVersion, ReleaseAdmin(address(releaseAdmin)));
            vm.expectRevert(abi.encodeWithSelector(
                ReleaseRegistry.ErrorReleaseRegistryServiceVersionMismatch.selector, 
                service, 
                serviceVersion,
                releaseVersion
            ));
            vm.prank(gifManager);
            releaseRegistry.registerService(service);
        }
    }

    function test_releaseRegistry_registerService_whenReleaseDeploying_withServiceDomainMismatch() public
    {
        // create initial
        vm.prank(gifAdmin);
        VersionPart releaseVersion = releaseRegistry.createNextRelease();

        // prepare initial
        IServiceAuthorization nextAuthMock = new ServiceAuthorizationMockWithRegistryService(releaseVersion);
        bytes32 nextSalt = bytes32(randomNumber(type(uint256).max)); 

        vm.prank(gifManager);
        (IAccessAdmin releaseAdmin,,) = releaseRegistry.prepareNextRelease(nextAuthMock, nextSalt);

        // register with revert
        // service mock have PRODUCT domain
        IService service = new ServiceMock(
            NftIdLib.zero(), 
            registryNftId, 
            false, // isInterceptor
            gifManager,
            releaseAdmin.authority());

        vm.expectRevert(abi.encodeWithSelector(
            ReleaseRegistry.ErrorReleaseRegistryServiceDomainMismatch.selector, 
            service,
            REGISTRY(),
            PRODUCT()
        ));
        vm.prank(gifManager);
        releaseRegistry.registerService(service);
    }

    function test_releaseRegistry_registerService_whenReleaseDeployed() public
    {
        for(uint i = 0; i <= 2; i++) 
        {
            // create - skip
            vm.prank(gifAdmin);
            VersionPart createdVersion = releaseRegistry.createNextRelease();

            // prepare
            IServiceAuthorization authMock = new ServiceAuthorizationMockWithRegistryService(createdVersion);
            bytes32 salt = bytes32(randomNumber(type(uint256).max)); 
            IAccessAdmin preparedAdmin;

            vm.prank(gifManager);
            (preparedAdmin,,) = releaseRegistry.prepareNextRelease(authMock, salt);

            // deploy (register all(1) services)
            IService service = _prepareServiceWithRegistryDomain(createdVersion, ReleaseAdmin(address(preparedAdmin)));

            vm.prank(gifManager);
            releaseRegistry.registerService(service);

            // register with revert
            ServiceMock serviceMock = new ServiceMock(
                NftIdLib.zero(), 
                registryNftId, 
                false, // isInterceptor
                gifManager,
                registryAdmin.authority());

            vm.expectRevert(abi.encodeWithSelector(
                ILifecycle.ErrorFromStateMissmatch.selector,
                address(releaseRegistry), 
                RELEASE(), 
                DEPLOYED(), 
                DEPLOYING()
            ));
            vm.prank(gifManager);
            releaseRegistry.registerService(serviceMock);
        }
    }

    function test_releaseRegistry_registerService_whenReleaseActive() public
    {
        for(uint i = 0; i <= 2; i++) 
        {
            // create - skip
            vm.prank(gifAdmin);
            VersionPart createdVersion = releaseRegistry.createNextRelease();

            // prepare
            IServiceAuthorization authMock = new ServiceAuthorizationMockWithRegistryService(createdVersion);
            bytes32 salt = bytes32(randomNumber(type(uint256).max)); 
            IAccessAdmin preparedAdmin;

            vm.prank(gifManager);
            (preparedAdmin,,) = releaseRegistry.prepareNextRelease(authMock, salt);

            // deploy (register all(1) services)
            IService service = _prepareServiceWithRegistryDomain(createdVersion, ReleaseAdmin(address(preparedAdmin)));

            vm.prank(gifManager);
            releaseRegistry.registerService(service);

            // activate
            vm.prank(gifAdmin);
            releaseRegistry.activateNextRelease();

            // register with revert
            ServiceMock serviceMock = new ServiceMock(
                NftIdLib.zero(), 
                registryNftId, 
                false, // isInterceptor
                gifManager,
                registryAdmin.authority());

            vm.expectRevert(abi.encodeWithSelector(
                ILifecycle.ErrorFromStateMissmatch.selector,
                address(releaseRegistry), 
                RELEASE(), 
                ACTIVE(), 
                DEPLOYING()
            ));
            vm.prank(gifManager);
            releaseRegistry.registerService(serviceMock);
        }
    }

    function test_releaseRegistry_registerService_whenReleasePaused() public
    {
        for(uint i = 0; i <= 2; i++) 
        {
            // create - skip
            vm.prank(gifAdmin);
            VersionPart createdVersion = releaseRegistry.createNextRelease();

            // prepare
            IServiceAuthorization authMock = new ServiceAuthorizationMockWithRegistryService(createdVersion);
            bytes32 salt = bytes32(randomNumber(type(uint256).max)); 
            IAccessAdmin preparedAdmin;

            vm.prank(gifManager);
            (preparedAdmin,,) = releaseRegistry.prepareNextRelease(authMock, salt);

            // deploy (register all(1) services)
            IService service = _prepareServiceWithRegistryDomain(createdVersion, ReleaseAdmin(address(preparedAdmin)));

            vm.prank(gifManager);
            releaseRegistry.registerService(service);

            // activate
            vm.prank(gifAdmin);
            releaseRegistry.activateNextRelease();

            // pause
            vm.prank(gifAdmin);
            releaseRegistry.setActive(createdVersion, false);

            // register with revert
            ServiceMock serviceMock = new ServiceMock(
                NftIdLib.zero(), 
                registryNftId, 
                false, // isInterceptor
                gifManager,
                registryAdmin.authority());

            vm.expectRevert(abi.encodeWithSelector(
                ILifecycle.ErrorFromStateMissmatch.selector,
                address(releaseRegistry), 
                RELEASE(), 
                PAUSED(), 
                DEPLOYING()
            ));
            vm.prank(gifManager);
            releaseRegistry.registerService(serviceMock);
        }
    }

    //------------------------ activate release ------------------------//

    function test_releaseRegistry_activateRelease_byNotAuthorizedCaller() public
    {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, gifManager));
        vm.prank(gifManager);
        releaseRegistry.activateNextRelease();

        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, stakingOwner));
        vm.prank(stakingOwner);
        releaseRegistry.activateNextRelease();

        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, outsider));
        vm.prank(outsider);
        releaseRegistry.activateNextRelease();
    }

    function test_activateRelease_whenInitialReleaseNotCreated() public
    {
        vm.expectRevert(abi.encodeWithSelector(
            ILifecycle.ErrorFromStateMissmatch.selector,
            address(releaseRegistry), 
            RELEASE(), 
            StateIdLib.zero(), 
            DEPLOYED()
        ));
        vm.prank(gifAdmin);
        releaseRegistry.activateNextRelease();

    }

    function test_releaseRegistry_activateRelease_whenReleaseScheduled() public
    {
       for(uint i = 0; i <= 2; i++) 
        {
            // create - skip
            vm.prank(gifAdmin);
            releaseRegistry.createNextRelease();

            // activate with revert
            vm.expectRevert(abi.encodeWithSelector(
                ILifecycle.ErrorFromStateMissmatch.selector,
                address(releaseRegistry), 
                RELEASE(), 
                SCHEDULED(), 
                DEPLOYED()
            ));
            vm.prank(gifAdmin);
            releaseRegistry.activateNextRelease();
        }
    }
    function test_releaseRegistry_activateRelease_whenReleaseDeploying() public
    {
        for(uint i = 0; i <= 2; i++) 
        {
            // create
            vm.prank(gifAdmin);
            VersionPart createdVersion = releaseRegistry.createNextRelease();

            // prepare
            ServiceAuthorizationMockWithRegistryService serviceAuth = new ServiceAuthorizationMockWithRegistryService(createdVersion);
            bytes32 salt = bytes32(randomNumber(type(uint256).max)); 

            vm.prank(gifManager);
            releaseRegistry.prepareNextRelease(serviceAuth, salt);

            // activate with revert
            vm.expectRevert(abi.encodeWithSelector(
                ILifecycle.ErrorFromStateMissmatch.selector,
                address(releaseRegistry), 
                RELEASE(), 
                DEPLOYING(), 
                DEPLOYED()
            ));
            vm.prank(gifAdmin);
            releaseRegistry.activateNextRelease();
        }
    }

    function test_releaseRegistry_activateRelease_whenReleaseDeployedHappyCase() public
    {
        // TODO ?
        // Equivalent to test_releaseRegistry_createRelease_whenReleaseActiveHappyCase()
        // create
        // prepare
        // register service
        // activate
        // loop
    }

    function test_releaseRegistry_activateRelease_whenReleaseActive() public
    {
        for(uint i = 0; i <= 2; i++) 
        {
            // create
            vm.prank(gifAdmin);
            VersionPart createdVersion = releaseRegistry.createNextRelease();

            // prepare
            IServiceAuthorization authMock = new ServiceAuthorizationMockWithRegistryService(createdVersion);
            bytes32 salt = bytes32(randomNumber(type(uint256).max)); 
            IAccessAdmin preparedAdmin;

            vm.prank(gifManager);
            (preparedAdmin,,) = releaseRegistry.prepareNextRelease(authMock, salt);

            // deploy (register all(1) services)
            IService service = _prepareServiceWithRegistryDomain(createdVersion, ReleaseAdmin(address(preparedAdmin)));

            vm.prank(gifManager);
            releaseRegistry.registerService(service);

            // activate
            vm.prank(gifAdmin);
            releaseRegistry.activateNextRelease();

            // activate with revert
            vm.expectRevert(abi.encodeWithSelector(
                ILifecycle.ErrorFromStateMissmatch.selector,
                address(releaseRegistry), 
                RELEASE(), 
                ACTIVE(), 
                DEPLOYED()
            ));
            vm.prank(gifAdmin);
            releaseRegistry.activateNextRelease();
        }
    }
    
    function test_releaseRegistry_activateRelease_whenReleasePaused() public
    {
        for(uint i = 0; i <= 2; i++) 
        {
            // create
            vm.prank(gifAdmin);
            VersionPart createdVersion = releaseRegistry.createNextRelease();

            // prepare
            IServiceAuthorization authMock = new ServiceAuthorizationMockWithRegistryService(createdVersion);
            bytes32 salt = bytes32(randomNumber(type(uint256).max)); 
            IAccessAdmin preparedAdmin;

            vm.prank(gifManager);
            (preparedAdmin,,) = releaseRegistry.prepareNextRelease(authMock, salt);

            // deploy (register all(1) services)
            IService service = _prepareServiceWithRegistryDomain(createdVersion, ReleaseAdmin(address(preparedAdmin)));

            vm.prank(gifManager);
            releaseRegistry.registerService(service);

            // activate
            vm.prank(gifAdmin);
            releaseRegistry.activateNextRelease();

            // pause
            vm.prank(gifAdmin);
            releaseRegistry.setActive(createdVersion, false);

            // activate with revert
            vm.expectRevert(abi.encodeWithSelector(
                ILifecycle.ErrorFromStateMissmatch.selector,
                address(releaseRegistry), 
                RELEASE(), 
                PAUSED(), 
                DEPLOYED()
            ));
            vm.prank(gifAdmin);
            releaseRegistry.activateNextRelease();
        }
    }

    //------------------------ pauseRelease ------------------------//
    function test_releaseRegistry_pauseRelease_byNotAuthorizedCaller() public
    {
        VersionPart version;

        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, gifManager));
        vm.prank(gifManager);
        releaseRegistry.setActive(version, false);

        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, stakingOwner));
        vm.prank(stakingOwner);
        releaseRegistry.setActive(version, false);

        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, outsider));
        vm.prank(outsider);
        releaseRegistry.setActive(version, false);
    }

    function test_pauseRelease_whenInitialReleaseNotCreated() public
    {
        // loop through first n versions
        for(uint i = 0; i < 5; i++)
        {
            VersionPart version = VersionPartLib.toVersionPart(i);
            vm.expectRevert(abi.encodeWithSelector(
                ILifecycle.ErrorFromStateMissmatch.selector,
                address(releaseRegistry), 
                RELEASE(), 
                StateIdLib.zero(), 
                ACTIVE()
            ));
            vm.prank(gifAdmin);
            releaseRegistry.setActive(version, false);
        }
    }

    function test_releaseRegistry_pauseRelease_whenReleaseScheduled() public
    {
       for(uint i = 0; i <= 2; i++) 
        {
            // create - skip
            vm.prank(gifAdmin);
            VersionPart createdVersion = releaseRegistry.createNextRelease();

            // pause with revert
            vm.expectRevert(abi.encodeWithSelector(
                ILifecycle.ErrorFromStateMissmatch.selector,
                address(releaseRegistry), 
                RELEASE(), 
                SCHEDULED(), 
                ACTIVE()
            ));
            vm.prank(gifAdmin);
            releaseRegistry.setActive(createdVersion, false);
        }
    }

    function test_releaseRegistry_pauseRelease_whenReleaseDeploying() public
    {
        for(uint i = 0; i <= 2; i++) 
        {
            // create
            vm.prank(gifAdmin);
            VersionPart createdVersion = releaseRegistry.createNextRelease();

            // prepare
            ServiceAuthorizationMockWithRegistryService serviceAuth = new ServiceAuthorizationMockWithRegistryService(createdVersion);
            bytes32 salt = bytes32(randomNumber(type(uint256).max)); 

            vm.prank(gifManager);
            releaseRegistry.prepareNextRelease(serviceAuth, salt);

            // pause with revert
            vm.expectRevert(abi.encodeWithSelector(
                ILifecycle.ErrorFromStateMissmatch.selector,
                address(releaseRegistry), 
                RELEASE(), 
                DEPLOYING(), 
                ACTIVE()
            ));
            vm.prank(gifAdmin);
            releaseRegistry.setActive(createdVersion, false);
        }
    }

    function test_releaseRegistry_pauseRelease_whenReleaseDeployed() public
    {
        for(uint i = 0; i <= 2; i++) 
        {
            // create
            vm.prank(gifAdmin);
            VersionPart createdVersion = releaseRegistry.createNextRelease();

            // prepare
            IServiceAuthorization authMock = new ServiceAuthorizationMockWithRegistryService(createdVersion);
            bytes32 salt = bytes32(randomNumber(type(uint256).max)); 
            IAccessAdmin preparedAdmin;

            vm.prank(gifManager);
            (preparedAdmin,,) = releaseRegistry.prepareNextRelease(authMock, salt);

            // deploy (register all(1) services)
            IService service = _prepareServiceWithRegistryDomain(createdVersion, ReleaseAdmin(address(preparedAdmin)));

            vm.prank(gifManager);
            releaseRegistry.registerService(service);

            // pause with revert
            vm.expectRevert(abi.encodeWithSelector(
                ILifecycle.ErrorFromStateMissmatch.selector,
                address(releaseRegistry), 
                RELEASE(), 
                DEPLOYED(), 
                ACTIVE()
            ));
            vm.prank(gifAdmin);
            releaseRegistry.setActive(createdVersion, false);
        }
    }

    function test_releaseRegistry_pauseRelease_whenReleaseActiveHappyCase() public
    {
        // Equivalent to test_releaseRegistry_createRelease_whenReleasePausedHappyCase()
        // create
        // prepare
        // register service
        // activate
        // pause
        // loop
    }

    function test_releaseRegistry_pauseRelease_whenReleasePaused() public
    {
        for(uint i = 0; i <= 2; i++) 
        {
            // create
            vm.prank(gifAdmin);
            VersionPart createdVersion = releaseRegistry.createNextRelease();

            // prepare
            IServiceAuthorization authMock = new ServiceAuthorizationMockWithRegistryService(createdVersion);
            bytes32 salt = bytes32(randomNumber(type(uint256).max)); 
            IAccessAdmin preparedAdmin;

            vm.prank(gifManager);
            (preparedAdmin,,) = releaseRegistry.prepareNextRelease(authMock, salt);

            // deploy (register all(1) services)
            IService service = _prepareServiceWithRegistryDomain(createdVersion, ReleaseAdmin(address(preparedAdmin)));

            vm.prank(gifManager);
            releaseRegistry.registerService(service);

            // activate
            vm.prank(gifAdmin);
            releaseRegistry.activateNextRelease();

            // pause
            vm.prank(gifAdmin);
            releaseRegistry.setActive(createdVersion, false);

            // pause with revert
            vm.expectRevert(abi.encodeWithSelector(
                ILifecycle.ErrorFromStateMissmatch.selector,
                address(releaseRegistry), 
                RELEASE(), 
                PAUSED(), 
                ACTIVE()
            ));
            vm.prank(gifAdmin);
            releaseRegistry.setActive(createdVersion, false);
        }
    }

    // ------------------------ unpauseRelease ----------------------------//

    function test_releaseRegistry_unpauseRelease_byNotAuthorizedCaller() public
    {
        VersionPart version;

        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, gifManager));
        vm.prank(gifManager);
        releaseRegistry.setActive(version, true);

        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, stakingOwner));
        vm.prank(stakingOwner);
        releaseRegistry.setActive(version, true);

        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, outsider));
        vm.prank(outsider);
        releaseRegistry.setActive(version, true);
    }

    function test_unpauseRelease_whenInitialReleaseNotCreated() public
    {
        // loop through first n versions
        for(uint i = 0; i < 5; i++)
        {
            VersionPart version = VersionPartLib.toVersionPart(i);
            vm.expectRevert(abi.encodeWithSelector(
                ILifecycle.ErrorFromStateMissmatch.selector,
                address(releaseRegistry), 
                RELEASE(), 
                StateIdLib.zero(), 
                PAUSED()
            ));
            vm.prank(gifAdmin);
            releaseRegistry.setActive(version, true);
        }
    }

    function test_releaseRegistry_unpauseRelease_whenReleaseScheduled() public
    {
       for(uint i = 0; i <= 2; i++) 
        {
            // create - skip
            vm.prank(gifAdmin);
            VersionPart createdVersion = releaseRegistry.createNextRelease();

            // unpause with revert
            vm.expectRevert(abi.encodeWithSelector(
                ILifecycle.ErrorFromStateMissmatch.selector,
                address(releaseRegistry), 
                RELEASE(), 
                SCHEDULED(), 
                PAUSED()
            ));
            vm.prank(gifAdmin);
            releaseRegistry.setActive(createdVersion, true);
        }
    }

    function test_releaseRegistry_unpauseRelease_whenReleaseDeploying() public
    {
        for(uint i = 0; i <= 2; i++) 
        {
            // create
            vm.prank(gifAdmin);
            VersionPart createdVersion = releaseRegistry.createNextRelease();

            // prepare
            ServiceAuthorizationMockWithRegistryService serviceAuth = new ServiceAuthorizationMockWithRegistryService(createdVersion);
            bytes32 salt = bytes32(randomNumber(type(uint256).max)); 

            vm.prank(gifManager);
            releaseRegistry.prepareNextRelease(serviceAuth, salt);

            // unpause with revert
            vm.expectRevert(abi.encodeWithSelector(
                ILifecycle.ErrorFromStateMissmatch.selector,
                address(releaseRegistry), 
                RELEASE(), 
                DEPLOYING(), 
                PAUSED()
            ));
            vm.prank(gifAdmin);
            releaseRegistry.setActive(createdVersion, true);
        }
    }

    function test_releaseRegistry_unpauseRelease_whenReleaseDeployed() public
    {
        for(uint i = 0; i <= 2; i++) 
        {
            // create
            vm.prank(gifAdmin);
            VersionPart createdVersion = releaseRegistry.createNextRelease();

            // prepare
            IServiceAuthorization authMock = new ServiceAuthorizationMockWithRegistryService(createdVersion);
            bytes32 salt = bytes32(randomNumber(type(uint256).max)); 
            IAccessAdmin preparedAdmin;

            vm.prank(gifManager);
            (preparedAdmin,,) = releaseRegistry.prepareNextRelease(authMock, salt);

            // deploy (register all(1) services)
            IService service = _prepareServiceWithRegistryDomain(createdVersion, ReleaseAdmin(address(preparedAdmin)));

            vm.prank(gifManager);
            releaseRegistry.registerService(service);

            // unpause with revert
            vm.expectRevert(abi.encodeWithSelector(
                ILifecycle.ErrorFromStateMissmatch.selector,
                address(releaseRegistry), 
                RELEASE(), 
                DEPLOYED(), 
                PAUSED()
            ));
            vm.prank(gifAdmin);
            releaseRegistry.setActive(createdVersion, true);
        }
    }

    function test_releaseRegistry_unpauseRelease_whenReleaseActive() public
    {
        for(uint i = 0; i <= 2; i++) 
        {
            // create
            vm.prank(gifAdmin);
            VersionPart createdVersion = releaseRegistry.createNextRelease();

            // prepare
            IServiceAuthorization authMock = new ServiceAuthorizationMockWithRegistryService(createdVersion);
            bytes32 salt = bytes32(randomNumber(type(uint256).max)); 
            IAccessAdmin preparedAdmin;

            vm.prank(gifManager);
            (preparedAdmin,,) = releaseRegistry.prepareNextRelease(authMock, salt);

            // deploy (register all(1) services)
            IService service = _prepareServiceWithRegistryDomain(createdVersion, ReleaseAdmin(address(preparedAdmin)));

            vm.prank(gifManager);
            releaseRegistry.registerService(service);

            // activate
            vm.prank(gifAdmin);
            releaseRegistry.activateNextRelease();

            // unpause with revert
            vm.expectRevert(abi.encodeWithSelector(
                ILifecycle.ErrorFromStateMissmatch.selector,
                address(releaseRegistry), 
                RELEASE(), 
                ACTIVE(), 
                PAUSED()
            ));
            vm.prank(gifAdmin);
            releaseRegistry.setActive(createdVersion, true);
        }
    }

    function test_releaseRegistry_unpauseRelease_whenReleasePausedHappyCase() public
    {
        // Equivalent to test_releaseRegistry_createRelease_whenReleaseUnpausedHappyCase()
        // create
        // prepare
        // register service
        // activate
        // pause
        // unpause
        // loop
    }
}
