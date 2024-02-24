// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../../registry/IRegistry.sol";
import {IInstance} from "../../instance/IInstance.sol";
import {InstanceAccessManager} from "../InstanceAccessManager.sol";
import {InstanceReader} from "../../instance/InstanceReader.sol";
import {ISetup} from "../../instance/module/ISetup.sol";

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
import {InstanceService} from "../InstanceService.sol";
import {IDistributionService} from "./IDistributionService.sol";
import {IComponent} from "../../components/IComponent.sol";


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
        address initialOwner;
        address registryAddress;
        (registryAddress, initialOwner) = abi.decode(data, (address, address));
        // TODO while DistributionService is not deployed in DistributionServiceManager constructor
        //      owner is DistributionServiceManager deployer
        _initializeService(registryAddress, owner);

        _registerInterface(type(IDistributionService).interfaceId);
    }

    function getDomain() public pure override(Service, IService) returns(ObjectType) {
        return DISTRIBUTION();
    }

    function register(address distributionAddress) 
        external
        returns(NftId distributionNftId)
    {
        (
            IComponent distribution,
            address owner,
            IInstance instance,
            NftId instanceNftId
        ) = _checkComponentForRegistration(
            distributionAddress,
            DISTRIBUTION(),
            DISTRIBUTION_OWNER_ROLE());

        (
            IRegistry.ObjectInfo memory distributionInfo,
            bytes memory data
        ) = getRegistryService().registerDistribution(distribution, owner);
        distribution.linkToRegisteredNftId();
        distributionNftId = distributionInfo.nftId;

        (
            string memory name, 
            ISetup.DistributionSetupInfo memory initialSetup
        ) = _decodeAndVerifyDistributionData(data);
        instance.createDistributionSetup(distributionNftId, initialSetup);

        getInstanceService().createTarget(instanceNftId, distributionAddress, name);
    }

    function _decodeAndVerifyDistributionData(bytes memory data)
        internal 
        returns(string memory name, ISetup.DistributionSetupInfo memory setup)
    {
        (name, setup) = abi.decode(
            data,
            (string, ISetup.DistributionSetupInfo)
        );

        // TODO add checks if applicable 
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
