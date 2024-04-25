// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount} from "../type/Amount.sol";
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
        selectors[0] = new bytes4[](1);
        selectors[0][0] = IProductComponent.setFees.selector;

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
            emit LogComponentServiceUpdateFee(
                productNftId, 
                "ProductFee",
                productInfo.productFee.fractionalFee,
                productInfo.productFee.fixedFee,
                productFee.fractionalFee,
                productFee.fixedFee
            );

            productInfo.productFee = productFee;
            feesChanged = true;
        }

        // update processing fee if required
        if(!FeeLib.eq(productInfo.processingFee, processingFee)) {
            emit LogComponentServiceUpdateFee(
                productNftId, 
                "ProcessingFee",
                productInfo.processingFee.fractionalFee,
                productInfo.processingFee.fixedFee,
                processingFee.fractionalFee,
                processingFee.fixedFee
            );

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
        if(feeAmount.gtz()) { instanceStore.increaseFees(productNftId, feeAmount); }
    }

    function decreaseProductFees(InstanceStore instanceStore, NftId productNftId, Amount feeAmount) external virtual restricted() {}

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
        selectors[0] = new bytes4[](1);
        selectors[0][0] = IDistributionComponent.setFees.selector;

        // authorizaion for product service
        roles[1] = PRODUCT_SERVICE_ROLE();
        selectors[1] = new bytes4[](1);
        selectors[1][0] = IDistributionComponent.processRenewal.selector;

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
        InstanceReader instanceReader = instance.getInstanceReader();
        NftId productNftId = instanceReader.getComponentInfo(distributionNftId).productNftId;
        IComponents.ProductInfo memory productInfo = instance.getInstanceReader().getProductInfo(productNftId);
        bool feesChanged = false;

        // update distributino fee if required
        if(!FeeLib.eq(productInfo.distributionFee, distributionFee)) {
            emit LogComponentServiceUpdateFee(
                productNftId, 
                "DistributionFee",
                productInfo.distributionFee.fractionalFee,
                productInfo.distributionFee.fixedFee,
                distributionFee.fractionalFee,
                distributionFee.fixedFee
            );

            productInfo.distributionFee = distributionFee;
            feesChanged = true;
        }

        // update min distribution owner fee if required
        if(!FeeLib.eq(productInfo.minDistributionOwnerFee, minDistributionOwnerFee)) {
            emit LogComponentServiceUpdateFee(
                productNftId, 
                "MinDistributionOwnerFee",
                productInfo.minDistributionOwnerFee.fractionalFee,
                productInfo.minDistributionOwnerFee.fixedFee,
                minDistributionOwnerFee.fractionalFee,
                minDistributionOwnerFee.fixedFee
            );

            productInfo.minDistributionOwnerFee = minDistributionOwnerFee;
            feesChanged = true;
        }
        
        if(feesChanged) {
            instance.getInstanceStore().updateProduct(productNftId, productInfo, KEEP_STATE());
            emit LogComponentServiceDistributionFeesUpdated(distributionNftId);
        }
    }


    function increaseDistributionFees(
        InstanceStore instanceStore, 
        NftId distributionNftId, 
        Amount feeAmount
    )
        external
        virtual
        // TODO re-enable once role granting is stable and fixed
        // restricted()
    {
        if(feeAmount.gtz()) { instanceStore.increaseFees(distributionNftId, feeAmount); }
    }


    function decreaseDistributionFees(
        InstanceStore instanceStore, 
        NftId distributionNftId, 
        Amount feeAmount
    )
        external
        virtual
        // TODO re-enable once role granting is stable and fixed
        // restricted()
    {

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
        selectors[0] = new bytes4[](1);
        selectors[0][0] = IPoolComponent.setFees.selector;

        // authorizaion for product service
        roles[1] = POLICY_SERVICE_ROLE();
        selectors[1] = new bytes4[](1);
        selectors[1][0] = IPoolComponent.verifyApplication.selector;

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
        InstanceReader instanceReader = instance.getInstanceReader();
        NftId productNftId = instanceReader.getComponentInfo(poolNftId).productNftId;
        IComponents.ProductInfo memory productInfo = instanceReader.getProductInfo(productNftId);
        bool feesChanged = false;

        // update pool fee if required
        if(!FeeLib.eq(productInfo.poolFee, poolFee)) {
            emit LogComponentServiceUpdateFee(
                productNftId, 
                "PoolFee",
                productInfo.poolFee.fractionalFee,
                productInfo.poolFee.fixedFee,
                poolFee.fractionalFee,
                poolFee.fixedFee
            );

            productInfo.poolFee = poolFee;
            feesChanged = true;
        }

        // update staking fee if required
        if(!FeeLib.eq(productInfo.stakingFee, stakingFee)) {
            emit LogComponentServiceUpdateFee(
                productNftId, 
                "StakingFee",
                productInfo.stakingFee.fractionalFee,
                productInfo.stakingFee.fixedFee,
                stakingFee.fractionalFee,
                stakingFee.fixedFee
            );

            productInfo.stakingFee = stakingFee;
            feesChanged = true;
        }

        // update performance fee if required
        if(!FeeLib.eq(productInfo.performanceFee, performanceFee)) {
            emit LogComponentServiceUpdateFee(
                productNftId, 
                "PerformanceFee",
                productInfo.performanceFee.fractionalFee,
                productInfo.performanceFee.fixedFee,
                performanceFee.fractionalFee,
                performanceFee.fixedFee
            );

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
        if(amount.gtz()) { instanceStore.increaseBalance(poolNftId, amount); }
        if(feeAmount.gtz()) { instanceStore.increaseFees(poolNftId, feeAmount); }
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
        if(amount.gtz()) { instanceStore.decreaseBalance(poolNftId, amount); }
        if(feeAmount.gtz()) { instanceStore.decreaseFees(poolNftId, feeAmount); }
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
        if(amount.gtz()) { instanceStore.increaseBalance(bundleNftId, amount); }
        if(feeAmount.gtz()) { instanceStore.increaseFees(bundleNftId, feeAmount); }
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
        if(amount.gtz()) { instanceStore.decreaseBalance(bundleNftId, amount); }
        if(feeAmount.gtz()) { instanceStore.decreaseFees(bundleNftId, feeAmount); }
    }


    //-------- internal functions ------------------------------------------//

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
        // check component has not already been registered
        if (getRegistry().getNftId(componentAddress).gtz()) {
            revert ErrorComponentServiceAlreadyRegistered(componentAddress);
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

        // check instance has assigned required role to inital owner
        instance = _getInstance(info.parentNftId);
        owner = info.initialOwner;

        if(!instance.getInstanceAccessManager().hasRole(requiredRole, owner)) {
            revert ErrorComponentServiceExpectedRoleMissing(info.parentNftId, requiredRole, owner);
        }
    }
}