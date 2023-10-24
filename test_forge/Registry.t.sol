// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin5/contracts/access/Ownable.sol";

//import "../lib/forge-std/src/Test.sol";

import {Test, Vm, console} from "../lib/forge-std/src/Test.sol";
import {VersionLib} from "../contracts/types/Version.sol";
import {NftId} from "../contracts/types/NftId.sol";
import {IVersionable} from "../contracts/shared/IVersionable.sol";
import {VersionableUpgradeable} from "../contracts/shared/VersionableUpgradeable.sol";
import {Proxy} from "../contracts/shared/Proxy.sol";
import {ChainNft} from "../contracts/registry/ChainNft.sol";

//import {IRegistry} from "../contracts/registry/IRegistry.sol";
import {RegistryUpgradeable} from "../contracts/registry/RegistryUpgradeable.sol";
import {RegistryV02} from "./mock/RegistryV02.sol";

contract RegistryTest is Test {


    address public proxyOwner = makeAddr("proxyOwner");
    address public outsider = makeAddr("outsider");
    address public registryOwner = makeAddr("registryOwner");

    Proxy public proxy;
    IVersionable public versionable;

    RegistryUpgradeable public registry;
    address public registryAddress;
    NftId public registryNftId;

    function _deployRegistry()
        internal
    {
        proxy = new Proxy();
        // solhint-disable-next-line
        console.log("proxy deployer address", address(proxy));

        bytes memory initializationData = abi.encode(registryOwner);
        versionable = proxy.deploy(address(new RegistryUpgradeable()), initializationData);
        registryAddress = address(versionable);

        // solhint-disable-next-line
        console.log("registry proxy address", registryAddress);
    }

    function testRegistryV01Deploy() 
        public 
    {
        _deployRegistry();

        assertTrue(address(versionable) != address(0), "registry proxy address zero");
        assertTrue(versionable.getVersion() == VersionLib.toVersion(1,0,0), "version not (1,0,0)");
        assertTrue(versionable.getInitializedVersion() == 1, "initialized version not 1");

        registry = RegistryUpgradeable(registryAddress);
        registryNftId = registry.getNftId();

        // solhint-disable
        console.log("registry deployed at", registryAddress);
        console.log("registry NFT[int]", registryNftId.toInt()); 
        console.log("registry version[int]", registry.getVersion().toInt());
        console.log("registry initialized version[int]", registry.getInitializedVersion());
        // solhint-enable
    }

    function testRegistryV01DeployAndUpgradeToV02()
        public
    {
        testRegistryV01Deploy();

        // upgrade
        bytes memory upgradeData = abi.encode(uint(0));
        proxy.upgrade(address(new RegistryV02()), upgradeData);

        assertTrue(versionable.getVersion() == VersionLib.toVersion(1,1,0), "version not (1,1,0)");
        assertTrue(VersionLib.toVersion(versionable.getInitializedVersion()) == VersionLib.toVersion(1,1,0), "initialized version not (1,1,0)");

        RegistryV02 registryV2 = RegistryV02(registryAddress);
        NftId registryV2NftId = registry.getNftId();
        uint v2data = registryV2.getDataV2();

        assertEq(v2data, type(uint).max, "unxpected value of initialized V2 variable");
        assertEq(registryNftId.toInt(), registryV2NftId.toInt(), "nftId of v1 differs from v2");

        // solhint-disable
        console.log("after upgrade registry NFT[int]", registryV2NftId.toInt()); 
        console.log("after upgrade, registry version[int]", registry.getVersion().toInt());
        console.log("after upgrade, registry initialized version[int]", registry.getInitializedVersion());
        // solhint-enable
    }
}
