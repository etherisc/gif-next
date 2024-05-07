// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {RoleId, PUBLIC_ROLE, POLICY_SERVICE_ROLE, APPLICATION_SERVICE_ROLE, CLAIM_SERVICE_ROLE, PRODUCT_SERVICE_ROLE, POOL_SERVICE_ROLE, BUNDLE_SERVICE_ROLE, COMPONENT_SERVICE_ROLE, PRICING_SERVICE_ROLE, DISTRIBUTION_SERVICE_ROLE, INSTANCE_SERVICE_ROLE, REGISTRY_SERVICE_ROLE, PRODUCT_OWNER_ROLE, POOL_OWNER_ROLE, ORACLE_OWNER_ROLE, STAKING_SERVICE_ROLE, CAN_CREATE_GIF_TARGET_ROLE} from "../../contracts/type/RoleId.sol";
import {ObjectType, REGISTRY, SERVICE, PRODUCT, ORACLE, POOL, INSTANCE, DISTRIBUTION, DISTRIBUTOR, APPLICATION, POLICY, CLAIM, BUNDLE, STAKE, PRICE} from "../../contracts/type/ObjectType.sol";
import {StateId, ACTIVE, PAUSED} from "../../contracts/type/StateId.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
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

import {ComponentService} from "../../contracts/shared/ComponentService.sol";
import {ComponentServiceManager} from "../../contracts/shared/ComponentServiceManager.sol";

import {InstanceServiceManager} from "../../contracts/instance/InstanceServiceManager.sol";
import {InstanceService} from "../../contracts/instance/InstanceService.sol";  

import {RegistryServiceManager} from "../../contracts/registry/RegistryServiceManager.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";

import {PricingServiceManager} from "../../contracts/product/PricingServiceManager.sol";
import {PricingService} from "../../contracts/product/PricingService.sol";

