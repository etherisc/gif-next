// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IRegistry} from "../registry/IRegistry.sol";

abstract contract Cloneable is 
    AccessManagedUpgradeable
{
    event CloneableInitialized(address authority, address registry);

    error CloneableAlreadyInitialized();
    error CloneableAuthorityZero();
    error CloneableRegistryInvalid(address registry);

    IRegistry internal _registry;

    bool private _initialized;

    constructor() {
        _initialized = true;
        __AccessManaged_init(address(0));
    }

    /// @dev call to initialize MUST be made in the same transaction as cloning of the contract
    function initialize(
        address authority,
        address registry
    )
        public 
    {
        // check/handle initialization
        if (_initialized) {
            revert CloneableAlreadyInitialized();
        }

        _initialized = true;

        // check/handle access managed
        if (authority == address(0)) {
            revert CloneableAuthorityZero();
        }

        __AccessManaged_init(authority);

        // check/handle registry
        IERC165 registryCandidate = IERC165(registry);
        if (!registryCandidate.supportsInterface(type(IRegistry).interfaceId)) {
            revert CloneableRegistryInvalid(registry);
        }

        _registry = IRegistry(registry);

        emit CloneableInitialized(authority, registry);
    }

    function getRegistry() external view returns (IRegistry) {
        return _registry;
    }
}