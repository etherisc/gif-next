// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/// @dev FireUSD is a stablecoin with 6 decimals and an initial supply of 1 Billion tokens. 
contract FlightUSD is ERC20Permit {

    string public constant NAME = "FlightUSD";
    string public constant SYMBOL = "FLTD";
    uint8 public constant DECIMALS = 6;
    uint256 public constant INITIAL_SUPPLY = 10**12 * 10**DECIMALS; // 1'000'000'000'000
    
    constructor()
        ERC20Permit(NAME)
        ERC20(NAME, SYMBOL)
    {
        _mint(
            _msgSender(),
            INITIAL_SUPPLY
        );   
    }

    function decimals() public pure override returns(uint8) {
        return DECIMALS;
    }
}
