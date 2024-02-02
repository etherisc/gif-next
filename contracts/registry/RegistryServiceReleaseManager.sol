// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";

import {NftId} from "../types/NftId.sol";
import {RoleId} from "../types/RoleId.sol";
import {ObjectType, zeroObjectType, SERVICE} from "../types/ObjectType.sol";
import {VersionPart, VersionPartLib} from "../types/Version.sol";

import {ContractDeployerLib} from "../shared/ContractDeployerLib.sol";
import {IVersionable} from "../shared/IVersionable.sol";
import {IService} from "../shared/IService.sol";
import {ProxyManager} from "../shared/ProxyManager.sol";

import {IRegistry} from "./IRegistry.sol";
import {Registry} from "./Registry.sol";
import {IRegistryService} from "./IRegistryService.sol";
import {RegistryService} from "./RegistryService.sol";
import {RegistryServiceManager} from "./RegistryServiceManager.sol";
import {RegistryServiceAccessManager} from "./RegistryServiceAccessManager.sol";


contract RegistryServiceReleaseManager is AccessManaged
{
    struct ReleaseInfo {
        ObjectType[] types; // service types of release
        uint awaitingRegistration;// "services left to register" counter 
    }

    // unique role for some service function
    struct ConfigInfo {
        bytes4[] selector;
        RoleId roleId; 
    }

    RegistryServiceAccessManager private immutable _accessManager;
    // TODO keep mapping of all proxy managers
    RegistryServiceManager private immutable _proxyManager;
    IRegistry private immutable _registry;

    VersionPart _latest;// latest active version
    VersionPart _initial;// first active version

    mapping(VersionPart version => ReleaseInfo info) _release;

    mapping(VersionPart version => mapping(ObjectType serviceType => ConfigInfo)) _config;

    // TODO parametrize initial implementations?
    constructor(
        RegistryServiceAccessManager accessManager/*,
        bytes memory registryByteCodeWithInitCode,
        bytes memory registryServiceByetCodeWithInitCode*/)
        AccessManaged(accessManager.authority())
    {
        _accessManager = accessManager;

        address owner = msg.sender;
        _proxyManager = new RegistryServiceManager(
            owner,
            address(this)
            /*initialAuthority, 
            type(Registry).creationCode, 
            type(RegistryService).creationCode*/
        );

        IRegistryService registryService = _proxyManager.getRegistryService();
        _registry = registryService.getRegistry();

        // get initial release version
        VersionPart initialVersion = registryService.getMajorVersion();
        //require(initialVersion.toInt() > 0, "Release manager: initial version 0");
        _initial = initialVersion;
        //_latest = zeroVersionPart();// 0 - no activated releases yet
        
        // create initial release
        //IRegistryService.FunctionConfig[] memory config = registryService.getConfig();
        (, bytes memory data) = registryService.getInitialInfo();
        IRegistryService.FunctionConfig[] memory config = abi.decode(data, (IRegistryService.FunctionConfig[]));

        _verifyAndStoreConfig(address(registryService), config);
    }

    function createNextRelease(IService registryService)
        external
        restricted // GIF_ADMIN_ROLE
        returns(NftId nftId)
    {
        // check interface
        // check authority

        (
            IRegistry.ObjectInfo memory info, 
            bytes memory data
        ) = _getAndVerifyContractInfo(registryService, SERVICE(), msg.sender);

        VersionPart nextVersion = getNextVersion();
        _verifyServiceInfo(info, nextVersion, SERVICE());

        IRegistryService.FunctionConfig[] memory config = abi.decode(data, (IRegistryService.FunctionConfig[]));
        _verifyAndStoreConfig(address(registryService), config);

        // close registry service
        // redundant -> only activateNextRelease() will make registry accessible
        //setTargetClosed(newRegistryService, true);

        nftId = _registry.registerService(info);
    }

    function registerService(IService service) 
        external
        restricted // GIF_MANAGER_ROLE
        returns(NftId nftId)
    {
        // check interface
        // check authority

        (
            IRegistry.ObjectInfo memory info, 
            //bytes memory data
        ) = _getAndVerifyContractInfo(service, SERVICE(), msg.sender);

        VersionPart nextVersion = getNextVersion();
        ObjectType serviceType = _verifyServiceInfo(info, nextVersion, zeroObjectType());

        bytes4[] memory selector = _config[nextVersion][serviceType].selector;

        // service type is in release
        if(selector.length == 0) { revert(); }

        // service of this type is not registered yet -> redundant -> checked by registry
        //if(roleId > 0) { revert(); }

        // release registration is ongoing
        // redundant? -> if in release and not yet registered -> guarantees awaitingRegistration > 0?
        /*if(_release[nextVersion].awaitingRegistration == 0) {
            revert ();
        }*/

        // never underflows
        _release[nextVersion].awaitingRegistration--;

        // setup and grant unique role
        address registryService = _registry.getServiceAddress(SERVICE(), nextVersion);
        RoleId roleId = _accessManager.setAndGrantUniqueRole(
            address(service), 
            registryService, 
            _config[nextVersion][serviceType].selector);

        _config[nextVersion][serviceType].roleId = roleId;

        nftId = _registry.registerService(info);
    }

    // TODO activate during last service registration
    function activateNextRelease() 
        external 
        restricted // GIF_ADMIN_ROLE
    {
        VersionPart nextVersion = getNextVersion();
        ReleaseInfo memory release = _release[nextVersion];
        
        // release fully deployed
        if(release.awaitingRegistration > 0) {
            revert();
        }

        //setTargetClosed(newRegistryService, false);

        _latest = nextVersion;

        bool active = true;
        _registry.setServiceActive(nextVersion, SERVICE(), active);
    }

    //--- view functions ----------------------------------------------------//

    function getProxyManager() external view returns(RegistryServiceManager)
    {
        return _proxyManager;
    }

    /*function getAccessManager()
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
    }*/

    function getNextVersion() public view returns(VersionPart) 
    {
        uint256 latest = _latest.toInt();

        return latest == 0 ?
            _initial : // no active releases yet
            VersionPartLib.toVersionPart(latest + 1);
    }

    function getLatestVersion() public view returns(VersionPart) {
        return _latest;
    }

    function getInitialVersion() public view returns(VersionPart) {
        return _initial;
    }

    //--- private functions ----------------------------------------------------//

    function _getAndVerifyContractInfo(
        IService service,
        ObjectType expectedType,
        address expectedOwner // assume alway valid, can not be 0
    )
        internal
        view
        returns(
            IRegistry.ObjectInfo memory info, 
            bytes memory data
        )
    {
        (
            info, 
            data
        ) = service.getInitialInfo();
        info.objectAddress = address(service);
        info.isInterceptor = false; // service is never interceptor, at least now

        if(info.objectType != expectedType) {// type is checked in registry anyway...but service logic may depend on expected value
            revert();// UnexpectedRegisterableType(expectedType, info.objectType);
        }

        address owner = info.initialOwner;

        if(owner != expectedOwner) { // registerable owner protection
            revert();// NotRegisterableOwner(expectedOwner);
        }

        if(owner == address(service)) {
            revert();// SelfRegistration();
        }

        /*if(owner == address(0)) { // never 0
            revert();// RegisterableOwnerIsZero();
        }*/
        
        if(_registry.isRegistered(owner)) { 
            revert();// RegisterableOwnerIsRegistered();
        }

        /*NftId parentNftId = info.parentNftId;
        IRegistry.ObjectInfo memory parentInfo = getRegistry().getObjectInfo(parentNftId);

        if(parentInfo.objectType != parentType) { // parent registration + type
            revert InvalidParent(parentNftId);
        }*/

        return(info, data);
    }

    function _verifyServiceInfo(
        IRegistry.ObjectInfo memory info,
        VersionPart expectedVersion,
        ObjectType expectedType
    )
        internal
        view
        returns(ObjectType)
    {
        (
            ObjectType serviceType,
            VersionPart serviceVersion
        ) = abi.decode(info.data, (ObjectType, VersionPart));

        if(serviceVersion != expectedVersion) {
            revert();
        }

        if(expectedType != zeroObjectType()) { 
            if(serviceType != expectedType) {
                revert();
            }
        }

        return serviceType;
    }

    function _verifyAndStoreConfig(address registryService, IRegistryService.FunctionConfig[] memory config)
        internal
    {
        VersionPart nextVersion = getNextVersion();

        for(uint idx = 0; idx < config.length; idx++)
        {
            ObjectType serviceType = config[idx].serviceType;
            bytes4[] memory selector = config[idx].selector;

            // not "registry service" type
            if(serviceType == SERVICE()) { revert(); }

            // at least one selector exists
            if(selector.length == 0) { revert(); }

            // no zero selectors
            for(uint jdx = 0; jdx < selector.length; jdx++) {
                if(selector[jdx] == 0) { revert(); }
            }

            // no overwrite
            if(_config[nextVersion][serviceType].selector.length > 0) { revert(); }
            
            _config[nextVersion][serviceType].selector = selector;
            _release[nextVersion].types.push(serviceType);
        }

        _release[nextVersion].awaitingRegistration = config.length;
    }
}
