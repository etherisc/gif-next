// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../../registry/IRegistry.sol";
import {IProductComponent} from "../../components/IProductComponent.sol";
import {Product} from "../../components/Product.sol";
import {IBaseComponent} from "../../components/IBaseComponent.sol";
import {IPoolComponent} from "../../components/IPoolComponent.sol";
import {IDistributionComponent} from "../../components/IDistributionComponent.sol";
import {IInstance} from "../IInstance.sol";
import {IPolicy} from "../module/IPolicy.sol";
import {IRisk} from "../module/IRisk.sol";
import {IBundle} from "../module/IBundle.sol";
import {IProductService} from "./IProductService.sol";
import {ITreasury} from "../module/ITreasury.sol";
import {ISetup} from "../module/ISetup.sol";

import {TokenHandler} from "../../shared/TokenHandler.sol";

import {IVersionable} from "../../shared/IVersionable.sol";
import {Versionable} from "../../shared/Versionable.sol";

import {Timestamp, zeroTimestamp} from "../../types/Timestamp.sol";
import {UFixed, UFixedLib} from "../../types/UFixed.sol";
import {Blocknumber, blockNumber} from "../../types/Blocknumber.sol";
import {ObjectType, PRODUCT, POOL, POLICY} from "../../types/ObjectType.sol";
import {APPLIED, UNDERWRITTEN, ACTIVE, KEEP_STATE} from "../../types/StateId.sol";
import {NftId, NftIdLib, zeroNftId} from "../../types/NftId.sol";
import {Fee, FeeLib} from "../../types/Fee.sol";
import {ReferralId} from "../../types/Referral.sol";
import {RiskId} from "../../types/RiskId.sol";
import {StateId} from "../../types/StateId.sol";
import {Version, VersionLib} from "../../types/Version.sol";
import {RoleId, PRODUCT_OWNER_ROLE} from "../../types/RoleId.sol";

import {IService} from "../../shared/IService.sol";
import {Service} from "../../shared/Service.sol";
import {ComponentServiceBase} from "../base/ComponentServiceBase.sol";
import {IProductService} from "./IProductService.sol";
import {InstanceReader} from "../InstanceReader.sol";
import {IPoolService} from "./PoolService.sol";

// TODO or name this ProtectionService to have Product be something more generic (loan, savings account, ...)
contract ProductService is ComponentServiceBase, IProductService {
    using NftIdLib for NftId;

    IPoolService internal _poolService;

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

        _initializeService(registryAddress, owner);

        _poolService = IPoolService(_registry.getServiceAddress(POOL(), getMajorVersion()));

        _registerInterface(type(IProductService).interfaceId);
    }


    function getDomain() public pure override(IService, Service) returns(ObjectType) {
        return PRODUCT();
    }

    function register(address productAddress) 
        external
        returns(NftId productNftId)
    {
        address productOwner = msg.sender;
        IBaseComponent product = IBaseComponent(productAddress);

        IRegistry.ObjectInfo memory info;
        bytes memory data;
        (info, data) = getRegistryService().registerProduct(product, productOwner);

        IInstance instance = _getInstance(info);
        bool hasRole = getInstanceService().hasRole(
            productOwner, 
            PRODUCT_OWNER_ROLE(), 
            address(instance));

        if(!hasRole) {
            revert ExpectedRoleMissing(PRODUCT_OWNER_ROLE(), productOwner);
        }

        productNftId = info.nftId;
        ISetup.ProductSetupInfo memory initialSetup = _decodeAndVerifyProductSetup(data);
        instance.createProductSetup(productNftId, initialSetup);
    }

    function _decodeAndVerifyProductSetup(bytes memory data) internal returns(ISetup.ProductSetupInfo memory setup)
    {
        setup = abi.decode(
            data,
            (ISetup.ProductSetupInfo)
        );

        // TODO add checks if applicable 
    }

    function setFees(
        Fee memory productFee,
        Fee memory processingFee
    )
        external
    {
        // TODO check args 

        (
            IRegistry.ObjectInfo memory productInfo, 
            IInstance instance
        ) = _getAndVerifyComponentInfoAndInstance(PRODUCT());

        InstanceReader instanceReader = instance.getInstanceReader();
        NftId productNftId = productInfo.nftId;
        ISetup.ProductSetupInfo memory productSetupInfo = instanceReader.getProductSetupInfo(productNftId);

        productSetupInfo.productFee = productFee;
        productSetupInfo.processingFee = processingFee;
        
        instance.updateProductSetup(productNftId, productSetupInfo, KEEP_STATE());
    }

    function createRisk(
        RiskId riskId,
        bytes memory data
    ) external override {
        (
            IRegistry.ObjectInfo memory productInfo, 
            IInstance instance
        ) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
        NftId productNftId = productInfo.nftId;
        IRisk.RiskInfo memory riskInfo = IRisk.RiskInfo(productNftId, data);
        instance.createRisk(
            riskId,
            riskInfo
        );
    }

    function updateRisk(
        RiskId riskId,
        bytes memory data
    ) external {
        (, IInstance instance) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
        InstanceReader instanceReader = instance.getInstanceReader();
        IRisk.RiskInfo memory riskInfo = instanceReader.getRiskInfo(riskId);
        riskInfo.data = data;
        instance.updateRisk(riskId, riskInfo, KEEP_STATE());
    }

    function updateRiskState(
        RiskId riskId,
        StateId state
    ) external {
        (, IInstance instance) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
        instance.updateRiskState(riskId, state);
    }
}
