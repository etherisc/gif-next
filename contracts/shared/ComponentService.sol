// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IAccountingService} from "../accounting/IAccountingService.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IComponentService} from "./IComponentService.sol";
import {IInstance} from "../instance/IInstance.sol";
import {IInstanceLinkedComponent} from "./IInstanceLinkedComponent.sol";
import {InstanceAdmin} from "../instance/InstanceAdmin.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {InstanceStore} from "../instance/InstanceStore.sol";
import {IPoolComponent} from "../pool/IPoolComponent.sol";
import {IProductComponent} from "../product/IProductComponent.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IRegistryService} from "../registry/IRegistryService.sol";
import {IStaking} from "../staking/IStaking.sol";
import {IStakingService} from "../staking/IStakingService.sol";

import {AccessManagerCloneable} from "../authorization/AccessManagerCloneable.sol";
import {Amount, AmountLib} from "../type/Amount.sol";
import {ChainIdLib} from "../type/ChainId.sol";
import {ContractLib} from "../shared/ContractLib.sol";
import {Fee, FeeLib} from "../type/Fee.sol";
import {KEEP_STATE} from "../type/StateId.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {ObjectType, ACCOUNTING, REGISTRY, COMPONENT, DISTRIBUTION, INSTANCE, ORACLE, POOL, PRODUCT, STAKING} from "../type/ObjectType.sol";
import {ProductStore} from "../instance/ProductStore.sol";
import {Service} from "../shared/Service.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {TokenHandlerDeployerLib} from "../shared/TokenHandlerDeployerLib.sol";


