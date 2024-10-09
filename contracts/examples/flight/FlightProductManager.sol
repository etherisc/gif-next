// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAuthorization} from "../../authorization/IAuthorization.sol";
import {IVersionable} from "../../upgradeability/IVersionable.sol";

import {NftId} from "../../type/NftId.sol";
import {ProxyManager} from "../../upgradeability/ProxyManager.sol";
import {FlightProduct} from "./FlightProduct.sol";


contract FlightProductManager is ProxyManager {

    FlightProduct private _flightProduct;
    bytes32 private _salt = "0x1234";

    /// @dev initializes proxy manager with flight product implementation 
    constructor(
        address registry,
        NftId instanceNftId,
        string memory componentName,
        IAuthorization authorization
    ) 
    {
        // FlightProduct prd = new FlightProduct{salt: _salt}();
        // bytes memory data = abi.encode(
        //     registry, 
        //     instanceNftId, 
        //     componentName, 
        //     authorization);

        // IVersionable versionable = initialize(
        //     registry,
        //     address(prd), 
        //     data,
        //     _salt);

        // _flightProduct = FlightProduct(address(versionable));
    }

    //--- view functions ----------------------------------------------------//
    function getFlightProduct()
        external
        view
        returns (FlightProduct flightProduct)
    {
        return _flightProduct;
    }
}