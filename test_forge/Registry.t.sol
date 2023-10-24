// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin5/contracts/access/Ownable.sol";

//import "../lib/forge-std/src/Test.sol";

import {Test, Vm, console} from "../lib/forge-std/src/Test.sol";
import {VersionLib} from "../contracts/types/Version.sol";
import {NftId} from "../contracts/types/NftId.sol";
import {IVersionable} from "../contracts/shared/IVersionable.sol";
import {VersionableUpgradeable} from "../contracts/shared/VersionableUpgradeable.sol";
import {ProxyDeployer} from "../contracts/shared/Proxy.sol";
import {ChainNft} from "../contracts/registry/ChainNft.sol";

//import {IRegistry} from "../contracts/registry/IRegistry.sol";
import {RegistryUpgradeable} from "../contracts/registry/RegistryUpgradeable.sol";
import {RegistryV02} from "./mock/RegistryV02.sol";

contract RegistryTest is Test {


    address public proxyOwner = makeAddr("proxyOwner");
    address public outsider = makeAddr("outsider");
    address public registryOwner = makeAddr("registryOwner");

    NftId public registryNftId;

    function testRegistryV01Deploy() public 
    {
        ProxyDeployer proxy = new ProxyDeployer();
        // solhint-disable-next-line
        console.log("proxy deployer address", address(proxy));
        assertTrue(address(proxy) != address(0), "proxy deployer address zero");

        bytes memory initializationData = abi.encode(registryOwner);
        IVersionable versionable = proxy.deploy(address(new RegistryUpgradeable()), initializationData);
        // solhint-disable-next-line
        console.log("registry proxy address", address(versionable));
        assertTrue(address(versionable) != address(0), "registry proxy address zero");

        // solhint-disable-next-line
        assertTrue(versionable.getVersion() == VersionLib.toVersion(1,0,0), "version not (1,0,0)");
        assertTrue(versionable.getInitializedVersion() == 1, "initialized version not 1");

        address registryAddress = address(versionable);
        RegistryUpgradeable registry = RegistryUpgradeable(registryAddress);
        registryNftId = registry.getNftId();
        console.log("registry deployed at", registryAddress);
        console.log("registry NFT[int]", registryNftId.toInt()); 
        console.log("registry version[int]", registry.getVersion().toInt());
        console.log("registry initialized version[int]", registry.getInitializedVersion());
        console.log("registry NFT deployed at", address(registry.getChainNft()));
    }    
    function testRegistryV01DeployAndUpgradeToV02() public
    {
        ProxyDeployer proxy = new ProxyDeployer();
        // solhint-disable-next-line
        console.log("proxy deployer[address]", address(proxy));
        assertTrue(address(proxy) != address(0), "proxy deployer address zero");

        // deploy
        bytes memory initializationData = abi.encode(registryOwner);
        IVersionable versionable = proxy.deploy(address(new RegistryUpgradeable()), initializationData);
        // solhint-disable-next-line
        console.log("registry proxy[address]", address(versionable));
        assertTrue(address(versionable) != address(0), "registry proxy address zero");

        // solhint-disable-next-line
        assertTrue(versionable.getVersion() == VersionLib.toVersion(1,0,0), "version not (1,0,0)");
        assertTrue(versionable.getInitializedVersion() == 1, "initialized version not 1");

        address registryAddress = address(versionable);
        RegistryUpgradeable registry = RegistryUpgradeable(registryAddress);

        registryNftId = registry.getNftId();
        console.log("registry deployed at", registryAddress);
        console.log("registry NFT[int]", registryNftId.toInt()); 
        console.log("registry version[int]", registry.getVersion().toInt());
        console.log("registry initialized version[int]", registry.getInitializedVersion());
        console.log("registry NFT deployed at", address(registry.getChainNft()));

        // upgrade
        bytes memory upgradeData = abi.encode(uint(0));
        proxy.upgrade(address(new RegistryV02()), upgradeData);

        assertTrue(versionable.getVersion() == VersionLib.toVersion(1,1,0), "version not (1,1,0)");
        assertTrue(VersionLib.toVersion(versionable.getInitializedVersion()) == VersionLib.toVersion(1,1,0), "initialized version not (1,1,0)");

        RegistryV02 registryV02 = RegistryV02(registryAddress);
        NftId registryV2NftId = registryV02.getNftId();
        uint v2data = registryV02.getRegistryDataV2();

        assertEq(v2data, type(uint).max, "unxpected value of initialized V2 variable");
        assertEq(registryNftId.toInt(), registryV2NftId.toInt(), "nftId of v1 differs from v2");

        console.log("after upgrade, registry NFT[int]", registryV2NftId.toInt()); 
        console.log("after upgrade, registry version[int]", registryV02.getVersion().toInt());
        console.log("after upgrade, registry initialized version[int]", registryV02.getInitializedVersion());
        console.log("after upgrade, registry NFT deployed at", address(registry.getChainNft()));

    }
}