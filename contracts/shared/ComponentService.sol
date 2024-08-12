// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {ComponentServiceHelperLib} from "./ComponentServiceHelperLib.sol";
import {ComponentVerifyingService} from "../shared/ComponentVerifyingService.sol";
import {ContractLib} from "../shared/ContractLib.sol";
import {Fee, FeeLib} from "../type/Fee.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IComponentService} from "./IComponentService.sol";
import {IDistributionComponent} from "../distribution/IDistributionComponent.sol";
import {IInstance} from "../instance/IInstance.sol";
import {IInstanceLinkedComponent} from "./IInstanceLinkedComponent.sol";
import {InstanceAdmin} from "../instance/InstanceAdmin.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {InstanceStore} from "../instance/InstanceStore.sol";
import {IInstanceService} from "../instance/IInstanceService.sol";
import {IRegisterable} from "../shared/IRegisterable.sol";
import {IPoolComponent} from "../pool/IPoolComponent.sol";
import {IProductComponent} from "../product/IProductComponent.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IRegistryService} from "../registry/IRegistryService.sol";
import {KEEP_STATE} from "../type/StateId.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, REGISTRY, BUNDLE, COMPONENT, DISTRIBUTION, DISTRIBUTOR, INSTANCE, ORACLE, POOL, PRODUCT} from "../type/ObjectType.sol";
import {RoleId} from "../type/RoleId.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {TokenHandlerDeployerLib} from "../shared/TokenHandlerDeployerLib.sol";

