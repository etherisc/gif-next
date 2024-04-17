// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {RoleId, PUBLIC_ROLE, POLICY_SERVICE_ROLE, APPLICATION_SERVICE_ROLE, CLAIM_SERVICE_ROLE, PRODUCT_SERVICE_ROLE, POOL_SERVICE_ROLE, BUNDLE_SERVICE_ROLE, PRICING_SERVICE_ROLE, DISTRIBUTION_SERVICE_ROLE, INSTANCE_SERVICE_ROLE, REGISTRY_SERVICE_ROLE, PRODUCT_OWNER_ROLE, POOL_OWNER_ROLE, ORACLE_OWNER_ROLE, STAKING_SERVICE_ROLE, CAN_CREATE_GIF_TARGET_ROLE} from "../../contracts/type/RoleId.sol";
import {ObjectType, REGISTRY, SERVICE, PRODUCT, ORACLE, POOL, INSTANCE, DISTRIBUTION, DISTRIBUTOR, APPLICATION, POLICY, CLAIM, BUNDLE, STAKE, PRICE} from "../../contracts/type/ObjectType.sol";
import {StateId, ACTIVE, PAUSED} from "../../contracts/type/StateId.sol";
import {NftId, NftIdLib, zeroNftId} from "../../contracts/type/NftId.sol";
import {Fee, FeeLib} from "../../contracts/type/Fee.sol";
import {Version, VersionPart, VersionLib} from "../../contracts/type/Version.sol";

import {IVersionable} from "../../contracts/shared/IVersionable.sol";
import {Versionable} from "../../contracts/shared/Versionable.sol";
import {IRegisterable} from "../../contracts/shared/IRegisterable.sol";
import {Registerable} from "../../contracts/shared/Registerable.sol";
import {Service} from "../../contracts/shared/Service.sol";
import {IService} from "../../contracts/shared/IService.sol";
import {UpgradableProxyWithAdmin} from "../../contracts/shared/UpgradableProxyWithAdmin.sol";
import {AccessManagerUpgradeableInitializeable} from "../../contracts/shared/AccessManagerUpgradeableInitializeable.sol";


import {PolicyServiceManager} from "../../contracts/product/PolicyServiceManager.sol";
import {PolicyService} from "../../contracts/product/PolicyService.sol";

import {ApplicationServiceManager} from "../../contracts/product/ApplicationServiceManager.sol";
import {ApplicationService} from "../../contracts/product/ApplicationService.sol";

import {ClaimService} from "../../contracts/product/ClaimService.sol";
import {ClaimServiceManager} from "../../contracts/product/ClaimServiceManager.sol";

import {ProductService} from "../../contracts/product/ProductService.sol";
import {ProductServiceManager} from "../../contracts/product/ProductServiceManager.sol";

import {PoolService} from "../../contracts/pool/PoolService.sol";
import {PoolServiceManager} from "../../contracts/pool/PoolServiceManager.sol";

import {BundleService} from "../../contracts/pool/BundleService.sol";
import {BundleServiceManager} from "../../contracts/pool/BundleServiceManager.sol";

import {DistributionService} from "../../contracts/distribution/DistributionService.sol";
import {DistributionServiceManager} from "../../contracts/distribution/DistributionServiceManager.sol";

import {InstanceServiceManager} from "../../contracts/instance/InstanceServiceManager.sol";
import {InstanceService} from "../../contracts/instance/InstanceService.sol";  

import {RegistryServiceManager} from "../../contracts/registry/RegistryServiceManager.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";

import {PricingServiceManager} from "../../contracts/product/PricingServiceManager.sol";
import {PricingService} from "../../contracts/product/PricingService.sol";

import {StakingServiceManager} from "../../contracts/staking/StakeingServiceManager.sol";
import {StakingService} from "../../contracts/staking/StakingService.sol";

import {IInstance} from "../../contracts/instance/IInstance.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {IRegistryService} from "../../contracts/registry/IRegistryService.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {ReleaseManager} from "../../contracts/registry/ReleaseManager.sol";


