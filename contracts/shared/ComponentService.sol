// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "../type/Amount.sol";
import {ComponentVerifyingService} from "../shared/ComponentVerifyingService.sol";
import {Fee, FeeLib} from "../type/Fee.sol";
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
import {IRegistry} from "../registry/IRegistry.sol";
import {IRegistryService} from "../registry/IRegistryService.sol";
import {KEEP_STATE} from "../type/StateId.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, REGISTRY, COMPONENT, DISTRIBUTION, INSTANCE, ORACLE, POOL, PRODUCT} from "../type/ObjectType.sol";
import {RoleId} from "../type/RoleId.sol";
import {TokenHandlerDeployerLib} from "../shared/TokenHandlerDeployerLib.sol";

contract ComponentService is
    ComponentVerifyingService,
    IComponentService
{
    error ErrorComponentServiceAlreadyRegistered(address component);
    error ErrorComponentServiceNotComponent(address component);
    error ErrorComponentServiceInvalidType(address component, ObjectType requiredType, ObjectType componentType);
    error ErrorComponentServiceSenderNotOwner(address component, address initialOwner, address sender);
    error ErrorComponentServiceExpectedRoleMissing(NftId instanceNftId, RoleId requiredRole, address sender);
    error ErrorComponentServiceComponentLocked(address component);
    error ErrorComponentServiceSenderNotService(address sender);
    error ErrorComponentServiceComponentTypeInvalid(address component, ObjectType expectedType, ObjectType foundType);

    bool private constant INCREASE = true;
    bool private constant DECREASE = false;

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
            address registryAddress,
            address authority
        ) = abi.decode(data, (address, address));

        _initializeService(registryAddress, authority, owner);

        _registryService = IRegistryService(_getServiceAddress(REGISTRY()));
        _instanceService = IInstanceService(_getServiceAddress(INSTANCE()));

        _registerInterface(type(IComponentService).interfaceId);
    }

    //-------- component ----------------------------------------------------//

    function setWallet(address newWallet) external virtual {
        (NftId componentNftId,, IInstance instance) = _getAndVerifyActiveComponent(COMPONENT());
        IComponents.ComponentInfo memory info = instance.getInstanceReader().getComponentInfo(componentNftId);
        address currentWallet = info.wallet;

        if (newWallet == address(0)) {
            revert ErrorComponentServiceNewWalletAddressZero();
        }

        if (currentWallet == address(0)) {
            revert ErrorComponentServiceWalletAddressZero();
        }

        if (newWallet == currentWallet) {
            revert ErrorComponentServiceWalletAddressIsSameAsCurrent();
        }

        info.wallet = newWallet;
        instance.getInstanceStore().updateComponent(componentNftId, info, KEEP_STATE());
        emit LogComponentServiceWalletAddressChanged(componentNftId, currentWallet, newWallet);
    }

    // TODO implement
    function lock() external virtual {}

    // TODO implement
    function unlock() external virtual {}

    function withdrawFees(Amount amount)
        external
        virtual
        returns (Amount withdrawnAmount)
    {
        (NftId componentNftId,, IInstance instance) = _getAndVerifyActiveComponent(COMPONENT());
        IComponents.ComponentInfo memory info = instance.getInstanceReader().getComponentInfo(componentNftId);
        address componentWallet = info.wallet;

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
        _changeTargetBalance(DECREASE, instance.getInstanceStore(), componentNftId, AmountLib.zero(), withdrawnAmount);
        
        // transfer amount to component owner
        address componentOwner = getRegistry().ownerOf(componentNftId);
        emit LogComponentServiceComponentFeesWithdrawn(componentNftId, componentOwner, address(info.token), withdrawnAmount);
        info.tokenHandler.distributeTokens(componentWallet, componentOwner, withdrawnAmount);
    }


    //-------- product ------------------------------------------------------//

    function registerProduct(address productAddress)
        external
        virtual
        returns (NftId productNftId)
    {
        // register/create component setup
        InstanceAdmin instanceAdmin;
        InstanceStore instanceStore;
        (, instanceAdmin, instanceStore, productNftId) = _register(
            productAddress,
            PRODUCT());

        // get product
        IProductComponent product = IProductComponent(productAddress);

        // create info
        instanceStore.createProduct(
            productNftId, 
            product.getInitialProductInfo());

        // authorize
        instanceAdmin.initializeComponentAuthorization(product);
    }


    function setProductFees(
        Fee memory productFee, // product fee on net premium
        Fee memory processingFee // product fee on payout amounts        
    )
        external
        virtual
    {
        (NftId productNftId,, IInstance instance) = _getAndVerifyActiveComponent(PRODUCT());
        IComponents.ProductInfo memory productInfo = instance.getInstanceReader().getProductInfo(productNftId);
        bool feesChanged = false;

        // update product fee if required
        if(!FeeLib.eq(productInfo.productFee, productFee)) {
            _logUpdateFee(productNftId, "ProductFee", productInfo.productFee, productFee);
            productInfo.productFee = productFee;
            feesChanged = true;
        }

        // update processing fee if required
        if(!FeeLib.eq(productInfo.processingFee, processingFee)) {
            _logUpdateFee(productNftId, "ProcessingFee", productInfo.processingFee, processingFee);
            productInfo.processingFee = processingFee;
            feesChanged = true;
        }
        
        if(feesChanged) {
            instance.getInstanceStore().updateProduct(productNftId, productInfo, KEEP_STATE());
            emit LogComponentServiceProductFeesUpdated(productNftId);
        }
    }

    function increaseProductFees(
        InstanceStore instanceStore,
        NftId productNftId, 
        Amount feeAmount
    ) 
        external 
        virtual 
        // TODO re-enable once role granting is stable and fixed
        // restricted()
    {
        _changeTargetBalance(INCREASE, instanceStore, productNftId, AmountLib.zero(), feeAmount);
    }


    function decreaseProductFees(InstanceStore instanceStore, NftId productNftId, Amount feeAmount)
        external 
        virtual 
        // TODO re-enable once role granting is stable and fixed
        // restricted()
    {
        _changeTargetBalance(DECREASE, instanceStore, productNftId, AmountLib.zero(), feeAmount);
    }

    //-------- distribution -------------------------------------------------//

    /// @dev registers the sending component as a distribution component
    function registerDistribution(address distributioAddress)
        external
        virtual
        returns (NftId distributionNftId)
    {
        // register/create component info
        InstanceAdmin instanceAdmin;
        (, instanceAdmin,, distributionNftId) =_register(
            distributioAddress,
            DISTRIBUTION());

        // authorize
        instanceAdmin.initializeComponentAuthorization(
            IInstanceLinkedComponent(distributioAddress));
    }


    function setDistributionFees(
        Fee memory distributionFee, // distribution fee for sales that do not include commissions
        Fee memory minDistributionOwnerFee // min fee required by distribution owner (not including commissions for distributors)
    )
        external
        virtual
    {
        (NftId distributionNftId,, IInstance instance) = _getAndVerifyActiveComponent(DISTRIBUTION());
        (NftId productNftId, IComponents.ProductInfo memory productInfo) = _getLinkedProductInfo(
            instance.getInstanceReader(), distributionNftId);
        bool feesChanged = false;

        // update distributino fee if required
        if(!FeeLib.eq(productInfo.distributionFee, distributionFee)) {
            _logUpdateFee(productNftId, "DistributionFee", productInfo.distributionFee, distributionFee);
            productInfo.distributionFee = distributionFee;
            feesChanged = true;
        }

        // update min distribution owner fee if required
        if(!FeeLib.eq(productInfo.minDistributionOwnerFee, minDistributionOwnerFee)) {
            _logUpdateFee(productNftId, "MinDistributionOwnerFee", productInfo.minDistributionOwnerFee, minDistributionOwnerFee);
            productInfo.minDistributionOwnerFee = minDistributionOwnerFee;
            feesChanged = true;
        }
        
        if(feesChanged) {
            instance.getInstanceStore().updateProduct(productNftId, productInfo, KEEP_STATE());
            emit LogComponentServiceDistributionFeesUpdated(distributionNftId);
        }
    }

    function increaseDistributionBalance(
        InstanceStore instanceStore, 
        NftId distributionNftId, 
        Amount amount,
        Amount feeAmount
    )
        external
        virtual
        // TODO re-enable once role granting is stable and fixed
        // restricted()
    {
        _changeTargetBalance(INCREASE, instanceStore, distributionNftId, amount, feeAmount);
    }


    function decreaseDistributionBalance(
        InstanceStore instanceStore, 
        NftId distributionNftId, 
        Amount amount,
        Amount feeAmount
    )
        external
        virtual
        // TODO re-enable once role granting is stable and fixed
        // restricted()
    {
        _changeTargetBalance(DECREASE, instanceStore, distributionNftId, amount, feeAmount);
    }

    //-------- distributor -------------------------------------------------------//

    function increaseDistributorBalance(
        InstanceStore instanceStore, 
        NftId distributorNftId, 
        Amount amount, 
        Amount feeAmount
    )
        external
        virtual
        // TODO re-enable once role granting is stable and fixed
        // restricted()
    {
        _changeTargetBalance(INCREASE, instanceStore, distributorNftId, amount, feeAmount);
    }

    function decreaseDistributorBalance(
        InstanceStore instanceStore, 
        NftId distributorNftId, 
        Amount amount, 
        Amount feeAmount
    )
        external
        virtual
        // TODO re-enable once role granting is stable and fixed
        // restricted()
    {
        _changeTargetBalance(DECREASE, instanceStore, distributorNftId, amount, feeAmount);
    }

    //-------- oracle -------------------------------------------------------//

    function registerOracle(address oracleAddress)
        external
        virtual
        returns (NftId oracleNftId)
    {
        // register/create component setup
        InstanceAdmin instanceAdmin;
        (, instanceAdmin,, oracleNftId) = _register(
            oracleAddress,
            ORACLE());

        // authorize
        instanceAdmin.initializeComponentAuthorization(
            IInstanceLinkedComponent(oracleAddress));
    }

    //-------- pool ---------------------------------------------------------//

    function registerPool(address poolAddress)
        external
        virtual
        returns (NftId poolNftId)
    {
        // register/create component setup
        InstanceReader instanceReader;
        InstanceAdmin instanceAdmin;
        InstanceStore instanceStore;
        (instanceReader, instanceAdmin, instanceStore, poolNftId) = _register(
            poolAddress,
            POOL());            

        // get pool
        IPoolComponent pool = IPoolComponent(poolAddress);

        // create info
        instanceStore.createPool(
            poolNftId, 
            pool.getInitialPoolInfo());

        // set pool in product info
        NftId productNftId = getRegistry().getObjectInfo(poolNftId).parentNftId;
        IComponents.ProductInfo memory productInfo = instanceReader.getProductInfo(productNftId);
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
        virtual
    {
        (NftId poolNftId,, IInstance instance) = _getAndVerifyActiveComponent(POOL());
        (NftId productNftId, IComponents.ProductInfo memory productInfo) = _getLinkedProductInfo(
            instance.getInstanceReader(), poolNftId);
        bool feesChanged = false;

        // update pool fee if required
        if(!FeeLib.eq(productInfo.poolFee, poolFee)) {
            _logUpdateFee(productNftId, "PoolFee", productInfo.poolFee, poolFee);
            productInfo.poolFee = poolFee;
            feesChanged = true;
        }

        // update staking fee if required
        if(!FeeLib.eq(productInfo.stakingFee, stakingFee)) {
            _logUpdateFee(productNftId, "StakingFee", productInfo.stakingFee, stakingFee);
            productInfo.stakingFee = stakingFee;
            feesChanged = true;
        }

        // update performance fee if required
        if(!FeeLib.eq(productInfo.performanceFee, performanceFee)) {
            _logUpdateFee(productNftId, "PerformanceFee", productInfo.performanceFee, performanceFee);
            productInfo.performanceFee = performanceFee;
            feesChanged = true;
        }
        
        if(feesChanged) {
            instance.getInstanceStore().updateProduct(productNftId, productInfo, KEEP_STATE());
            emit LogComponentServicePoolFeesUpdated(poolNftId);
        }
    }

    function increasePoolBalance(
        InstanceStore instanceStore, 
        NftId poolNftId, 
        Amount amount, 
        Amount feeAmount
    )
        public 
        virtual 
        // TODO re-enable once role granting is stable and fixed
        // restricted()
    {
        _changeTargetBalance(INCREASE, instanceStore, poolNftId, amount, feeAmount);
    }

    function decreasePoolBalance(
        InstanceStore instanceStore, 
        NftId poolNftId, 
        Amount amount, 
        Amount feeAmount
    )
        public 
        virtual 
        // TODO re-enable once role granting is stable and fixed
        // restricted()
    {
        _changeTargetBalance(DECREASE, instanceStore, poolNftId, amount, feeAmount);
    }

    //-------- bundle -------------------------------------------------------//

    function increaseBundleBalance(
        InstanceStore instanceStore, 
        NftId bundleNftId, 
        Amount amount, 
        Amount feeAmount
    )
        external
        virtual
        // TODO re-enable once role granting is stable and fixed
        // restricted()
    {
        _changeTargetBalance(INCREASE, instanceStore, bundleNftId, amount, feeAmount);
    }

    function decreaseBundleBalance(
        InstanceStore instanceStore, 
        NftId bundleNftId, 
        Amount amount, 
        Amount feeAmount
    )
        external
        virtual
        // TODO re-enable once role granting is stable and fixed
        // restricted()
    {
        _changeTargetBalance(DECREASE, instanceStore, bundleNftId, amount, feeAmount);
    }


    //-------- internal functions ------------------------------------------//

    function _changeTargetBalance(
        bool increase,
        InstanceStore instanceStore, 
        NftId targetNftId, 
        Amount amount, 
        Amount feeAmount
    )
        internal
        virtual
    {
        Amount totalAmount = amount + feeAmount;

        if(increase) {
            if(totalAmount.gtz()) { instanceStore.increaseBalance(targetNftId, totalAmount); }
            if(feeAmount.gtz()) { instanceStore.increaseFees(targetNftId, feeAmount); }
        } else {
            if(totalAmount.gtz()) { instanceStore.decreaseBalance(targetNftId, totalAmount); }
            if(feeAmount.gtz()) { instanceStore.decreaseFees(targetNftId, feeAmount); }
        }
    }

    /// @dev registers the component represented by the provided address
    function _register(
        address componentAddress, // address of component to register
        ObjectType requiredType // required type for component for registration
    )
        internal
        virtual
        returns (
            InstanceReader instanceReader, 
            InstanceAdmin instanceAdmin, 
            InstanceStore instanceStore, 
            NftId componentNftId
        )
    {
        (
            NftId instanceNftId,
            IInstance instance,
            IInstanceLinkedComponent component,
            address initialOwner
        ) = _getAndVerifyRegisterableComponent(
            componentAddress,
            requiredType);

        // register with registry
        if (requiredType == PRODUCT()) {
            componentNftId = _registryService.registerProduct(
                component, initialOwner).nftId;
        } else {
            componentNftId = _registryService.registerProductLinkedComponent(
                component, requiredType, initialOwner).nftId;
        }

        component.linkToRegisteredNftId();

        // save amended component info with instance
        instanceReader = instance.getInstanceReader();
        instanceAdmin = instance.getInstanceAdmin();
        instanceStore = instance.getInstanceStore();

        // deploy and wire token handler
        IComponents.ComponentInfo memory componentInfo = component.getInitialComponentInfo();
        address tokenAddress = address(componentInfo.token);
        componentInfo.tokenHandler = TokenHandlerDeployerLib.deployTokenHandler(
            tokenAddress, 
            address(instance.getInstanceAdmin().authority()));

        // register component with instance
        instanceStore.createComponent(
            component.getNftId(), 
            componentInfo);

        emit LogComponentServiceRegistered(instanceNftId, componentNftId, requiredType, address(component), tokenAddress, initialOwner);
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


    function _createSelectors(bytes4 selector) internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](1);
        selectors[0] = selector;
    }


    function _getLinkedProductInfo(
        InstanceReader instanceReader, 
        NftId componentNftId
    )
        internal
        view 
        returns(
            NftId productNftId, 
            IComponents.ProductInfo memory info
        )
    {
        productNftId = _getProductNftId(componentNftId);
        info = instanceReader.getProductInfo(productNftId);
    }


    /// @dev Based on the provided component address required type the component 
    /// and related instance contract this function reverts iff:
    /// - the sender is not registered
    /// - the component contract does not support IInstanceLinkedComponent
    /// - the component type does not match with the required type
    /// - the component has already been registered
    function _getAndVerifyRegisterableComponent(
        address componentAddress,
        ObjectType requiredType
    )
        internal
        view
        returns (
            NftId instanceNftId,
            IInstance instance,
            IInstanceLinkedComponent component,
            address initialOwner
        )
    {
        // check sender is registered
        IRegistry.ObjectInfo memory senderInfo = getRegistry().getObjectInfo(msg.sender);
        if (senderInfo.nftId.eqz()) {
            revert ErrorComponentServiceSenderNotRegistered(msg.sender);
        }

        // check this is a component
        component = IInstanceLinkedComponent(componentAddress);
        if(!component.supportsInterface(type(IInstanceLinkedComponent).interfaceId)) {
            revert ErrorComponentServiceNotComponent(componentAddress);
        }

        // check component is of required type
        IRegistry.ObjectInfo memory info = component.getInitialInfo();
        if(info.objectType != requiredType) {
            revert ErrorComponentServiceInvalidType(componentAddress, requiredType, info.objectType);
        }

        // check component has not already been registered
        if (getRegistry().getNftIdForAddress(componentAddress).gtz()) {
            revert ErrorComponentServiceAlreadyRegistered(componentAddress);
        }

        // check component parent nft id matches with sender nft id
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
        instance = _getInstance(instanceNftId);
    }


    function _getDomain() internal pure virtual override returns(ObjectType) {
        return COMPONENT();
    }
}