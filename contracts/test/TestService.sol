// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {ObjectType, PRODUCT} from "../../contracts/types/ObjectType.sol";
import {NftId} from "../../contracts/types/NftId.sol";
import {Version, VersionLib} from "../../contracts/types/Version.sol";
import {Service} from "../../contracts/shared/Service.sol";

import {IVersionable} from "../../contracts/shared/IVersionable.sol";
import {Versionable} from "../../contracts/shared/Versionable.sol";

contract TestService is Service {

    string public constant NAME = "TestService";

    constructor(address registry, NftId registryNftId, address initialOwner)
    // solhint-disable-next-line no-empty-blocks
    {
        initializeService(registry, address(0), initialOwner);
    }

    function getDomain() public pure override returns(ObjectType) {
        return PRODUCT();
    }
}