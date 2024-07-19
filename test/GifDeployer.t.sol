// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {console} from "../lib/forge-std/src/Test.sol";

import {ChainNft} from "../contracts/registry/ChainNft.sol";
import {Dip} from "../contracts/mock/Dip.sol";
import {GifDeployer} from "./base/GifDeployer.sol";
import {GIF_MANAGER_ROLE, GIF_ADMIN_ROLE} from "../contracts/type/RoleId.sol";
import {IRegistry} from "../contracts/registry/IRegistry.sol";
import {IServiceAuthorization} from "../contracts/authorization/IServiceAuthorization.sol";
import {NftId, NftIdLib} from "../contracts/type/NftId.sol";
import {Registry} from "../contracts/registry/Registry.sol";
import {RegistryAdmin} from "../contracts/registry/RegistryAdmin.sol";
import {ReleaseRegistry} from "../contracts/registry/ReleaseRegistry.sol";
import {REGISTRY, STAKING} from "../contracts/type/ObjectType.sol";
import {Selector, SelectorLib} from "../contracts/type/Selector.sol";
import {ServiceAuthorizationV3} from "../contracts/registry/ServiceAuthorizationV3.sol";
import {Staking} from "../contracts/staking/Staking.sol";
import {StakingManager} from "../contracts/staking/StakingManager.sol";
import {StakingReader} from "../contracts/staking/StakingReader.sol";
import {StakingStore} from "../contracts/staking/StakingStore.sol";
import {TokenRegistry} from "../contracts/registry/TokenRegistry.sol";
import {VersionPart, VersionPartLib} from "../contracts/type/Version.sol";

