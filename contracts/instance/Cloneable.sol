// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IRegistry} from "../registry/IRegistry.sol";

abstract contract Cloneable is 
    AccessManagedUpgradeable
{
    event CloneableInitialized(address authority, address registry);

    error CloneableRegistryInvalid(address registry);

    IRegistry internal _registry;

    constructor() {
        _registry = IRegistry(address(0));
    }

    /// @dev call to initialize MUST be made in the same transaction as cloning of the contract
    function initialize(
        address authority,
        address registry
    )
        public 
        initializer
    {
        // check/handle access managed
        __AccessManaged_init(authority);

        // check/handle registry
        if (registry.code.length == 0) {
            revert CloneableRegistryInvalid(registry);
        }

        _registry = IRegistry(registry);

        emit CloneableInitialized(authority, registry);
    }

    function getRegistry() external view returns (IRegistry) {
        return _registry;
    }
}
