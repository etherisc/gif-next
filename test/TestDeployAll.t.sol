// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";

import {console} from "../lib/forge-std/src/Script.sol";
import {GifTest} from "./base/GifTest.sol";
import {IAccessAdmin} from "../contracts/shared/IAccessAdmin.sol";
import {InstanceLinkedComponent} from "../contracts/shared/InstanceLinkedComponent.sol";
import {IRegistry} from "../contracts/registry/IRegistry.sol";
import {IStaking} from "../contracts/staking/IStaking.sol";
import {IStakingService} from "../contracts/staking/IStakingService.sol";
import {NftId, NftIdLib} from "../contracts/type/NftId.sol";
import {ObjectType} from "../contracts/type/ObjectType.sol";
import {BUNDLE, COMPONENT, DISTRIBUTION, ORACLE, POOL, PRODUCT, POLICY, RISK, REQUEST, SERVICE, STAKING} from "../contracts/type/ObjectType.sol";
import {RoleId, PRODUCT_OWNER_ROLE, POOL_OWNER_ROLE, ORACLE_OWNER_ROLE, DISTRIBUTION_OWNER_ROLE} from "../contracts/type/RoleId.sol";

contract TestDeployAll is GifTest {
    using NftIdLib for NftId;

    function setUp() public override {
        super.setUp();
        _prepareProduct();  
    }

    function test_deployRegistryAdmin() public {
        console.log("registry admin deployed:", address(registryAdmin));
        console.log("registry admin authority", registryAdmin.authority());

        uint256 roles = registryAdmin.roles();
        uint256 targets = registryAdmin.targets();

        console.log("==========================================");
        console.log("roles", registryAdmin.roles());
        // solhint-enable

        for(uint256 i = 0; i < registryAdmin.roles(); i++) {
            _printRoleMembers(registryAdmin, registryAdmin.getRoleId(i));
        }

        // solhint-disable no-console
        console.log("==========================================");
        console.log("targets", registryAdmin.targets());
        // solhint-enable

        for(uint256 i = 0; i < registryAdmin.targets(); i++) {
            _printTarget(registryAdmin, registryAdmin.getTargetAddress(i));
        }
    }

    function _getTargetText(uint256 idx) internal returns (string memory) {
        address target = registryAdmin.getTargetAddress(idx);
        return string(
            abi.encodePacked(
                "address ", 
                _toString(target), 
                " ", 
                registryAdmin.getTargetInfo(target).name));
    }

    function _getRoleText(uint256 idx) internal returns (string memory) {
        RoleId roleId = registryAdmin.getRoleId(idx);
        return string(
            abi.encodePacked(
                "roleId ", 
                _toString(roleId.toInt()), 
                " ", 
                registryAdmin.getRoleInfo(roleId).name,
                " members ",
                _toString(registryAdmin.roleMembers(roleId))));
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        return Strings.toString(value);
    }

    function _toString(address _address) internal pure returns (string memory) {
        return Strings.toHexString(uint256(uint160(_address)), 20);
    }

    function test_deploySimpleProduct() public {
        _checkMockComponent(product, productNftId, instanceNftId, PRODUCT(), "SimpleProduct", productOwner, PRODUCT_OWNER_ROLE());
    }

    function test_deploySimpleOracle() public {
        _checkMockComponent(oracle, oracleNftId, instanceNftId, ORACLE(), "SimpleOracle", oracleOwner, ORACLE_OWNER_ROLE());
    }

    function test_deploySimpleDistribution() public {
        _checkMockComponent(distribution, distributionNftId, instanceNftId, DISTRIBUTION(), "SimpleDistribution", distributionOwner, DISTRIBUTION_OWNER_ROLE());
    }

    function test_deploySimplePool() public {
        _checkMockComponent(pool, poolNftId, instanceNftId, POOL(), "SimplePool", poolOwner, POOL_OWNER_ROLE());
    }


    function test_deployServicesOverview() public {
        assertEq(registry.getObjectCount(), 24, "invalid object count for base setup");

        // validate registry service
        assertTrue(registry.getNftId(address(registryService)).eq(registryServiceNftId), "registry service nft does not match");
        assertTrue(address(registryServiceManager) != address(0), "registry service manager is zero address");

        // validate staking service
        assertTrue(registry.getNftId(address(stakingService)).eq(stakingServiceNftId), "staking service nft does not match");
        assertTrue(address(stakingServiceManager) != address(0), "staking service manager is zero address");

        // validate instance service
        assertTrue(registry.getNftId(address(instanceService)).eq(instanceServiceNftId), "instance service nft does not match");
        assertTrue(address(instanceServiceManager) != address(0), "instance service manager is zero address");

        // validate component service
        assertTrue(registry.getNftId(address(componentService)).eq(componentServiceNftId), "instance service nft does not match");
        assertTrue(address(componentServiceManager) != address(0), "instance service manager is zero address");

        // validate distribution service
        assertTrue(registry.getNftId(address(distributionService)).eq(distributionServiceNftId), "distribution service nft does not match");
        assertTrue(address(distributionServiceManager) != address(0), "distribution service manager is zero address");

        // validate pricing service
        assertTrue(registry.getNftId(address(pricingService)).eq(pricingServiceNftId), "pricing service nft does not match");
        assertTrue(address(pricingServiceManager) != address(0), "pricing service manager is zero address");

        // validate bundle service
        assertTrue(registry.getNftId(address(bundleService)).eq(bundleServiceNftId), "bundle service nft does not match");
        assertTrue(address(bundleServiceManager) != address(0), "bundle service manager is zero address");

        // validate pool service
        assertTrue(registry.getNftId(address(poolService)).eq(poolServiceNftId), "pool service nft does not match");
        assertTrue(address(poolServiceManager) != address(0), "pool service manager is zero address");

        // validate oracle service
        assertTrue(registry.getNftId(address(oracleService)).eq(oracleServiceNftId), "oracle service nft does not match");
        assertTrue(address(oracleServiceManager) != address(0), "oracle service manager is zero address");

        // validate product service
        assertTrue(registry.getNftId(address(productService)).eq(productServiceNftId), "product service nft does not match");
        assertTrue(address(productServiceManager) != address(0), "product service manager is zero address");

        // validate claim service
        assertTrue(registry.getNftId(address(claimService)).eq(claimServiceNftId), "claim service nft does not match");
        assertTrue(address(claimServiceManager) != address(0), "claim service manager is zero address");

        // validate application service
        assertTrue(registry.getNftId(address(applicationService)).eq(applicationServiceNftId), "application service nft does not match");
        assertTrue(address(applicationServiceManager) != address(0), "application service manager is zero address");

        // validate policy service
        assertTrue(registry.getNftId(address(policyService)).eq(policyServiceNftId), "policy service nft does not match");
        assertTrue(address(policyServiceManager) != address(0), "policy service manager is zero address");

        // validate master instance
        assertTrue(registry.getNftId(address(masterInstance)).eq(masterInstanceNftId), "master instance nft does not match");
        assertTrue(address(masterInstanceAdmin) != address(0), "master instance admin is zero address");
        assertTrue(address(masterInstanceReader) != address(0), "master instance reader is zero address");

        // validate created (cloned) instance
        assertTrue(registry.getNftId(address(instance)).eq(instanceNftId), "instance nft does not match");
        assertTrue(address(instanceAdmin) != address(0), "instance admin is zero address");
        assertTrue(address(instanceReader) != address(0), "instance reader is zero address");
    }

    function test_deployAllInstanceOwner() public {
        NftId nftId = registry.getNftId(address(instance));
        assertEq(
            registry.ownerOf(nftId),
            instanceOwner,
            "unexpected instance owner"
        );
    }

    function test_deployAllInstanceLifecycles() public {
        assertTrue(instance.getInstanceStore().hasLifecycle(BUNDLE()), "instance misses bundle lifecycle");
        assertTrue(instance.getInstanceStore().hasLifecycle(COMPONENT()), "instance misses component lifecycle");
        assertTrue(instance.getInstanceStore().hasLifecycle(POLICY()), "instance misses policy lifecycle");
        assertTrue(instance.getInstanceStore().hasLifecycle(RISK()), "instance misses risk lifecycle");
        assertTrue(instance.getInstanceStore().hasLifecycle(REQUEST()), "instance misses request lifecycle");
    }


    function _checkMockComponent(
        InstanceLinkedComponent component,
        NftId nftId, 
        NftId parentNftId, 
        ObjectType componentType,
        string memory componentName,
        address componentOwner,
        RoleId ownerRoleId
    )
        internal
    {
        // check params against unexpected 0 values
        assertTrue(address(component) != address(0), "component address 0");
        assertTrue(nftId.gtz(), "component id 0");
        assertTrue(parentNftId.gtz(), "component parent id 0");
        assertTrue(componentType.gtz(), "component type 0");
        assertTrue(bytes(componentName).length > 0, "component name length 0");
        assertTrue(componentOwner != address(0), "component owner address 0");
        assertTrue(ownerRoleId.gtz(), "component owner role 0");

        // check against registered object info
        IRegistry.ObjectInfo memory info = registry.getObjectInfo(address(component));
        assertEq(info.nftId.toInt(), nftId.toInt(), "unexpected component nft id");
        assertEq(info.parentNftId.toInt(), parentNftId.toInt(), "unexpected component parent nft id");
        assertEq(info.objectType.toInt(), componentType.toInt(), "unexpected component type");
        assertEq(info.objectAddress, address(component), "unexpected component address");

        // TODO component name

        // check owner
        assertEq(registry.ownerOf(address(component)), componentOwner, "unexpected component owner");

        // check component owner has expected role
        assertTrue(instanceReader.hasRole(componentOwner, ownerRoleId), "component owner missing component owner role");
    }


    function _printRoleMembers(IAccessAdmin aa, RoleId roleId) internal {
        IAccessAdmin.RoleInfo memory info = aa.getRoleInfo(roleId);
        uint256 members = aa.roleMembers(roleId);

        // solhint-disable no-console
        console.log("role", info.name.toString(), "id", roleId.toInt()); 
        console.log("role members", members); 
        for(uint i = 0; i < members; i++) {
            console.log("-", i, aa.getRoleMember(roleId, i));
        }
        // solhint-enable
    }

    function _printTarget(IAccessAdmin aa, address target) internal view {
        IAccessAdmin.TargetInfo memory info = aa.getTargetInfo(target);

        // solhint-disable no-console
        uint256 functions = aa.authorizedFunctions(target);
        console.log("target", info.name.toString(), "address", target);
        console.log("authorized functions", functions);
        for(uint256 i = 0; i < functions; i++) {
            (
                IAccessAdmin.Function memory func,
                RoleId roleId
            ) = aa.getAuthorizedFunction(target, i);
            string memory role = aa.getRoleInfo(roleId).name.toString();

            console.log("-", i, string(abi.encodePacked(func.name.toString(), "(): ", role,":")), roleId.toInt());
        }
        // solhint-enable
    }

}