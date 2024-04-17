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
import {ITreasury} from "../instance/module/ITreasury.sol";
import {ISetup} from "../instance/module/ISetup.sol";

import {TokenHandler} from "../shared/TokenHandler.sol";

import {IVersionable} from "../shared/IVersionable.sol";
import {Versionable} from "../shared/Versionable.sol";

import {Timestamp, zeroTimestamp} from "../type/Timestamp.sol";
import {UFixed, UFixedLib} from "../type/UFixed.sol";
import {Blocknumber, blockNumber} from "../type/Blocknumber.sol";
import {ObjectType, PRODUCT, POOL, POLICY} from "../type/ObjectType.sol";
import {APPLIED, ACTIVE, KEEP_STATE} from "../type/StateId.sol";
import {NftId, NftIdLib, zeroNftId} from "../type/NftId.sol";
import {Fee, FeeLib} from "../type/Fee.sol";
import {ReferralId} from "../type/Referral.sol";
import {RiskId} from "../type/RiskId.sol";
import {StateId} from "../type/StateId.sol";
import {Version, VersionLib} from "../type/Version.sol";
import {RoleId, PRODUCT_OWNER_ROLE} from "../type/RoleId.sol";

import {IService} from "../shared/IService.sol";
import {Service} from "../shared/Service.sol";
import {ComponentService} from "../shared/ComponentService.sol";
import {IProductService} from "./IProductService.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {IPoolService} from "../pool/PoolService.sol";

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
        (
            address registryAddress,, 
            //address managerAddress
            address authority
        ) = abi.decode(data, (address, address, address));

        initializeService(registryAddress, authority, owner);

        _poolService = IPoolService(getRegistry().getServiceAddress(POOL(), getVersion().toMajorPart()));

        registerInterface(type(IProductService).interfaceId);
    }


    function register(address productAddress) 
        external
        returns(NftId productNftId)
    {
        (
            IInstanceLinkedComponent component,
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
        IInstanceLinkedComponent distribution = IInstanceLinkedComponent(getRegistry().getObjectInfo(setup.distributionNftId).objectAddress);
        IInstanceLinkedComponent pool = IInstanceLinkedComponent(getRegistry().getObjectInfo(setup.poolNftId).objectAddress);

        distribution.setProductNftId(productNftId);
        pool.setProductNftId(productNftId);
        product.setProductNftId(productNftId);
        product.linkToRegisteredNftId();

        // create product setup in instance
        instance.getInstanceStore().createProductSetup(productNftId, product.getSetupInfo());

        bytes4[][] memory selectors = new bytes4[][](1);
        selectors[0] = new bytes4[](1);
        selectors[0][0] = IProductComponent.setFees.selector;

        RoleId[] memory roles = new RoleId[](1);
        roles[0] = PRODUCT_OWNER_ROLE();

        // create target for instane access manager
        getInstanceService().createGifTarget(
            getRegistry().getNftId(address(instance)), 
            address(product), 
            product.getName(),
            selectors,
            roles);
    }

    function getDomain() public pure override returns(ObjectType) {
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
    }

    function setFees(
        Fee memory productFee,
        Fee memory processingFee
    )
        external
    {
        // TODO check args 

        (NftId productNftId,, IInstance instance) = _getAndVerifyCallingComponentAndInstance(PRODUCT());
        InstanceReader instanceReader = instance.getInstanceReader();

        ISetup.ProductSetupInfo memory productSetupInfo = instanceReader.getProductSetupInfo(productNftId);

        productSetupInfo.productFee = productFee;
        productSetupInfo.processingFee = processingFee;
        
        instance.getInstanceStore().updateProductSetup(productNftId, productSetupInfo, KEEP_STATE());
    }

    function createRisk(
        RiskId riskId,
        bytes memory data
    )
        external 
        override
    {
        (NftId productNftId,, IInstance instance) = _getAndVerifyCallingComponentAndInstance(PRODUCT());
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
        (,, IInstance instance) = _getAndVerifyCallingComponentAndInstance(PRODUCT());
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
        (,, IInstance instance) = _getAndVerifyCallingComponentAndInstance(PRODUCT());
        instance.getInstanceStore().updateRiskState(riskId, state);
    }
}