contract ComponentService is
    ComponentVerifyingService,
    IComponentService
{

    bool private constant INCREASE = true;
    bool private constant DECREASE = false;

    IRegistryService private _registryService;
    IInstanceService private _instanceService;

    modifier onlyComponent(address component) {
        if (!ContractLib.supportsInterface(component, type(IInstanceLinkedComponent).interfaceId)) {
            revert ErrorComponentServiceNotInstanceLinkedComponent(component);
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
            address registryAddress,
            address authority
        ) = abi.decode(data, (address, address));

        _initializeService(registryAddress, authority, owner);

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
        ObjectType componentType = IInstanceLinkedComponent(component).getInitialInfo().objectType;
        if (componentType == POOL()) {
            return _registerPool(component);
        }
        if (componentType == DISTRIBUTION()) {
            return _registerDistribution(component);
        }
        if (componentType == ORACLE()) {
            return _registerOracle(component);
        }

        // fail
        revert ErrorComponentServiceTypeNotSupported(component, componentType);
    }


    function setWallet(address newWallet) external virtual {
        // checks
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

        uint256 currentBalance = info.token.balanceOf(currentWallet);

        // effects
        info.wallet = newWallet;
        instance.getInstanceStore().updateComponent(componentNftId, info, KEEP_STATE());

        emit LogComponentServiceWalletAddressChanged(componentNftId, currentWallet, newWallet);

        // interactions
        info.tokenHandler.addAllowedTarget(newWallet);
        
        // FIXME: transfer tokens to new wallet in case of instance linked component too?
        // if (currentBalance > 0) {
        //     // move tokens from old to new wallet 
        //     emit LogComponentWalletTokensTransferred(currentWallet, newWallet, currentBalance);

        //     if (currentWallet == address(this)) {
        //         // transfer from the component requires an allowance
        //         info.tokenHandler.distributeTokens(currentWallet, newWallet, AmountLib.toAmount(currentBalance));
        //     } else {
        //         info.tokenHandler.collectTokens(currentWallet, newWallet, AmountLib.toAmount(currentBalance));
        //     }
        // }

        // this breaks the cei pattern, but right now i don't see a way how to change this
        info.tokenHandler.removeAllowedTarget(currentWallet);
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
        onlyComponent(productAddress)
        returns (NftId productNftId)
    {
        // register/create component setup
        InstanceAdmin instanceAdmin;
        InstanceStore instanceStore;
        (, instanceAdmin, instanceStore,, productNftId) = _register(
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
        _checkNftType(productNftId, PRODUCT());
        _changeTargetBalance(INCREASE, instanceStore, productNftId, AmountLib.zero(), feeAmount);
    }


    function decreaseProductFees(InstanceStore instanceStore, NftId productNftId, Amount feeAmount)
        external 
        virtual 
        // TODO re-enable once role granting is stable and fixed
        // restricted()
    {
        _checkNftType(productNftId, PRODUCT());
        _changeTargetBalance(DECREASE, instanceStore, productNftId, AmountLib.zero(), feeAmount);
    }

    //-------- distribution -------------------------------------------------//

    /// @dev registers the sending component as a distribution component
    function _registerDistribution(address distributioAddress)
        internal
        virtual
        returns (NftId distributionNftId)
    {
        // register/create component info
        InstanceReader instanceReader;
        InstanceAdmin instanceAdmin;
        InstanceStore instanceStore;
        NftId productNftId;
        (instanceReader, instanceAdmin, instanceStore, productNftId, distributionNftId) = _register(
            distributioAddress,
            DISTRIBUTION());

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
        instanceAdmin.initializeComponentAuthorization(
            IInstanceLinkedComponent(distributioAddress));

        IDistributionComponent distribution = IDistributionComponent(distributioAddress);
        IComponents.ComponentInfo memory productComponentInfo = instanceReader.getComponentInfo(productNftId);
        productComponentInfo.tokenHandler.addAllowedTarget(distribution.getWallet());
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
        _checkNftType(distributionNftId, DISTRIBUTION());
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
        _checkNftType(distributionNftId, DISTRIBUTION());
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
        _checkNftType(distributorNftId, DISTRIBUTOR());
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
        _checkNftType(distributorNftId, DISTRIBUTOR());
        _changeTargetBalance(DECREASE, instanceStore, distributorNftId, amount, feeAmount);
    }

    //-------- oracle -------------------------------------------------------//

    function _registerOracle(address oracleAddress)
        internal
        virtual
        returns (NftId oracleNftId)
    {
        // register/create component setup
        InstanceReader instanceReader;
        InstanceAdmin instanceAdmin;
        InstanceStore instanceStore;
        NftId productNftId;

        (instanceReader, instanceAdmin, instanceStore, productNftId, oracleNftId) =_register(
            oracleAddress,
            ORACLE());

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
        instanceAdmin.initializeComponentAuthorization(
            IInstanceLinkedComponent(oracleAddress));
    }

    //-------- pool ---------------------------------------------------------//

    function _registerPool(address poolAddress)
        internal
        virtual
        returns (NftId poolNftId)
    {
        // register/create component setup
        InstanceReader instanceReader;
        InstanceAdmin instanceAdmin;
        InstanceStore instanceStore;
        NftId productNftId;

        (instanceReader, instanceAdmin, instanceStore, productNftId, poolNftId) =_register(
            poolAddress,
            POOL());

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

        // authorize
        instanceAdmin.initializeComponentAuthorization(pool);

        IComponents.ComponentInfo memory productComponentInfo = instanceReader.getComponentInfo(productNftId);
        productComponentInfo.tokenHandler.addAllowedTarget(pool.getWallet());
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
        _checkNftType(poolNftId, POOL());
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
        _checkNftType(poolNftId, POOL());
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
        _checkNftType(bundleNftId, BUNDLE());
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
        _checkNftType(bundleNftId, BUNDLE());
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

    /// @dev Registers the component represented by the provided address.
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
        ) = ComponentServiceHelperLib.getAndVerifyRegisterableComponent(
            getRegistry(),
            componentAddress,
            requiredType);

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
        IComponents.ComponentInfo memory componentInfo = component.getInitialComponentInfo();
        IERC20Metadata token = componentInfo.token;
        componentInfo.tokenHandler = TokenHandlerDeployerLib.deployTokenHandler(
            address(token), 
            address(instanceAdmin.authority()),
            componentInfo.wallet);

        // register component with instance
        instanceStore.createComponent(
            componentNftId, 
            componentInfo);

        // link component contract to nft id
        component.linkToRegisteredNftId();

        emit LogComponentServiceRegistered(instanceNftId, componentNftId, requiredType, address(component), address(token), initialOwner);
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

    function _getDomain() internal pure virtual override returns(ObjectType) {
        return COMPONENT();
    }
}