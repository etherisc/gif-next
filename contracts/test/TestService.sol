// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId} from "../../contracts/types/NftId.sol";
import {Version, toVersion, toVersionPart} from "../../contracts/types/Version.sol";
import {ServiceBase} from "../../contracts/instance/service/ServiceBase.sol";

import {IVersionable} from "../../contracts/shared/IVersionable.sol";
import {Versionable} from "../../contracts/shared/Versionable.sol";

contract TestService is ServiceBase {

    string public constant NAME = "TestService";

    constructor(address registry, NftId registryNftId)
        ServiceBase(registry, registryNftId)
    // solhint-disable-next-line no-empty-blocks
    {}

    function getVersion()
        public 
        pure 
        virtual override (IVersionable, Versionable)
        returns(Version)
    {
        return toVersion(
            toVersionPart(3),
            toVersionPart(0),
            toVersionPart(0));
    }

    function getName() external pure override returns(string memory name) {
        return NAME;
    }
}