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

    // keccak256(abi.encode(uint256(keccak256("etherisc.gif.ComponentService@3.0.0")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant COMPONENT_SERVICE_STORAGE_LOCATION_V3_0 = 0xc5533ae48eb96dccabcb7c228b271a453799a15cdbe5e61ead04b4ec1b7d9c00;

    struct ComponentServiceStorage {
        IAccountingService _accountingService;
        IRegistryService _registryService;
        IStaking _staking;
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

        ComponentServiceStorage storage $ = _getComponentServiceStorage();
        $._accountingService = IAccountingService(_getServiceAddress(ACCOUNTING()));
        $._registryService = IRegistryService(_getServiceAddress(REGISTRY()));
        $._staking = IStakingService(_getServiceAddress(STAKING())).getStaking();

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
        // checks
        // check sender is registered product
        IRegistry registry = getRegistry();
        if (!registry.isObjectType(msg.sender, PRODUCT())) {
            revert ErrorComponentServiceCallerNotProduct(msg.sender);
        }

        // check provided address is product contract
        if (!_isInstanceLinkedComponent(componentAddress)) {
            revert ErrorComponentServiceNotComponent(componentAddress);
        }

        NftId productNftId = registry.getNftIdForAddress(msg.sender);
        IInstance instance = IInstance(
            registry.getObjectAddress(
                registry.getParentNftId(productNftId)));

        componentNftId = _verifyAndRegister(
            instance, 
            componentAddress, 
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
        ComponentServiceStorage storage $ = _getComponentServiceStorage();
        $._accountingService.decreaseComponentFees(
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

    /// @inheritdoc IComponentService
    function registerProduct(address productAddress, address token)
        external
        virtual
        restricted()
        nonReentrant()
        returns (NftId productNftId)
    {
        // checks
        // check sender is registered instance
        IRegistry registry = getRegistry();
        if (!registry.isObjectType(msg.sender, INSTANCE())) {
            revert ErrorComponentServiceCallerNotInstance(msg.sender);
        }

        // check provided address is product contract
        if (!_isProduct(productAddress)) {
            revert ErrorComponentServiceNotProduct(productAddress);
        }

        IInstance instance = IInstance(msg.sender);
        NftId instanceNftId = registry.getNftIdForAddress(msg.sender);
        productNftId = _verifyAndRegister(
            instance, 
            productAddress, 
            instanceNftId, // instance is parent of product to be registered 
            token);

        // add product specific token for product to staking
        ComponentServiceStorage storage $ = _getComponentServiceStorage();
        $._staking.addTargetToken(
            instanceNftId, 
            token);
    }


    function _isProduct(address target) internal view virtual returns (bool) {
        if (!_isInstanceLinkedComponent(target)) {
            return false;
        }

        return IInstanceLinkedComponent(target).getInitialInfo().objectType == PRODUCT();
    }


    function _isInstanceLinkedComponent(address target) internal view virtual returns (bool) {
        if (!ContractLib.isContract(target)) {
            return false;
        }

        return ContractLib.supportsInterface(target, type(IInstanceLinkedComponent).interfaceId);
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
    function _verifyAndRegister(
        IInstance instance,
        address componentAddress,
        NftId parentNftId,
        address token
    )
        internal
        virtual
        returns (NftId componentNftId)
    {
        (
            IInstanceLinkedComponent component,
            IRegistry.ObjectInfo memory objectInfo // initial component info
        ) = _getAndVerifyRegisterableComponent(
            componentAddress,
            parentNftId);

        ObjectType componentType = objectInfo.objectType;
        ComponentServiceStorage storage $ = _getComponentServiceStorage();

        if(componentType == PRODUCT()) {
            // register product with registry
            componentNftId = $._registryService.registerProduct(
                component, 
                objectInfo.initialOwner).nftId;

            // create product info in instance store
            _createProduct(instance.getProductStore(), componentNftId, componentAddress);
        } else {
            // register non product component with registry
            componentNftId = $._registryService.registerProductLinkedComponent(
                component, 
                objectInfo.objectType, 
                objectInfo.initialOwner).nftId;

            InstanceReader instanceReader = instance.getInstanceReader();

            // create non product component info in instance store
            NftId productNftId = parentNftId;
            IComponents.ProductInfo memory productInfo = instanceReader.getProductInfo(productNftId);
            if(componentType == POOL()) {
                _createPool(instance.getInstanceStore(), instance.getProductStore(), productNftId, componentNftId, componentAddress, productInfo);
            } else if(componentType == DISTRIBUTION()) {
                _createDistribution(instance.getProductStore(), productNftId, componentNftId, productInfo);
            } else if(componentType == ORACLE()) {
                _createOracle(instance.getProductStore(), productNftId, componentNftId, productInfo);
            } else {
                revert ErrorComponentServiceComponentTypeNotSupported(componentAddress, componentType);
            }

            // get product's token
            token = address(instanceReader.getTokenHandler(productNftId).TOKEN());
        }

        _checkToken(instance, token);

        InstanceAdmin instanceAdmin = instance.getInstanceAdmin();
        
        // deploy and wire token handler
        IComponents.ComponentInfo memory componentInfo = component.getInitialComponentInfo();
        componentInfo.tokenHandler = TokenHandlerDeployerLib.deployTokenHandler(
            address(getRegistry()),
            address(component), // initially, component is its own wallet
            token, 
            instanceAdmin.authority());
        
        // register component with instance
        instance.getInstanceStore().createComponent(
            componentNftId, 
            componentInfo);

        // link component contract to nft id
        component.linkToRegisteredNftId();

        // authorize
        instanceAdmin.initializeComponentAuthorization(componentAddress, componentType);

        emit LogComponentServiceRegistered(
            instance.getNftId(),
            componentNftId, 
            componentType, 
            componentAddress, 
            token, 
            objectInfo.initialOwner);
    }


    function _checkToken(IInstance instance, address token) 
        internal
        view
    {
        if (! instance.isTokenRegistryDisabled()) {
            // check if provided token is whitelisted and active
            if (!ContractLib.isActiveToken(
                getRegistry().getTokenRegistryAddress(), 
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
        productNftId = getRegistry().getParentNftId(componentNftId);
        info = instanceReader.getFeeInfo(productNftId);
    }


    /// @dev Based on the provided component address required type the component 
    /// and related instance contract this function reverts iff:
    /// - the component parent does not match with the required parent
    /// - the component release does not match with the service release
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
        component = IInstanceLinkedComponent(componentAddress);
        info = component.getInitialInfo();

        // check component parent
        if(info.parentNftId != requiredParent) {
            revert ErrorComponentServiceComponentParentInvalid(componentAddress, requiredParent, info.parentNftId);
        }

        // check component release (must match with service release)
        if(component.getRelease() != getRelease()) {
            revert ErrorComponentServiceComponentReleaseMismatch(componentAddress, getRelease(), component.getRelease());
        }

        // check component has not already been registered
        if (getRegistry().getNftIdForAddress(componentAddress).gtz()) {
            revert ErrorComponentServiceComponentAlreadyRegistered(componentAddress);
        }
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

    function _getComponentServiceStorage() private pure returns (ComponentServiceStorage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := COMPONENT_SERVICE_STORAGE_LOCATION_V3_0
        }
    }

    function _getDomain() internal pure virtual override returns(ObjectType) {
        return COMPONENT();
    }
}