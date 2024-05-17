// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "../type/Amount.sol";
import {ComponentVerifyingService} from "../shared/ComponentVerifyingService.sol";
import {Fee, FeeLib} from "../type/Fee.sol";
import {IInstanceLinkedComponent} from "./IInstanceLinkedComponent.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IRegistryService} from "../registry/IRegistryService.sol";
import {IInstance} from "../instance/IInstance.sol";
import {IAccess} from "../instance/module/IAccess.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, REGISTRY, COMPONENT, DISTRIBUTION, INSTANCE, POOL, PRODUCT} from "../type/ObjectType.sol";
import {RoleId, DISTRIBUTION_OWNER_ROLE, POOL_OWNER_ROLE, PRODUCT_OWNER_ROLE, POLICY_SERVICE_ROLE, PRODUCT_SERVICE_ROLE} from "../type/RoleId.sol";
import {KEEP_STATE} from "../type/StateId.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IComponentService} from "./IComponentService.sol";
import {IDistributionComponent} from "../distribution/IDistributionComponent.sol";
import {IInstanceService} from "../instance/IInstanceService.sol";
import {IPoolComponent} from "../pool/IPoolComponent.sol";
import {IProductComponent} from "../product/IProductComponent.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {InstanceStore} from "../instance/InstanceStore.sol";
import {TokenHandler} from "./TokenHandler.sol";

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
        // TODO check this, might no longer be the way, refactor if necessary
        address registryAddress;
        address initialOwner;
        (registryAddress, initialOwner) = abi.decode(data, (address, address));

        initializeService(registryAddress, address(0), owner);

        _registryService = IRegistryService(_getServiceAddress(REGISTRY()));
        _instanceService = IInstanceService(_getServiceAddress(INSTANCE()));

        registerInterface(type(IComponentService).interfaceId);
    }


    function getDomain() public pure virtual override returns(ObjectType) {
        return COMPONENT();
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


    //-------- product ------------------------------------------------------//

    function registerProduct()
        external
        virtual
    {
        address contractAddress = msg.sender;
        RoleId[] memory roles = new RoleId[](1);
        bytes4[][] memory selectors = new bytes4[][](1);

        // authorizaion for distribution owner
        roles[0] = PRODUCT_OWNER_ROLE();
        selectors[0] = _createSelectors(IProductComponent.setFees.selector);

        // register/create component setup
        (
            InstanceReader instanceReader, 
            InstanceStore instanceStore, 
            NftId productNftId
        ) = _register(
            contractAddress,
            PRODUCT(),
            PRODUCT_OWNER_ROLE(),
            roles,
            selectors);

        // create product info
        IComponents.ProductInfo memory productInfo = IProductComponent(contractAddress).getInitialProductInfo();
        instanceStore.createProduct(productNftId, productInfo);

        // link distribution and pool to product
        _linkToProduct(instanceReader, instanceStore, productInfo.distributionNftId, productNftId);
        _linkToProduct(instanceReader, instanceStore, productInfo.poolNftId, productNftId);
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
    function registerDistribution()
        external
        virtual
    {
        address contractAddress = msg.sender;
        RoleId[] memory roles = new RoleId[](2);
        bytes4[][] memory selectors = new bytes4[][](2);

        // authorizaion for distribution owner
        roles[0] = DISTRIBUTION_OWNER_ROLE();
        selectors[0] = _createSelectors(IDistributionComponent.setFees.selector);

        // authorizaion for product service
        roles[1] = PRODUCT_SERVICE_ROLE();
        selectors[1] = _createSelectors(IDistributionComponent.processRenewal.selector);

        // register/create component info
        _register(
            contractAddress,
            DISTRIBUTION(),
            DISTRIBUTION_OWNER_ROLE(),
            roles,
            selectors);
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

    //-------- pool ---------------------------------------------------------//

    /// @dev registers the sending component as a distribution component
    function registerPool()
        external
        virtual
    {
        address contractAddress = msg.sender;
        RoleId[] memory roles = new RoleId[](2);
        bytes4[][] memory selectors = new bytes4[][](2);

        // authorizaion for distribution owner
        roles[0] = POOL_OWNER_ROLE();
        selectors[0] = _createSelectors(IPoolComponent.setFees.selector);

        // authorizaion for product service
        roles[1] = POLICY_SERVICE_ROLE();
        selectors[1] = _createSelectors(IPoolComponent.verifyApplication.selector);

        // register/create component setup
        (
            , // instance reader
            InstanceStore instanceStore, 
            NftId componentNftId
        ) = _register(
            contractAddress,
            POOL(),
            POOL_OWNER_ROLE(),
            roles,
            selectors);            

        // create info
        instanceStore.createPool(
            componentNftId, 
            IPoolComponent(contractAddress).getInitialPoolInfo());
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
        ObjectType requiredType, // required type for component for registration
        RoleId requiredRole, // role required for comonent owner for registration
        RoleId[] memory roles, // roles with write access to component
        bytes4[][] memory selectors // authorized functions per role with write access
    )
        internal
        virtual
        returns (
            InstanceReader instanceReader, 
            InstanceStore instanceStore, 
            NftId componentNftId
        )
    {
        (
            IInstance instance,
            IInstanceLinkedComponent component,
            address owner
        ) = _getAndVerifyRegisterableComponent(
            componentAddress,
            requiredType,
            requiredRole);

        // register component with registry
        componentNftId = _registryService.registerComponent(
            component, 
            requiredType, 
            owner).nftId;

        component.linkToRegisteredNftId();

        // save amended component info with instance
        instanceReader = instance.getInstanceReader();
        instanceStore = instance.getInstanceStore();

        IComponents.ComponentInfo memory componentInfo = component.getComponentInfo();
        componentInfo.tokenHandler = new TokenHandler(address(componentInfo.token));
        instanceStore.createComponent(component.getNftId(), componentInfo);

        // configure instance authorization
        _instanceService.createComponentTarget(
            instance.getNftId(), 
            componentAddress, 
            component.getName(), 
            selectors, 
            roles);
    }


    /// @dev link the component info corresponding to the componentNftId to the provided productNftId
    function _linkToProduct(
        InstanceReader instanceReader, 
        InstanceStore instanceStore,
        NftId componentNftId,
        NftId productNftId
    )
        internal
    {
        // only link components that are registered
        if(componentNftId.eqz()) {
            return;
        }
    
        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(componentNftId);
        componentInfo.productNftId = productNftId;
        instanceStore.updateComponent(componentNftId, componentInfo, KEEP_STATE());
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


    function _createSelectors(bytes4 selector) internal view returns (bytes4[] memory selectors) {
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
        productNftId = instanceReader.getComponentInfo(componentNftId).productNftId;
        info = instanceReader.getProductInfo(productNftId);
    }


    /// @dev based on the provided component address required type and role returns the component and related instance contract
    /// the function reverts iff:
    /// - the component has already been registered
    /// - the component contract does not support IInstanceLinkedComponent
    /// - the component type does not match with the required type
    /// - the initial component owner misses the required role (with the instance access manager)
    function _getAndVerifyRegisterableComponent(
        address componentAddress,
        ObjectType requiredType,
        RoleId requiredRole
    )
        internal
        // view
        returns (
            IInstance instance,
            IInstanceLinkedComponent component,
            address owner
        )
    {
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
        if (getRegistry().getNftId(componentAddress).gtz()) {
            revert ErrorComponentServiceAlreadyRegistered(componentAddress);
        }

        // check instance has assigned required role to inital owner
        instance = _getInstance(info.parentNftId);
        owner = info.initialOwner;

        (bool hasRole,) = instance.getInstanceAccessManager().hasRole(requiredRole.toInt(), owner);
        if(!hasRole) {
            revert ErrorComponentServiceExpectedRoleMissing(info.parentNftId, requiredRole, owner);
        }
    }
}