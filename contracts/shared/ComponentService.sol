// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IAccountingService} from "../accounting/IAccountingService.sol";
import {IComponent} from "../shared/IComponent.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IComponentService} from "./IComponentService.sol";
import {IInstance} from "../instance/IInstance.sol";
import {IInstanceLinkedComponent} from "./IInstanceLinkedComponent.sol";
import {InstanceAdmin} from "../instance/InstanceAdmin.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {InstanceStore} from "../instance/InstanceStore.sol";
import {IInstanceService} from "../instance/IInstanceService.sol";
import {IPoolComponent} from "../pool/IPoolComponent.sol";
import {IProductComponent} from "../product/IProductComponent.sol";
import {IRegisterable} from "../shared/IRegisterable.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IRegistryService} from "../registry/IRegistryService.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {ContractLib} from "../shared/ContractLib.sol";
import {Fee, FeeLib} from "../type/Fee.sol";
import {KEEP_STATE} from "../type/StateId.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {ObjectType, ACCOUNTING, REGISTRY, COMPONENT, DISTRIBUTION, INSTANCE, ORACLE, POOL, PRODUCT} from "../type/ObjectType.sol";
import {ComponentVerifyingService} from "../shared/ComponentVerifyingService.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {TokenHandlerDeployerLib} from "../shared/TokenHandlerDeployerLib.sol";
import {VersionPart} from "../type/Version.sol";


