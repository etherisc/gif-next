// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { FoundryRandom } from "foundry-random/FoundryRandom.sol";

import {NftId} from "../../contracts/types/NftId.sol";
import {Version, VersionLib} from "../../contracts/types/Version.sol";
import {ObjectType, toObjectType, INSTANCE} from "../../contracts/types/ObjectType.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {Instance} from "../../contracts/instance/Instance.sol";

import {IRegisterable} from "../../contracts/shared/IRegisterable.sol";
import {Registerable} from "../../contracts/shared/Registerable.sol";

contract InstanceMock is Instance {

    constructor(address registry, NftId registryNftId, address initialOwner)
        Instance(registry, registryNftId, initialOwner)
    // solhint-disable-next-line no-empty-blocks
    {}
}

contract InstanceMockWithRandomInvalidType is Instance {

    ObjectType public _invalidType;

    constructor(address registry, NftId registryNftId, address initialOwner)
        Instance(registry, registryNftId, initialOwner)
    // solhint-disable-next-line no-empty-blocks
    {
        FoundryRandom rng = new FoundryRandom();

        ObjectType invalidType = toObjectType(rng.randomNumber(type(uint96).max));
        if(invalidType == INSTANCE()) {
            invalidType = toObjectType(invalidType.toInt() + 1);
        }

        _invalidType = invalidType;
    }

    function getInitialInfo() 
        public 
        view 
        virtual override
        returns (IRegistry.ObjectInfo memory, bytes memory) 
    {
        (
            IRegistry.ObjectInfo memory info,
            bytes memory data
        ) = super.getInitialInfo();

        info.objectType = _invalidType;

        return (info, data);
    }
}

contract InstanceMockWithRandomInvalidAddress is Instance {

    address public _invalidAddress;

    constructor(address registry, NftId registryNftId, address initialOwner)
        Instance(registry, registryNftId, initialOwner)
    // solhint-disable-next-line no-empty-blocks
    {
        FoundryRandom rng = new FoundryRandom();

        address invalidAddress = address(uint160(rng.randomNumber(type(uint160).max)));
        if(invalidAddress == address(this)) {
            invalidAddress = address(uint160(invalidAddress) + 1);
        }

        _invalidAddress = invalidAddress;
    }

    function getInitialInfo() 
        public 
        view 
        virtual override
        returns (IRegistry.ObjectInfo memory, bytes memory) 
    {
        (
            IRegistry.ObjectInfo memory info,
            bytes memory data
        ) = super.getInitialInfo();

        info.objectAddress = _invalidAddress;

        return (info, data);
    }
}
