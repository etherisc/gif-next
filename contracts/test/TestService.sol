// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

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
        _initializeService(registry, initialOwner);
    }

    function getName() public pure override returns(string memory name) {
        return NAME;
    }
}