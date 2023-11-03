// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

//import {IRegisterable} from "../shared/IRegisterable.sol";
import {IRegisterable_new} from "../shared/IRegisterable_new.sol";
import {IInstanceLinked} from "../instance/IInstanceLinked.sol";

interface IBaseComponent is IRegisterable_new, IInstanceLinked {

    function lock() external;

    function unlock() external;

    function getToken() external view returns (IERC20Metadata token);

    function getWallet() external view returns (address walletAddress);

}