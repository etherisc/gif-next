// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../registry/IRegistry.sol";
import {IProductComponent} from "./IProductComponent.sol";
import {Product} from "./Product.sol";
import {IInstanceLinkedComponent} from "../shared/IInstanceLinkedComponent.sol";
import {IPoolComponent} from "../pool/IPoolComponent.sol";
import {IDistributionComponent} from "../distribution/IDistributionComponent.sol";
import {IInstance} from "../instance/IInstance.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";
import {IRisk} from "../instance/module/IRisk.sol";
import {IBundle} from "../instance/module/IBundle.sol";
import {IProductService} from "./IProductService.sol";
import {IComponents} from "../instance/module/IComponents.sol";

import {TokenHandler} from "../shared/TokenHandler.sol";

import {IVersionable} from "../shared/IVersionable.sol";
import {Versionable} from "../shared/Versionable.sol";

import {Timestamp, zeroTimestamp} from "../type/Timestamp.sol";
import {UFixed, UFixedLib} from "../type/UFixed.sol";
import {Blocknumber, blockNumber} from "../type/Blocknumber.sol";
import {ObjectType, INSTANCE, PRODUCT, POOL, POLICY, REGISTRY} from "../type/ObjectType.sol";
import {APPLIED, ACTIVE, KEEP_STATE} from "../type/StateId.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {Fee, FeeLib} from "../type/Fee.sol";
import {ReferralId} from "../type/Referral.sol";
import {RiskId} from "../type/RiskId.sol";
import {StateId} from "../type/StateId.sol";
import {Version, VersionLib} from "../type/Version.sol";
import {RoleId, PRODUCT_OWNER_ROLE} from "../type/RoleId.sol";

import {IService} from "../shared/IService.sol";
import {Service} from "../shared/Service.sol";
import {ComponentVerifyingService} from "../shared/ComponentVerifyingService.sol";
import {IInstanceService} from "../instance/IInstanceService.sol";
import {IProductService} from "./IProductService.sol";
import {IRegistryService} from "../registry/IRegistryService.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {IPoolService} from "../pool/PoolService.sol";

contract ProductService is
    ComponentVerifyingService,
    IProductService 
{
    IInstanceService private _instanceService;
    IPoolService internal _poolService;
    IRegistryService private _registryService;

    event LogProductServiceSender(address sender);

    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        initializer
        virtual override
    {
        address registryAddress;
        address initialOwner;
        (registryAddress, initialOwner) = abi.decode(data, (address, address));

        initializeService(registryAddress, address(0), owner);

        _instanceService = IInstanceService(_getServiceAddress(INSTANCE()));
        _poolService = IPoolService(getRegistry().getServiceAddress(POOL(), getVersion().toMajorPart()));
        _registryService = IRegistryService(_getServiceAddress(REGISTRY()));

        registerInterface(type(IProductService).interfaceId);
    }


    function getDomain() public pure override returns(ObjectType) {
        return PRODUCT();
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
}