// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {ClaimId, ClaimIdLib} from "../../contracts/type/ClaimId.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {ObjectType, ObjectTypeLib, PROTOCOL, REGISTRY, STAKING} from "../../contracts/type/ObjectType.sol";
import {Key32} from "../../contracts/type/Key32.sol";
import {PayoutId, PayoutIdLib} from "../../contracts/type/PayoutId.sol";

contract ObjectTypeTest is Test {

    function test_ObjectTypeProtocol() public {
        uint protocolTypeInt = 1;
        ObjectType protocol = ObjectTypeLib.toObjectType(protocolTypeInt);

        assertTrue(protocol.gtz(), "protocol id 0");
        assertTrue(protocol == PROTOCOL(), "protocol id differs from PROTOCOL()");
        assertEq(protocol.toInt(), protocolTypeInt, "unexpected protocol id");
        assertEq(protocol.toInt(), PROTOCOL().toInt(), "unexpected protocol id (via PROTOCOL)");
        assertEq(ObjectTypeLib.toName(protocol), "ObjectType1", "unexpected protocol type name");
    }

    function test_ObjectTypeRegistry() public {
        uint registryTypeInt = 2;
        ObjectType registry = ObjectTypeLib.toObjectType(registryTypeInt);

        assertTrue(registry.gtz(), "registry id 0");
        assertTrue(registry == REGISTRY(), "registry id differs from PROTOCOL()");
        assertEq(registry.toInt(), registryTypeInt, "unexpected registry id");
        assertEq(registry.toInt(), REGISTRY().toInt(), "unexpected registry id");
        assertEq(ObjectTypeLib.toName(registry), "Registry", "unexpected registry type name");
    }

    function test_ObjectTypeNames() public {
        assertEq(ObjectTypeLib.toName(REGISTRY()), "Registry", "unexpected type name");
        assertEq(ObjectTypeLib.toName(STAKING()), "Staking", "unexpected type name");
    }

    function test_ObjecTypeIntToString() public {
        assertEq(ObjectTypeLib.toString(0), "0", "unexpected string for uint");
        assertEq(ObjectTypeLib.toString(1), "1", "unexpected string for uint");
        assertEq(ObjectTypeLib.toString(17), "17", "unexpected string for uint");
        assertEq(ObjectTypeLib.toString(99), "99", "unexpected string for uint");
        assertEq(ObjectTypeLib.toString(100), "100", "unexpected string for uint");
        assertEq(ObjectTypeLib.toString(987654321), "987654321", "unexpected string for uint");
    }
}
