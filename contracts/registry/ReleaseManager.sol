// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";

import {NftId} from "../types/NftId.sol";
import {RoleId} from "../types/RoleId.sol";
import {ObjectType, zeroObjectType, REGISTRY, SERVICE} from "../types/ObjectType.sol";
import {VersionPart, VersionPartLib} from "../types/Version.sol";

import {IService} from "../shared/IService.sol";

import {IRegistry} from "./IRegistry.sol";
import {Registry} from "./Registry.sol";
import {IRegistryService} from "./IRegistryService.sol";
import {RegistryAccessManager} from "./RegistryAccessManager.sol";


contract ReleaseManager is AccessManaged
{
    event LogReleaseCreation(VersionPart version, IService registryService); 
    event LogReleaseActivation(VersionPart version);

    // createNextRelease
    error NotRegistryService();
    error UnexpectedServiceAuthority(address expected, address found);

    // registerService
    error NotService();
    error ServiceNotInRelease(IService service, ObjectType serviceDomain);

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

    // unique role for some service function
    struct ConfigInfo {
        bytes4[] selector; // selector used by service
        RoleId roleId; // roleId granted to service
    }

    RegistryAccessManager private immutable _accessManager;
    IRegistry private immutable _registry;

    VersionPart _latest;// latest active version
    VersionPart immutable _initial;// first active version

    mapping(VersionPart version => IRegistry.ReleaseInfo info) _release;

    mapping(VersionPart version => mapping(ObjectType serviceDomain => ConfigInfo)) _config;

    uint _awaitingRegistration; // "services left to register" counter

    mapping(address registryService => bool isActive) _active;

    constructor(
        RegistryAccessManager accessManager, 
        VersionPart initialVersion)
        AccessManaged(accessManager.authority())
    {
        require(initialVersion.toInt() > 0, "ReleaseManager: initial version is 0");

        _accessManager = accessManager;

        _initial = initialVersion;

        _registry = new Registry();
    }

    // TODO deploy proxy and initialize with given implementation instead of using given proxy?
    // IMPORTANT: MUST never be possible to create with access/release manager, token registry
    function createNextRelease(IRegistryService service)
        external
        restricted // GIF_ADMIN_ROLE
        returns(NftId nftId)
    {
        if(!service.supportsInterface(type(IRegistryService).interfaceId)) {
            revert NotRegistryService();
        }
        // TODO unreliable! MUST guarantee the same authority -> how?
        if(service.authority() != authority()) {
            revert UnexpectedServiceAuthority(
                authority(), 
                service.authority()); 
        }

        (
            IRegistry.ObjectInfo memory info, 
            bytes memory data
        ) = _getAndVerifyContractInfo(service, SERVICE(), msg.sender);

        VersionPart version = getNextVersion();
        ObjectType domain = REGISTRY();
        _verifyServiceInfo(info, version, domain);

        _verifyAndStoreConfig(data);

        //setTargetClosed(newRegistryService, true);
        
        nftId = _registry.registerService(info, version, domain);

        // external call
        service.linkToRegisteredNftId();

        emit LogReleaseCreation(version, service); 
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

        VersionPart version = getNextVersion();
        ObjectType domain = _verifyServiceInfo(info, version, zeroObjectType());

        bytes4[] memory selector = _config[version][domain].selector;

        // service type is in release
        if(selector.length == 0) {
            revert ServiceNotInRelease(service, domain);
        }

        // setup and grant unique role
        address registryService = _registry.getServiceAddress(REGISTRY(), version);
        RoleId roleId = _accessManager.setAndGrantUniqueRole(
            address(service), 
            registryService, 
            selector);

        _config[version][domain].roleId = roleId;
        _awaitingRegistration--;

        // activate release
        if(_awaitingRegistration == 0) {
            _latest = version;
            _active[registryService] = true;  

            emit LogReleaseActivation(version);
        }

        nftId = _registry.registerService(info, version, domain);

        // external call
        service.linkToRegisteredNftId(); 
    }

    /*function activateNextRelease() 
        external 
        restricted // GIF_ADMIN_ROLE
    {
        VersionPart version = getNextVersion();
        address service = _registry.getServiceAddress(REGISTRY(), version);

        // release was created
        if(service == address(0)) {
            revert ReleaseNotCreated();
        }

        // release fully deployed
        if(_awaitingRegistration > 0) {
            revert ReleaseRegistrationNotFinished();
        }

        //setTargetClosed(newRegistryService, false);

        _latest = version;
        _active[service] = true;

        LogReleaseActivation(version);
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

    function getReleaseInfo(VersionPart version) external view returns(IRegistry.ReleaseInfo memory)
    {
        return _release[version];
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
        ObjectType expectedDomain
    )
        internal
        view
        returns(ObjectType)
    {
        (
            ObjectType domain,
            VersionPart version
        ) = abi.decode(info.data, (ObjectType, VersionPart));

        if(version != expectedVersion) {
            revert UnexpectedServiceVersion(expectedVersion, version);
        }

        if(expectedDomain != zeroObjectType()) { 
            if(domain != expectedDomain) {
                revert UnexpectedServiceDomain(expectedDomain, domain);
            }
        }

        return domain;
    }

    function _verifyAndStoreConfig(bytes memory configBytes)
        internal
    {
        VersionPart version = getNextVersion();
        IRegistryService.FunctionConfig[] memory config = abi.decode(configBytes, (IRegistryService.FunctionConfig[]));

        if(config.length == 0) {
            revert ConfigMissing();
        }
        // always in release
        _release[version].domains.push(REGISTRY());
        for(uint idx = 0; idx < config.length; idx++)
        {
            ObjectType domain = config[idx].serviceDomain;
            bytes4[] memory selector = config[idx].selector;

            // not "registry service" domain
            if(domain == REGISTRY()) { revert ConfigServiceDomainInvalid(); } 

            // at least one selector exists
            if(selector.length == 0) { revert ConfigSelectorMissing(); }

            // no zero selectors
            for(uint jdx = 0; jdx < selector.length; jdx++) {
                if(selector[jdx] == 0) { revert ConfigSelectorZero(); }
            }

            // no overwrite
            if(_config[version][domain].selector.length > 0) {
                revert ConfigSelectorAlreadyExists(version, domain); 
            }
            
            _config[version][domain].selector = selector;
            _release[version].domains.push(domain);
        }

        _awaitingRegistration = config.length;
    }
}
