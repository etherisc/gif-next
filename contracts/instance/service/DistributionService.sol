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
        address initialOwner = address(0);
        (_registryAddress, initialOwner) = abi.decode(data, (address, address));

        // IRegistry registry = IRegistry(_registryAddress);

        _initializeService(_registryAddress, initialOwner);

        _registerInterface(type(IService).interfaceId);
        _registerInterface(type(IDistributionService).interfaceId);
    }


    function getName() public pure override(IService, Service) returns(string memory name) {
        return NAME;
    }

    function register(address distributionComponentAddress) 
        external 
        returns (NftId distributionNftId)
    {
        address componentOwner = msg.sender;
        // TODO validate permission of componentOwner. check if componentOwner has correct permission on instance via InstanceService - DISTRIBUTION_OWNER
        Distribution distribution = Distribution(distributionComponentAddress);
        IRegistryService registryService = getRegistryService();
        (IRegistry.ObjectInfo memory distributionObjInfo, ) = registryService.registerDistribution(
            distribution,
            componentOwner
        );
        distributionNftId = distributionObjInfo.nftId;

        ISetup.DistributionSetupInfo memory initialSetup = distribution.getInitialSetupInfo();
        IInstance instance = distribution.getInstance();
        instance.createDistributionSetup(distributionNftId, initialSetup);
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
