// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, Vm, console} from "../lib/forge-std/src/Test.sol";
import {VersionLib, VersionPartLib, VersionPart} from "../contracts/type/Version.sol";
import {IUpgradeable} from "../contracts/upgradeability/IUpgradeable.sol";
import {ProxyManager} from "../contracts/upgradeability/ProxyManager.sol";

import {GifTest} from "./base/GifTest.sol";

import {ContractV01} from "./mock/ContractV01.sol";
import {ContractV02} from "./mock/ContractV02.sol";

contract ProxyManagerTest is GifTest {

    function testProductV01Deploy() public {
        ProxyManager proxyManager = new ProxyManager();
        // solhint-disable-next-line
        console.log("proxyManager[address]", address(proxyManager));
        assertTrue(address(proxyManager) != address(0), "proxyManager address zero");

        bytes memory initializationData = abi.encode(uint(42));
        IUpgradeable upgradeable = proxyManager.initialize(
            address(new ContractV01()), 
            initializationData,
            bytes32(""));
        // solhint-disable-next-line
        console.log("upgradeable[address]", address(upgradeable));
        assertTrue(address(upgradeable) != address(0), "upgradeable address zero");

        // solhint-disable-next-line
        console.log("version[int]", upgradeable.getVersion().toInt());
        assertTrue(upgradeable.getVersion() == VersionLib.toVersion(3,0,0), "version not (3,0,0)");

        ContractV01 productV1 = ContractV01(address(upgradeable));
        assertEq(productV1.getDataV01(), "hi from version 1", "unexpected message for getDataV01");

        ContractV02 productV2 = ContractV02(address(upgradeable));
        vm.expectRevert();
        productV2.getDataV02();
    }

    function testProductV01DeployAndUpgrade() public {

        ProxyManager proxyManager = new ProxyManager();
        VersionPart release = VersionPartLib.toVersionPart(4);
        bytes memory initializationData = abi.encode(uint(0));
        bytes memory upgradeData = abi.encode(uint(0));
        IUpgradeable upgradeable = proxyManager.initialize(
            address(new ContractV01()),
            initializationData,
            bytes32(""));
        proxyManager.upgrade(address(new ContractV02()), upgradeData);

        assertTrue(upgradeable.getVersion() == VersionLib.toVersion(3,0,1), "version not (3,0,1)");

        ContractV02 productV2 = ContractV02(address(upgradeable));
        assertEq(productV2.getDataV01(), "hi from version 1", "unexpected message for getDataV01");
        assertEq(productV2.getDataV02(), "hi from version 2", "unexpected message for getDataV02");
    }

    // getting the proxy admin address via logs
    // https://forum.openzeppelin.com/t/version-5-how-can-should-the-proxyadmin-of-the-transparentupgradableproxy-be-used/38127
    function testProductV01DeployCheckProxyAdminAddress() public {
        ProxyManager proxyManager = new ProxyManager();

        vm.recordLogs();
        bytes memory initializationData = abi.encode(uint(0));
        proxyManager.initialize(
            address(new ContractV01()),
            initializationData,
            bytes32(""));

        Vm.Log[] memory entries = vm.getRecordedLogs();
        // solhint-disable-next-line
        console.log(entries.length, "log entries");

        string memory logAdminChangedSignature = vm.toString(keccak256("AdminChanged(address,address)"));
        // solhint-disable-next-line
        console.log("keccak256('AdminChanged(address,address)')", logAdminChangedSignature);

        // admin changed
        if(entries.length > 4) {
            // solhint-disable-next-line
            console.log("entries[4]", vm.toString(entries[4].topics[0]));
            if(entries[4].topics[0] == keccak256("AdminChanged(address,address)")) {
                // solhint-disable-next-line
                console.log("AdminChanged topics", entries[4].topics.length);
                (address oldAdmin, address newAdmin) = abi.decode(entries[4].data, (address,address));
                // solhint-disable-next-line
                console.log("AdminChanged", oldAdmin, newAdmin);

                assertEq(address(proxyManager.getProxy().getProxyAdmin()), newAdmin, "non-matching admin addresses");
            } 
        }
    }
}
