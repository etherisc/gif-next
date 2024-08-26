// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
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

    IERC20Metadata public dip;
    ChainNft public chainNft;
    Registry public registry;
    TokenRegistry public tokenRegistry;
    ReleaseRegistry public releaseRegistry;
    RegistryAdmin public registryAdmin;
    StakingManager public stakingManager;
    Staking public staking;

    VersionPart public gifV3 = VersionPartLib.toVersionPart(3);
    IServiceAuthorization public serviceAuthorization = new ServiceAuthorizationV3("85b428cbb5185aee615d101c2554b0a58fb64810");

    address public globalRegistry = makeAddr("globalRegistry");
    address public registryOwner = makeAddr("registryOwner");
    address public gifAdmin = registryOwner;
    address public gifManager = registryOwner;
    address public stakingOwner = registryOwner;


    function test_deployerCoreDip() public {
        assertTrue(address(dip) != address(0), "dip address zero");
        assertEq(dip.decimals(), 18, "unexpected decimals for dip");
    }


    function test_deployerCoreRegistry() public {
        assertTrue(address(registry) != address(0), "registry address zero");

        // check registry
        NftId registryNftId = registry.getNftId();
        assertTrue(registryNftId.gtz(), "registry nft id zero");

        // nft id and ownership
        assertEq(registry.getNftIdForAddress(address(registry)).toInt(), registryNftId.toInt(), "unexpected registry nft id");
        assertEq(registry.ownerOf(registryNftId), registry.NFT_LOCK_ADDRESS(), "unexpected registry nft owner (via nft lock address)");
        assertEq(registry.ownerOf(registryNftId), registry.getOwner(), "unexpected registry nft owner (via owner)");

        // check info
        IRegistry.ObjectInfo memory info = registry.getObjectInfo(registryNftId);
        assertEq(info.nftId.toInt(), registryNftId.toInt(), "unexpected registry nft id (info)");
        assertTrue(info.parentNftId.gtz(), "registry parent nft zero");
        assertEq(info.objectType.toInt(), REGISTRY().toInt(), "unexpected registry type");
        assertFalse(info.isInterceptor, "registry marked as interceptor");
        assertEq(info.objectAddress, address(registry), "unexpected registry address");

        // check linked contracts
        assertEq(registry.getChainNftAddress(), address(chainNft), "unexpected chainNft address");
        assertEq(registry.getReleaseRegistryAddress(), address(releaseRegistry), "unexpected release manager address");
        assertEq(registry.getStakingAddress(), address(staking), "unexpected staking address");
        assertEq(registry.getTokenRegistryAddress(), address(tokenRegistry), "unexpected token registry address");
    }


    function test_deployerCoreTokenRegistry() public {
        assertTrue(address(tokenRegistry) != address(0), "token registry address zero");

        assertEq(address(tokenRegistry.getDipToken()), address(dip), "unexpected dip address");
        assertTrue(tokenRegistry.isRegistered(block.chainid, address(dip)), "dip not registered with token registry");

        // TODO reactivate + amend once full gif setup is streamlined
        // assertTrue(tokenRegistry.isActive(block.chainid, address(dip), VersionPartLib.toVersionPart(3)), "dip not active for gif version 3");
    }


    function test_deployerCoreReleaseRegistry() public {
        assertTrue(address(releaseRegistry) != address(0), "release manager address zero");

        // check authority
        assertEq(releaseRegistry.authority(), registryAdmin.authority(), "unexpected release manager authority");

        // check linked contracts
        assertEq(address(releaseRegistry.getRegistry()), address(registry), "unexpected registry address");
        assertEq(releaseRegistry.INITIAL_GIF_VERSION(), gifV3.toInt(), "unexpected initial gif version");
        assertEq(address(releaseRegistry.getRegistryAdmin()), address(registryAdmin), "unexpected registry address");

        // TODO amend once full gif setup is streamlined
    }


    function test_deployerCoreRegistryAccessManager() public {
        assertTrue(address(registryAdmin) != address(0), "registry admin manager address zero");
        assertTrue(registryAdmin.authority() != address(0), "registry admin manager authority address zero");

        // check authority
        assertEq(registryAdmin.authority(), registryAdmin.authority(), "unexpected release manager authority");

        // check initial roles assignments
        assertTrue(registryAdmin.hasRole(gifAdmin, GIF_ADMIN_ROLE()), "registry owner not admin");
        assertTrue(registryAdmin.hasRole(gifManager, GIF_MANAGER_ROLE()), "registry owner not manager");

        // check sample admin access
        IAccessManager authority = IAccessManager(registryAdmin.authority());
        bool can;
        (can,) = authority.canCall(gifAdmin, address(registryAdmin), TokenRegistry.registerToken.selector);
        assertFalse(can, "gif admin cannot call registerToken");

        // check sample manager access
        (can,) = authority.canCall(gifManager, address(tokenRegistry), TokenRegistry.registerToken.selector);
        assertTrue(can, "gif manager cannot call registerToken");

        // check linked contracts
        assertEq(address(releaseRegistry.getRegistry()), address(registry), "unexpected registry address");
        assertEq(releaseRegistry.INITIAL_GIF_VERSION(), gifV3.toInt(), "unexpected initial gif version");
        assertEq(address(releaseRegistry.getRegistryAdmin()), address(registryAdmin), "unexpected registry address");

        // TODO amend once full gif setup is streamlined
    }

    function test_deployerCoreStakingManager() public {
        assertTrue(address(stakingManager) != address(0), "staking manager address zero");

        // assertEq(stakingOwner, registryOwner, "unexpected staking owner");
        // assertEq(stakingManager.getOwner(), stakingOwner, "unexpected staking manager owner");
        // assertEq(stakingManager.getOwner(), staking.getOwner(), "staking manager owner mismatch");
        // assertEq(address(stakingManager.getStaking()), address(staking), "unexpected staking address");
    }


    function test_deployerCoreStakingContract() public {
        assertTrue(address(staking) != address(0), "staking address zero");

        // check nft id
        NftId stakingNftId = staking.getNftId();
        assertTrue(stakingNftId.gtz(), "staking nft id zero");
        assertEq(stakingNftId.toInt(), registry.getNftIdForAddress(address(staking)).toInt(), "unexpected staking nft id");

        // check ownership
        assertEq(stakingOwner, registryOwner, "unexpected staking owner");
        assertEq(staking.getOwner(), stakingOwner, "unexpected staking owner (via staking)");
        assertEq(registry.ownerOf(address(staking)), stakingOwner, "unexpected staking owner (via registry)");

        // check authority
        assertEq(staking.authority(), registryAdmin.authority(), "unexpected staking authority");

        // check info
        IRegistry.ObjectInfo memory info = registry.getObjectInfo(stakingNftId);
        assertEq(info.nftId.toInt(), stakingNftId.toInt(), "unexpected staking nft id (info)");
        assertEq(info.parentNftId.toInt(), registry.getNftId().toInt(), "staking parent nft not registry");
        assertEq(info.objectType.toInt(), STAKING().toInt(), "unexpected staking type");
        assertFalse(info.isInterceptor, "staking marked as interceptor");
        assertEq(info.objectAddress, address(staking), "unexpected staking address");

        // check linked contracts
        assertTrue(address(staking.getStakingReader()) != address(0), "staking reader zero");
        assertTrue(address(staking.getStakingStore()) != address(0), "staking reader zero");
    }


    function test_deployerCoreStakingReader() public {
        StakingReader reader = StakingReader(staking.getStakingReader());

        assertEq(address(reader.getRegistry()), address(registry), "unexpected registry address");
        assertEq(address(reader.getStaking()), address(staking), "unexpected staking address");
    }


    function test_deployerCoreStakingStore() public {
        StakingStore store = StakingStore(staking.getStakingStore());

        // check authority
        assertEq(store.authority(), registryAdmin.authority(), "unexpected staking store authority");
    }


    function setUp() public virtual {
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
        
        chainNft = ChainNft(registry.getChainNftAddress());

        deployRelease(
            releaseRegistry,
            serviceAuthorization,
            gifAdmin,
            gifManager);
    }
}
