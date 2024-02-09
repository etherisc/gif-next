// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";

import {NftId} from "../types/NftId.sol";
import {RoleId} from "../types/RoleId.sol";
import {ObjectType, zeroObjectType, REGISTRY, SERVICE} from "../types/ObjectType.sol";
import {VersionPart, VersionPartLib} from "../types/Version.sol";

import {IVersionable} from "../shared/IVersionable.sol";
import {IService} from "../shared/IService.sol";
import {ProxyManager} from "../shared/ProxyManager.sol";

import {IRegistry} from "./IRegistry.sol";
import {Registry} from "./Registry.sol";
import {IRegistryService} from "./IRegistryService.sol";
import {RegistryService} from "./RegistryService.sol";
import {RegistryServiceManager} from "./RegistryServiceManager.sol";
import {RegistryAccessManager} from "./RegistryAccessManager.sol";


contract ReleaseManager is AccessManaged
{
    event LogReleaseCreation(VersionPart version, IService registryService); 
    event LogServiceRegistration(VersionPart majorVersion, ObjectType serviceDomain); 
    event LogReleaseActivation(VersionPart version);

    // createNextRelease
    error NotRegistryService();
    error UnexpectedServiceAuthority(address expected, address found);

    // registerService
    error NotService();
    error ServiceNotInRelease(IService service, ObjectType serviceDomain);
    error ServiceAlreadyRegistered(address service);

    // activateNextRelease
    //error ReleaseNotCreated();
    //error ReleaseRegistrationNotFinished();

    // _getAndVerifyContractInfo
    error UnexpectedRegisterableType(ObjectType expected, ObjectType found);
    error NotRegisterableOwner(address expectedOwner);
    error SelfRegistration();
    error RegisterableOwnerIsRegistered();

    // _verifyServiceInfo
    error UnexpectedServiceVersion(VersionPart expected, VersionPart found);
    error UnexpectedServiceDomain(ObjectType expected, ObjectType found);
    
    // _verifyAndStoreConfig
    error ConfigMissing();
    error ConfigServiceDomainInvalid();
    error ConfigSelectorMissing(); 
    error ConfigSelectorZero(); 
    error ConfigSelectorAlreadyExists(VersionPart serviceVersion, ObjectType serviceDomain);

    struct ReleaseInfo {
        ObjectType[] types; // service types in release
    }

    // unique role for some service function
    struct ConfigInfo {
        bytes4[] selector; // selector used by service
        RoleId roleId; // roleId granted to service
    }

    RegistryAccessManager private immutable _accessManager;
    IRegistry private immutable _registry;

    VersionPart _latest;// latest active version
    VersionPart immutable _initial;// first active version

    mapping(VersionPart version => ReleaseInfo info) _release;

    mapping(VersionPart version => mapping(ObjectType serviceDomain => ConfigInfo)) _config;

    mapping(VersionPart version => mapping(ObjectType serviceDomain => address)) _service;

    uint _awaitingRegistration; // "services left to register" counter

    mapping(address registryService => bool isActive) _active;

    constructor(
        RegistryAccessManager accessManager, 
        VersionPart initialVersion)
        AccessManaged(accessManager.authority())
    {
        require(address(accessManager) > address(0));
        require(initialVersion.toInt() > 0);

        _accessManager = accessManager;

        _initial = initialVersion;

        _registry = new Registry();
    }

    // TODO deploy proxy and initialize with given implementation instead of using given proxy?
    // IMPORTANT: MUST never be possible to create with access/release manager, token registry
    function createNextRelease(IRegistryService registryService)
        external
        restricted // GIF_ADMIN_ROLE
        returns(NftId nftId)
    {
        if(!registryService.supportsInterface(type(IRegistryService).interfaceId)) {
            revert NotRegistryService();
        }
        // TODO unreliable! MUST guarantee the same authority -> how?
        if(registryService.authority() != authority()) {
            revert UnexpectedServiceAuthority(
                authority(), 
                registryService.authority()); 
        }

        (
            IRegistry.ObjectInfo memory info, 
            bytes memory data
        ) = _getAndVerifyContractInfo(registryService, SERVICE(), msg.sender);

        VersionPart nextVersion = getNextVersion();
        ObjectType serviceDomain = REGISTRY();
        _verifyServiceInfo(info, nextVersion, serviceDomain);

        _verifyAndStoreConfig(data);

        //setTargetClosed(newRegistryService, true);

        _registerService(address(registryService), nextVersion, serviceDomain);
        
        nftId = _registry.registerService(info);

        // external call
        registryService.linkToRegisteredNftId();

        emit LogReleaseCreation(nextVersion, registryService); 
    }

    // TODO adding service to release -> synchronized with proxy upgrades
    // TODO removing service from release? -> set _active to false forever, but keep all other records?
    function registerService(IService service) 
        external
        restricted // GIF_MANAGER_ROLE
        returns(NftId nftId)
    {
        if(!service.supportsInterface(type(IService).interfaceId)) {
            revert NotService();
        }

        (
            IRegistry.ObjectInfo memory info, 
            //bytes memory data
        ) = _getAndVerifyContractInfo(service, SERVICE(), msg.sender);

        VersionPart nextVersion = getNextVersion();
        ObjectType serviceDomain = _verifyServiceInfo(info, nextVersion, zeroObjectType());

        bytes4[] memory selector = _config[nextVersion][serviceDomain].selector;

        // service type is in release
        if(selector.length == 0) {
            revert ServiceNotInRelease(service, serviceDomain); 
        }

        // setup and grant unique role
        address registryService = getService(nextVersion, REGISTRY());
        RoleId roleId = _accessManager.setAndGrantUniqueRole(
            address(service), 
            registryService, 
            selector);

        _config[nextVersion][serviceDomain].roleId = roleId;
        _awaitingRegistration--;

        // activate release
        if(_awaitingRegistration == 0) {
            _latest = nextVersion;
            _active[registryService] = true;  

            emit LogReleaseActivation(nextVersion);
        }

        _registerService(address(service), nextVersion, serviceDomain);

        nftId = _registry.registerService(info);

        // external call
        service.linkToRegisteredNftId(); 
    }

    /*function activateNextRelease() 
        external 
        restricted // GIF_ADMIN_ROLE
    {
        VersionPart nextVersion = getNextVersion();
        address service = _service[nextVersion][REGISTRY()];

        // release was created
        if(service == address(0)) {
            revert ReleaseNotCreated();
        }

        // release fully deployed
        if(_awaitingRegistration > 0) {
            revert ReleaseRegistrationNotFinished();
        }

        //setTargetClosed(newRegistryService, false);

        _latest = nextVersion;
        _active[service] = true;

        LogReleaseActivation(nextVersion);
    }*/

    //--- view functions ----------------------------------------------------//

    function isActiveRegistryService(address service) external view returns(bool)
    {
        return _active[service];
    }

    function getRegistry() external view returns(address)
    {
        return (address(_registry));
    }

    function getService(VersionPart serviceVersion, ObjectType serviceDomain) public view returns(address)
    {
        return _service[serviceVersion][serviceDomain];
    }

    function getReleaseInfo(VersionPart releaseVersion) external view returns(ReleaseInfo memory)
    {
        return _release[releaseVersion];
    }

    function getNextVersion() public view returns(VersionPart) 
    {
        uint256 latest = _latest.toInt();

        return latest == 0 ?
            _initial : // no active releases yet
            VersionPartLib.toVersionPart(latest + 1);
    }

    function getLatestVersion() external view returns(VersionPart) {
        return _latest;
    }

    function getInitialVersion() external view returns(VersionPart) {
        return _initial;
    }

    //--- private functions ----------------------------------------------------//

    function _registerService(address service, VersionPart version, ObjectType serviceDomain) 
        internal
    {
        if(_service[version][serviceDomain] > address(0)) {
            revert ServiceAlreadyRegistered(service);
        }

        _service[version][serviceDomain] = service;

        emit LogServiceRegistration(version, serviceDomain);
    }

    function _getAndVerifyContractInfo(
        IService service,
        ObjectType expectedType,
        address expectedOwner // assume always valid, can not be 0
    )
        internal
        view
        returns(
            IRegistry.ObjectInfo memory info, 
            bytes memory data
        )
    {
        (info, data) = service.getInitialInfo();
        info.objectAddress = address(service);
        info.isInterceptor = false; // service is never interceptor, at least now

        if(info.objectType != expectedType) {// type is checked in registry anyway...but service logic may depend on expected value
            revert UnexpectedRegisterableType(expectedType, info.objectType);
        }

        address owner = info.initialOwner;

        if(owner != expectedOwner) { // registerable owner protection
            revert NotRegisterableOwner(expectedOwner); 
        }

        if(owner == address(service)) {
            revert SelfRegistration();
        }

        /*if(owner == address(0)) { // never 0
            revert();// RegisterableOwnerIsZero();
        }*/
        
        if(_registry.isRegistered(owner)) { 
            revert RegisterableOwnerIsRegistered(); 
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
            ObjectType serviceDomain,
            VersionPart serviceVersion
        ) = abi.decode(info.data, (ObjectType, VersionPart));

        if(serviceVersion != expectedVersion) {
            revert UnexpectedServiceVersion(expectedVersion, serviceVersion);
        }

        if(expectedType != zeroObjectType()) { 
            if(serviceDomain != expectedType) {
                revert UnexpectedServiceDomain(expectedType, serviceDomain);
            }
        }

        return serviceDomain;
    }

    function _verifyAndStoreConfig(bytes memory configBytes)
        internal
    {
        VersionPart nextVersion = getNextVersion();
        IRegistryService.FunctionConfig[] memory config = abi.decode(configBytes, (IRegistryService.FunctionConfig[]));

        if(config.length == 0) {
            revert ConfigMissing();
        }
        // always in release
        _release[nextVersion].types.push(REGISTRY());

        for(uint idx = 0; idx < config.length; idx++)
        {
            ObjectType serviceDomain = config[idx].serviceDomain;
            bytes4[] memory selector = config[idx].selector;

            // not "registry service" type
            if(serviceDomain == REGISTRY()) { revert ConfigServiceDomainInvalid(); } 

            // at least one selector exists
            if(selector.length == 0) { revert ConfigSelectorMissing(); }

            // no zero selectors
            for(uint jdx = 0; jdx < selector.length; jdx++) {
                if(selector[jdx] == 0) { revert ConfigSelectorZero(); }
            }

            // no overwrite
            if(_config[nextVersion][serviceDomain].selector.length > 0) { 
                revert ConfigSelectorAlreadyExists(nextVersion, serviceDomain); 
            }
            
            _config[nextVersion][serviceDomain].selector = selector;
            _release[nextVersion].types.push(serviceDomain);
        }

        _awaitingRegistration = config.length;
    }
}
