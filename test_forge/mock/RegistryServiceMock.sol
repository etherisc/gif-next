// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {DISTRIBUTION} from "../../contracts/types/ObjectType.sol";

import {Version, VersionLib} from "../../contracts/types/Version.sol";
import {Versionable} from "../../contracts/shared/Versionable.sol";
import {IVersionable} from "../../contracts/shared/IVersionable.sol";
import {Service} from "../../contracts/shared/Service.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";


contract RegistryServiceMock is Versionable {


    function _initialize(address owner, bytes memory data)
        internal
        onlyInitializing
        virtual override
    {}

    function getVersion()
        public
        pure
        virtual override
        returns(Version)
    {
        return VersionLib.toVersion(3, 0, 1);
    }

    function getMessage() external virtual returns (string memory message) {
        return "hi from mock";
    }
}

contract RegistryServiceMockWithSimpleConfig is RegistryService
{
    function getInitialInfo() public view override 
        returns(
            IRegistry.ObjectInfo memory info,
            bytes memory data
        )
    {
        (info, ) = super.getInitialInfo();
        FunctionConfig[] memory config = new FunctionConfig[](1);

        config[0].serviceDomain = DISTRIBUTION();
        config[0].selector = RegistryService.registerDistribution.selector;

        data = abi.encode(config);
    }

    function getVersion()
        public
        pure
        virtual override (IVersionable, Service)
        returns(Version)
    {
        return VersionLib.toVersion(3, 0, 2);
    }

    function _upgrade(bytes memory data)
        internal
        onlyInitializing
        override
    // solhint-disable-next-line no-empty-blocks
    {}
}
