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
import {IBaseComponent} from "../../components/IBaseComponent.sol";


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
        address distributionOwner = msg.sender;
        IBaseComponent distribution = IBaseComponent(distributionAddress);

        IRegistry.ObjectInfo memory info;
        bytes memory data;
        (info, data) = getRegistryService().registerDistribution(distribution, distributionOwner);

        NftId instanceNftId = info.parentNftId;
        IInstance instance = _getInstance(instanceNftId);
        InstanceService instanceService = getInstanceService();

        bool hasRole = instanceService.hasRole(
            distributionOwner, 
            DISTRIBUTION_OWNER_ROLE(), 
            address(instance));

        if(!hasRole) {
            revert ExpectedRoleMissing(DISTRIBUTION_OWNER_ROLE(), distributionOwner);
        }

        distributionNftId = info.nftId;
        string memory distributionName;
        ISetup.DistributionSetupInfo memory initialSetup;
        (distributionName, initialSetup) = _decodeAndVerifyDistributionData(data);
        instance.createDistributionSetup(distributionNftId, initialSetup);

        instanceService.createTarget(instanceNftId, distributionAddress, distributionName);

        distribution.linkToRegisteredNftId();
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