// IMPORTANT: only for easier testing, hh script should precalculate addresses and give to release manager
// extended version with access control setup
// deployment size > 800kb
contract ReleaseConfig
{
    address public immutable _releaseManager;
    address public immutable _accessManager;
    address public immutable _registry;
    address public immutable _owner;
    bytes32 public immutable _salt;
    VersionPart public immutable _version;

    IRegistry.ConfigStruct[] internal _config;

    constructor(ReleaseManager releaseManager, address owner, VersionPart version, bytes32 salt)
    {
        _releaseManager = address(releaseManager);
        _registry = releaseManager.getRegistry();
        _owner = owner;
        _version = version;
        _salt = keccak256(
            bytes.concat(
                bytes32(_version.toInt()),
                salt));
        _accessManager = Clones.predictDeterministicAddress(
            address(releaseManager._accessManager().authority()), // implementation
            _salt,
            address(releaseManager)); // deployer

        _config.push(_stakingServiceConfig());
        _config.push(_policyServiceConfig());
        _config.push(_applicationServiceConfig());
        _config.push(_claimServiceConfig());
        _config.push(_productService());
        _config.push(_poolServiceConfig());
        _config.push(_bundleServiceConfig());
        _config.push(_pricingServiceConfig());
        _config.push(_distributionServiceConfig());
        _config.push(_instanceServiceConfig());
        _config.push(_registryServiceConfig());
    }

    function length() external view returns(uint) {
        return _config.length;
    }

    function getServiceConfig(uint idx) external view returns(IRegistry.ConfigStruct memory) {
        return _config[idx];
    }

    function getConfig() external view returns(IRegistry.ConfigStruct[] memory) {
        return _config;
    }

    function getAccessManager() external view returns(address) {
        return _accessManager;
    }

    function getSalt() external view returns(bytes32) {
        return _salt;
    }

    function getVersion() external view returns(VersionPart) {
        return _version;
    }

    function _stakingServiceConfig() internal returns(IRegistry.ConfigStruct memory config)
    {
        address proxyManager = _computeProxyManagerAddress(type(StakingServiceManager).creationCode);
        address implementation = _computeImplementationAddress(type(StakingService).creationCode, proxyManager);
        address proxyAddress = _computeProxyAddress(implementation, proxyManager);

        config = IRegistry.ConfigStruct(
            proxyAddress,
            new RoleId[](1),
            //STAKE(),
            new bytes4[][](0),
            new RoleId[](0)
        );

        config.serviceRoles[0] = STAKING_SERVICE_ROLE();
    }

    function _policyServiceConfig() internal returns(IRegistry.ConfigStruct memory config)
    {
        address proxyManager = _computeProxyManagerAddress(type(PolicyServiceManager).creationCode);
        address implementation = _computeImplementationAddress(type(PolicyService).creationCode, proxyManager);
        address proxyAddress = _computeProxyAddress(implementation, proxyManager);

        config = IRegistry.ConfigStruct(
            proxyAddress,
            new RoleId[](1),
            //POLICY(),
            new bytes4[][](0),
            new RoleId[](0)
        );

        config.serviceRoles[0] = POLICY_SERVICE_ROLE();
    }

    function _applicationServiceConfig() internal returns(IRegistry.ConfigStruct memory config)
    {
        address proxyManager = _computeProxyManagerAddress(type(ApplicationServiceManager).creationCode);
        address implementation = _computeImplementationAddress(type(ApplicationService).creationCode, proxyManager);
        address proxyAddress = _computeProxyAddress(implementation, proxyManager);

        config = IRegistry.ConfigStruct(
            proxyAddress,
            new RoleId[](1),
            //APPLICATION(),
            new bytes4[][](0),
            new RoleId[](0)
        );

        config.serviceRoles[0] = APPLICATION_SERVICE_ROLE();
    }

    function _claimServiceConfig() internal returns(IRegistry.ConfigStruct memory config)
    {
        address proxyManager = _computeProxyManagerAddress(type(ClaimServiceManager).creationCode);
        address implementation = _computeImplementationAddress(type(ClaimService).creationCode, proxyManager);
        address proxyAddress = _computeProxyAddress(implementation, proxyManager);

        config = IRegistry.ConfigStruct(
            proxyAddress,
            new RoleId[](1),
            //CLAIM(),
            new bytes4[][](0),
            new RoleId[](0)
        );

        config.serviceRoles[0] = CLAIM_SERVICE_ROLE();
    }

    function _productService()  internal returns(IRegistry.ConfigStruct memory config)
    {
        address proxyManager = _computeProxyManagerAddress(type(ProductServiceManager).creationCode);
        address implementation = _computeImplementationAddress(type(ProductService).creationCode, proxyManager);
        address proxyAddress = _computeProxyAddress(implementation, proxyManager);

        config = IRegistry.ConfigStruct(
            proxyAddress,
            new RoleId[](2),
            //PRODUCT(),
            new bytes4[][](0),
            new RoleId[](0)
        );

        config.serviceRoles[0] = PRODUCT_SERVICE_ROLE();
        config.serviceRoles[1] = CAN_CREATE_GIF_TARGET_ROLE();
    }

    function _poolServiceConfig() internal returns(IRegistry.ConfigStruct memory)
    {
        address proxyManager = _computeProxyManagerAddress(type(PoolServiceManager).creationCode);
        address implementation = _computeImplementationAddress(type(PoolService).creationCode, proxyManager);
        address proxyAddress = _computeProxyAddress(implementation, proxyManager);

        IRegistry.ConfigStruct memory config = IRegistry.ConfigStruct(
            proxyAddress,
            new RoleId[](2),
            //POOL(),
            new bytes4[][](2),
            new RoleId[](2)
        );

        config.serviceRoles[0] = POOL_SERVICE_ROLE();
        config.serviceRoles[1] = CAN_CREATE_GIF_TARGET_ROLE();

        config.functionRoles[0] = POLICY_SERVICE_ROLE();
        config.selectors[0] = new bytes4[](3);
        config.selectors[0][0] = PoolService.lockCollateral.selector;
        config.selectors[0][1] = PoolService.releaseCollateral.selector;
        config.selectors[0][2] = PoolService.processSale.selector;

        config.functionRoles[1] = CLAIM_SERVICE_ROLE();
        config.selectors[1] = new bytes4[](1);
        config.selectors[1][0] = PoolService.reduceCollateral.selector;

        return config;
    }

    function _bundleServiceConfig() internal returns(IRegistry.ConfigStruct memory config)
    {
        address proxyManager = _computeProxyManagerAddress(type(BundleServiceManager).creationCode);
        address implementation = _computeImplementationAddress(type(BundleService).creationCode, proxyManager);
        address proxyAddress = _computeProxyAddress(implementation, proxyManager);

        config = IRegistry.ConfigStruct(
            proxyAddress,
            new RoleId[](1),
            //BUNDLE(),
            new bytes4[][](2),
            new RoleId[](2)
        );

        config.serviceRoles[0] = BUNDLE_SERVICE_ROLE();

        config.functionRoles[0] = POLICY_SERVICE_ROLE();
        config.selectors[0] = new bytes4[](1);
        config.selectors[0][0] = BundleService.increaseBalance.selector;

        config.functionRoles[1] = POOL_SERVICE_ROLE();
        config.selectors[1] = new bytes4[](5);
        config.selectors[1][0] = BundleService.create.selector;
        config.selectors[1][1] = BundleService.lockCollateral.selector;
        config.selectors[1][2] = BundleService.close.selector;
        config.selectors[1][3] = BundleService.releaseCollateral.selector;
        config.selectors[1][4] = BundleService.unlinkPolicy.selector;

        return config;
    }

    function _pricingServiceConfig() internal returns(IRegistry.ConfigStruct memory config)
    {
        address proxyManager = _computeProxyManagerAddress(type(PricingServiceManager).creationCode);
        address implementation = _computeImplementationAddress(type(PricingService).creationCode, proxyManager);
        address proxyAddress = _computeProxyAddress(implementation, proxyManager);

        config = IRegistry.ConfigStruct(
            proxyAddress,
            new RoleId[](1),
            //PRICE(),
            new bytes4[][](0),
            new RoleId[](0)
        );

        config.serviceRoles[0] = PRICING_SERVICE_ROLE();
    }

    function _distributionServiceConfig() internal returns(IRegistry.ConfigStruct memory)
    {
        address proxyManager = _computeProxyManagerAddress(type(DistributionServiceManager).creationCode);
        address implementation = _computeImplementationAddress(type(DistributionService).creationCode, proxyManager);
        address proxyAddress = _computeProxyAddress(implementation, proxyManager);

        IRegistry.ConfigStruct memory config = IRegistry.ConfigStruct(
            proxyAddress,
            new RoleId[](2),
            //DISTRIBUTION(),
            new bytes4[][](1),
            new RoleId[](1)
        );

        config.serviceRoles[0] = DISTRIBUTION_SERVICE_ROLE();
        config.serviceRoles[1] = CAN_CREATE_GIF_TARGET_ROLE();

        config.functionRoles[0] = POLICY_SERVICE_ROLE();
        config.selectors[0] = new bytes4[](1);
        config.selectors[0][0] = DistributionService.processSale.selector;

        return config;
    }

    function _instanceServiceConfig() internal returns(IRegistry.ConfigStruct memory config)
    {
        address proxyManager = _computeProxyManagerAddress(type(InstanceServiceManager).creationCode);
        address implementation = _computeImplementationAddress(type(InstanceService).creationCode, proxyManager);
        address proxyAddress = _computeProxyAddress(implementation, proxyManager);

        config = IRegistry.ConfigStruct(
            proxyAddress,
            new RoleId[](1),
            //INSTANCE(),
            new bytes4[][](1),
            new RoleId[](1)
        );

        config.serviceRoles[0] = INSTANCE_SERVICE_ROLE();

        config.functionRoles[0] = PRODUCT_SERVICE_ROLE();
        config.selectors[0] = new bytes4[](1);
        // TODO each service can call this function...
        config.selectors[0][0] = InstanceService.createGifTarget.selector;

        return config;
    }

    function _registryServiceConfig() internal returns(IRegistry.ConfigStruct memory config)
    {
        address proxyManager = _computeProxyManagerAddress(type(RegistryServiceManager).creationCode);
        address implementation = _computeImplementationAddress(type(RegistryService).creationCode, proxyManager);
        address proxyAddress = _computeProxyAddress(implementation, proxyManager);

        config = IRegistry.ConfigStruct(
            proxyAddress,
            new RoleId[](1),
            //REGISTRY(),
            new bytes4[][](6),
            new RoleId[](6)
        );

        config.serviceRoles[0] = REGISTRY_SERVICE_ROLE();

        config.functionRoles[0] = APPLICATION_SERVICE_ROLE();
        config.selectors[0] = new bytes4[](1);
        config.selectors[0][0] = RegistryService.registerPolicy.selector;

        config.functionRoles[1] = PRODUCT_SERVICE_ROLE();
        config.selectors[1] = new bytes4[](1);
        config.selectors[1][0] = RegistryService.registerProduct.selector;

        config.functionRoles[2] = POOL_SERVICE_ROLE();
        config.selectors[2] = new bytes4[](1);
        config.selectors[2][0] = RegistryService.registerPool.selector;

        config.functionRoles[3] = BUNDLE_SERVICE_ROLE();
        config.selectors[3] = new bytes4[](1);
        config.selectors[3][0] = RegistryService.registerBundle.selector;

        config.functionRoles[4] = DISTRIBUTION_SERVICE_ROLE();
        config.selectors[4] = new bytes4[](2);
        config.selectors[4][0] = RegistryService.registerDistribution.selector;
        config.selectors[4][1] = RegistryService.registerDistributor.selector;

        config.functionRoles[5] = INSTANCE_SERVICE_ROLE();
        config.selectors[5] = new bytes4[](1);
        config.selectors[5][0] = RegistryService.registerInstance.selector;

        return config;
    }

    function _computeProxyManagerAddress(bytes memory creationCode) internal view returns(address) {
        bytes memory initCode = abi.encodePacked(
            creationCode, 
            abi.encode(_accessManager, _registry, _salt));
        return Create2.computeAddress(_salt, keccak256(initCode), _owner);
    }

    function _computeImplementationAddress(bytes memory creationCode, address proxyManager) internal view returns(address) {
        bytes memory initCode = abi.encodePacked(creationCode);
        return Create2.computeAddress(_salt, keccak256(initCode), proxyManager);
    }

    function _computeProxyAddress(address implementation, address proxyManager) internal view returns(address) {
        bytes memory data = abi.encode(
            _registry, 
            proxyManager, 
            _accessManager);

        data = abi.encodeWithSelector(
            IVersionable.initializeVersionable.selector,
            _owner,
            data);

        bytes memory initCode = abi.encodePacked(
            type(UpgradableProxyWithAdmin).creationCode,
            abi.encode(
                implementation,
                proxyManager, // is proxy admin owner
                data));

        return Create2.computeAddress(_salt, keccak256(initCode), proxyManager);
    }
}