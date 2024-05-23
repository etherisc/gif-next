// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";

import {Dip} from "../../contracts/mock/Dip.sol";
import {GIF_MANAGER_ROLE, GIF_ADMIN_ROLE} from "../../contracts/type/RoleId.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {RegistryAdmin} from "../../contracts/registry/RegistryAdmin.sol";
import {ReleaseManager} from "../../contracts/registry/ReleaseManager.sol";
import {Staking} from "../../contracts/staking/Staking.sol";
import {StakingManager} from "../../contracts/staking/StakingManager.sol";
import {StakingReader} from "../../contracts/staking/StakingReader.sol";
import {StakingStore} from "../../contracts/staking/StakingStore.sol";
import {TokenRegistry} from "../../contracts/registry/TokenRegistry.sol";

contract GifDeployer is Test {

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
            ReleaseManager releaseManager,
            RegistryAdmin registryAdmin,
            StakingManager stakingManager,
            Staking staking
        )
    {
        // 1) deploy dip token
        dip = new Dip();

        // 2) deploy registry admin and registry access manager
        registryAdmin = new RegistryAdmin();

        // 3) deploy registry and chainNft
        registry = new Registry(registryAdmin);

        // 4) deploy release manager
        releaseManager = new ReleaseManager(registry);

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
            address(releaseManager),
            address(tokenRegistry),
            address(staking));
        staking.linkToRegisteredNftId();

        // 11) initialize registry admin
        registryAdmin.initialize(
            registry,
            gifAdmin,
            gifManager);
    }
}