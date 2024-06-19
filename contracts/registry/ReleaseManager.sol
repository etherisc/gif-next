// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {NftId} from "../type/NftId.sol";
import {RoleId, ADMIN_ROLE, PUBLIC_ROLE} from "../type/RoleId.sol";
import {ObjectType, ObjectTypeLib, POOL, RELEASE, REGISTRY, SERVICE, STAKING} from "../type/ObjectType.sol";
import {Version, VersionLib, VersionPart, VersionPartLib} from "../type/Version.sol";
import {Timestamp, TimestampLib, zeroTimestamp, ltTimestamp} from "../type/Timestamp.sol";
import {Seconds, SecondsLib} from "../type/Seconds.sol";
import {StateId, INITIAL, SCHEDULED, DEPLOYING, ACTIVE} from "../type/StateId.sol";
import {Version, VersionLib, VersionPart, VersionPartLib} from "../type/Version.sol";

import {IService} from "../shared/IService.sol";
import {AccessManagerExtendedWithDisableInitializeable} from "../shared/AccessManagerExtendedWithDisableInitializeable.sol";
import {ILifecycle} from "../shared/ILifecycle.sol";
import {INftOwnable} from "../shared/INftOwnable.sol";
import {IRegisterable} from "../shared/IRegisterable.sol";

import {IRegistry} from "./IRegistry.sol";
import {IRegistryLinked} from "../shared/IRegistryLinked.sol";
import {IRegistryService} from "./IRegistryService.sol";
import {IServiceAuthorization} from "./IServiceAuthorization.sol";
import {IAccessAdmin} from "../shared/IAccessAdmin.sol";
import {RegistryAdmin} from "./RegistryAdmin.sol";
import {Registry} from "./Registry.sol";
import {TokenRegistry} from "./TokenRegistry.sol";


