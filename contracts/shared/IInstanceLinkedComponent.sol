// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Amount} from "../type/Amount.sol";
import {IComponent} from "../shared/IComponent.sol";
import {IAuthorization} from "../authorization/IAuthorization.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IInstance} from "../instance/IInstance.sol";
import {IInstanceService} from "../instance/IInstanceService.sol";
import {IProductService} from "../product/IProductService.sol";
import {IRegisterable} from "../shared/IRegisterable.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";

/// @dev component base class
/// component examples are product, distribution, pool and oracle
interface IInstanceLinkedComponent is 
    IComponent
{
    error ErrorComponentNotProductService(address caller);
    error ErrorComponentNotInstance(NftId instanceNftId);
    error ErrorComponentProductNftAlreadySet();

    /// @dev registers this component with the registry and instance.
    /// a component may only be linked once
    /// only initial component owner (nft holder) is authorizes to call this function
    function register() external;

    /// @dev locks component to disable functions that may change state related to this component, the only exception is function "unlock"
    /// only component owner (nft holder) is authorizes to call this function
    function lock() external;

    /// @dev unlocks component to (re-)enable functions that may change state related to this component
    /// only component owner (nft holder) is authorizes to call this function
    function unlock() external;

    /// @dev Withdraw fees from the distribution component. Only component owner is allowed to withdraw fees.
    /// @param amount the amount to withdraw
    /// @return withdrawnAmount the amount that was actually withdrawn
    function withdrawFees(Amount amount) external returns (Amount withdrawnAmount);

    /// @dev defines the instance to which this component is linked to
    function getInstance() external view returns (IInstance instance);

    /// @dev returns the initial component authorization specification.
    function getAuthorization() external view returns (IAuthorization authorization);

    /// @dev defines the product to which this component is linked to
    /// this is only relevant for pool and distribution components
    function getProductNftId() external view returns (NftId productNftId);

}