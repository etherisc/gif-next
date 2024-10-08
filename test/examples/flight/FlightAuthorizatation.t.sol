// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../../lib/forge-std/src/Test.sol";

import {IOracle} from "../../../contracts/oracle/IOracle.sol";
import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";

import {IAccess} from "../../../contracts/authorization/IAccess.sol";
import {Authorization} from "../../../contracts/authorization/Authorization.sol";
import {RoleId} from "../../../contracts/type/RoleId.sol";

import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {FlightMessageVerifier} from "../../../contracts/examples/flight/FlightMessageVerifier.sol";
import {FlightOracle} from "../../../contracts/examples/flight/FlightOracle.sol";
import {FlightOracleAuthorization} from "../../../contracts/examples/flight/FlightOracleAuthorization.sol";
import {FlightPool} from "../../../contracts/examples/flight/FlightPool.sol";
import {FlightPoolAuthorization} from "../../../contracts/examples/flight/FlightPoolAuthorization.sol";
import {FlightProduct} from "../../../contracts/examples/flight/FlightProduct.sol";
import {FlightProductAuthorization} from "../../../contracts/examples/flight/FlightProductAuthorization.sol";
import {FlightUSD} from "../../../contracts/examples/flight/FlightUSD.sol";
import {GifTest} from "../../base/GifTest.sol";
import {NftId} from "../../../contracts/type/NftId.sol";
import {RequestId} from "../../../contracts/type/RequestId.sol";
import {RiskId} from "../../../contracts/type/RiskId.sol";
import {Str, StrLib} from "../../../contracts/type/String.sol";
import {Timestamp, TimestampLib} from "../../../contracts/type/Timestamp.sol";
import {VersionPartLib} from "../../../contracts/type/Version.sol";


contract FlightBaseTest is GifTest {

    address public flightOwner = makeAddr("flightOwner");

    FlightUSD public flightUSD;
    FlightOracle public flightOracle;
    FlightPool public flightPool;
    FlightProduct public flightProduct;

    NftId public flightOracleNftId;
    NftId public flightPoolNftId;
    NftId public flightProductNftId;

    FlightMessageVerifier public flightMessageVerifier;
    address public verifierOwner = makeAddr("verifierOwner");

    uint256 public customerPrivateKey = 0xB0B;

    address public dataSigner;
    uint256 public dataSignerPrivateKey;

    function setUp() public virtual override {
        customer = vm.addr(customerPrivateKey);
        
        super.setUp();
    }

    function test_flightProductAuthz() public {
        FlightProductAuthorization productAuthz = new FlightProductAuthorization("FlightProduct");
        _printRoles(productAuthz);
    }

    function _printRoles(Authorization authz) public {
        RoleId[] memory roles = authz.getRoles();

        for(uint256 i = 0; i < roles.length; i++) { 
            _printRole(authz, roles[i]);
        }
    }

    function _printRole(Authorization authz, RoleId roleId) public {
        IAccess.RoleInfo memory roleInfo = authz.getRoleInfo(roleId);

        // solhint-disable
        console.log("role id", roleId.toInt(), "admin role id", roleInfo.adminRoleId.toInt());
        console.log("target type", uint256(roleInfo.targetType), "max member count", roleInfo.maxMemberCount);
        console.log("name", roleInfo.name.toString());
        // solhint-enable
    }

}