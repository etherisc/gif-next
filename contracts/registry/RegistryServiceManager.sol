// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";

import {ContractDeployerLib} from "../shared/ContractDeployerLib.sol";
import {RoleId,
        PRODUCT_REGISTRAR_ROLE,
        POOL_REGISTRAR_ROLE,
        DISTRIBUTION_REGISTRAR_ROLE,
        POLICY_REGISTRAR_ROLE,
        BUNDLE_REGISTRAR_ROLE,
        REGISTRY_SERVICE_MANAGER_ROLE,
        REGISTRY_SERVICE_ADMIN_ROLE} from "../types/RoleId.sol";

import {Registry} from "./Registry.sol";
import {IVersionable} from "../shared/IVersionable.sol";
import {ProxyManager} from "../shared/ProxyManager.sol";
import {RegistryService} from "./RegistryService.sol";
import {TokenRegistry} from "./TokenRegistry.sol";

/*
    3 types of roles: 
    1) REGISTRAR roles 
        - one per registry service function ( except registerService() )
        - one member(service) per role per version
    2) REGISTRY_SERVICE_MANAGER_ROLE 
        - admin of all REGISTRAR roles
        - can have arbitrary number of members
    3) REGISTRY_SERVICE_ADMIN_ROLE 
        - admin of REGISTRY_SERVICE_MANAGER_ROLE
        - MUST have 1 member at any time
        - granted/revoked ONLY by RegistreServiceManager in transferAdminRole() consider lock out situations!!!
        - this role is analogous to registry service nft owner
*/