contract ReleaseManager is 
    AccessManaged, 
    Initializable, 
    ILifecycle, 
    IRegistryLinked
{
    using ObjectTypeLib for ObjectType;

    uint256 public constant INITIAL_GIF_VERSION = 3;

    event LogReleaseCreation(VersionPart version, bytes32 salt, address authority); 
    event LogReleaseActivation(VersionPart version);

    // constructor
    error ErrorReleaseManagerNotRegistry(address registry);

    // createNextRelease
    error ErrorReleaseManagerReleaseCreationDisallowed(StateId currentStateId);

    // prepareRelease
    error ErrorReleaseManagerReleasePreparationDisallowed(StateId currentStateId);
    error ErrorReleaseManagerReleaseAlreadyPrepared(VersionPart version);
    error ErrorReleaseManagerVersionMismatch(VersionPart expectedVersion, VersionPart providedVersion);
    error ErrorReleaseManagerNoDomains(VersionPart version);

    // register staking
    //error ErrorReleaseManagerStakingAlreadySet(address stakingAddress);

    // registerService
    error ErrorReleaseManagerNoServiceRegistrationExpected();
    error ErrorReleaseManagerServiceRegistrationDisallowed(StateId currentStateId);
    error ErrorReleaseManagerServiceDomainMismatch(ObjectType expectedDomain, ObjectType actualDomain);
    error ErrorReleaseManagerNotService(IService service);
    error ErrorReleaseManagerServiceAddressInvalid(IService given, address expected);

    // activateNextRelease
    error ErrorReleaseManagerReleaseActivationDisallowed(StateId currentStateId);
    error ErrorReleaseManagerReleaseNotCreated(VersionPart releaseVersion);
    error ErrorReleaseManagerReleaseRegistrationNotFinished(VersionPart releaseVersion, uint awaitingRegistration);
    error ErrorReleaseManagerReleaseAlreadyActivated(VersionPart releaseVersion);

    // disableRelease
    error ErrorReleaseManagerReleaseNotActivated(VersionPart releaseVersion);
    error ErrorReleaseManagerReleaseAlreadyDisabled(VersionPart releaseVersion);

    // _verifyService
    error ErrorReleaseManagerServiceReleaseAuthorityMismatch(IService service, address serviceAuthority, address releaseAuthority);
    error ErrorReleaseManagerServiceReleaseVersionMismatch(IService service, VersionPart serviceVersion, VersionPart releaseVersion);

    // _verifyServiceInfo
    error ErrorReleaseManagerServiceInfoAddressInvalid(IService service, address expected);
    error ErrorReleaseManagerServiceInfoInterceptorInvalid(IService service, bool isInterceptor);
    error ErrorReleaseManagerServiceInfoTypeInvalid(IService service, ObjectType expected, ObjectType found);
    error ErrorReleaseManagerServiceInfoOwnerInvalid(IService service, address expected, address found);
    error ErrorReleaseManagerServiceSelfRegistration(IService service);
    error ErrorReleaseManagerServiceOwnerRegistered(IService service, address owner);

    Seconds public constant MIN_DISABLE_DELAY = Seconds.wrap(60 * 24 * 365); // 1 year

    RegistryAdmin private _admin;
    address public _releaseAccessManagerCodeAddress;
    Registry private _registry;
    IRegisterable private _staking;
    address private _stakingOwner;

    // TODO remove once it's clear that release authority will always be registry authority
    mapping(VersionPart version => address authority) internal _releaseAccessManager;
    mapping(VersionPart version => IRegistry.ReleaseInfo info) internal _releaseInfo;
    mapping(address registryService => VersionPart version) _releaseVersionByAddress;

    mapping(VersionPart version => IServiceAuthorization authz) internal _serviceAuthorization;

    VersionPart private _initial;// first active version    
    VersionPart internal _latest; // latest active version
    VersionPart internal _next; // version to create and activate 
    StateId internal _state; // current state of release manager

    uint256 internal _registeredServices;
    uint256 internal _servicesToRegister;

    constructor()
        AccessManaged(msg.sender)
    {
        //AccessManagerExtendedWithDisableInitializeable masterReleaseAccessManager = new AccessManagerExtendedWithDisableInitializeable();
        //masterReleaseAccessManager.initialize(address(this));
          //masterReleaseAccessManager.disable();
        //_releaseAccessManagerCodeAddress = address(masterReleaseAccessManager);

        _initial = VersionPartLib.toVersionPart(INITIAL_GIF_VERSION);
        _next = VersionPartLib.toVersionPart(INITIAL_GIF_VERSION - 1);
        _state = getInitialState(RELEASE());
    }

    function initialize(address registry) 
        public 
        initializer
    {
        // TODO move this part to RegistryLinked constructor
        if(!_isRegistry(registry)) {
            revert ErrorReleaseManagerNotRegistry(registry);
        }

        _registry = Registry(registry);
        setAuthority(_registry.getAuthority());
        _admin = RegistryAdmin(_registry.getRegistryAdminAddress());
    }

    /// @dev skips previous release if was not activated
    /// sets release manager into state SCHEDULED
    function createNextRelease()
        external
        restricted() // GIF_ADMIN_ROLE
        returns(VersionPart)
    {
        if (!isValidTransition(RELEASE(), _state, SCHEDULED())) {
            revert ErrorReleaseManagerReleaseCreationDisallowed(_state);
        }

        _next = VersionPartLib.toVersionPart(_next.toInt() + 1);
        _servicesToRegister = 0;
        _registeredServices = 0;
        _state = SCHEDULED();

        return _next;
    }

    function prepareNextRelease(
        IServiceAuthorization serviceAuthorization,
        bytes32 salt
    )
        external
        restricted() // GIF_MANAGER_ROLE
        returns(
            address authority, 
            VersionPart version, 
            bytes32 releaseSalt
        )
    {
        // TODO Any call to serviceAuthorization contract must be treated as a call to an external malicious contract
        // How can wrong authorizations tamper the core, releases or instances?
        (
            VersionPart releaseVersion,
            uint serviceDomainsCount
        ) = serviceAuthorization.getRelease();

        // verify authorizaion contract release matches with expected version
        if (releaseVersion != _next) {
            revert ErrorReleaseManagerVersionMismatch(_next, releaseVersion);
        }

        // sanity check to ensure service domain list is not empty
        if (serviceDomainsCount == 0) {
            revert ErrorReleaseManagerNoDomains(_next);
        }

        // verify release manager is in proper state to start deploying a next release
        if (!isValidTransition(RELEASE(), _state, DEPLOYING())) {
            revert ErrorReleaseManagerReleasePreparationDisallowed(_state);
        }

        // verify prepareNextRelease is only called once per release
        if(_servicesToRegister > 0) {
            revert ErrorReleaseManagerReleaseAlreadyPrepared(version);
        }

        // store release specific service authorization
        _serviceAuthorization[_next] = serviceAuthorization;

        // ensures unique salt
        // TODO CreateX have clones capability also
        // what would releaseSalt look like if used with CreateX in pemissioned mode?
        releaseSalt = keccak256(
            bytes.concat(
                bytes32(version.toInt()),
                salt));

        authority = _admin.authority();

        _releaseAccessManager[_next] = authority;
        _servicesToRegister = serviceDomainsCount;

        _state = DEPLOYING();

        emit LogReleaseCreation(version, releaseSalt, authority);
    }


    function registerService(IService service) 
        external
        restricted // GIF_MANAGER_ROLE
        returns(NftId nftId)
    {
        // TODO is it usefull to check transition from A to A?
        if (!isValidTransition(RELEASE(), _state, DEPLOYING())) {
            revert ErrorReleaseManagerServiceRegistrationDisallowed(_state);
        }

        if (_servicesToRegister == _registeredServices) {
            revert ErrorReleaseManagerNoServiceRegistrationExpected();
        }

        (
            IRegistry.ObjectInfo memory info,
            ObjectType domain,
            VersionPart version
        ) = _verifyService(service);

        ObjectType expectedDomain = _serviceAuthorization[version].getServiceDomains()[_registeredServices];
        if (service.getDomain() != expectedDomain) {
            revert ErrorReleaseManagerServiceDomainMismatch(expectedDomain, service.getDomain());
        }

        // checked in registry
        _releaseInfo[version].domains.push(domain);

        // register service with registry
        nftId = _registry.registerService(info, version, domain);
        _registeredServices++;

        service.linkToRegisteredNftId();

        // setup service authorization
        _admin.authorizeService(
            _serviceAuthorization[version], 
            service);

        // TODO consider to extend this to REGISTRY
        // special roles for registry/staking/pool service
        if (domain == STAKING() || domain == POOL()) {
            // TODO rename to grantServiceDomainRole()
            _admin.grantServiceRoleForAllVersions(service, domain);
        }

        if (_registeredServices < _servicesToRegister) {
            _state = DEPLOYING();
        } else {
            // TODO end state depends on (_awaitingRegistration == 0)
        }
    }


    function activateNextRelease() 
        external 
        restricted // GIF_ADMIN_ROLE
    {
        if (!isValidTransition(RELEASE(), _state, ACTIVE())) {
            revert ErrorReleaseManagerReleaseActivationDisallowed(_state);
        }

        // release fully deployed
        VersionPart version = _next;
        if(_registeredServices < _servicesToRegister) {
            revert ErrorReleaseManagerReleaseRegistrationNotFinished(version, _servicesToRegister - _registeredServices);
        }

        // release exists, registry service MUST exist
        address service = _registry.getServiceAddress(REGISTRY(), version);
        if(service == address(0)) {
            revert ErrorReleaseManagerReleaseNotCreated(version);
        }

        // release is not activated
        if(_releaseInfo[version].activatedAt.gtz()) {
            revert ErrorReleaseManagerReleaseAlreadyActivated(version);
        }

        _latest = version;
        _state = ACTIVE();

        _releaseVersionByAddress[service] = version;
        _releaseInfo[version].activatedAt = TimestampLib.blockTimestamp();

        emit LogReleaseActivation(version);
    }

    // release becomes disabled after delay expiration (can be reenabled before that)
    function disableRelease(VersionPart version, Seconds disableDelay)
        external
        restricted // GIF_ADMIN_ROLE
    {
        // release was activated
        if(_releaseInfo[version].activatedAt.eqz()) {
            revert ErrorReleaseManagerReleaseNotActivated(version);
        }

        // release not disabled already
        if(_releaseInfo[version].disabledAt.gtz()) {
            revert ErrorReleaseManagerReleaseAlreadyDisabled(version);
        }

        disableDelay = SecondsLib.toSeconds(Math.max(disableDelay.toInt(), MIN_DISABLE_DELAY.toInt()));
        
        // TODO come up with a substitute
        //_releaseAccessManager[version].disable();

        _releaseInfo[version].disabledAt = TimestampLib.blockTimestamp().addSeconds(disableDelay);
    }
    
    function enableRelease(VersionPart version)
        external
        restricted // GIF_ADMIN_ROLE
    {
        // release was disabled
        //if(_releaseInfo[version].disabledAt.eqz()) {
        //    revert ErrorReleaseManagerReleaseAlreadyEnabled(version);
        //}

        // reverts if disable delay expired
        // TODO come up with a substitute
        // _releaseAccessManager[version].enable();
        
        _releaseInfo[version].disabledAt = zeroTimestamp();
    }

    //--- view functions ----------------------------------------------------//

    function predictDeterministicAddress(
        address implementation,
        bytes32 salt,
        address deployer
    ) external pure returns (address predicted) {
        return Clones.predictDeterministicAddress(implementation, salt, deployer);
    }

    function isActiveRegistryService(address service) external view returns(bool) {
        VersionPart version = _releaseVersionByAddress[service];
        return isActiveRelease(version);
    }

    function isActiveRelease(VersionPart version) public view returns(bool) {
        return _releaseInfo[version].activatedAt.gtz();
    }

    function getReleaseInfo(VersionPart version) external view returns(IRegistry.ReleaseInfo memory) {
        return _releaseInfo[version];
    }

    function getNextVersion() public view returns(VersionPart) {
        return _next;
    }

    function getLatestVersion() external view returns(VersionPart) {
        return _latest;
    }

    function getInitialVersion() external view returns(VersionPart) {
        return _initial;
    }

    function getState() external view returns (StateId stateId) {
        return _state;
    }

    function getRemainingServicesToRegister() external view returns (uint256 services) {
        return _servicesToRegister - _registeredServices;
    }

    // TODO cleanup
    function getReleaseAccessManager(VersionPart version) external view returns(AccessManagerExtendedWithDisableInitializeable) {
        // return _releaseAccessManager[version];
    }

    // TODO token registry knows nothing about adfmin, only registry
    function getRegistryAdmin() external view returns (address) {
        return address(_admin);
    }

    //--- IRegistryLinked ------------------------------------------------------//

    function getRegistry() external view returns (IRegistry) {
        return _registry;
    }

    //--- ILifecycle -----------------------------------------------------------//

    function hasLifecycle(ObjectType objectType) external pure returns (bool) { return objectType == RELEASE(); }

    function getInitialState(ObjectType objectType) public pure returns (StateId stateId) { 
        if (objectType == RELEASE()) {
            stateId = INITIAL();
        }
    }

    function isValidTransition(
        ObjectType objectType,
        StateId fromId,
        StateId toId
    )
        public 
        pure 
        returns (bool isValid)
    {
        if (objectType != RELEASE()) { return false; }

        if (fromId == INITIAL() && toId == SCHEDULED()) { return true; }
        if (fromId == SCHEDULED() && toId == DEPLOYING()) { return true; }
        if (fromId == DEPLOYING() && toId == SCHEDULED()) { return true; }
        if (fromId == DEPLOYING() && toId == DEPLOYING()) { return true; }
        if (fromId == DEPLOYING() && toId == ACTIVE()) { return true; }
        // TODO active -> scheduled missing, add tests to cover this and more scenarios (#358)

        return false;
    }

    //--- private functions ----------------------------------------------------//

    function _verifyService(IService service)
        internal
        view
        returns(
            IRegistry.ObjectInfo memory serviceInfo,
            ObjectType serviceDomain, 
            VersionPart serviceVersion
        )
    {
        if(!service.supportsInterface(type(IService).interfaceId)) {
            revert ErrorReleaseManagerNotService(service);
        }

        address owner = msg.sender;
        address serviceAuthority = service.authority();
        serviceVersion = service.getVersion().toMajorPart();
        serviceDomain = service.getDomain();// checked in registry
        serviceInfo = service.getInitialInfo();

        _verifyServiceInfo(service, serviceInfo, owner);

        VersionPart releaseVersion = getNextVersion(); // never 0
        address releaseAuthority = address(_releaseAccessManager[releaseVersion]); // can be zero if registering service when release is not created

        // IMPORTANT: can not guarantee service access is actually controlled by authority
        if(serviceAuthority != releaseAuthority) {
            revert ErrorReleaseManagerServiceReleaseAuthorityMismatch(
                service,
                serviceAuthority,
                releaseAuthority);
        }

        if(serviceVersion != releaseVersion) {
            revert ErrorReleaseManagerServiceReleaseVersionMismatch(
                service,
                serviceVersion,
                releaseVersion);            
        }
    }


    function _verifyServiceInfo(
        IService service,
        IRegistry.ObjectInfo memory info,
        address expectedOwner // assume always valid, can not be 0
    )
        internal
        view
    {
        if(info.objectAddress != address(service)) {
            revert ErrorReleaseManagerServiceInfoAddressInvalid(service, address(service));
        }

        if(info.isInterceptor != false) { // service is never interceptor
            revert ErrorReleaseManagerServiceInfoInterceptorInvalid(service, info.isInterceptor);
        }

        if(info.objectType != SERVICE()) {// type is checked in registry anyway...but service logic may depend on expected value
            revert ErrorReleaseManagerServiceInfoTypeInvalid(service, SERVICE(), info.objectType);
        }

        address owner = info.initialOwner;

        if(owner != expectedOwner) { // registerable owner protection
            revert ErrorReleaseManagerServiceInfoOwnerInvalid(service, expectedOwner, owner); 
        }

        if(owner == address(service)) {
            revert ErrorReleaseManagerServiceSelfRegistration(service);
        }
        
        if(_registry.isRegistered(owner)) { 
            revert ErrorReleaseManagerServiceOwnerRegistered(service, owner);
        }
    }

    /// @dev returns true iff a the address passes some simple proxy tests.
    function _isRegistry(address registryAddress) internal view returns (bool) {

        // zero address is certainly not registry
        if (registryAddress == address(0)) {
            return false;
        }
        // TODO try catch and return false in case of revert
        // a just panic
        // check if contract returns a zero nft id for its own address
        if (IRegistry(registryAddress).getNftId(registryAddress).eqz()) {
            return false;
        }

        return true;
    }
}
