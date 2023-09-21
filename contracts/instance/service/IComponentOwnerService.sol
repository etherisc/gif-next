// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId} from "../../types/NftId.sol";
import {IComponentBase} from "../../components/IComponentBase.sol";
import {IService} from "./IService.sol";

// TODO likely merge this into IComponentBase interface
// which would make a separate component owner service obsolete
interface IComponentOwnerService is IService {
    function register(IComponentBase component) external returns(NftId componentNftId);

    function lock(IComponentBase component) external;

    function unlock(IComponentBase component) external;
}