contract ComponentService is
    ComponentVerifyingService,
    IComponentService
{
    bool private constant INCREASE = true;
    bool private constant DECREASE = false;

    IAccountingService private _accountingService;
    IRegistryService private _registryService;
    IInstanceService private _instanceService;

    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        virtual override
        initializer()
    {
        (
            address authority,
            address registry
        ) = abi.decode(data, (address, address));

        __Service_init(authority, registry, owner);

        _accountingService = IAccountingService(_getServiceAddress(ACCOUNTING()));
        _registryService = IRegistryService(_getServiceAddress(REGISTRY()));
        _instanceService = IInstanceService(_getServiceAddress(INSTANCE()));

        _registerInterface(type(IComponentService).interfaceId);
    }

    //-------- component ----------------------------------------------------//

    function registerComponent(address componentAddress)
        external
        virtual
        restricted()
        returns (NftId componentNftId)
    {
        (NftId productNftId,, IInstance instance) = _getAndVerifyCallingComponent(PRODUCT());

        (
            IInstanceLinkedComponent component,
            IRegistry.ObjectInfo memory componentInfo // initial component info
        ) = _getAndVerifyRegisterableComponent(
            componentAddress,
            productNftId);
        ObjectType componentType = componentInfo.objectType;

        if (componentType == POOL()) {
            IPoolComponent pool = IPoolComponent(componentAddress);
            return _registerPool(instance, productNftId, pool, componentInfo);
        }
        if (componentType == DISTRIBUTION()) {
            return _registerDistribution(instance, productNftId, component, componentInfo);
        }
        if (componentType == ORACLE()) {
            return _registerOracle(instance, productNftId, component, componentInfo);
        }

        // fail
        revert ErrorComponentServiceComponentTypeNotSupported(componentAddress, componentType);
    }

    function approveTokenHandler(
        IERC20Metadata token,
        Amount amount
    )
        external
        virtual
        restricted()
    {
        // checks
        (NftId componentNftId,, IInstance instance) = _getAndVerifyCallingComponent(COMPONENT());
        TokenHandler tokenHandler = instance.getInstanceReader().getComponentInfo(
            componentNftId).tokenHandler;

        // effects
        tokenHandler.approve(token, amount);
    }


    function approveStakingTokenHandler(
        IERC20Metadata token,
        Amount amount
    )
        external
        virtual
        restricted()
    {
        // checks
        ContractLib.getAndVerifyStaking(
            getRegistry(),
            msg.sender); // only active

        // effects
        TokenHandler tokenHandler = IComponent(msg.sender).getTokenHandler();
        tokenHandler.approve(token, amount);
    }


    function setWallet(address newWallet)
        external
        virtual
        restricted()
    {
        // checks
        (NftId componentNftId,, IInstance instance) = _getAndVerifyCallingComponent(COMPONENT());
        TokenHandler tokenHandler = instance.getInstanceReader().getComponentInfo(
            componentNftId).tokenHandler;

        // effects
        tokenHandler.setWallet(newWallet);
    }

    /// @inheritdoc IComponentService
    function setComponentLocked(address componentAddress, bool locked) 
        external 
        virtual
        restricted()
    {
        (,, IInstance instance) = _getAndVerifyCallingComponent(COMPONENT());
        instance.setLockedFromService(componentAddress, locked);
    }

    function withdrawFees(Amount amount)
        external
        virtual
        restricted()
        returns (Amount withdrawnAmount)
    {
        (NftId componentNftId,, IInstance instance) = _getAndVerifyCallingComponent(COMPONENT());
        IComponents.ComponentInfo memory info = instance.getInstanceReader().getComponentInfo(componentNftId);
        address componentWallet = info.tokenHandler.getWallet();

        // determine withdrawn amount
        withdrawnAmount = amount;
        if (withdrawnAmount.gte(AmountLib.max())) {
            withdrawnAmount = instance.getInstanceReader().getFeeAmount(componentNftId);
        } else if (withdrawnAmount.eqz()) {
            revert ErrorComponentServiceWithdrawAmountIsZero();
        } else {
            Amount withdrawLimit = instance.getInstanceReader().getFeeAmount(componentNftId);
            if (withdrawnAmount.gt(withdrawLimit)) {
                revert ErrorComponentServiceWithdrawAmountExceedsLimit(withdrawnAmount, withdrawLimit);
            }
        }

        // decrease fee counters by withdrawnAmount
        _accountingService.decreaseComponentFees(instance.getInstanceStore(), componentNftId, withdrawnAmount);
        
        // transfer amount to component owner
        address componentOwner = getRegistry().ownerOf(componentNftId);
        emit LogComponentServiceComponentFeesWithdrawn(componentNftId, componentOwner, address(info.token), withdrawnAmount);
        info.tokenHandler.distributeTokens(componentWallet, componentOwner, withdrawnAmount);
    }


    //-------- product ------------------------------------------------------//

    function registerProduct(address productAddress)
        external
        virtual
        restricted()
        nonReentrant()
        returns (NftId productNftId)
    {
        (NftId instanceNftId,, IInstance instance) = _getAndVerifyCallingInstance();

        (
            ,
            IRegistry.ObjectInfo memory productInfo // initial product info
        ) = _getAndVerifyRegisterableComponent(
            productAddress,
            instanceNftId);

        if(productInfo.objectType != PRODUCT()) {
            revert ErrorComponentServiceComponentTypeNotSupported(productAddress, productInfo.objectType);
        }

        // register/create component info
        IProductComponent product = IProductComponent(productAddress);
        productNftId = _register(instance, product, productInfo);

        InstanceAdmin instanceAdmin = instance.getInstanceAdmin();
        InstanceStore instanceStore = instance.getInstanceStore();

        // create product in instance store
        IComponents.ProductInfo memory initialProductInfo = product.getInitialProductInfo();
        // force initialization of linked components with empty values to 
        // ensure no components are linked upon initialization of the product
        initialProductInfo.poolNftId = NftIdLib.zero();
        initialProductInfo.distributionNftId = NftIdLib.zero();
        initialProductInfo.oracleNftId = new NftId[](initialProductInfo.expectedNumberOfOracles);

        // create info
        instanceStore.createProduct(
            productNftId, 
            initialProductInfo);
        instanceStore.createFee(
            productNftId, 
            product.getInitialFeeInfo());

        // authorize
        instanceAdmin.initializeComponentAuthorization(product);
    }


    function setProductFees(
        Fee memory productFee, // product fee on net premium
        Fee memory processingFee // product fee on payout amounts        
    )
        external
        virtual
        restricted()
        nonReentrant()
    {
        (NftId productNftId,, IInstance instance) = _getAndVerifyCallingComponent(PRODUCT());
        IComponents.FeeInfo memory feeInfo = instance.getInstanceReader().getFeeInfo(productNftId);
        bool feesChanged = false;

        // update product fee if required
        if(!FeeLib.eq(feeInfo.productFee, productFee)) {
            _logUpdateFee(productNftId, "ProductFee", feeInfo.productFee, productFee);
            feeInfo.productFee = productFee;
            feesChanged = true;
        }

        // update processing fee if required
        if(!FeeLib.eq(feeInfo.processingFee, processingFee)) {
            _logUpdateFee(productNftId, "ProcessingFee", feeInfo.processingFee, processingFee);
            feeInfo.processingFee = processingFee;
            feesChanged = true;
        }
        
        if(feesChanged) {
            instance.getInstanceStore().updateFee(productNftId, feeInfo);
            emit LogComponentServiceProductFeesUpdated(productNftId);
        }
    }

    //-------- distribution -------------------------------------------------//

    /// @dev registers the sending component as a distribution component
    function _registerDistribution(
        IInstance instance,
        NftId productNftId,
        IInstanceLinkedComponent distribution,
        IRegistry.ObjectInfo memory info
    )
        internal
        virtual
        nonReentrant()
        returns (NftId distributionNftId)
    {
        // register/create component info
        distributionNftId = _register(instance, distribution, info);

        InstanceReader instanceReader = instance.getInstanceReader();
        InstanceAdmin instanceAdmin = instance.getInstanceAdmin();
        InstanceStore instanceStore = instance.getInstanceStore();

        // check product is still expecting a distribution registration
        IComponents.ProductInfo memory productInfo = instanceReader.getProductInfo(productNftId);
        if (!productInfo.hasDistribution) {
            revert ErrorProductServiceNoDistributionExpected(productNftId);
        }
        if (productInfo.distributionNftId.gtz()) {
            revert ErrorProductServiceDistributionAlreadyRegistered(productNftId, productInfo.distributionNftId);
        }

        // set distribution in product info
        productInfo.distributionNftId = distributionNftId;
        instanceStore.updateProduct(productNftId, productInfo, KEEP_STATE());

        // authorize
        instanceAdmin.initializeComponentAuthorization(distribution);
    }


    function setDistributionFees(
        Fee memory distributionFee, // distribution fee for sales that do not include commissions
        Fee memory minDistributionOwnerFee // min fee required by distribution owner (not including commissions for distributors)
    )
        external
        virtual
        restricted()
    {
        (NftId distributionNftId,, IInstance instance) = _getAndVerifyCallingComponent(DISTRIBUTION());
        (NftId productNftId, IComponents.FeeInfo memory feeInfo) = _getLinkedFeeInfo(
            instance.getInstanceReader(), distributionNftId);
        bool feesChanged = false;

        // update distributino fee if required
        if(!FeeLib.eq(feeInfo.distributionFee, distributionFee)) {
            _logUpdateFee(productNftId, "DistributionFee", feeInfo.distributionFee, distributionFee);
            feeInfo.distributionFee = distributionFee;
            feesChanged = true;
        }

        // update min distribution owner fee if required
        if(!FeeLib.eq(feeInfo.minDistributionOwnerFee, minDistributionOwnerFee)) {
            _logUpdateFee(productNftId, "MinDistributionOwnerFee", feeInfo.minDistributionOwnerFee, minDistributionOwnerFee);
            feeInfo.minDistributionOwnerFee = minDistributionOwnerFee;
            feesChanged = true;
        }
        
        if(feesChanged) {
            instance.getInstanceStore().updateFee(productNftId, feeInfo);
            emit LogComponentServiceDistributionFeesUpdated(distributionNftId);
        }
    }

    //-------- oracle -------------------------------------------------------//

    function _registerOracle(
        IInstance instance,
        NftId productNftId,
        IInstanceLinkedComponent oracle,
        IRegistry.ObjectInfo memory info
    )
        internal
        virtual
        returns (NftId oracleNftId)
    {
        // register/create component info
        oracleNftId = _register(instance, oracle, info);

        InstanceReader instanceReader = instance.getInstanceReader();
        InstanceAdmin instanceAdmin = instance.getInstanceAdmin();
        InstanceStore instanceStore = instance.getInstanceStore();

        // check product is still expecting an oracle registration
        IComponents.ProductInfo memory productInfo = instanceReader.getProductInfo(productNftId);
        if (productInfo.expectedNumberOfOracles == 0) {
            revert ErrorProductServiceNoOraclesExpected(productNftId);
        }
        if (productInfo.numberOfOracles == productInfo.expectedNumberOfOracles) {
            revert ErrorProductServiceOraclesAlreadyRegistered(productNftId, productInfo.expectedNumberOfOracles);
        }

        // update/add oracle to product info
        productInfo.oracleNftId[productInfo.numberOfOracles] = oracleNftId;
        productInfo.numberOfOracles++;
        instanceStore.updateProduct(productNftId, productInfo, KEEP_STATE());

        // authorize
        instanceAdmin.initializeComponentAuthorization(oracle);
    }

    //-------- pool ---------------------------------------------------------//

    function _registerPool(
        IInstance instance,
        NftId productNftId,
        IPoolComponent pool,
        IRegistry.ObjectInfo memory info
    )
        internal
        virtual
        returns (NftId poolNftId)
    {
        // register/create component info
        poolNftId = _register(instance, pool, info);

        InstanceReader instanceReader = instance.getInstanceReader();
        InstanceAdmin instanceAdmin = instance.getInstanceAdmin();
        InstanceStore instanceStore = instance.getInstanceStore();

        // check product is still expecting a pool registration
        IComponents.ProductInfo memory productInfo = instanceReader.getProductInfo(productNftId);
        if (productInfo.poolNftId.gtz()) {
            revert ErrorProductServicePoolAlreadyRegistered(productNftId, productInfo.poolNftId);
        }

        // create info
        instanceStore.createPool(
            poolNftId, 
            pool.getInitialPoolInfo());

        // update pool in product info
        productInfo.poolNftId = poolNftId;
        instanceStore.updateProduct(productNftId, productInfo, KEEP_STATE());

        // authorize
        instanceAdmin.initializeComponentAuthorization(pool);
    }


    function setPoolFees(
        Fee memory poolFee, // pool fee on net premium
        Fee memory stakingFee, // pool fee on staked capital from investor
        Fee memory performanceFee // pool fee on profits from capital investors
    )
        external
        restricted()
        virtual
    {
        (NftId poolNftId,, IInstance instance) = _getAndVerifyCallingComponent(POOL());
        (NftId productNftId, IComponents.FeeInfo memory feeInfo) = _getLinkedFeeInfo(
            instance.getInstanceReader(), poolNftId);
        bool feesChanged = false;

        // update pool fee if required
        if(!FeeLib.eq(feeInfo.poolFee, poolFee)) {
            _logUpdateFee(productNftId, "PoolFee", feeInfo.poolFee, poolFee);
            feeInfo.poolFee = poolFee;
            feesChanged = true;
        }

        // update staking fee if required
        if(!FeeLib.eq(feeInfo.stakingFee, stakingFee)) {
            _logUpdateFee(productNftId, "StakingFee", feeInfo.stakingFee, stakingFee);
            feeInfo.stakingFee = stakingFee;
            feesChanged = true;
        }

        // update performance fee if required
        if(!FeeLib.eq(feeInfo.performanceFee, performanceFee)) {
            _logUpdateFee(productNftId, "PerformanceFee", feeInfo.performanceFee, performanceFee);
            feeInfo.performanceFee = performanceFee;
            feesChanged = true;
        }
        
        if(feesChanged) {
            instance.getInstanceStore().updateFee(productNftId, feeInfo);
            emit LogComponentServicePoolFeesUpdated(poolNftId);
        }
    }

    /// @dev Registers the component represented by the provided address.
    function _register(
        IInstance instance,
        IInstanceLinkedComponent component,
        IRegistry.ObjectInfo memory info
    )
        internal
        virtual
        returns (NftId componentNftId)
    {
        // register component with registry
        componentNftId =
            info.objectType == PRODUCT() ?
            _registryService.registerProduct(component, info.initialOwner).nftId :
            _registryService.registerProductLinkedComponent(component, info.objectType, info.initialOwner).nftId;

        // deploy and wire token handler
        // TODO deploy token handler in instance contract ?!
        IComponents.ComponentInfo memory componentInfo = component.getInitialComponentInfo();
        IERC20Metadata token = componentInfo.token;
        componentInfo.tokenHandler = TokenHandlerDeployerLib.deployTokenHandler(
            address(getRegistry()),
            address(component), // initially, component is its own wallet
            address(token), 
            address(instance.getInstanceAdmin().authority()));

        // register component with instance
        instance.getInstanceStore().createComponent(
            componentNftId, 
            componentInfo);

        // link component contract to nft id
        component.linkToRegisteredNftId();

        emit LogComponentServiceRegistered(
            getRegistry().getNftIdForAddress(address(instance)), 
            componentNftId, 
            info.objectType,
            address(component), 
            address(token), 
            info.initialOwner);
    }

    function _logUpdateFee(NftId productNftId, string memory name, Fee memory feeBefore, Fee memory feeAfter)
        internal
        virtual
    {
        emit LogComponentServiceUpdateFee(
            productNftId, 
            name,
            feeBefore.fractionalFee,
            feeBefore.fixedFee,
            feeAfter.fractionalFee,
            feeAfter.fixedFee
        );
    }


    function _getLinkedFeeInfo(
        InstanceReader instanceReader, 
        NftId componentNftId
    )
        internal
        view 
        returns(
            NftId productNftId, 
            IComponents.FeeInfo memory info
        )
    {
        productNftId = getRegistry().getObjectInfo(componentNftId).parentNftId;
        info = instanceReader.getFeeInfo(productNftId);
    }

    /// @dev Based on the provided component address required type the component 
    /// and related instance contract this function reverts iff:
    /// - the component contract does not support IInstanceLinkedComponent
    /// - the component parent does not match with the required parent
    /// - the component version does not match with the service release
    /// - the component has already been registered
    function _getAndVerifyRegisterableComponent(
        address componentAddress,
        NftId requiredParent
    )
        internal
        view
        returns (
            IInstanceLinkedComponent component,
            IRegistry.ObjectInfo memory info
        )
    {
        // check component interface
        if (!ContractLib.supportsInterface(componentAddress, type(IInstanceLinkedComponent).interfaceId)) {
            revert ErrorComponentServiceNotInstanceLinkedComponent(address(component));
        }

        component = IInstanceLinkedComponent(componentAddress);
        info = component.getInitialInfo();

        // check component parent
        if(info.parentNftId != requiredParent) {
            revert ErrorComponentServiceComponentParentInvalid(componentAddress, requiredParent, info.parentNftId);
        }

        // check component release
        // TODO check version with registry
        //if(info.version != getRelease()) {
        if(component.getRelease() != getRelease()) {
            revert ErrorComponentServiceComponentReleaseMismatch(componentAddress, getRelease(), component.getRelease());
        }

        // check component has not already been registered
        if (getRegistry().getNftIdForAddress(componentAddress).gtz()) {
            revert ErrorComponentServiceComponentAlreadyRegistered(componentAddress);
        }
    }

    function _getDomain() internal pure virtual override returns(ObjectType) {
        return COMPONENT();
    }
}