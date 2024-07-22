// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IInstance} from "../instance/IInstance.sol";
import {IInstanceService} from "../instance/IInstanceService.sol";
import {IPoolService} from "../pool/PoolService.sol";
import {IRiskService} from "./IRiskService.sol";
import {IRegistryService} from "../registry/IRegistryService.sol";
import {IRisk} from "../instance/module/IRisk.sol";

import {InstanceReader} from "../instance/InstanceReader.sol";
import {ObjectType, INSTANCE, PRODUCT, POOL, POLICY, REGISTRY} from "../type/ObjectType.sol";
import {KEEP_STATE} from "../type/StateId.sol";
import {NftId} from "../type/NftId.sol";
import {RiskId} from "../type/RiskId.sol";
import {StateId} from "../type/StateId.sol";
import {ComponentVerifyingService} from "../shared/ComponentVerifyingService.sol";

contract RiskService is
    ComponentVerifyingService,
    IRiskService 
{
    IInstanceService private _instanceService;
    IPoolService internal _poolService;
    IRegistryService private _registryService;

    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        initializer
        virtual override
    {
        (
            address registryAddress,
            address authority
        ) = abi.decode(data, (address, address));

        _initializeService(registryAddress, authority, owner);

        _instanceService = IInstanceService(_getServiceAddress(INSTANCE()));
        _poolService = IPoolService(getRegistry().getServiceAddress(POOL(), getVersion().toMajorPart()));
        _registryService = IRegistryService(_getServiceAddress(REGISTRY()));

        _registerInterface(type(IRiskService).interfaceId);
    }


    function createRisk(
        RiskId riskId,
        bytes memory data
    )
        external 
        override
    {
        (NftId productNftId,, IInstance instance) = _getAndVerifyActiveComponent(PRODUCT());
        IRisk.RiskInfo memory riskInfo = IRisk.RiskInfo(productNftId, data);

        instance.getInstanceStore().createRisk(
            riskId,
            riskInfo
        );
    }


    function updateRisk(
        RiskId riskId,
        bytes memory data
    )
        external
    {
        (,, IInstance instance) = _getAndVerifyActiveComponent(PRODUCT());
        InstanceReader instanceReader = instance.getInstanceReader();

        IRisk.RiskInfo memory riskInfo = instanceReader.getRiskInfo(riskId);
        riskInfo.data = data;
        instance.getInstanceStore().updateRisk(riskId, riskInfo, KEEP_STATE());
    }


    function updateRiskState(
        RiskId riskId,
        StateId state
    )
        external
    {
        (,, IInstance instance) = _getAndVerifyActiveComponent(PRODUCT());
        instance.getInstanceStore().updateRiskState(riskId, state);
    }


    function _getDomain() internal pure override returns(ObjectType) {
        return PRODUCT();
    }
}