// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount} from "../../../contracts/type/Amount.sol";
import {FlightBaseTest} from "./FlightBase.t.sol";
import {FlightProduct} from "../../../contracts/examples/flight/FlightProduct.sol";

// solhint-disable func-name-mixedcase
contract FlightUSDCTest is FlightBaseTest {

    function test_flightUsdPermitHappyCase() public {
        // GIVEN
        Amount premiumAmount = flightProduct.MAX_PREMIUM(); // AmountLib.toAmount(30 * 10 ** flightUSD.decimals());
        (FlightProduct.PermitData memory permit) = _createPermitWithSignature(
            customer, 
            premiumAmount, 
            customerPrivateKey, 
            0); // nonce

        assertEq(flightUSD.allowance(customer, address(flightProduct.getTokenHandler())), 0, "product allowance not zero");

        // WHEN
        flightUSD.permit(
            permit.owner,
            permit.spender,
            permit.value,
            permit.deadline,
            permit.v,
            permit.r,
            permit.s);

        // THEN
        assertEq(flightUSD.allowance(customer, address(flightProduct.getTokenHandler())), premiumAmount.toInt(), "product allowance not zero");
    }
}