import {StakingServiceManager} from "../../contracts/staking/StakingServiceManager.sol";
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
    VersionPart public immutable _version;
    address public immutable _releaseManager;
    address public immutable _accessManager;// release access manager
    address public immutable _registry;
    address public immutable _owner;
    bytes32 public immutable _salt;
    address[] internal _addresses;
    RoleId[][] internal _serviceRoles;
    RoleId[][] internal _functionRoles;
    bytes4[][][] internal _selectors;

    constructor(ReleaseManager releaseManager, address owner, VersionPart version, bytes32 salt)
    { 
        _releaseManager = address(releaseManager);
        _registry = releaseManager.getRegistryAddress();
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

        // order is important
        _pushPolicyServiceConfig();
        _pushApplicationServiceConfig();
        _pushClaimServiceConfig();
        _pushProductServiceConfig();
        _pushPoolServiceConfig();
        _pushBundleServiceConfig();
        _pushPricingServiceConfig();
        _pushDistributionServiceConfig();
        _pushComponentServiceConfig();
        _pushInstanceServiceConfig();
        _pushStakingServiceConfig();
        _pushRegistryServiceConfig();
    }

    function length() external view returns(uint) {
        return _addresses.length;
    }

    function getServiceConfig(uint serviceIdx) 
        external 
        view 
        returns(
            address serviceAddress, 
            RoleId[] memory, 
            RoleId[] memory, 
            bytes4[][] memory
        )
    {
        return(
            _addresses[serviceIdx], 
            _serviceRoles[serviceIdx], 
            _functionRoles[serviceIdx], 
            _selectors[serviceIdx]
        );
    }

    function getConfig() 
        external 
        view returns(
            address[] memory, 
            RoleId[][] memory, 
            RoleId[][] memory, 
            bytes4[][][] memory
        )
    {
        return (
            _addresses, 
            _serviceRoles, 
            _functionRoles, 
            _selectors
        );
    }

    function _pushStakingServiceConfig() internal
    {
        address proxyManager = _computeProxyManagerAddress(type(StakingServiceManager).creationCode);
        address implementation = _computeImplementationAddress(type(StakingService).creationCode, proxyManager);
        address proxyAddress = _computeProxyAddress(implementation, proxyManager);

        _addresses.push(proxyAddress);
        _serviceRoles.push(new RoleId[](1));
        _functionRoles.push(new RoleId[](0));
        _selectors.push(new bytes4[][](0));
        uint serviceIdx = _addresses.length - 1;

        _serviceRoles[serviceIdx][0] = STAKING_SERVICE_ROLE();
    }

    function _pushPolicyServiceConfig() internal
    {
        address proxyManager = _computeProxyManagerAddress(type(PolicyServiceManager).creationCode);
        address implementation = _computeImplementationAddress(type(PolicyService).creationCode, proxyManager);
        address proxyAddress = _computeProxyAddress(implementation, proxyManager);

        _addresses.push(proxyAddress);
        _serviceRoles.push(new RoleId[](1));
        _functionRoles.push(new RoleId[](0));
        _selectors.push(new bytes4[][](0));
        uint serviceIdx = _addresses.length - 1;

        _serviceRoles[serviceIdx][0] = POLICY_SERVICE_ROLE();
    }

    function _pushApplicationServiceConfig() internal
    {
        address proxyManager = _computeProxyManagerAddress(type(ApplicationServiceManager).creationCode);
        address implementation = _computeImplementationAddress(type(ApplicationService).creationCode, proxyManager);
        address proxyAddress = _computeProxyAddress(implementation, proxyManager);

        _addresses.push(proxyAddress);
        _serviceRoles.push(new RoleId[](1));
        _functionRoles.push(new RoleId[](0));
        _selectors.push(new bytes4[][](0));
        uint serviceIdx = _addresses.length - 1;

        _serviceRoles[serviceIdx][0] = APPLICATION_SERVICE_ROLE();
    }

    function _pushClaimServiceConfig() internal
    {
        address proxyManager = _computeProxyManagerAddress(type(ClaimServiceManager).creationCode);
        address implementation = _computeImplementationAddress(type(ClaimService).creationCode, proxyManager);
        address proxyAddress = _computeProxyAddress(implementation, proxyManager);

        _addresses.push(proxyAddress);
        _serviceRoles.push(new RoleId[](1));
        _functionRoles.push(new RoleId[](0));
        _selectors.push(new bytes4[][](0));
        uint serviceIdx = _addresses.length - 1;

        _serviceRoles[serviceIdx][0] = CLAIM_SERVICE_ROLE();
    }

    function _pushProductServiceConfig() internal
    {
        address proxyManager = _computeProxyManagerAddress(type(ProductServiceManager).creationCode);
        address implementation = _computeImplementationAddress(type(ProductService).creationCode, proxyManager);
        address proxyAddress = _computeProxyAddress(implementation, proxyManager);

        _addresses.push(proxyAddress);
        _serviceRoles.push(new RoleId[](2));
        _functionRoles.push(new RoleId[](0));
        _selectors.push(new bytes4[][](0));
        uint serviceIdx = _addresses.length - 1;

        _serviceRoles[serviceIdx][0] = PRODUCT_SERVICE_ROLE();
        _serviceRoles[serviceIdx][1] = CAN_CREATE_GIF_TARGET_ROLE();
    }

    function _pushPoolServiceConfig() internal
    {
        address proxyManager = _computeProxyManagerAddress(type(PoolServiceManager).creationCode);
        address implementation = _computeImplementationAddress(type(PoolService).creationCode, proxyManager);
        address proxyAddress = _computeProxyAddress(implementation, proxyManager);

        _addresses.push(proxyAddress);
        _serviceRoles.push(new RoleId[](2));
        _functionRoles.push(new RoleId[](2));
        _selectors.push(new bytes4[][](2));
        uint serviceIdx = _addresses.length - 1;

        _serviceRoles[serviceIdx][0] = POOL_SERVICE_ROLE();
        _serviceRoles[serviceIdx][1] = CAN_CREATE_GIF_TARGET_ROLE();

        _functionRoles[serviceIdx][0] = POLICY_SERVICE_ROLE();
        _selectors[serviceIdx][0] = new bytes4[](3);
        _selectors[serviceIdx][0][0] = PoolService.lockCollateral.selector;
        _selectors[serviceIdx][0][1] = PoolService.releaseCollateral.selector;
        _selectors[serviceIdx][0][2] = PoolService.processSale.selector;

        _functionRoles[serviceIdx][1] = CLAIM_SERVICE_ROLE();
        _selectors[serviceIdx][1] = new bytes4[](1);
        _selectors[serviceIdx][1][0] = PoolService.reduceCollateral.selector;
    }

    function _pushBundleServiceConfig() internal
    {
        address proxyManager = _computeProxyManagerAddress(type(BundleServiceManager).creationCode);
        address implementation = _computeImplementationAddress(type(BundleService).creationCode, proxyManager);
        address proxyAddress = _computeProxyAddress(implementation, proxyManager);

        _addresses.push(proxyAddress);
        _serviceRoles.push(new RoleId[](1));
        _functionRoles.push(new RoleId[](2));
        _selectors.push(new bytes4[][](2));
        uint serviceIdx = _addresses.length - 1;

        _serviceRoles[serviceIdx][0] = BUNDLE_SERVICE_ROLE();

        _functionRoles[serviceIdx][0] = POLICY_SERVICE_ROLE();
        _selectors[serviceIdx][0] = new bytes4[](1);
        // TODO reenable
        // _selectors[serviceIdx][0][0] = BundleService.increaseBalance.selector;

        _functionRoles[serviceIdx][1] = POOL_SERVICE_ROLE();
        _selectors[serviceIdx][1] = new bytes4[](5);
        _selectors[serviceIdx][1][0] = BundleService.create.selector;
        _selectors[serviceIdx][1][1] = BundleService.lockCollateral.selector;
        _selectors[serviceIdx][1][2] = BundleService.close.selector;
        _selectors[serviceIdx][1][3] = BundleService.releaseCollateral.selector;
        _selectors[serviceIdx][1][4] = BundleService.unlinkPolicy.selector;
    }

    function _pushPricingServiceConfig() internal
    {
        address proxyManager = _computeProxyManagerAddress(type(PricingServiceManager).creationCode);
        address implementation = _computeImplementationAddress(type(PricingService).creationCode, proxyManager);
        address proxyAddress = _computeProxyAddress(implementation, proxyManager);

        _addresses.push(proxyAddress);
        _serviceRoles.push(new RoleId[](1));
        _functionRoles.push(new RoleId[](0));
        _selectors.push(new bytes4[][](0));
        uint serviceIdx = _addresses.length - 1;

        _serviceRoles[serviceIdx][0] = PRICING_SERVICE_ROLE();
    }

    function _pushDistributionServiceConfig() internal
    {
        address proxyManager = _computeProxyManagerAddress(type(DistributionServiceManager).creationCode);
        address implementation = _computeImplementationAddress(type(DistributionService).creationCode, proxyManager);
        address proxyAddress = _computeProxyAddress(implementation, proxyManager);

        _addresses.push(proxyAddress);
        _serviceRoles.push(new RoleId[](2));
        _functionRoles.push(new RoleId[](1));
        _selectors.push(new bytes4[][](1));
        uint serviceIdx = _addresses.length - 1;

        _serviceRoles[serviceIdx][0] = DISTRIBUTION_SERVICE_ROLE();
        _serviceRoles[serviceIdx][1] = CAN_CREATE_GIF_TARGET_ROLE();

        _functionRoles[serviceIdx][0] = POLICY_SERVICE_ROLE();
        _selectors[serviceIdx][0] = new bytes4[](1);
        _selectors[serviceIdx][0][0] = DistributionService.processSale.selector;
    }

    function _pushComponentServiceConfig() internal
    {
        address proxyManager = _computeProxyManagerAddress(type(ComponentServiceManager).creationCode);
        address implementation = _computeImplementationAddress(type(ComponentService).creationCode, proxyManager);
        address proxyAddress = _computeProxyAddress(implementation, proxyManager);

        _addresses.push(proxyAddress);
        _serviceRoles.push(new RoleId[](1));
        _functionRoles.push(new RoleId[](0));
        _selectors.push(new bytes4[][](0));
        uint serviceIdx = _addresses.length - 1;

        _serviceRoles[serviceIdx][0] = COMPONENT_SERVICE_ROLE();
    }

    function _pushInstanceServiceConfig() internal
    {
        address proxyManager = _computeProxyManagerAddress(type(InstanceServiceManager).creationCode);
        address implementation = _computeImplementationAddress(type(InstanceService).creationCode, proxyManager);
        address proxyAddress = _computeProxyAddress(implementation, proxyManager);

        _addresses.push(proxyAddress);
        _serviceRoles.push(new RoleId[](1));
        _functionRoles.push(new RoleId[](1));
        _selectors.push(new bytes4[][](1));
        uint serviceIdx = _addresses.length - 1;

        _serviceRoles[serviceIdx][0] = INSTANCE_SERVICE_ROLE();

        _functionRoles[serviceIdx][0] = CAN_CREATE_GIF_TARGET_ROLE();
        _selectors[serviceIdx][0] = new bytes4[](1);
        _selectors[serviceIdx][0][0] = InstanceService.createGifTarget.selector;
    }

    function _pushRegistryServiceConfig() internal
    {
        address proxyManager = _computeProxyManagerAddress(type(RegistryServiceManager).creationCode);
        address implementation = _computeImplementationAddress(type(RegistryService).creationCode, proxyManager);
        address proxyAddress = _computeProxyAddress(implementation, proxyManager);

        _addresses.push(proxyAddress);
        _serviceRoles.push(new RoleId[](1));
        _functionRoles.push(new RoleId[](8));
        _selectors.push(new bytes4[][](8));
        uint serviceIdx = _addresses.length - 1;

        _serviceRoles[serviceIdx][0] = REGISTRY_SERVICE_ROLE();

        _functionRoles[serviceIdx][0] = APPLICATION_SERVICE_ROLE();
        _selectors[serviceIdx][0] = new bytes4[](1);
        _selectors[serviceIdx][0][0] = RegistryService.registerPolicy.selector;

        _functionRoles[serviceIdx][1] = PRODUCT_SERVICE_ROLE();
        _selectors[serviceIdx][1] = new bytes4[](1);
        _selectors[serviceIdx][1][0] = RegistryService.registerProduct.selector;

        _functionRoles[serviceIdx][2] = POOL_SERVICE_ROLE();
        _selectors[serviceIdx][2] = new bytes4[](1);
        _selectors[serviceIdx][2][0] = RegistryService.registerPool.selector;

        _functionRoles[serviceIdx][3] = BUNDLE_SERVICE_ROLE();
        _selectors[serviceIdx][3] = new bytes4[](1);
        _selectors[serviceIdx][3][0] = RegistryService.registerBundle.selector;

        _functionRoles[serviceIdx][4] = DISTRIBUTION_SERVICE_ROLE();
        _selectors[serviceIdx][4] = new bytes4[](2);
        _selectors[serviceIdx][4][0] = RegistryService.registerDistribution.selector;
        _selectors[serviceIdx][4][1] = RegistryService.registerDistributor.selector;

        _functionRoles[serviceIdx][5] = INSTANCE_SERVICE_ROLE();
        _selectors[serviceIdx][5] = new bytes4[](1);
        _selectors[serviceIdx][5][0] = RegistryService.registerInstance.selector;

        _functionRoles[serviceIdx][6] = COMPONENT_SERVICE_ROLE();
        _selectors[serviceIdx][6] = new bytes4[](1);
        _selectors[serviceIdx][6][0] = RegistryService.registerComponent.selector;

        _functionRoles[serviceIdx][7] = STAKING_SERVICE_ROLE();
        _selectors[serviceIdx][7] = new bytes4[](1);
        _selectors[serviceIdx][7][0] = RegistryService.registerStake.selector;
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