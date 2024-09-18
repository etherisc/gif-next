// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console, Test} from "../../lib/forge-std/src/Test.sol";
import {AccessAdmin} from "../../contracts/authorization/AccessAdmin.sol";
import {AccessManagerCloneable} from "../../contracts/authorization/AccessManagerCloneable.sol";
import {UpgradableProxyWithAdmin} from "../../contracts/upgradeability/UpgradableProxyWithAdmin.sol";
import {VersionPartLib} from "../../contracts/type/Version.sol";

contract MockContract {
    function hello() public pure returns (string memory) {
        return "hello";
    }
}

contract LockedEthersTest is Test {

    uint256 public constant LOCKED_ETHERS = 5 ether;
    uint256 public constant INITIAL_BALANCE = 10 ether;

    AccessManagerCloneable public accessManagerMaster;
    UpgradableProxyWithAdmin public upgradeableProxyWithAdmin;
    address public initialAdmin = makeAddr("initialAdmin");
    address public account1 = vm.addr(1);
    address public account2 = vm.addr(2);

    function setUp() public {
        accessManagerMaster = new AccessManagerCloneable();
        AccessAdmin admin = new AccessAdmin();

        vm.startPrank(initialAdmin);
        admin.initialize(
            address(accessManagerMaster), 
            "Test", 
            VersionPartLib.toVersionPart(5));
        vm.stopPrank();

        upgradeableProxyWithAdmin = new UpgradableProxyWithAdmin(
            address(new MockContract()), initialAdmin, "");

        vm.deal(account1, INITIAL_BALANCE);
    }

    function test_lockedEthersSetUp() public view {
        // GIVEN, WHEN, THEN
        assertEq(address(accessManagerMaster).balance, 0, "unexpected initial balance for accessManagerMaster");
        assertEq(initialAdmin.balance, 0, "unexpected initial balance for initialAdmin");
        assertEq(account1.balance, INITIAL_BALANCE, "unexpected initial balance for account1");
        assertEq(account2.balance, 0, "unexpected initial balance for account2");
    }


    function test_lockedEthersTransferToAccessManagerCloneable() public {
        // GIVEN + WHEN + THEN
        vm.expectRevert();
        vm.prank(account1);
        payable(address(accessManagerMaster)).transfer(LOCKED_ETHERS);

        // check account1 still has full initial balance
        assertEq(account1.balance, INITIAL_BALANCE, "unexpected initial balance for account1");
    }


    function test_lockedEthersTransferToUpgradeableProxyWithAdmin() public {
        // GIVEN + WHEN

        // THEN
        vm.expectRevert();
        vm.prank(account1);
        payable(address(upgradeableProxyWithAdmin)).transfer(LOCKED_ETHERS);

        // check account1 still has full initial balance
        assertEq(account1.balance, INITIAL_BALANCE, "unexpected initial balance for account1");
    }


    function test_lockedEthersSimpleTransfer() public {
        // GIVEN + WHEN
        vm.prank(account1);
        payable(account2).transfer(1 ether);

        // THEN
        assertEq(account1.balance, INITIAL_BALANCE - 1 ether, "unexpected balance for account1");
        assertEq(account2.balance, 1 ether, "unexpected balance for account2");
    }
}
