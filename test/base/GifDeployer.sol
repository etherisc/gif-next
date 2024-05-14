// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";

import {Dip} from "../../contracts/mock/Dip.sol";
import {GIF_MANAGER_ROLE, GIF_ADMIN_ROLE} from "../../contracts/type/RoleId.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {RegistryAccessManager} from "../../contracts/registry/RegistryAccessManager.sol";
import {ReleaseManager} from "../../contracts/registry/ReleaseManager.sol";
import {Staking} from "../../contracts/staking/Staking.sol";
import {StakingManager} from "../../contracts/staking/StakingManager.sol";
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
            RegistryAccessManager registryAccessManager,
            StakingManager stakingManager,
            Staking staking
        )
    {
        // 1) deploy dip token
        dip = new Dip();

        // 2) deploy registry
        registry = new Registry();

        // 3) deploy release manager
        releaseManager = new ReleaseManager(
            gifAdmin,
            gifManager,
            address(registry));

        registryAccessManager = releaseManager.getRegistryAccessManager();

        // 4) deploy token registry
        tokenRegistry = new TokenRegistry(
            registryAccessManager.authority(),
            address(registry),
            address(dip));

        // 5) grant gif manager role access to token registry
        registryAccessManager.setTokenRegistry(
            address(tokenRegistry));

        // 6) initialize registry with links to 
        // relase manager and token registry
        registry.initialize(
            address(releaseManager),
            address(tokenRegistry));

        // 7) deploy staking store
        StakingStore stakingStore = new StakingStore(
            registryAccessManager.authority(),
            address(registry)
        );

        // 8) deploy staking manager / staking
        stakingManager = new StakingManager(
            address(registry),
            address(stakingStore),
            stakingOwner);

        // 9) register staking with registry (via release manager)
        staking = stakingManager.getStaking();
        releaseManager.registerStaking(address(staking));
    }
}