// solhint-disable-next-line max-states-count
contract GifDeployerTest is GifDeployer {

    GifCore core;

    VersionPart public gifV3 = VersionPartLib.toVersionPart(3);
    IServiceAuthorization public serviceAuthorization = new ServiceAuthorizationV3("85b428cbb5185aee615d101c2554b0a58fb64810");

    address public globalRegistry = makeAddr("globalRegistry");
    address public registryOwner = makeAddr("registryOwner");
    address public gifAdmin = registryOwner;
    address public gifManager = registryOwner;
    address public stakingOwner = registryOwner;


    // TODO missing setup function

    function test_deployerCoreDip() public {
        assertTrue(address(core.dip) != address(0), "dip address zero");
        assertEq(core.dip.decimals(), 18, "unexpected decimals for dip");
    }


    function test_deployerCoreRegistry() public {
        assertTrue(address(core.registry) != address(0), "registry address zero");

        // check registry
        NftId registryNftId = core.registry.getNftId();
        assertTrue(registryNftId.gtz(), "registry nft id zero");

        // nft id and ownership
        assertEq(core.registry.getNftIdForAddress(address(core.registry)).toInt(), registryNftId.toInt(), "unexpected registry nft id");
        assertEq(core.registry.ownerOf(registryNftId), core.registry.NFT_LOCK_ADDRESS(), "unexpected registry nft owner (via nft lock address)");
        assertEq(core.registry.ownerOf(registryNftId), core.registry.getOwner(), "unexpected registry nft owner (via owner)");

        // check info
        IRegistry.ObjectInfo memory info = core.registry.getObjectInfo(registryNftId);
        assertEq(info.nftId.toInt(), registryNftId.toInt(), "unexpected registry nft id (info)");
        assertTrue(info.parentNftId.gtz(), "registry parent nft zero");
        assertEq(info.objectType.toInt(), REGISTRY().toInt(), "unexpected registry type");
        assertFalse(info.isInterceptor, "registry marked as interceptor");
        assertEq(info.objectAddress, address(core.registry), "unexpected registry address");

        // check linked contracts
        assertEq(core.registry.getChainNftAddress(), address(core.chainNft), "unexpected chainNft address");
        assertEq(core.registry.getReleaseRegistryAddress(), address(core.releaseRegistry), "unexpected release manager address");
        assertEq(core.registry.getStakingAddress(), address(core.staking), "unexpected staking address");
        assertEq(core.registry.getTokenRegistryAddress(), address(core.tokenRegistry), "unexpected token registry address");
    }


    function test_deployerCoreTokenRegistry() public {
        assertTrue(address(core.tokenRegistry) != address(0), "token registry address zero");

        assertEq(address(core.tokenRegistry.getDipToken()), address(core.dip), "unexpected dip address");
        assertTrue(core.tokenRegistry.isRegistered(block.chainid, address(core.dip)), "dip not registered with token registry");

        // TODO reactivate + amend once full gif setup is streamlined
        // assertTrue(core.tokenRegistry.isActive(block.chainid, address(core.dip), VersionPartLib.toVersionPart(3)), "dip not active for gif version 3");
    }


    function test_deployerCoreReleaseRegistry() public {
        assertTrue(address(core.releaseRegistry) != address(0), "release manager address zero");

        // check authority
        assertEq(core.releaseRegistry.authority(), core.registryAdmin.authority(), "unexpected release manager authority");

        // check linked contracts
        assertEq(address(core.releaseRegistry.getRegistry()), address(core.registry), "unexpected registry address");
        assertEq(core.releaseRegistry.INITIAL_GIF_VERSION(), gifV3.toInt(), "unexpected initial gif version");
        assertEq(address(core.releaseRegistry.getRegistryAdmin()), address(core.registryAdmin), "unexpected registry address");

        // TODO amend once full gif setup is streamlined
    }


    function test_deployerCoreRegistryAdmin() public {
        assertTrue(address(core.registryAdmin) != address(0), "registry admin manager address zero");
        assertTrue(core.registryAdmin.authority() != address(0), "registry admin manager authority address zero");

        // check authority
        // TODO is this correct? 
        assertEq(core.registryAdmin.authority(), core.registryAdmin.authority(), "unexpected release manager authority");

        // check initial roles assignments
        assertTrue(core.registryAdmin.hasRole(gifAdmin, GIF_ADMIN_ROLE()), "registry owner not admin");
        assertTrue(core.registryAdmin.hasRole(gifManager, GIF_MANAGER_ROLE()), "registry owner not manager");

        // check sample admin access
        assertTrue(
            core.registryAdmin.canCall(
                gifAdmin, // caller
                address(core.releaseRegistry), // target
                _toSelector(ReleaseRegistry.createNextRelease.selector)), 
            "gif manager cannot call registerToken");

        // check sample manager access
        assertTrue(
            core.registryAdmin.canCall(
                gifManager, // caller
                address(core.tokenRegistry), // target
                _toSelector(TokenRegistry.registerToken.selector)), 
            "gif manager cannot call registerToken");

        // check linked contracts
        assertEq(address(core.releaseRegistry.getRegistry()), address(core.registry), "unexpected registry address");
        assertEq(core.releaseRegistry.INITIAL_GIF_VERSION(), gifV3.toInt(), "unexpected initial gif version");
        assertEq(address(core.releaseRegistry.getRegistryAdmin()), address(core.registryAdmin), "unexpected registry address");

        // TODO amend once full gif setup is streamlined
    }

    function _toSelector(bytes4 selector) internal pure returns (Selector) {
        return SelectorLib.toSelector(selector);
    }

    function test_deployerCoreStakingManager() public {
        assertTrue(address(core.stakingManager) != address(0), "staking manager address zero");

        // assertEq(stakingOwner, registryOwner, "unexpected staking owner");
        // assertEq(core.stakingManager.getOwner(), stakingOwner, "unexpected staking manager owner");
        // assertEq(core.stakingManager.getOwner(), core.staking.getOwner(), "staking manager owner mismatch");
        // assertEq(address(core.stakingManager.getStaking()), address(core.staking), "unexpected staking address");
    }


    function test_deployerCoreStakingContract() public {
        assertTrue(address(core.staking) != address(0), "staking address zero");

        // check nft id
        NftId stakingNftId = core.staking.getNftId();
        assertTrue(stakingNftId.gtz(), "staking nft id zero");
        assertEq(stakingNftId.toInt(), core.registry.getNftIdForAddress(address(core.staking)).toInt(), "unexpected staking nft id");

        // check ownership
        assertEq(stakingOwner, registryOwner, "unexpected staking owner");
        assertEq(core.staking.getOwner(), stakingOwner, "unexpected staking owner (via staking)");
        assertEq(core.registry.ownerOf(address(core.staking)), stakingOwner, "unexpected staking owner (via registry)");

        // check authority
        assertEq(core.staking.authority(), core.registryAdmin.authority(), "unexpected staking authority");

        // check info
        IRegistry.ObjectInfo memory info = core.registry.getObjectInfo(stakingNftId);
        assertEq(info.nftId.toInt(), stakingNftId.toInt(), "unexpected staking nft id (info)");
        assertEq(info.parentNftId.toInt(), core.registry.getNftId().toInt(), "staking parent nft not registry");
        assertEq(info.objectType.toInt(), STAKING().toInt(), "unexpected staking type");
        assertFalse(info.isInterceptor, "staking marked as interceptor");
        assertEq(info.objectAddress, address(core.staking), "unexpected staking address");

        // check linked contracts
        assertTrue(address(core.staking.getStakingReader()) != address(0), "staking reader zero");
        assertTrue(address(core.staking.getStakingStore()) != address(0), "staking reader zero");
    }


    function test_deployerCoreStakingReader() public {
        StakingReader reader = StakingReader(core.staking.getStakingReader());

        assertEq(address(reader.getRegistry()), address(core.registry), "unexpected registry address");
        assertEq(address(reader.getStaking()), address(core.staking), "unexpected staking address");
    }


    function test_deployerCoreStakingStore() public {
        StakingStore store = StakingStore(core.staking.getStakingStore());

        // check authority
        assertEq(store.authority(), core.registryAdmin.authority(), "unexpected staking store authority");
    }


    function setUp() public virtual {
        core = deployCore(
            globalRegistry,
            gifAdmin,
            gifManager,
            stakingOwner);

        deployRelease(
            core.releaseRegistry,
            serviceAuthorization,
            gifAdmin,
            gifManager);
    }
}
