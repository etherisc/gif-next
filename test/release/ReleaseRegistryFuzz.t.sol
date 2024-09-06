// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {FoundryRandom} from "foundry-random/FoundryRandom.sol";
import {console} from "../../lib/forge-std/src/Test.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {IRelease} from "../../contracts/registry/IRelease.sol";
import {IService} from "../../contracts/shared/IService.sol";

import {ChainNft} from "../../contracts/registry/ChainNft.sol";
import {GifDeployer} from "../base/GifDeployer.sol";
import {NftIdLib} from "../../contracts/type/NftId.sol";
import {ObjectType, SERVICE} from "../../contracts/type/ObjectType.sol";
import {ReleaseRegistry} from "../../contracts/registry/ReleaseRegistry.sol";
import {ServiceMockWithRegistryDomainV3, ServiceMockWithRegistryDomainV4, ServiceMockWithRegistryDomainV5} from "../mock/ServiceMock.sol";
import {StateIdLib, SCHEDULED, DEPLOYING, DEPLOYED, SKIPPED, ACTIVE, PAUSED} from "../../contracts/type/StateId.sol";
import {TimestampLib, gteTimestamp} from "../../contracts/type/Timestamp.sol";
import {VersionPart, VersionPartLib} from "../../contracts/type/Version.sol";


contract ReleaseRegistryTest is GifDeployer, FoundryRandom {

    // keep identical to ReleaseRegistry events
    event LogReleaseCreation(VersionPart version, bytes32 salt); 
    event LogReleaseActivation(VersionPart version);
    event LogReleaseDisabled(VersionPart version);
    event LogReleaseEnabled(VersionPart version);

    address public outsider = makeAddr("outsider");
    mapping(VersionPart version => IService) public serviceByVersion;


    function setUp() public virtual
    {
        gifAdmin = makeAddr("gifAdmin");
        gifManager = makeAddr("gifManager");
        stakingOwner = makeAddr("stakingOwner");

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

        vm.startPrank(gifManager);

        serviceByVersion[VersionPartLib.toVersionPart(3)] = new ServiceMockWithRegistryDomainV3(
            NftIdLib.zero(), 
            registryNftId, 
            false, // isInterceptor
            gifManager,
            registryAdmin.authority());
        serviceByVersion[VersionPartLib.toVersionPart(4)] = new ServiceMockWithRegistryDomainV4(
            NftIdLib.zero(), 
            registryNftId, 
            false, // isInterceptor
            gifManager,
            registryAdmin.authority());
        serviceByVersion[VersionPartLib.toVersionPart(5)] = new ServiceMockWithRegistryDomainV5(
            NftIdLib.zero(), 
            registryNftId, 
            false, // isInterceptor
            gifManager,
            registryAdmin.authority());

        vm.stopPrank();
    }

    function _verifyServiceInfoChecks(IService service, IRegistry.ObjectInfo memory info, address expectedOwner) 
        public 
        view
        returns(bool expectRevert, bytes memory revertMsg)
    {
        address owner = info.initialOwner;

        if(info.objectAddress != address(service)) {
            revertMsg = abi.encodeWithSelector(
                ReleaseRegistry.ErrorReleaseRegistryServiceInfoAddressInvalid.selector,
                service, 
                info.objectAddress
            );
            expectRevert = true;
        } else if(info.isInterceptor != false) { // service is never interceptor
            revertMsg = abi.encodeWithSelector(
                ReleaseRegistry.ErrorReleaseRegistryServiceInfoInterceptorInvalid.selector,
                service, 
                info.isInterceptor
            );
            expectRevert = true;
        } else if(info.objectType != SERVICE()) {
            revertMsg = abi.encodeWithSelector(
                ReleaseRegistry.ErrorReleaseRegistryServiceInfoTypeInvalid.selector,
                service, 
                SERVICE(), 
                info.objectType
            );
            expectRevert = true;
        } else if(owner != expectedOwner) { // registerable owner protection
            revertMsg = abi.encodeWithSelector(
                ReleaseRegistry.ErrorReleaseRegistryServiceInfoOwnerInvalid.selector,
                service, 
                expectedOwner, 
                owner
            );
            expectRevert = true;
        } else if(owner == address(service)) {
            revertMsg = abi.encodeWithSelector(
                ReleaseRegistry.ErrorReleaseRegistryServiceSelfRegistration.selector,
                service
            );
            expectRevert = true;
        } else if(registry.isRegistered(owner)) { 
            revertMsg = abi.encodeWithSelector(
                ReleaseRegistry.ErrorReleaseRegistryServiceOwnerRegistered.selector,
                service, 
                owner
            );
            expectRevert = true;
        }
    }
    function _checkReleaseInfo(IRelease.ReleaseInfo memory info) public view 
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
            // solhint-disable next-line
            console.log("Unexpected state ", info.state.toInt());
            assertTrue(false, "Test error: unexpected state");
        }        
    }

    // assert by version getters
    function _assert_releaseRegistry_getters(VersionPart version, IRelease.ReleaseInfo memory info) public view
    {
        _checkReleaseInfo(info);

        assertEq(releaseRegistry.isActiveRelease(version), (info.activatedAt.gtz() && info.disabledAt.eqz()), "isActiveRelease() return unxpected value");
        assertTrue(eqReleaseInfo(releaseRegistry.getReleaseInfo(version), info), "getReleaseInfo() return unxpected value");  
        assertEq(releaseRegistry.getState(version).toInt(), info.state.toInt(), "getState() return unexpected value #1");
        assertEq(address(releaseRegistry.getServiceAuthorization(version)), address(info.auth), "getServiceAuthorization() return unexpected value #1");    
    }

    function test_releaseRegistry_setUp() public view
    {
        for(uint256 i = 0; i <= releaseRegistry.INITIAL_GIF_VERSION() + 1; i++) {
            _assert_releaseRegistry_getters(VersionPartLib.toVersionPart(i), zeroReleaseInfo());
        }

        assertEq(releaseRegistry.releases(), 0, "releases() return unexpected value");
        assertEq(releaseRegistry.getNextVersion().toInt(), releaseRegistry.INITIAL_GIF_VERSION() - 1, "getNextVersion() return unexpected value");
        assertEq(releaseRegistry.getLatestVersion().toInt(), 0, "getLatestVersion() return unexpected value");

        assertEq(releaseRegistry.getRemainingServicesToRegister(), 0, "getRemainingServicesToRegister() return unexpected value");

        assertEq(releaseRegistry.getRegistryAdmin(), address(registryAdmin), "getRegistryAdmin() return unexpected value");
        assertEq(address(releaseRegistry.getRegistry()), address(registry), "getRegistry() return unexpected value");
    }


    function testFuzz_releaseRegistry_prepareRelease_verifyServiceInfo() public
    {
        // create harness
    }
}
