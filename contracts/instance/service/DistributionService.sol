// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../../registry/IRegistry.sol";
import {IRegistryService} from "../../registry/IRegistryService.sol";
import {IInstance} from "../../instance/IInstance.sol";
import {InstanceReader} from "../../instance/InstanceReader.sol";
import {ISetup} from "../../instance/module/ISetup.sol";
import {ITreasury} from "../../instance/module/ITreasury.sol";

import {NftId, NftIdLib} from "../../types/NftId.sol";
import {Fee} from "../../types/Fee.sol";
import {DISTRIBUTION_OWNER_ROLE} from "../../types/RoleId.sol";
import {KEEP_STATE} from "../../types/StateId.sol";
import {ObjectType, DISTRIBUTION} from "../../types/ObjectType.sol";
import {Version, VersionLib} from "../../types/Version.sol";

import {IVersionable} from "../../shared/IVersionable.sol";
import {Versionable} from "../../shared/Versionable.sol";

import {IService} from "../../shared/IService.sol";
import {Service} from "../../shared/Service.sol";
import {ComponentServiceBase} from "../base/ComponentServiceBase.sol";
import {IDistributionService} from "./IDistributionService.sol";
import {Distribution} from "../../components/Distribution.sol";
import {InstanceService} from "../InstanceService.sol";
import {Instance} from "../Instance.sol";
import {INftOwnable} from "../../shared/INftOwnable.sol";


contract DistributionService is
    ComponentServiceBase,
    IDistributionService
{
    using NftIdLib for NftId;

    address internal _registryAddress;
    
    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        initializer
        virtual override
    {
        address initialOwner = address(0);
        (_registryAddress, initialOwner) = abi.decode(data, (address, address));
        // TODO while DistributionService is not deployed in DistributionServiceManager constructor
        //      owner is DistributionServiceManager deployer
        _initializeService(_registryAddress, owner);

        _registerInterface(type(IService).interfaceId);
        _registerInterface(type(IDistributionService).interfaceId);
    }

    function getType() public pure override(Service, IService) returns(ObjectType) {
        return DISTRIBUTION();
    }

    function _finalizeComponentRegistration(NftId componentNftId, bytes memory initialObjData, IInstance instance) internal override {
        ISetup.DistributionSetupInfo memory initialSetup = abi.decode(
            initialObjData,
            (ISetup.DistributionSetupInfo)
        );
        instance.createDistributionSetup(componentNftId, initialSetup);
    }

    function setFees(
        Fee memory distributionFee
    )
        external
        override
    {
        (IRegistry.ObjectInfo memory info , IInstance instance) = _getAndVerifyComponentInfoAndInstance(DISTRIBUTION());
        InstanceReader instanceReader = instance.getInstanceReader();
        NftId distributionNftId = info.nftId;

        ISetup.DistributionSetupInfo memory distSetupInfo = instanceReader.getDistributionSetupInfo(distributionNftId);
        distSetupInfo.distributionFee = distributionFee;
        
        instance.updateDistributionSetup(distributionNftId, distSetupInfo, KEEP_STATE());
    }
}
