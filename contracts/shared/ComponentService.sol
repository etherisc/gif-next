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

import {AccessManagerCloneable} from "../authorization/AccessManagerCloneable.sol";
import {Amount, AmountLib} from "../type/Amount.sol";
import {ContractLib} from "../shared/ContractLib.sol";
import {Fee, FeeLib} from "../type/Fee.sol";
import {KEEP_STATE} from "../type/StateId.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {ObjectType, ACCOUNTING, REGISTRY, COMPONENT, DISTRIBUTION, INSTANCE, ORACLE, POOL, PRODUCT} from "../type/ObjectType.sol";
import {Service} from "../shared/Service.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {TokenHandlerDeployerLib} from "../shared/TokenHandlerDeployerLib.sol";
import {VersionPart} from "../type/Version.sol";


contract ComponentService is
    Service,
    IComponentService
{
    bool private constant INCREASE = true;
    bool private constant DECREASE = false;

    IAccountingService private _accountingService;
    IRegistryService private _registryService;
    IInstanceService private _instanceService;

    modifier onlyComponent(address component) {
        _checkSupportsInterface(component);
        _;
    }

    modifier onlyInstance() {        
        NftId instanceNftId = getRegistry().getNftIdForAddress(msg.sender);
        if (instanceNftId.eqz()) {
            revert ErrorComponentServiceNotRegistered(msg.sender);
        }

        ObjectType objectType = getRegistry().getObjectInfo(instanceNftId).objectType;
        if (objectType != INSTANCE()) {
            revert ErrorComponentServiceNotInstance(msg.sender, objectType);
        }

        VersionPart instanceVersion = IInstance(msg.sender).getRelease();
        if (instanceVersion != getVersion().toMajorPart()) {
            revert ErrorComponentServiceInstanceVersionMismatch(msg.sender, instanceVersion);
        }

        _;
    }


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

    function registerComponent(address component)
        external
        virtual
        onlyComponent(component)
        returns (NftId componentNftId)
    {
        // type specific registration
        IRegistry.ObjectInfo memory componentObjectInfo = IInstanceLinkedComponent(component).getInitialInfo();
        ObjectType componentType = componentObjectInfo.objectType;        
        IComponent productComponent = IComponent(getRegistry().getObjectAddress(componentObjectInfo.parentNftId));

        if (componentType == POOL()) {
            return _registerPool(component, address(productComponent.getToken()));
        }
        if (componentType == DISTRIBUTION()) {
            return _registerDistribution(component, address(productComponent.getToken()));
        }
        if (componentType == ORACLE()) {
            return _registerOracle(component, address(productComponent.getToken()));
        }

        // fail
        revert ErrorComponentServiceTypeNotSupported(component, componentType);
    }

    function approveTokenHandler(
        IERC20Metadata token,
        Amount amount
    )
        external
        virtual
    {
        // checks
        (NftId componentNftId, IInstance instance) = _getAndVerifyActiveComponent(COMPONENT());
        TokenHandler tokenHandler = instance.getInstanceReader().getComponentInfo(
            componentNftId).tokenHandler;

        // effects
        tokenHandler.approve(token, amount);
    }


    function setWallet(address newWallet)
        external
        virtual
    {
        // checks
        (NftId componentNftId, IInstance instance) = _getAndVerifyActiveComponent(COMPONENT());
        TokenHandler tokenHandler = instance.getInstanceReader().getComponentInfo(
            componentNftId).tokenHandler;

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
        instance.getInstanceAdmin().setComponentLocked(
            component, 
            locked);
    }

    /// @inheritdoc IComponentService
    function withdrawFees(Amount amount)
        external
        virtual
        restricted()
        returns (Amount withdrawnAmount)
    {
        // checks
        (NftId componentNftId, IInstance instance) = _getAndVerifyActiveComponent(COMPONENT());
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
        address componentOwner = getRegistry().ownerOf(componentNftId);
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

    function registerProduct(address productAddress, address token)
        external
        virtual
        nonReentrant()
        onlyComponent(productAddress)
        returns (NftId productNftId)
    {
        // register/create component setup
        InstanceAdmin instanceAdmin;
        InstanceStore instanceStore;
        (, instanceAdmin, instanceStore,, productNftId) = _register(
            productAddress,
            PRODUCT(),
            token);

        // get product
        IProductComponent product = IProductComponent(productAddress);
        
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
    }


    function setProductFees(
        Fee memory productFee, // product fee on net premium
        Fee memory processingFee // product fee on payout amounts        
    )
        external
        virtual
        nonReentrant()
    {
        (NftId productNftId, IInstance instance) = _getAndVerifyActiveComponent(PRODUCT());
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
    function _registerDistribution(address distributioAddress, address token)
        internal
        virtual
        nonReentrant()
        returns (NftId distributionNftId)
    {
        // register/create component info
        InstanceReader instanceReader;
        InstanceAdmin instanceAdmin;
        InstanceStore instanceStore;
        NftId productNftId;
        (instanceReader, instanceAdmin, instanceStore, productNftId, distributionNftId) = _register(
            distributioAddress,
            DISTRIBUTION(),
            token);

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
    }


    function setDistributionFees(
        Fee memory distributionFee, // distribution fee for sales that do not include commissions
        Fee memory minDistributionOwnerFee // min fee required by distribution owner (not including commissions for distributors)
    )
        external
        virtual
    {
        (NftId distributionNftId, IInstance instance) = _getAndVerifyActiveComponent(DISTRIBUTION());
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

    function _registerOracle(address oracleAddress, address token)
        internal
        virtual
        returns (NftId oracleNftId)
    {
        // register/create component setup
        InstanceReader instanceReader;
        InstanceAdmin instanceAdmin;
        InstanceStore instanceStore;
        NftId productNftId;

        (instanceReader, instanceAdmin, instanceStore, productNftId, oracleNftId) = _register(
            oracleAddress,
            ORACLE(),
            token);

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
    }

    //-------- pool ---------------------------------------------------------//

    function _registerPool(address poolAddress, address token)
        internal
        virtual
        returns (NftId poolNftId)
    {
        // register/create component setup
        InstanceReader instanceReader;
        InstanceAdmin instanceAdmin;
        InstanceStore instanceStore;
        NftId productNftId;

        (instanceReader, instanceAdmin, instanceStore, productNftId, poolNftId) = _register(
            poolAddress,
            POOL(),
            token);

        // check product is still expecting a pool registration
        IComponents.ProductInfo memory productInfo = instanceReader.getProductInfo(productNftId);
        if (productInfo.poolNftId.gtz()) {
            revert ErrorProductServicePoolAlreadyRegistered(productNftId, productInfo.poolNftId);
        }

        // create info
        IPoolComponent pool = IPoolComponent(poolAddress);
        instanceStore.createPool(
            poolNftId, 
            pool.getInitialPoolInfo());

        // update pool in product info
        productInfo.poolNftId = poolNftId;
        instanceStore.updateProduct(productNftId, productInfo, KEEP_STATE());
    }


    function setPoolFees(
        Fee memory poolFee, // pool fee on net premium
        Fee memory stakingFee, // pool fee on staked capital from investor
        Fee memory performanceFee // pool fee on profits from capital investors
    )
        external
        virtual
    {
        (NftId poolNftId, IInstance instance) = _getAndVerifyActiveComponent(POOL());

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
        address componentAddress, // address of component to register
        ObjectType requiredType, // required type for component for registration
        address token
    )
        internal
        virtual
        returns (
            InstanceReader instanceReader, 
            InstanceAdmin instanceAdmin, 
            InstanceStore instanceStore, 
            NftId parentNftId,
            NftId componentNftId
        )
    {
        NftId instanceNftId;
        IInstance instance;
        IInstanceLinkedComponent component;
        address initialOwner;

        (
            instanceNftId, 
            instance, 
            parentNftId, 
            component, 
            initialOwner
        ) = _getAndVerifyRegisterableComponent(
            getRegistry(),
            componentAddress,
            requiredType);

        {
            // check if provided token is whitelisted and active
            if (!ContractLib.isActiveToken(
                getRegistry().getTokenRegistryAddress(), 
                token, 
                block.chainid, 
                AccessManagerCloneable(authority()).getRelease())
            ) {
                revert ErrorComponentServiceTokenInvalid(token);
            }
        }

        // get instance supporting contracts (as function return values)
        instanceReader = instance.getInstanceReader();
        instanceAdmin = instance.getInstanceAdmin();
        instanceStore = instance.getInstanceStore();

        // register with registry
        if (requiredType == PRODUCT()) {
            componentNftId = _registryService.registerProduct(
                component, initialOwner).nftId;
        } else {
            componentNftId = _registryService.registerProductLinkedComponent(
                component, requiredType, initialOwner).nftId;
        }

        // deploy and wire token handler
        {
            IComponents.ComponentInfo memory componentInfo = component.getInitialComponentInfo();
            // TODO: check if token is whitelisted
            componentInfo.tokenHandler = TokenHandlerDeployerLib.deployTokenHandler(
                address(getRegistry()),
                componentAddress, // initially, component is its own wallet
                token, 
                address(instanceAdmin.authority()));
            
            // register component with instance
            instanceStore.createComponent(
                componentNftId, 
                componentInfo);
        }

        // link component contract to nft id
        component.linkToRegisteredNftId();

        // authorize
        instanceAdmin.initializeComponentAuthorization(componentAddress, requiredType);

        emit LogComponentServiceRegistered(instanceNftId, componentNftId, requiredType, componentAddress, token, initialOwner);
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
        productNftId = getRegistry().getParentNftId(componentNftId);
        info = instanceReader.getFeeInfo(productNftId);
    }


    /// @dev Based on the provided component address required type the component 
    /// and related instance contract this function reverts iff:
    /// - the sender is not registered
    /// - the component contract does not support IInstanceLinkedComponent
    /// - the component type does not match with the required type
    /// - the component has already been registered
    function _getAndVerifyRegisterableComponent(
        IRegistry registry,
        address componentAddress,
        ObjectType requiredType
    )
        internal
        view
        returns (
            NftId instanceNftId,
            IInstance instance,
            NftId parentNftId,
            IInstanceLinkedComponent component,
            address initialOwner
        )
    {
        // check sender (instance or product) is registered
        IRegistry.ObjectInfo memory senderInfo = registry.getObjectInfo(msg.sender);
        if (senderInfo.nftId.eqz()) {
            revert ErrorComponentServiceSenderNotRegistered(msg.sender);
        }

        // the sender is the parent of the component to be registered
        // an instance caller wanting to register a product - or -
        // a product caller wantint go register a distribution, oracle or pool
        parentNftId = senderInfo.nftId;

        // check component is of required type
        component = IInstanceLinkedComponent(componentAddress);
        IRegistry.ObjectInfo memory info = component.getInitialInfo();
        if(info.objectType != requiredType) {
            revert ErrorComponentServiceInvalidType(componentAddress, requiredType, info.objectType);
        }

        // check component has not already been registered
        if (getRegistry().getNftIdForAddress(componentAddress).gtz()) {
            revert ErrorComponentServiceAlreadyRegistered(componentAddress);
        }

        // component release matches servie release
        address parentAddress = registry.getObjectAddress(parentNftId);
        if (component.getRelease() != getRelease()) {
            revert ErrorComponentServiceReleaseMismatch(componentAddress, component.getRelease(), getRelease());
        // component release matches parent release
        } else if (component.getRelease() != IRegisterable(parentAddress).getRelease()){
            revert ErrorComponentServiceReleaseMismatch(componentAddress, component.getRelease(), IRegisterable(parentAddress).getRelease());
        }

        // check component belongs to same product cluster 
        // parent of product must be instance, parent of other componet types must be product
        if (info.parentNftId != senderInfo.nftId) {
            revert ErrorComponentServiceSenderNotComponentParent(senderInfo.nftId, info.parentNftId);
        }

        // verify parent is registered instance
        if (requiredType == PRODUCT()) {
            if (senderInfo.objectType != INSTANCE()) {
                revert ErrorComponentServiceParentNotInstance(senderInfo.nftId, senderInfo.objectType);
            }

            instanceNftId = senderInfo.nftId;
        // verify parent is registered product
        } else {
            if (senderInfo.objectType != PRODUCT()) {
                revert ErrorComponentServiceParentNotProduct(senderInfo.nftId, senderInfo.objectType);
            }

            instanceNftId = senderInfo.parentNftId;
        }

        // get initial owner and instance
        initialOwner = info.initialOwner;
        instance = IInstance(registry.getObjectAddress(instanceNftId));
    }

    function _setLocked(InstanceAdmin instanceAdmin, address componentAddress, bool locked) internal {
        instanceAdmin.setTargetLocked(componentAddress, locked);
    }

    function _getAndVerifyActiveComponent(ObjectType expectedType) 
        internal 
        view 
        returns (
            NftId componentNftId,
            IInstance instance
        )
    {
        return _getAndVerifyComponent(expectedType, true); // only active
    }

    function _getAndVerifyComponent(ObjectType expectedType, bool isActive) 
        internal 
        view 
        returns (
            NftId componentNftId,
            IInstance instance
        )
    {
        IRegistry.ObjectInfo memory info;
        address instanceAddress;

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

    function _getDomain() internal pure virtual override returns(ObjectType) {
        return COMPONENT();
    }

    function _checkSupportsInterface(address component) internal view {
        if (!ContractLib.supportsInterface(component, type(IInstanceLinkedComponent).interfaceId)) {
            revert ErrorComponentServiceNotInstanceLinkedComponent(component);
        }
    }
}