// TODO non nftOwnabe (AccessManaged) version of ProxyManager and TokenRegistry
// TODO get REGISTRAR roles from registry service
// TODO add/remove REGISTRAR roles during minor upgrades
// TODO what AccessManaher functions need a wrapper? 
// TODO registry is not passive, still needs owner to set majorVersion
contract RegistryServiceManager is
    ProxyManager
{
    bytes32 constant public ACCESS_MANAGER_CREATION_CODE_HASH = 0x0;

    AccessManager private _accessManager;
    RegistryService private _registryService; 
    TokenRegistry private _tokenRegistry;

    // TODO on upgrade have to get roles set from RegistryService
    //mapping(RoleId roleId => bytes4 functionSelector) selectorByRole;

    constructor(address manager)
        ProxyManager()
    {
        _accessManager = new AccessManager(address(this));

        _deployRegistryServiceAndRegistry();

        // deploy token registry
        // _tokenRegistry = new TokenRegistry(
        //     address(_registryService.getRegistry()),
        //     address(_registryService));

        // configure REGISTRY_SERVICE_ADMIN_ROLE for all deployed contracts
        _configureAdminRole();

        // configure REGISTRY_SERVICE_MANAGER_ROLE for all deployed contracts
        _configureManagerRole();
    
        // configure REGISTRAR roles for registry service
        _configureRegistrarRoles();

        // configure roles hierarchy admin->manager->registrar
        _configureRolesAdmins();

        address admin = msg.sender;
        _accessManager.grantRole(REGISTRY_SERVICE_ADMIN_ROLE().toInt(), admin, 0);

        _accessManager.grantRole(REGISTRY_SERVICE_MANAGER_ROLE().toInt(), manager, 0);

        // implies that after this constructor call only upgrade functionality is available
        _isDeployed = true;
    }

    /*function transferAdmin(address to)
        external
        restricted // only with REGISTRY_SERVICE_ADMIN_ROLE or nft owner
    {
        _accessManager.revoke(REGISTRY_SERVICE_ADMIN_ROLE, );
        _accesssManager.grant(REGISTRY_SERVICE_ADMIN_ROLE, to, 0);
    }*/

    //--- view functions ----------------------------------------------------//

    function getAccessManager()
        external
        view
        returns (AccessManager)
    {
        return _accessManager;
    }

    function getRegistryService()
        external
        view
        returns (RegistryService registryService)
    {
        return _registryService;
    }

    function getTokenRegistry()
        external
        view
        returns (TokenRegistry)
    {
        return _tokenRegistry;
    }

    /*function isExistingRole(RoleId roleId) public view returns(bool)
    {
        return selectorByRole[roleId] == bytes4(0);
    }*/

    //--- private functions -------------------------------------------------//'

    function _deployRegistryServiceAndRegistry() private
    {
        bytes memory initializationData = abi.encode(_accessManager, type(Registry).creationCode);

        // will mint and lock protocolNftId, globalRegistryNftId, regitryNftId, registryServiceNftId
        IVersionable versionable = deploy(
            address(new RegistryService()), 
            initializationData);

        _registryService = RegistryService(address(versionable));

        // assume transfer of registryServiceNftId is meaningless -> no NftOwnable here
        // REGISTRY_SERVICE_ADMIN_ROLE in "full controll" of RegistryServiceManager, RegistryService and TokenRegistry
        // "full controll" is defined by RegistryServiceManager
        // link ownership of registry service manager to nft owner of registry service
        //_linkToNftOwnable(
        //    address(_registryService.getRegistry()),
        //   address(_registryService));
    }
    
    function _configureAdminRole() private
    {
        //bytes4[] memory functionSelector = new bytes4[](2);

        // configure REGISTRY_SERVICE_ADMIN_ROLE for RegistryServiceManager
        //functionSelector[0] = RegistryServiceManager.setTargetFunctionRole.selector;
        //functionSelector[1] = RegistryServiceManager.setRoleAdmin.selector;
        //functionSelector[2] = RegistryServiceManager.grantRole.selector;
        //_setTargetFunctionRole(address(this), functionSelector, REGISTRY_SERVICE_ADMIN_ROLE());

        // configure REGISTRY_SERVICE_ADMIN_ROLE for TokenRegistry
    }
    
    function _configureManagerRole() private 
    {
        bytes4[] memory functionSelector = new bytes4[](1);

        // configure REGISTRY_SERVICE_MANAGER_ROLE for TokenRegistry
        functionSelector[0] = TokenRegistry.setActive.selector;
        _setTargetFunctionRole(address(_tokenRegistry), functionSelector, REGISTRY_SERVICE_MANAGER_ROLE());

        // configure REGISTRY_SERVICE_MANAGER_ROLE for RegistryService
        functionSelector[0] = RegistryService.registerService.selector;
        _setTargetFunctionRole(address(_registryService), functionSelector, REGISTRY_SERVICE_MANAGER_ROLE());
    }

    function _configureRegistrarRoles() private        
    {
        bytes4[] memory functionSelector = new bytes4[](1);
        address registryService = address(_registryService);

        functionSelector[0] = RegistryService.registerProduct.selector;
        _setTargetFunctionRole(registryService, functionSelector, PRODUCT_REGISTRAR_ROLE());

        functionSelector[0] = RegistryService.registerPool.selector;
        _setTargetFunctionRole(registryService, functionSelector, POOL_REGISTRAR_ROLE());

        functionSelector[0] = RegistryService.registerDistribution.selector;
        _setTargetFunctionRole(registryService, functionSelector, DISTRIBUTION_REGISTRAR_ROLE());

        functionSelector[0] = RegistryService.registerPolicy.selector;
        _setTargetFunctionRole(registryService, functionSelector, POLICY_REGISTRAR_ROLE());

        functionSelector[0] = RegistryService.registerBundle.selector;
        _setTargetFunctionRole(registryService, functionSelector, BUNDLE_REGISTRAR_ROLE());
    }
    
    // TODO do not set roles admins if granting/revoking through RegistryServiceManager!!! 
    function _configureRolesAdmins() private
    {
        // set REGISTRY_SERVCE_MANAGER_ROLE as admin for all REGISTRAR roles 
        _setRoleAdmin(PRODUCT_REGISTRAR_ROLE(), REGISTRY_SERVICE_MANAGER_ROLE());
        _setRoleAdmin(POOL_REGISTRAR_ROLE(), REGISTRY_SERVICE_MANAGER_ROLE());
        _setRoleAdmin(DISTRIBUTION_REGISTRAR_ROLE(), REGISTRY_SERVICE_MANAGER_ROLE());
        _setRoleAdmin(POLICY_REGISTRAR_ROLE(), REGISTRY_SERVICE_MANAGER_ROLE());
        _setRoleAdmin(BUNDLE_REGISTRAR_ROLE(), REGISTRY_SERVICE_MANAGER_ROLE());

        // set REGISTRY_SERVICE_ADMIN_ROLE as admin for REGISTRY_SERVCE_MANAGER_ROLE
        _setRoleAdmin(REGISTRY_SERVICE_MANAGER_ROLE(), REGISTRY_SERVICE_ADMIN_ROLE());
    }

    function _setTargetFunctionRole(address target, bytes4[] memory selectors, RoleId roleId) private {
        _accessManager.setTargetFunctionRole(target, selectors, roleId.toInt());        
    }

    function _setRoleAdmin(RoleId roleId, RoleId adminRoleId) private {
        _accessManager.setRoleAdmin(roleId.toInt(), adminRoleId.toInt());
    }
}
