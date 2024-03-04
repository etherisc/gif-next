// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../../registry/IRegistry.sol";
import {IProductComponent} from "../../components/IProductComponent.sol";
import {Product} from "../../components/Product.sol";
import {IComponent} from "../../components/IComponent.sol";
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
import {ComponentService} from "../base/ComponentService.sol";
import {IProductService} from "./IProductService.sol";
import {InstanceReader} from "../InstanceReader.sol";
import {IPoolService} from "./PoolService.sol";

// TODO or name this ProtectionService to have Product be something more generic (loan, savings account, ...)
contract ProductService is ComponentService, IProductService {
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


    function register(address productAddress) 
        external
        returns(NftId productNftId)
    {
        (
            IComponent component,
            address owner,
            IInstance instance,
            NftId instanceNftId
        ) = _checkComponentForRegistration(
            productAddress,
            PRODUCT(),
            PRODUCT_OWNER_ROLE());

        IProductComponent product = IProductComponent(productAddress);
        IRegistry.ObjectInfo memory productInfo = getRegistryService().registerProduct(product, owner);
        productNftId = productInfo.nftId;
        _createProductSetup(
            instance, 
            product, 
            productNftId);
    }


    function _createProductSetup(
        IInstance instance, 
        IProductComponent product, 
        NftId productNftId 
    )
        internal
        returns (string memory name)
    {
        // wire distribution and pool components to product component
        ISetup.ProductSetupInfo memory setup = product.getSetupInfo();
        IComponent distribution = IComponent(_registry.getObjectInfo(setup.distributionNftId).objectAddress);
        IComponent pool = IComponent(_registry.getObjectInfo(setup.poolNftId).objectAddress);

        distribution.setProductNftId(productNftId);
        pool.setProductNftId(productNftId);
        product.setProductNftId(productNftId);
        product.linkToRegisteredNftId();

        // create product setup in instance
        instance.createProductSetup(productNftId, product.getSetupInfo());

        // create target for instane access manager
        getInstanceService().createGifTarget(
            _registry.getNftId(address(instance)), 
            address(product), 
            product.getName());
        getInstanceService().grantProductDefaultPermissions(instance.getNftId(), address(product), product.getName());
    }

    function getDomain() public pure override(IService, Service) returns(ObjectType) {
        return PRODUCT();
    }


    function _decodeAndVerifyProductData(bytes memory data) 
        internal 
        returns(string memory name, ISetup.ProductSetupInfo memory setup)
    {
        (name, setup) = abi.decode(
            data,
            (string, ISetup.ProductSetupInfo)
        );

        // TODO add checks
        // if(wallet == address(0)) {
        //     revert WalletIsZero();
        // }

        // IRegistry.ObjectInfo memory tokenInfo = _registry.getObjectInfo(address(info.token));

        // if(tokenInfo.objectType != TOKEN()) {
        //     revert InvalidToken();
        // } 

        // IRegistry.ObjectInfo memory poolInfo = _registry.getObjectInfo(info.poolNftId);

        // if(poolInfo.objectType != POOL()) {
        //     revert InvalidPool();
        // }

        // if(poolInfo.parentNftId != instanceNftId) {
        //     revert InvalidPoolsInstance();
        // }
        // // TODO pool have the same token
        // //ITreasury.PoolSetup memory poolSetup = instance.getPoolSetup(info.poolNftId);
        // //require(tokenInfo.objectAddress == address(poolSetup.token), "ERROR:COS-018:PRODUCT_POOL_TOKEN_MISMATCH");
        // // TODO pool is not linked

        // IRegistry.ObjectInfo memory distributionInfo = _registry.getObjectInfo(info.distributionNftId);

        // if(distributionInfo.objectType != DISTRIBUTION()) {
        //     revert  InvalidDistribution();
        // } 

        // if(distributionInfo.parentNftId != instanceNftId) {
        //     revert InvalidDistributionsInstance();
        // }
        // // TODO distribution have the same token
        // // TODO distribution is not linked
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
