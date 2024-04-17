// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Dip is ERC20 {

    // https://etherscan.io/token/0xc719d010b63e5bbf2c0551872cd5316ed26acd83#readContract
    string public constant NAME = "Decentralized Insurance Protocol - DUMMY";
    string public constant SYMBOL = "DIP";
    uint8 public constant DECIMALS = 18;
    uint256 public constant INITIAL_SUPPLY = 10**9 * 10**DECIMALS; // 1 Billion 1'000'000'000
    // decimals == 18 (openzeppelin erc20 default)
    constructor()
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
