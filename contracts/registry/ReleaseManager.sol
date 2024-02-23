// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";

import {NftId} from "../types/NftId.sol";
import {RoleId} from "../types/RoleId.sol";
import {ObjectType, ObjectTypeLib, zeroObjectType, REGISTRY, SERVICE} from "../types/ObjectType.sol";
import {VersionPart, VersionPartLib} from "../types/Version.sol";
import {Timestamp, TimestampLib} from "../types/Timestamp.sol";

import {IService} from "../shared/IService.sol";

import {IRegistry} from "./IRegistry.sol";
import {Registry} from "./Registry.sol";
import {IRegistryService} from "./IRegistryService.sol";
import {RegistryAccessManager} from "./RegistryAccessManager.sol";


contract ReleaseManager is AccessManaged
{
    using ObjectTypeLib for ObjectType;

    event LogReleaseCreation(VersionPart version); 
    event LogReleaseActivation(VersionPart version);

    // createNextRelease
    error NotRegistryService();
    error UnexpectedServiceAuthority(address expected, address found);

    // registerService
    error NotService();

    // activateNextRelease
    error ReleaseNotCreated();
    error ReleaseRegistrationNotFinished();

    // _getAndVerifyContractInfo
    error UnexpectedRegisterableType(ObjectType expected, ObjectType found);
    error NotRegisterableOwner(address notOwner);
    error SelfRegistration();
    error RegisterableOwnerIsRegistered();

    // _verifyServiceInfo
    error UnexpectedServiceVersion(VersionPart expected, VersionPart found);
    error UnexpectedServiceDomain(ObjectType expected, ObjectType found);
    
    // _verifyAndStoreConfig
    error ConfigMissing();
    error ConfigServiceDomainInvalid(uint configArrayIndex, ObjectType domain);
    error ConfigSelectorZero(uint configArrayIndex);
    error SelectorAlreadyExists(VersionPart releaseVersion, ObjectType serviceDomain);


    RegistryAccessManager private immutable _accessManager;
    IRegistry private immutable _registry;

    VersionPart immutable _initial;// first active version    
    VersionPart _latest;// latest active version
    VersionPart _next;// version to create and activate 

    mapping(VersionPart version => IRegistry.ReleaseInfo info) _release;

    mapping(VersionPart version => mapping(ObjectType serviceDomain => bytes4)) _selector; // registry service function selector assigned to domain 

    uint _awaitingRegistration; // "services left to register" counter

    mapping(address registryService => bool isActive) _active;

    mapping(VersionPart version => bool isValid) _valid; // TODO refactor to use _active only

    constructor(
        RegistryAccessManager accessManager, 
        VersionPart initialVersion)
        AccessManaged(accessManager.authority())
    {
        require(initialVersion.toInt() > 0, "ReleaseManager: initial version is 0");

        _accessManager = accessManager;

        _initial = initialVersion;
        _next = initialVersion;

        _registry = new Registry();
    }

    /// @dev skips previous release if was not activated
    function createNextRelease()
        external
        restricted // GIF_ADMIN_ROLE
    {
        // allow to register new registry service for next version
        VersionPartLib.toVersionPart(_next.toInt() + 1);
        // disallow registration of regular services for next version while registry service is not registered 
        _awaitingRegistration = 0;

        emit LogReleaseCreation(_next); 
    }

    function activateNextRelease() 
        external 
        restricted // GIF_ADMIN_ROLE
    {
        VersionPart version = _next;
        address service = _registry.getServiceAddress(REGISTRY(), version);

        // release was created
        if(service == address(0)) {
            revert ReleaseNotCreated();
        }

        // release fully deployed
        if(_awaitingRegistration > 0) {
            revert ReleaseRegistrationNotFinished();
        }

        //setTargetClosed(service, false);

        _latest = version;

        _active[service] = true;
        _valid[version] = true;

        emit LogReleaseActivation(version);
    }

    // TODO deploy proxy and initialize with given implementation instead of using given proxy?
    // IMPORTANT: MUST never be possible to create with access/release manager, token registry
    // callable once per release after release creation, can not register regular services while registry service is not registered
    function registerRegistryService(IRegistryService service)
        external
        restricted // GIF_MANAGER_ROLE
        returns(NftId nftId)
    {
        if(!service.supportsInterface(type(IRegistryService).interfaceId)) {
            revert NotRegistryService();
        }
        // TODO unreliable! MUST guarantee the same authority -> how?
        address serviceAuthority = service.authority();
        if(serviceAuthority != authority()) {
            revert UnexpectedServiceAuthority(
                authority(), 
                serviceAuthority); 
        }

        (
            IRegistry.ObjectInfo memory info, 
            bytes memory data
        ) = _getAndVerifyContractInfo(service, SERVICE(), msg.sender);

        VersionPart version = _next;
        ObjectType domain = REGISTRY();
        _verifyServiceInfo(info, version, domain);

        _createRelease(data);

        //setTargetClosed(service, true);
        
        nftId = _registry.registerService(info, version, domain);

        // external call
        service.linkToRegisteredNftId();
    }

    // TODO adding service to release -> synchronized with proxy upgrades or simple addServiceToRelease(service, version, selector)?
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

        VersionPart version = _next;
        ObjectType domain = _release[version].domains[_awaitingRegistration];// reversed registration order of services specified in RegistryService config
        _verifyServiceInfo(info, version, domain);

        // setup and grant unique role if service does registrations
        bytes4[] memory selector = new bytes4[](1);
        selector[0] = _selector[version][domain];
        address registryService = _registry.getServiceAddress(REGISTRY(), version);
        if(selector[0] != 0) {
            _accessManager.setAndGrantUniqueRole(
                address(service), 
                registryService, 
                selector);
        }
        
        _awaitingRegistration--;

        nftId = _registry.registerService(info, version, domain);

        // external call
        service.linkToRegisteredNftId(); 
    }

    //--- view functions ----------------------------------------------------//

    function isActiveRegistryService(address service) external view returns(bool)
    {
        return _active[service];
    }

    function isValidRelease(VersionPart version) external view returns(bool)
    {
        return _valid[version];
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
        return _next;
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

        if(domain != expectedDomain) {
            revert UnexpectedServiceDomain(expectedDomain, domain);
        }

        return domain;
    }

    // TODO check if registry supports types specified in the config array
    function _createRelease(bytes memory configBytes)
        internal
    {
        VersionPart version = _next;
        IRegistryService.FunctionConfig[] memory config = abi.decode(configBytes, (IRegistryService.FunctionConfig[]));

        if(config.length == 0) {
            revert ConfigMissing();
        }
        // always in release
        _release[version].domains.push(REGISTRY());
        for(uint idx = 0; idx < config.length; idx++)
        {
            ObjectType domain = config[idx].serviceDomain;
            bytes4 selector = config[idx].selector;

            // not "registry service" / zero domain
            if(
                domain == REGISTRY() ||
                domain.eqz()
            ) { revert ConfigServiceDomainInvalid(idx, domain); } 

            // TODO can be zero -> e.g. duplicate domain, first with zero selector, second with non zero selector -> need to check _release[version].domains.contains(domain) instead
            // no overwrite
            if(_selector[version][domain] > 0) {
                revert SelectorAlreadyExists(version, domain); 
            }
            
            _selector[version][domain] = selector;
            _release[version].domains.push(domain);
        }
        // TODO set when activated?
        _release[version].createdAt = TimestampLib.blockTimestamp();
        //_release[version].updatedAt = TimestampLib.blockTimestamp();

        _awaitingRegistration = config.length;
    }
}
