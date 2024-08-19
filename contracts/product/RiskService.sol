// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IInstance} from "../instance/IInstance.sol";
import {IInstanceService} from "../instance/IInstanceService.sol";
import {IPoolService} from "../pool/PoolService.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IRegistryService} from "../registry/IRegistryService.sol";
import {IRisk} from "../instance/module/IRisk.sol";
import {IRiskService} from "./IRiskService.sol";

import {ContractLib} from "../shared/ContractLib.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {ObjectType, COMPONENT, INSTANCE, PRODUCT, POOL, POLICY, REGISTRY, RISK} from "../type/ObjectType.sol";
import {ACTIVE, PAUSED, KEEP_STATE} from "../type/StateId.sol";
import {NftId} from "../type/NftId.sol";
import {RiskId} from "../type/RiskId.sol";
import {StateId} from "../type/StateId.sol";
import {RiskSet} from "../product/RiskSet.sol";
import {Service} from "../shared/Service.sol";
import {TimestampLib} from "../type/Timestamp.sol";

contract RiskService is
    Service,
    IRiskService 
{

    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        initializer
        virtual override
    {
        (
            address authority,
            address registry
        ) = abi.decode(data, (address, address));

        __Service_init(authority, registry, owner);

        // TODO cleanup
        // _instanceService = IInstanceService(_getServiceAddress(INSTANCE()));
        // _poolService = IPoolService(getRegistry().getServiceAddress(POOL(), getVersion().toMajorPart()));
        // _registryService = IRegistryService(_getServiceAddress(REGISTRY()));

        _registerInterface(type(IRiskService).interfaceId);
    }


    function createRisk(
        RiskId riskId,
        bytes memory data
    )
        external 
        restricted()
    {
        // checks
        (NftId productNftId, IInstance instance) = _getAndVerifyActiveComponent(PRODUCT());

        // effects
        IRisk.RiskInfo memory riskInfo = IRisk.RiskInfo({
            productNftId: productNftId, 
            createdAt: TimestampLib.blockTimestamp(),
            data: data});

        instance.getInstanceStore().createRisk(
            riskId,
            riskInfo
        );

        // add risk to RiskSet
        RiskSet riskSet = instance.getRiskSet();
        riskSet.add(riskId);
    }


    function updateRisk(
        RiskId riskId,
        bytes memory data
    )
        external 
        restricted()
    {
        // checks
        (NftId productNftId, IInstance instance) = _getAndVerifyActiveComponent(PRODUCT());

        // effects
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
        restricted()
    {
        // checks
        (NftId productNftId, IInstance instance) = _getAndVerifyActiveComponent(PRODUCT());

        // effects
        instance.getInstanceStore().updateRiskState(riskId, state);

        if (state == ACTIVE()) {
            instance.getRiskSet().activate(riskId);
        } else if (state == PAUSED()) {
            instance.getRiskSet().pause(riskId);
        }
    }

    function _getAndVerifyActiveComponent(ObjectType expectedType) 
        internal 
        view 
        returns (
            NftId componentNftId,
            IInstance instance
        )
    {
        IRegistry.ObjectInfo memory info;
        address instanceAddress;
        bool isActive = true;

        if (expectedType != COMPONENT()) {
            (info, instanceAddress) = ContractLib.getAndVerifyComponent(
                getRegistry(),
                msg.sender, // caller
                expectedType,
                isActive); 
        } else {
            (info, instanceAddress) = ContractLib.getAndVerifyAnyComponent(
                getRegistry(),
                msg.sender,
                isActive); 
        }

        // get component nft id and instance
        componentNftId = info.nftId;
        instance = IInstance(instanceAddress);
    }


    function _getDomain() internal pure override returns(ObjectType) {
        return RISK();
    }
}