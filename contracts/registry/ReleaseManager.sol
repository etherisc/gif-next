// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";

import {NftId} from "../type/NftId.sol";
import {RoleId} from "../type/RoleId.sol";
import {ObjectType, ObjectTypeLib, zeroObjectType, REGISTRY, SERVICE, STAKING} from "../type/ObjectType.sol";
import {Version, VersionLib, VersionPart, VersionPartLib} from "../type/Version.sol";
import {Timestamp, TimestampLib} from "../type/Timestamp.sol";

import {IRegisterable} from "../shared/IRegisterable.sol";
import {IRegistry} from "./IRegistry.sol";
import {IRegistryService} from "./IRegistryService.sol";
import {IService} from "../shared/IService.sol";
import {IStaking} from "../staking/IStaking.sol";

import {Registry} from "./Registry.sol";
import {RegistryAccessManager} from "./RegistryAccessManager.sol";
import {ServiceAuthorizationsLib} from "./ServiceAuthorizationsLib.sol";
import {TokenRegistry} from "./TokenRegistry.sol";

contract ReleaseManager is AccessManaged
{
    using ObjectTypeLib for ObjectType;

    event LogReleaseCreation(VersionPart version); 
    event LogReleaseActivation(VersionPart version);

    // createNextRelease
    error NotRegistryService();
    error UnexpectedServiceAuthority(address expected, address found);

    // register staking
    error ErrorReleaseManagerStakingAlreadySet(address stakingAddress);

    // registerService
    error NotService();

    // activateNextRelease
    error ReleaseNotCreated();
    error ReleaseRegistrationNotFinished();

    // _getAndVerifyContractInfo
    error ErrorReleaseManagerUnexpectedRegisterableAddress(address expected, address actual);
    error ErrorReleaseManagerIsInterceptorTrue();
    error UnexpectedRegisterableType(ObjectType expected, ObjectType found);
    error NotRegisterableOwner(address expectedOwner, address actualOwner);
    error SelfRegistration();
    error RegisterableOwnerIsRegistered();

    // _verifyService
    error UnexpectedServiceVersion(VersionPart expected, VersionPart found);
    error UnexpectedServiceDomain(ObjectType expected, ObjectType found);
    
    // _verifyAndStoreConfig
    error ConfigMissing();
    error ConfigServiceDomainInvalid(uint configArrayIndex, ObjectType domain);
    error ConfigSelectorZero(uint configArrayIndex);
    error SelectorAlreadyExists(VersionPart releaseVersion, ObjectType serviceDomain);

    RegistryAccessManager private immutable _accessManager;
    Registry private immutable _registry;
    TokenRegistry private immutable _tokenRegistry;
    IStaking private _staking;

    VersionPart immutable _initial;// first active major version    
    VersionPart _latest;// latest active major version
    VersionPart _next;// major version to create and activate 

    mapping(VersionPart majorVersion => IRegistry.ReleaseInfo info) _release;

    // registry service function selector assigned to domain 
    mapping(VersionPart majorVersion => mapping(ObjectType serviceDomain => bytes4[])) _selectors; 

    uint _awaitingRegistration; // "services left to register" counter

    mapping(address registryService => bool isActive) _active;

    mapping(VersionPart majorVersion => bool isValid) _valid; // TODO refactor to use _active only

    constructor(
        RegistryAccessManager accessManager, 
        VersionPart initialVersion,
        address dipTokenAddress
    )
        AccessManaged(accessManager.authority())
    {
        require(initialVersion.toInt() > 0, "ReleaseManager: initial version is 0");

        _accessManager = accessManager;

        _initial = initialVersion;
        _next = initialVersion;

        _registry = new Registry();
        _tokenRegistry = new TokenRegistry(
            address(_registry),
            dipTokenAddress);

        _registry.setTokenRegistry(address(_tokenRegistry));
    }

    function registerStaking(
        address stakingAddress,
        address stakingOwner
    )
        external
        restricted // GIF_ADMIN_ROLE
        returns(NftId nftId)
    {
        // verify staking contract
        _getAndVerifyContractInfo(stakingAddress, STAKING(), stakingOwner);
        _staking = IStaking(stakingAddress);

        nftId = _registry.registerStaking(
            stakingAddress,
            stakingOwner);

        _staking.linkToRegisteredNftId();
    }

    /// @dev skips previous release if was not activated
    function createNextRelease()
        external
        restricted // GIF_ADMIN_ROLE
    {
        // allow to register new registry service for next version
        // TODO check/test: assignment to _next likely missing ...
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

    // TODO implement reliable way this function can only be called directly after createNextRelease()
    // IMPORTANT: MUST never be possible to create with access/release manager, token registry
    // callable once per release after release creation
    // can not register regular services
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

        IRegistry.ObjectInfo memory info = _getAndVerifyContractInfo(address(service), SERVICE(), msg.sender);

        VersionPart majorVersion = _next;
        ObjectType domain = REGISTRY();
        _verifyService(service, majorVersion, domain);
        _createRelease(service.getFunctionConfigs());
        
        nftId = _registry.registerService(info, majorVersion, domain);

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

        IRegistry.ObjectInfo memory info = _getAndVerifyContractInfo(address(service), SERVICE(), msg.sender);
        VersionPart majorVersion = getNextVersion();
        ObjectType domain = _release[majorVersion].domains[_awaitingRegistration];// reversed registration order of services specified in RegistryService config
        _verifyService(service, majorVersion, domain);

        // setup and grant unique role if service does registrations
        bytes4[] memory selectors = _selectors[majorVersion][domain];
        address registryService = _registry.getServiceAddress(REGISTRY(), majorVersion);
        if(selectors.length > 0) {
            _accessManager.setAndGrantUniqueRole(
                address(service), 
                registryService, 
                selectors);
        }
        
        // service to service authorization
        ServiceAuthorizationsLib.ServiceAuthorization memory authz = ServiceAuthorizationsLib.getAuthorizations(domain);
        for(uint8 idx = 0; idx < authz.authorizedRole.length; idx++) {
            _accessManager.setTargetFunctionRole(
                address(service), 
                authz.authorizedSelectors[idx], 
                authz.authorizedRole[idx]);
        }

        _awaitingRegistration--;

        nftId = _registry.registerService(info, majorVersion, domain);

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

    function getRegistryAddress() external view returns(address)
    {
        return address(_registry);
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
        address registerableAddress,
        ObjectType expectedType,
        address expectedOwner // assume always valid, can not be 0
    )
        internal
        // view
        returns(
            IRegistry.ObjectInfo memory info
        )
    {
        info = IRegisterable(registerableAddress).getInitialInfo();

        if(info.objectAddress != registerableAddress) {
            revert ErrorReleaseManagerUnexpectedRegisterableAddress(registerableAddress, info.objectAddress);
        }

        if(info.isInterceptor) {
            revert ErrorReleaseManagerIsInterceptorTrue();
        }

        if(info.objectType != expectedType) {// type is checked in registry anyway...but service logic may depend on expected value
            revert UnexpectedRegisterableType(expectedType, info.objectType);
        }

        address owner = info.initialOwner;

        if(owner != expectedOwner) { // registerable owner protection
            revert NotRegisterableOwner(expectedOwner, owner); 
        }

        if(owner == address(registerableAddress)) {
            revert SelfRegistration();
        }
        
        if(_registry.isRegistered(owner)) { 
            revert RegisterableOwnerIsRegistered(); 
        }
    }

    function _verifyService(
        IService service,
        VersionPart expectedVersion,
        ObjectType expectedDomain
    )
        internal
        view
        returns(ObjectType)
    {
        Version version = service.getVersion();
        VersionPart majorVersion = version.toMajorPart();
        if(majorVersion != expectedVersion) {
            revert UnexpectedServiceVersion(expectedVersion, majorVersion);
        }

        if(service.getDomain() != expectedDomain) {
            revert UnexpectedServiceDomain(expectedDomain, service.getDomain());
        }

        return expectedDomain;
    }

    // TODO check if registry supports types specified in the config array
    function _createRelease(IRegistryService.FunctionConfig[] memory config)
        internal
    {
        VersionPart version = getNextVersion();

        if(config.length == 0) {
            revert ConfigMissing();
        }
        // always in release
        _release[version].domains.push(REGISTRY());
        for(uint idx = 0; idx < config.length; idx++)
        {
            ObjectType domain = config[idx].serviceDomain;
            // not "registry service" / zero domain
            if(
                domain == REGISTRY() ||
                domain.eqz()
            ) { revert ConfigServiceDomainInvalid(idx, domain); } 

            bytes4[] memory selectors = config[idx].authorizedSelectors;

            // TODO can be zero -> e.g. duplicate domain, first with zero selector, second with non zero selector -> need to check _release[version].domains.contains(domain) instead
            // no overwrite
            if(_selectors[version][domain].length > 0) {
                revert SelectorAlreadyExists(version, domain); 
            }
            
            _selectors[version][domain] = selectors;
            _release[version].domains.push(domain);
        }
        // TODO set when activated?
        _release[version].createdAt = TimestampLib.blockTimestamp();
        //_release[version].updatedAt = TimestampLib.blockTimestamp();

        _awaitingRegistration = config.length;
    }
}
