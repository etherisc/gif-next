// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {CreateXScript} from "../../lib/createx-forge/script/CreateXScript.sol";
import {ICreateX} from "../../lib/createx-forge/script/ICreateX.sol";

import {AccessManagerExtendedWithDisableInitializeable} from "../../contracts/shared/AccessManagerExtendedWithDisableInitializeable.sol"; 


import {Dip} from "../../contracts/mock/Dip.sol";
import {GIF_MANAGER_ROLE, GIF_ADMIN_ROLE} from "../../contracts/type/RoleId.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
//import {GlobalRegistry} from "../../contracts/registry/GlobalRegistry.sol";
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

    struct GifCore {
        address accessManagerAddress;
        AccessManagerExtendedWithDisableInitializeable accessManager;
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
            Dip dip,
            Registry registry,
            ReleaseManager releaseManager,
            TokenRegistry tokenRegistry,
            StakingManager stakingManager
        )
    {
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
            gifAdmin, 
            gifManager, 
            permissionedSalt
        );

        // 4) deploy release manager
        core.releaseManager = _deployReleaseManager(
            core,
            permissionedSalt);

        // 5) deploy dip token and token registry
        // TODO Dip token deployment: can have differernt addresses on different chains????
        //IERC20Metadata dip = new Dip();
        address dipAddress = CreateX.deployCreate2(permissionedSalt, type(Dip).creationCode);
        core.tokenRegistry = _deployTokenRegistry(
            core,
            dipAddress,
            permissionedSalt);

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
        core.admin.completeCoreDeployment();

        dip = Dip(dipAddress);
        registry = core.registry;
        tokenRegistry = core.tokenRegistry;
        releaseManager = core.releaseManager;
        stakingManager = core.stakingManager;
    }

    function computeCoreAddresses(bytes32 salt, address stakingOwner) public 
        returns (GifCore memory core)
    {
        core.adminAddress = CreateX.computeCreate2Address(salt, keccak256(abi.encodePacked(type(RegistryAdmin).creationCode)));
        core.accessManagerAddress = CreateX.computeCreateAddress(core.adminAddress, 1);
        core.registryAddress = CreateX.computeCreate2Address(salt, keccak256(abi.encodePacked(type(Registry).creationCode)));
        core.releaseManagerAddress = CreateX.computeCreate2Address(salt, keccak256(type(ReleaseManager).creationCode));
        core.tokenRegistryAddress = CreateX.computeCreate2Address(salt, keccak256(type(TokenRegistry).creationCode));
        core.stakingReaderAddress = CreateX.computeCreate2Address(salt,keccak256(type(StakingReader).creationCode));
        core.stakingStoreAddress = CreateX.computeCreate2Address(salt, keccak256(type(StakingStore).creationCode));

        // TODO deploying with proxy manager sort of mimics create3 pattern
        //      you first do create2 (deploy proxy manager) then create (arbitrary number of creates, deploy implementation & proxy)
        // Non of core contracts addresses are dependend on staking manager address
        // thus ther addresses can be used in staking manager constructor
        bytes memory initCode = abi.encodePacked(
        type(StakingManager).creationCode, 
            abi.encode(
                core.registryAddress, 
                core.tokenRegistryAddress, 
                core.stakingStoreAddress, 
                stakingOwner
        ));
        core.stakingManagerAddress = CreateX.computeCreate2Address(salt, keccak256(initCode));
        address stakingImplementationAddress = CreateX.computeCreateAddress(core.stakingManagerAddress, 1);
        core.stakingAddress = CreateX.computeCreateAddress(core.stakingManagerAddress, 2);
    }

    function _deployAdmin(GifCore memory core, address gifAdmin, address gifManager, bytes32 salt) 
        internal 
        returns (RegistryAdmin admin, AccessManagerExtendedWithDisableInitializeable accessManager) 
    {
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
}
