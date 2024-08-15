// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount} from "../type/Amount.sol";
import {IComponent} from "../shared/IComponent.sol";
import {IAuthorization} from "../authorization/IAuthorization.sol";
import {IInstance} from "../instance/IInstance.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType} from "../type/ObjectType.sol";

/// @dev component base class
/// component examples are product, distribution, pool and oracle
interface IInstanceLinkedComponent is 
    IComponent
{
    error ErrorInstanceLinkedComponentTypeMismatch(ObjectType requiredType, ObjectType objectType);
    error ErrorInstanceLinkedComponentNotProduct(NftId nftId, ObjectType objectType);

    /// @dev Withdraw fees from the distribution component. Only component owner is allowed to withdraw fees.
    /// @param amount the amount to withdraw
    /// @return withdrawnAmount the amount that was actually withdrawn
    function withdrawFees(Amount amount) external returns (Amount withdrawnAmount);

    /// @dev defines the instance to which this component is linked to
    function getInstance() external view returns (IInstance instance);

    /// @dev returns the initial component authorization specification.
    function getAuthorization() external view returns (IAuthorization authorization);

}