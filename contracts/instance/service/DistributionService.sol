// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../../registry/IRegistry.sol";
import {IInstance} from "../../instance/IInstance.sol";
import {ITreasury} from "../../instance/module/treasury/ITreasury.sol";

import {NftId} from "../../types/NftId.sol";
import {Fee} from "../../types/Fee.sol";
import {DISTRIBUTION} from "../../types/ObjectType.sol";
import {Version, VersionLib} from "../../types/Version.sol";

import {IVersionable} from "../../shared/IVersionable.sol";
import {Versionable} from "../../shared/Versionable.sol";

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

    function getVersion()
        public 
        pure 
        virtual override (IVersionable, Versionable)
        returns(Version)
    {
        return VersionLib.toVersion(3,0,0);
    }

    function getName() external pure override returns(string memory name) {
        return NAME;
    }

    function setFees(
        Fee memory distributionFee
    )
        external
        override
    {
        (IRegistry.ObjectInfo memory distributionInfo, IInstance instance) = _getAndVerifyComponentInfoAndInstance(DISTRIBUTION());

        NftId productNftId = instance.getProductNftId(distributionInfo.nftId);
        ITreasury.TreasuryInfo memory treasuryInfo = instance.getTreasuryInfo(productNftId);
        treasuryInfo.distributionFee = distributionFee;
        instance.setTreasuryInfo(productNftId, treasuryInfo);
    }
}
