// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Registerable} from "../../contracts/registry/Registry.sol";
import {AccessModule} from "../../contracts/instance/access/Access.sol";
import {NftId, toNftId} from "../../contracts/types/NftId.sol";
import {ObjectType, INSTANCE} from "../../contracts/types/ObjectType.sol";

contract TestInstanceBase  is
    Registerable,
    AccessModule
{
    constructor(address registry)
        Registerable(registry)
        AccessModule()
    // solhint-disable-next-line no-empty-blocks
    {

    }

    // from registerable
    function register() external override returns (NftId nftId) {
        require(
            address(_registry) != address(0),
            "ERROR:PRD-001:REGISTRY_ZERO"
        );
        return _registry.register(address(this));
    }

    // from registerable
    function getParentNftId() public pure override returns (NftId) {
        // TODO  add self registry and exchange 0 for_registry.getNftId();
        // define parent tree for all registerables
        // eg 0 <- chain(mainnet) <- global registry <- chain registry <- instance <- component <- policy/bundle
        return toNftId(0);
    }

    // from registerable
    function getType() external pure override returns (ObjectType objectType) {
        return INSTANCE();
    }

    // from registerable
    function getData() external pure override returns (bytes memory data) {
        return bytes(abi.encode(0));
    }
}
