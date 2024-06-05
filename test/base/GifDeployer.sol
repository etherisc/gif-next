// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {CreateXScript} from "../../lib/createx-forge/script/CreateXScript.sol";


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
            StakingManager stakingManager
        )
    {
        address initializeOwner = gifAdmin;
        // prepare salt for permissioned deploymnet
        bytes32 guardedSalt = keccak256(abi.encodePacked(uint256(uint160(gifAdmin)), salt));
        // 1) deploy dip token
        IERC20Metadata dip = new Dip();

        // 2) deploy registry admin
        RegistryAdmin registryAdmin = _deployRegistryAdmin(initializeOwner, guardedSalt);

        // 3) deploy registry
        registry = _deployRegistry(
            address(registryAdmin),
            initializeOwner,
            guardedSalt);

        {
            // 4) deploy release manager
            ReleaseManager releaseManager = _deployReleaseManager(
                address(registry),
                guardedSalt);

            // 5) deploy token registry
            TokenRegistry tokenRegistry = _deployTokenRegistry(
                address(registry),
                address(dip),
                guardedSalt);

            // 6) deploy staking reader
            StakingReader stakingReader = _deployStakingReader(
                address(registry), 
                initializeOwner, 
                guardedSalt);

            // 7) deploy staking store
            StakingStore stakingStore = _deployStakingStore(
                address(registry),
                address(stakingReader),
                guardedSalt);

            // 8) deploy staking manager and staking component
            stakingManager = _deployStakingManager(
                address (registry), 
                address(tokenRegistry), 
                address(stakingStore), 
                stakingOwner, 
                guardedSalt);
            Staking staking = stakingManager.getStaking();

            // 9) initialize instance reader
            stakingReader.initialize(
                address(staking),
                address(stakingStore));

            // 10) intialize registry and register staking component
            registry.initialize(
                address(releaseManager),
                address(tokenRegistry), // <- under question
                address(staking));
            staking.linkToRegisteredNftId();
        }


        // 11) initialize registry admin
        registryAdmin.initialize(
            registry, // address(registry)
            gifAdmin,
            gifManager);
    }

    function _deployRegistryAdmin(address initializeOwner, bytes32 salt) internal returns (RegistryAdmin) {
        //registryAdmin = new RegistryAdmin(initializeOwner);
        bytes memory initCode = abi.encodePacked(
            type(RegistryAdmin).creationCode, 
            abi.encode(initializeOwner));//, salt));// exctract deployer from salt? can 
        return RegistryAdmin(CreateX.deployCreate2(salt, initCode));
    }

    function _deployRegistry(address registryAdmin, address initializeOwner, bytes32 salt) internal returns (Registry) {
        //registry = new Registry(registryAdmin, initializeOwner);
        bytes memory initCode = abi.encodePacked(
            type(Registry).creationCode, 
            abi.encode(registryAdmin, initializeOwner));//, salt));// exctract deployer from salt?
        return Registry(CreateX.deployCreate2(salt, initCode));
    }

    function _deployReleaseManager(address registry, bytes32 salt) internal returns (ReleaseManager) {
        //releaseManager = new ReleaseManager(registry);
        bytes memory initCode = abi.encodePacked(
            type(ReleaseManager).creationCode, 
            abi.encode(registry));
        return ReleaseManager(CreateX.deployCreate2(salt, initCode));
    }

    function _deployTokenRegistry(address registry, address dip, bytes32 salt) internal returns (TokenRegistry) {
        //tokenRegistry = new TokenRegistry(registry, dip);
        bytes memory initCode = abi.encodePacked(
            type(TokenRegistry).creationCode, 
            abi.encode(registry, dip));
        return TokenRegistry(CreateX.deployCreate2(salt, initCode));
    }

    function _deployStakingReader(address registry, address initializeOwner, bytes32 salt) internal returns (StakingReader) {
        //StakingReader stakingReader = new StakingReader(registry, initializeOwner);
        bytes memory initCode = abi.encodePacked(
            type(StakingReader).creationCode, 
            abi.encode(registry, initializeOwner));
        return StakingReader(CreateX.deployCreate2(salt, initCode));
    }

    function _deployStakingStore(address registry, address stakingReader, bytes32 salt) internal returns (StakingStore) {
        //StakingStore stakingStore = new StakingStore(registry, stakingReader);
        bytes memory initCode = abi.encodePacked(
            type(StakingStore).creationCode, 
            abi.encode(registry, stakingReader));
        return StakingStore(CreateX.deployCreate2(salt, initCode));
    }

    function _deployStakingManager(
        address registry, 
        address tokenRegistry, 
        address stakingStore, 
        address stakingOwner, 
        bytes32 salt
    ) internal returns (StakingManager) {
        //stakingManager = new StakingManager(
        //    address(registry),
        //    address(tokenRegistry),
        //    address(stakingStore),
        //    stakingOwner);
        bytes memory initCode = abi.encodePacked(
            type(StakingManager).creationCode, 
            abi.encode(
                registry, 
                tokenRegistry, 
                stakingStore, 
                stakingOwner
        ));
        return StakingManager(CreateX.deployCreate2(salt, initCode));
    }
}