contract ComponentService is
    Service,
    IComponentService
{
    bool private constant INCREASE = true;
    bool private constant DECREASE = false;

    IAccountingService private _accountingService;
    IRegistryService private _registryService;
    IStaking private _staking;

    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        virtual override
        onlyInitializing()
    {
        (
            address authority
        ) = abi.decode(data, (address));

        __Service_init(authority, owner);

        _accountingService = IAccountingService(_getServiceAddress(ACCOUNTING()));
        _registryService = IRegistryService(_getServiceAddress(REGISTRY()));
        _staking = IStakingService(_getServiceAddress(STAKING())).getStaking();

        _registerInterface(type(IComponentService).interfaceId);
    }

    //-------- component ----------------------------------------------------//

    /// @inheritdoc IComponentService
    function registerComponent(address componentAddress)
        external
        virtual
        restricted()
        returns (NftId componentNftId)
    {
        // check sender is registered product
        IRegistry registry = _getRegistry();
        if (!registry.isObjectType(msg.sender, PRODUCT(), getRelease())) {
            revert ErrorComponentServiceCallerNotProduct(msg.sender);
        }

        NftId productNftId = registry.getNftIdForAddress(msg.sender);
        IInstance instance = IInstance(
            registry.getObjectAddress(
                registry.getParentNftId(productNftId)));

        componentNftId = _register(
            instance, 
            componentAddress,
            COMPONENT(),
            productNftId, // product is parent of component to be registered
            address(0)); // token will be inhereited from product
    }


    /// @inheritdoc IComponentService
    function approveTokenHandler(
        IERC20Metadata token,
        Amount amount
    )
        external
        virtual
        restricted()
    {
        // checks
        (NftId componentNftId, IInstance instance) = _getAndVerifyComponent(COMPONENT(), true);
        TokenHandler tokenHandler = instance.getInstanceReader().getTokenHandler(
            componentNftId);

        // effects
        tokenHandler.approve(token, amount);
    }


    /// @inheritdoc IComponentService
    function setWallet(address newWallet)
        external
        virtual
        restricted()
    {
        // checks
        (NftId componentNftId, IInstance instance) = _getAndVerifyComponent(COMPONENT(), true);
        TokenHandler tokenHandler = instance.getInstanceReader().getTokenHandler(
            componentNftId);

        // effects
        tokenHandler.setWallet(newWallet);
    }

    /// @inheritdoc IComponentService
    function setLocked(bool locked) 
        external 
        virtual
        restricted()
    {
        (, IInstance instance) = _getAndVerifyComponent(COMPONENT(), false);

        address component = msg.sender;
        instance.getInstanceAdmin().setContractLocked(
            component, 
            locked);
        emit LogComponentServiceComponentLocked(component, locked);
    }


    /// @inheritdoc IComponentService
    function withdrawFees(Amount amount)
        external
        virtual
        restricted()
        returns (Amount withdrawnAmount)
    {
        // checks
        (NftId componentNftId, IInstance instance) = _getAndVerifyComponent(COMPONENT(), true);
        InstanceReader instanceReader = instance.getInstanceReader();

        // determine withdrawn amount
        Amount maxAvailableAmount = instanceReader.getFeeAmount(componentNftId);
        withdrawnAmount = amount;

        // max amount -> withraw all available fees
        if (amount == AmountLib.max()) {
            withdrawnAmount = maxAvailableAmount;
        }

        // check modified withdrawn amount
        if (withdrawnAmount.eqz()) {
            revert ErrorComponentServiceWithdrawAmountIsZero();
        } else if (withdrawnAmount > maxAvailableAmount) {
            revert ErrorComponentServiceWithdrawAmountExceedsLimit(withdrawnAmount, maxAvailableAmount);
        }

        // effects
        // decrease fee counters by withdrawnAmount
        _accountingService.decreaseComponentFees(
            instance.getInstanceStore(), 
            componentNftId, 
            withdrawnAmount);
        
        // transfer amount to component owner
        address componentOwner = _getRegistry().ownerOf(componentNftId);
        TokenHandler tokenHandler = instanceReader.getTokenHandler(componentNftId);
        emit LogComponentServiceComponentFeesWithdrawn(
            componentNftId, 
            componentOwner, 
            address(tokenHandler.TOKEN()), 
            withdrawnAmount);

        // interactions
        // transfer amount to component owner
        tokenHandler.pushFeeToken(
            componentOwner, 
            withdrawnAmount);
    }


    //-------- product ------------------------------------------------------//

    /// @inheritdoc IComponentService
    function registerProduct(address productAddress, address token)
        external
        virtual
        restricted()
        nonReentrant()
        returns (NftId productNftId)
    {
        // check sender is registered instance
        IRegistry registry = _getRegistry();
        if (!registry.isObjectType(msg.sender, INSTANCE(), getRelease())) {
            revert ErrorComponentServiceCallerNotInstance(msg.sender);
        }

        IInstance instance = IInstance(msg.sender);
        NftId instanceNftId = registry.getNftIdForAddress(msg.sender);
        productNftId = _register(
            instance, 
            productAddress, 
            PRODUCT(),
            instanceNftId, // instance is parent of product to be registered 
            token);

        // add product specific token for product to staking
        _staking.addTargetToken(
            instanceNftId, 
            token);
    }

    /// @inheritdoc IComponentService
    function setProductFees(
        Fee memory productFee, // product fee on net premium
        Fee memory processingFee // product fee on payout amounts        
    )
        external
        virtual
        restricted()
        nonReentrant()
    {
        (NftId productNftId, IInstance instance) = _getAndVerifyComponent(PRODUCT(), true);
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
            instance.getProductStore().updateFee(productNftId, feeInfo);
            emit LogComponentServiceProductFeesUpdated(productNftId);
        }
    }


    function _createProduct(
        ProductStore productStore,
        NftId productNftId,
        address productAddress
    )
        internal
        virtual
    {
        // create product in instance instanceStore
        IProductComponent product = IProductComponent(productAddress);
        IComponents.ProductInfo memory initialProductInfo = product.getInitialProductInfo();
        // force initialization of linked components with empty values to 
        // ensure no components are linked upon initialization of the product
        initialProductInfo.poolNftId = NftIdLib.zero();
        initialProductInfo.distributionNftId = NftIdLib.zero();
        initialProductInfo.oracleNftId = new NftId[](initialProductInfo.expectedNumberOfOracles);

        // create info
        productStore.createProduct(
            productNftId, 
            initialProductInfo);

        productStore.createFee(
            productNftId, 
            product.getInitialFeeInfo());
    }

    //-------- distribution -------------------------------------------------//

    /// @dev registers the sending component as a distribution component
    function _createDistribution(
        ProductStore productStore,
        NftId productNftId,
        NftId distributionNftId,
        IComponents.ProductInfo memory productInfo
    )
        internal
        virtual
        nonReentrant()
    {
        // check product is still expecting a distribution registration
        if (!productInfo.hasDistribution) {
            revert ErrorProductServiceNoDistributionExpected(productNftId);
        }
        if (productInfo.distributionNftId.gtz()) {
            revert ErrorProductServiceDistributionAlreadyRegistered(productNftId, productInfo.distributionNftId);
        }

        // set distribution in product info
        productInfo.distributionNftId = distributionNftId;
        productStore.updateProduct(productNftId, productInfo, KEEP_STATE());
    }


    function setDistributionFees(
        Fee memory distributionFee, // distribution fee for sales that do not include commissions
        Fee memory minDistributionOwnerFee // min fee required by distribution owner (not including commissions for distributors)
    )
        external
        virtual
        restricted()
    {
        (NftId distributionNftId, IInstance instance) = _getAndVerifyComponent(DISTRIBUTION(), true);
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
            instance.getProductStore().updateFee(productNftId, feeInfo);
            emit LogComponentServiceDistributionFeesUpdated(distributionNftId);
        }
    }

    //-------- oracle -------------------------------------------------------//

    function _createOracle(
        ProductStore productStore,
        NftId productNftId,
        NftId oracleNftId,
        IComponents.ProductInfo memory productInfo
    )
        internal
        virtual
    {
        // check product is still expecting an oracle registration
        if (productInfo.expectedNumberOfOracles == 0) {
            revert ErrorProductServiceNoOraclesExpected(productNftId);
        }
        if (productInfo.numberOfOracles == productInfo.expectedNumberOfOracles) {
            revert ErrorProductServiceOraclesAlreadyRegistered(productNftId, productInfo.expectedNumberOfOracles);
        }

        // update/add oracle to product info
        productInfo.oracleNftId[productInfo.numberOfOracles] = oracleNftId;
        productInfo.numberOfOracles++;
        productStore.updateProduct(productNftId, productInfo, KEEP_STATE());
    }

    //-------- pool ---------------------------------------------------------//

    function _createPool(
        InstanceStore instanceStore,
        ProductStore productStore,
        NftId productNftId,
        NftId poolNftId,
        address componentAddress,
        IComponents.ProductInfo memory productInfo
    )
        internal
        virtual
    {
        // check product is still expecting a pool registration
        //IComponents.ProductInfo memory productInfo = instanceReader.getProductInfo(productNftId);
        if (productInfo.poolNftId.gtz()) {
            revert ErrorProductServicePoolAlreadyRegistered(productNftId, productInfo.poolNftId);
        }

        // create info
        IPoolComponent pool = IPoolComponent(componentAddress);
        instanceStore.createPool(
            poolNftId, 
            pool.getInitialPoolInfo());

        // update pool in product info
        productInfo.poolNftId = poolNftId;
        productStore.updateProduct(productNftId, productInfo, KEEP_STATE());
    }


    function setPoolFees(
        Fee memory poolFee, // pool fee on net premium
        Fee memory stakingFee, // pool fee on staked capital from investor
        Fee memory performanceFee // pool fee on profits from capital investors
    )
        external
        virtual
        restricted()
    {
        (NftId poolNftId, IInstance instance) = _getAndVerifyComponent(POOL(), true);

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
            instance.getProductStore().updateFee(productNftId, feeInfo);
            emit LogComponentServicePoolFeesUpdated(poolNftId);
        }
    }


    /// @dev Registers the component represented by the provided address.
    /// The caller must ensure componentAddress is IInstanceLinkedComponent.
    function _register(
        IInstance instance,
        address componentAddress,
        ObjectType componentType,
        NftId parentNftId,
        address token
    )
        internal
        virtual
        returns (NftId componentNftId)
    {
        IInstanceLinkedComponent component = IInstanceLinkedComponent(componentAddress);
        // TODO consider adding release arg to _registryService.registerComponent() and similar
        // in order to be 100% sure that services have same release?
        IRegistry.ObjectInfo memory info = _registryService.registerComponent(
            component,
            parentNftId,
            componentType,
            address(0)); // component owner have no importance here

        componentType = info.objectType;
        componentNftId = info.nftId;

        InstanceStore instanceStore = instance.getInstanceStore();
        InstanceReader instanceReader = instance.getInstanceReader();

        if(componentType == PRODUCT()) {
            // create product info in instance store
            _createProduct(instance.getProductStore(), componentNftId, componentAddress);
        } else {
            // create non product component info in instance store
            NftId productNftId = info.parentNftId;
            IComponents.ProductInfo memory productInfo = instanceReader.getProductInfo(productNftId);

            if(componentType == POOL()) {
                _createPool(instanceStore, instance.getProductStore(), productNftId, componentNftId, componentAddress, productInfo);
            } else if(componentType == DISTRIBUTION()) {
                _createDistribution(instance.getProductStore(), productNftId, componentNftId, productInfo);
            } else if(componentType == ORACLE()) {
                _createOracle(instance.getProductStore(), productNftId, componentNftId, productInfo);
            } else {
                revert ErrorComponentServiceComponentTypeNotSupported(componentAddress, componentType);
            }

            // get product's token
            token = address(instanceReader.getToken(productNftId));
        }

        _checkToken(instance, token);

        InstanceAdmin instanceAdmin = instance.getInstanceAdmin();
        
        // deploy and wire token handler
        IRegistry registry = _getRegistry();
        IComponents.ComponentInfo memory componentInfo = component.getInitialComponentInfo();
        componentInfo.tokenHandler = TokenHandlerDeployerLib.deployTokenHandler(
            address(registry),
            componentAddress, // initially, component is its own wallet
            token, 
            instanceAdmin.authority());
        
        // register component with instance
        instanceStore.createComponent(
            componentNftId, 
            componentInfo);

        // link component contract to nft id
        component.linkToRegisteredNftId();

        // authorize
        instanceAdmin.initializeComponentAuthorization(componentAddress, componentType, getRelease());

        emit LogComponentServiceRegistered(
            instance.getNftId(),
            componentNftId, 
            componentType, 
            componentAddress, 
            token, 
            registry.ownerOf(componentNftId));
    }


    function _checkToken(IInstance instance, address token) 
        internal
        view
    {
        if (! instance.isTokenRegistryDisabled()) {
            // TODO call token registry directlly?
            // check if provided token is whitelisted and active
            if (!ContractLib.isActiveToken(
                _getRegistry().getTokenRegistryAddress(), 
                ChainIdLib.current(), 
                token, 
                AccessManagerCloneable(authority()).getRelease())
            ) {
                revert ErrorComponentServiceTokenInvalid(token);
            }
        }
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
        productNftId = _getRegistry().getParentNftId(componentNftId);
        info = instanceReader.getFeeInfo(productNftId);
    }

    function _setLocked(InstanceAdmin instanceAdmin, address componentAddress, bool locked) internal {
        instanceAdmin.setTargetLocked(componentAddress, locked);
    }


    function _getAndVerifyComponent(ObjectType expectedType, bool isActive) 
        internal 
        view 
        returns (
            NftId componentNftId,
            IInstance instance
        )
    {
        (componentNftId, instance) = ContractLib.getAndVerifyComponent(
            msg.sender, // caller
            expectedType,
            getRelease(),
            isActive);
    }


    function _getDomain() internal pure virtual override returns(ObjectType) {
        return COMPONENT();
    }
}