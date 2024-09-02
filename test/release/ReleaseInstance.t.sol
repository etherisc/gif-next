// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {Vm, console} from "../../lib/forge-std/src/Test.sol";

import {GifTest} from "../base/GifTest.sol";
import {AccessManagerCloneable} from "../../contracts/authorization/AccessManagerCloneable.sol";
import {Amount, AmountLib} from "../../contracts/type/Amount.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {ClaimId} from "../../contracts/type/ClaimId.sol";
import {SimpleProduct} from "../../contracts/examples/unpermissioned/SimpleProduct.sol";
import {SimplePool} from "../../contracts/examples/unpermissioned/SimplePool.sol";
import {IComponents} from "../../contracts/instance/module/IComponents.sol";
import {IInstance} from "../../contracts/instance/IInstance.sol";
import {ILifecycle} from "../../contracts/shared/ILifecycle.sol";
import {IPolicy} from "../../contracts/instance/module/IPolicy.sol";
import {IBundle} from "../../contracts/instance/module/IBundle.sol";
import {Fee, FeeLib} from "../../contracts/type/Fee.sol";
import {UFixedLib} from "../../contracts/type/UFixed.sol";
import {Seconds, SecondsLib} from "../../contracts/type/Seconds.sol";
import {Timestamp, TimestampLib} from "../../contracts/type/Timestamp.sol";
import {IPolicyService} from "../../contracts/product/IPolicyService.sol";
import {IRisk} from "../../contracts/instance/module/IRisk.sol";
import {PayoutId, PayoutIdLib} from "../../contracts/type/PayoutId.sol";
import {POLICY} from "../../contracts/type/ObjectType.sol";
import {RiskId, RiskIdLib, eqRiskId} from "../../contracts/type/RiskId.sol";
import {ReferralId, ReferralLib} from "../../contracts/type/Referral.sol";
import {APPLIED, SUBMITTED, ACTIVE, COLLATERALIZED, CONFIRMED, DECLINED, CLOSED, REVOKED} from "../../contracts/type/StateId.sol";
import {StateId} from "../../contracts/type/StateId.sol";
import {VersionPart, VersionPartLib} from "../../contracts/type/Version.sol";

contract ReleaseInstanceTest is GifTest {

    VersionPart public RELEASE_3 = VersionPartLib.toVersionPart(3);

    function setUp() public override {
        super.setUp();
    }

    function test_releaseInstanceSetUp() public {
        assertTrue(true, "setup failed");
    }

    function test_releaseInstanceCreateActiveInactive() public {
        // GIVEN release active

        vm.startPrank(instanceOwner);
        (
            IInstance newInstance, 
            NftId newInstanceNftId
        ) = instanceService.createInstance(false);
        vm.stopPrank();

        assertTrue(address(newInstance) != address(0), "instance creation failed");
        assertTrue(newInstanceNftId.gtz(), "new instance nft zero");

        // WHEN release is locked
        vm.startPrank(registryOwner);
        releaseRegistry.setActive(RELEASE_3, false);
        vm.stopPrank();

        // THEN instance creation fails
        // instanceOwner -[X]-> instanceService.craeteInstance()
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManaged.AccessManagedUnauthorized.selector, 
                address(instanceOwner)));

        vm.startPrank(instanceOwner);
        (
            IInstance newInstance2, 
            NftId newInstanceNftId2
        ) = instanceService.createInstance(false);
        vm.stopPrank();
    }
}