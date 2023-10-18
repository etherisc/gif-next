// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, Vm, console} from "../lib/forge-std/src/Test.sol";
import {ProxyAdmin} from "@openzeppelin5/contracts/proxy/transparent/ProxyAdmin.sol";
import {VersionLib} from "../contracts/types/Version.sol";
import {IVersionable} from "../contracts/shared/IVersionable.sol";
import {Proxy} from "../contracts/shared/Proxy.sol";

import {ContractV01} from "./mock/ContractV01.sol";
import {ContractV02} from "./mock/ContractV02.sol";

contract ProxyTest is Test {

    function testProductV01Deploy() public {
        Proxy proxy = new Proxy();
        console.log("proxy[address]", address(proxy));
        assertTrue(address(proxy) != address(0), "proxy address zero");

        IVersionable versionable = proxy.deploy(address(new ContractV01()));
        console.log("versionable[address]", address(versionable));
        assertTrue(address(versionable) != address(0), "versionable address zero");

        console.log("version[int]", versionable.getVersion().toInt());
        assertTrue(versionable.getVersion() == VersionLib.toVersion(1,0,0), "version not (1,0,0)");

        ContractV01 productV1 = ContractV01(address(versionable));
        assertEq(productV1.getDataV01(), "hi from version 1", "unexpected message for getDataV01");

        ContractV02 productV2 = ContractV02(address(versionable));
        vm.expectRevert();
        productV2.getDataV02();
    }

    function testProductV01DeployAndUpgrade() public {

        Proxy proxy = new Proxy();
        IVersionable versionable = proxy.deploy(address(new ContractV01()));
        proxy.upgrade(address(new ContractV02()));

        assertTrue(versionable.getVersion() == VersionLib.toVersion(1,0,1), "version not (1,0,1)");

        ContractV02 productV2 = ContractV02(address(versionable));
        assertEq(productV2.getDataV01(), "hi from version 1", "unexpected message for getDataV01");
        assertEq(productV2.getDataV02(), "hi from version 2", "unexpected message for getDataV02");
    }

    // getting the proxy admin address via logs
    // https://forum.openzeppelin.com/t/version-5-how-can-should-the-proxyadmin-of-the-transparentupgradableproxy-be-used/38127
    function testProductV01DeployCheckProxyAdminAddress() public {
        Proxy proxy = new Proxy();

        vm.recordLogs();
        proxy.deploy(address(new ContractV01()));

        Vm.Log[] memory entries = vm.getRecordedLogs();
        console.log(entries.length, "log entries");

        string memory logAdminChangedSignature = vm.toString(keccak256("AdminChanged(address,address)"));
        console.log("keccak256('AdminChanged(address,address)')", logAdminChangedSignature);

        // admin changed
        if(entries.length > 4) {
            console.log("entries[4]", vm.toString(entries[4].topics[0]));
            if(entries[4].topics[0] == keccak256("AdminChanged(address,address)")) {
                console.log("AdminChanged topics", entries[4].topics.length);
                (address oldAdmin, address newAdmin) = abi.decode(entries[4].data, (address,address));
                console.log("AdminChanged", oldAdmin, newAdmin);

                assertEq(address(proxy.getProxyAdmin()), newAdmin, "non-matching admin addresses");
            } 
        }
    }
}
