// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {console} from "../lib/forge-std/src/Script.sol";
import {TestGifBase} from "./base/TestGifBase.sol";
import {NftId, toNftId, NftIdLib} from "../contracts/types/NftId.sol";
import {PRODUCT_OWNER_ROLE, POOL_OWNER_ROLE, DISTRIBUTION_OWNER_ROLE} from "../contracts/types/RoleId.sol";
import {Distribution} from "../contracts/components/Distribution.sol";
import {IRegistry} from "../contracts/registry/IRegistry.sol";
import {ISetup} from "../contracts/instance/module/ISetup.sol";
import {Fee, FeeLib} from "../contracts/types/Fee.sol";
import {UFixedLib} from "../contracts/types/UFixed.sol";

contract TestDistribution is TestGifBase {
    using NftIdLib for NftId;

    function testSetFees() public {
        // GIVEN
        _prepareDistribution();

        ISetup.DistributionSetupInfo memory distributionSetupInfo = instanceReader.getDistributionSetupInfo(distributionNftId);
        Fee memory distributionFee = distributionSetupInfo.distributionFee;
        assertEq(distributionFee.fractionalFee.toInt(), 0, "distribution fee not 0");
        assertEq(distributionFee.fixedFee, 0, "distribution fee not 0");
        
        Fee memory newDistributionFee = FeeLib.toFee(UFixedLib.toUFixed(123,0), 456);

        // WHEN
        distribution.setFees(newDistributionFee);

        // THEN
        distributionSetupInfo = instanceReader.getDistributionSetupInfo(distributionNftId);
        distributionFee = distributionSetupInfo.distributionFee;
        assertEq(distributionFee.fractionalFee.toInt(), 123, "distribution fee not 123");
        assertEq(distributionFee.fixedFee, 456, "distribution fee not 456");
    }

    function test_BaseComponent_setWalletToExternallyOwned() public {
        // GIVEN
        _prepareDistribution();

        address externallyOwnerWallet = makeAddr("externallyOwnerWallet");

        // WHEN
        distribution.setWallet(externallyOwnerWallet);

        // THEN
        assertEq(distribution.getWallet(), externallyOwnerWallet, "wallet not changed to externallyOwnerWallet");
    }

    function test_BaseComponent_setWalletToContract() public {
        // GIVEN
        _prepareDistribution();

        address externallyOwnerWallet = makeAddr("externallyOwnerWallet");
        distribution.setWallet(externallyOwnerWallet);
        assertEq(distribution.getWallet(), externallyOwnerWallet, "wallet not externallyOwnerWallet");

        // WHEN
        distribution.setWallet(address(distribution));

        // THEN
        assertEq(distribution.getWallet(), address(distribution), "wallet not changed to distribution component");
    }

    function _prepareDistribution() internal {
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(DISTRIBUTION_OWNER_ROLE().toInt(), distributionOwner, 0);
        vm.stopPrank();

        vm.startPrank(distributionOwner);
        distribution = new Distribution(
            address(registry),
            instanceNftId,
            address(token),
            false,
            FeeLib.zeroFee(),
            distributionOwner
        );

        distributionNftId = distributionService.register(address(distribution));
    }

}
