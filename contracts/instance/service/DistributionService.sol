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
import {DISTRIBUTION} from "../../types/ObjectType.sol";
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
import {IBaseComponent} from "../../components/IBaseComponent.sol";

string constant DISTRIBUTION_SERVICE_NAME = "DistributionService";

contract DistributionService is
    ComponentServiceBase,
    IDistributionService
{
    using NftIdLib for NftId;

    string public constant NAME = "DistributionService";

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


    function getName() public pure override(IService, Service) returns(string memory name) {
        return NAME;
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

        IInstance instance = _getInstance(info);

        bool hasRole = getInstanceService().hasRole(
            distributionOwner, 
            DISTRIBUTION_OWNER_ROLE(), 
            address(instance));

        if(!hasRole) {
            revert ExpectedRoleMissing(DISTRIBUTION_OWNER_ROLE(), distributionOwner);
        }

        distributionNftId = info.nftId;
        ISetup.DistributionSetupInfo memory initialSetup = _decodeAndVerifyDistributionSetup(data);
        instance.createDistributionSetup(distributionNftId, initialSetup);
    }

    function _decodeAndVerifyDistributionSetup(bytes memory data) internal returns(ISetup.DistributionSetupInfo memory setup)
    {
        setup = abi.decode(
            data,
            (ISetup.DistributionSetupInfo)
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
