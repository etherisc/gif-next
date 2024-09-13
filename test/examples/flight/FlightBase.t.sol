// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {FlightUSD} from "../../../contracts/examples/flight/FlightUSD.sol";
import {FlightPool} from "../../../contracts/examples/flight/FlightPool.sol";
import {FlightPoolAuthorization} from "../../../contracts/examples/flight/FlightPoolAuthorization.sol";
import {FlightProduct} from "../../../contracts/examples/flight/FlightProduct.sol";
import {FlightProductAuthorization} from "../../../contracts/examples/flight/FlightProductAuthorization.sol";
import {GifTest} from "../../base/GifTest.sol";
import {NftId} from "../../../contracts/type/NftId.sol";
import {VersionPartLib} from "../../../contracts/type/Version.sol";


contract FlightBaseTest is GifTest {

    address public flightOwner = makeAddr("flightOwner");

    FlightUSD public flightUSD;
    FlightPool public flightPool;
    FlightProduct public flightProduct;

    NftId public flightPoolNftId;
    NftId public flightProductNftId;

    function setUp() public virtual override {
        super.setUp();
        
        _deployFlightUSD();
        _deployFlightProduct();
        _deployFlightPool();
        _initialFundAccounts();
    }

    function _deployFlightUSD() internal {
        // deploy fire token
        vm.startPrank(flightOwner);
        flightUSD = new FlightUSD();
        vm.stopPrank();

        // whitelist fire token and make it active for release 3
        vm.startPrank(registryOwner);
        tokenRegistry.registerToken(address(flightUSD));
        tokenRegistry.setActiveForVersion(
            currentChainId, 
            address(flightUSD), 
            VersionPartLib.toVersionPart(3),
            true);
        vm.stopPrank();
    }

    function _deployFlightProduct() internal {
        vm.startPrank(flightOwner);
        FlightProductAuthorization productAuthz = new FlightProductAuthorization("FlightProduct");
        flightProduct = new FlightProduct(
            address(registry),
            instanceNftId,
            "FlightProduct",
            productAuthz
        );
        vm.stopPrank();

        // instance owner registeres fire product with instance (and registry)
        vm.startPrank(instanceOwner);
        flightProductNftId = instance.registerProduct(
            address(flightProduct), 
            address(flightUSD));
        vm.stopPrank();
    }

    function _deployFlightPool() internal {
        vm.startPrank(flightOwner);
        FlightPoolAuthorization poolAuthz = new FlightPoolAuthorization("FlightPool");
        flightPool = new FlightPool(
            address(registry),
            flightProductNftId,
            "FlightPool",
            poolAuthz
        );
        vm.stopPrank();

        flightPoolNftId = _registerComponent(
            flightOwner, 
            flightProduct, 
            address(flightPool), 
            "flightPool");
    }


    function _createInitialBundle() internal {
        vm.startPrank(flightOwner);
        Amount investAmount = AmountLib.toAmount(10000000 * 10 ** 6);
        flightUSD.approve(
            address(flightPool.getTokenHandler()), 
            investAmount.toInt());
        bundleNftId = flightPool.createBundle(investAmount); // 5 years
        vm.stopPrank();
    }


    function _initialFundAccounts() internal {
        _fundAccount(flightOwner, 100000 * 10 ** flightUSD.decimals());
        _fundAccount(customer, 10000 * 10 ** flightUSD.decimals());
    }


    function _fundAccount(address account, uint256 amount) internal {
        vm.startPrank(flightOwner);
        flightUSD.transfer(account, amount);
        vm.stopPrank();
    }
}