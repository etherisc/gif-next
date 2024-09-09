// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IInstance} from "../instance/IInstance.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IRisk} from "../instance/module/IRisk.sol";
import {IRiskService} from "./IRiskService.sol";

import {ContractLib} from "../shared/ContractLib.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {ObjectType, COMPONENT, PRODUCT, RISK} from "../type/ObjectType.sol";
import {ACTIVE, KEEP_STATE, CLOSED} from "../type/StateId.sol";
import {NftId} from "../type/NftId.sol";
import {RiskId, RiskIdLib} from "../type/RiskId.sol";
import {StateId} from "../type/StateId.sol";
import {RiskSet} from "../instance/RiskSet.sol";
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
        _registerInterface(type(IRiskService).interfaceId);
    }

    /// @inheritdoc IRiskService
    function createRisk(
        bytes32 id,
        bytes memory data
    )
        external 
        virtual
        restricted()
        returns (RiskId riskId)
    {
        // checks
        (NftId productNftId, IInstance instance) = _getAndVerifyActiveComponent(PRODUCT());

        // effects
        riskId = RiskIdLib.toRiskId(productNftId, id);
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

        emit LogRiskServiceRiskCreated(productNftId, riskId);
    }


    function updateRisk(
        RiskId riskId,
        bytes memory data
    )
        external 
        virtual
        restricted()
    {
        // checks
        (NftId productNftId, IInstance instance) = _getAndVerifyActiveComponent(PRODUCT());

        // effects
        InstanceReader instanceReader = instance.getInstanceReader();
        IRisk.RiskInfo memory riskInfo = instanceReader.getRiskInfo(riskId);

        if (riskInfo.productNftId != productNftId) {
            revert ErrorRiskServiceRiskProductMismatch(riskId, riskInfo.productNftId, productNftId);
        }

        riskInfo.data = data;
        instance.getInstanceStore().updateRisk(riskId, riskInfo, KEEP_STATE());

        emit LogRiskServiceRiskUpdated(productNftId, riskId);
    }


    /// @inheritdoc IRiskService
    function setRiskLocked(
        RiskId riskId,
        bool locked
    )
        external 
        virtual
        restricted()
    {
        // checks
        (NftId productNftId, IInstance instance) = _getAndVerifyActiveComponent(PRODUCT());

        if (!instance.getRiskSet().hasRisk(productNftId, riskId)) {
            revert ErrorRiskServiceUnknownRisk(productNftId, riskId);
        }

        if (instance.getInstanceReader().getRiskState(riskId) != ACTIVE()) {
            revert ErrorRiskServiceRiskNotActive(productNftId, riskId);
        }

        if (locked) {
            instance.getRiskSet().deactivate(riskId);
            emit LogRiskServiceRiskLocked(productNftId, riskId);
        } else {
            instance.getRiskSet().activate(riskId);
            emit LogRiskServiceRiskUnlocked(productNftId, riskId);
        }
    }

    /// @inheritdoc IRiskService
    function closeRisk(
        RiskId riskId
    )
        external 
        virtual
        restricted()
    {
        // checks
        (NftId productNftId, IInstance instance) = _getAndVerifyActiveComponent(PRODUCT());
        (bool exists, bool active) = instance.getRiskSet().checkRisk(productNftId, riskId);

        if (!exists) {
            revert ErrorRiskServiceUnknownRisk(productNftId, riskId);
        }

        if (active) {
            revert ErrorRiskServiceRiskNotLocked(productNftId, riskId);
        }

        // effects
        instance.getInstanceStore().updateRiskState(riskId, CLOSED());

        emit LogRiskServiceRiskClosed(productNftId, riskId);
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