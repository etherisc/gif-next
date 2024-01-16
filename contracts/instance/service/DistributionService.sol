// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../../registry/IRegistry.sol";
import {IInstance} from "../../instance/IInstance.sol";
import {InstanceReader} from "../../instance/InstanceReader.sol";
import {ISetup} from "../../instance/module/ISetup.sol";
import {ITreasury} from "../../instance/module/ITreasury.sol";

import {NftId} from "../../types/NftId.sol";
import {Fee} from "../../types/Fee.sol";
import {DISTRIBUTION} from "../../types/ObjectType.sol";
import {Version, VersionLib} from "../../types/Version.sol";

import {IVersionable} from "../../shared/IVersionable.sol";
import {Versionable} from "../../shared/Versionable.sol";

import {IService} from "../../shared/IService.sol";
import {ComponentServiceBase} from "../base/ComponentServiceBase.sol";
import {IDistributionService} from "./IDistributionService.sol";

contract DistributionService is
    ComponentServiceBase,
    IDistributionService
{
    string public constant NAME = "DistributionService";

    constructor(
        address registry,
        NftId registryNftId,
        address initialOwner
    ) ComponentServiceBase(registry, registryNftId, initialOwner)
    {
        _registerInterface(type(IDistributionService).interfaceId);
    }


    function getName() public pure override(IService) returns(string memory name) {
        return NAME;
    }

    function setFees(
        Fee memory distributionFee
    )
        external
        override
    {
        (, IInstance instance) = _getAndVerifyComponentInfoAndInstance(DISTRIBUTION());
        InstanceReader instanceReader = instance.getInstanceReader();

        ISetup.DistributionSetupInfo memory info = instanceReader.getDistributionSetupInfo(getNftId());
        info.distributionFee = distributionFee;
        
        instance.updateDistributionSetup(info);
    }
}
