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
import {ReleaseLifecycle} from "./ReleaseLifecycle.sol";


contract ReleaseManager is 
    AccessManaged,
    ReleaseLifecycle, 
    IRegistryLinked
{
    using ObjectTypeLib for ObjectType;

    uint256 public constant INITIAL_GIF_VERSION = 3;

    event LogReleaseCreation(VersionPart version, bytes32 salt, address authority); 
    event LogReleaseActivation(VersionPart version);

    // constructor
    error ErrorReleaseManagerNotRegistry(Registry registry);

    // createNextRelease
    error ErrorReleaseManagerReleaseCreationDisallowed(VersionPart version, StateId currentStateId);

    // prepareRelease
    error ErrorReleaseManagerReleasePreparationDisallowed(VersionPart version, StateId currentStateId);
    error ErrorReleaseManagerReleaseAlreadyPrepared(VersionPart version, StateId currentStateId);
    error ErrorReleaseManagerVersionMismatch(VersionPart expected, VersionPart actual);
    error ErrorReleaseManagerNoDomains(VersionPart version);

    // register staking
    //error ErrorReleaseManagerStakingAlreadySet(address stakingAddress);

    // registerService
    error ErrorReleaseManagerNoServiceRegistrationExpected();
    error ErrorReleaseManagerServiceRegistrationDisallowed(StateId currentStateId);
    error ErrorReleaseManagerServiceDomainMismatch(ObjectType expectedDomain, ObjectType actualDomain);
    error ErrorReleaseManagerNotService(address notService);
    error ErrorReleaseManagerServiceAddressMismatch(address expected, address actual);

    // activateNextRelease
    error ErrorReleaseManagerReleaseActivationDisallowed(VersionPart releaseVersion, StateId currentStateId);
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
    mapping(VersionPart verson => StateId releaseState) _state;

    uint256 internal _registeredServices;
    uint256 internal _servicesToRegister;

    constructor(Registry registry)
        AccessManaged(msg.sender)
    {
        // TODO move this part to RegistryLinked constructor
        if(!_isRegistry(address(registry))) {
            revert ErrorReleaseManagerNotRegistry(registry);
        }

        setAuthority(registry.getAuthority());

        _registry = registry;
        _admin = RegistryAdmin(_registry.getRegistryAdminAddress());

        _initial = VersionPartLib.toVersionPart(INITIAL_GIF_VERSION);
        _next = VersionPartLib.toVersionPart(INITIAL_GIF_VERSION - 1);

        //AccessManagerExtendedWithDisableInitializeable masterReleaseAccessManager = new AccessManagerExtendedWithDisableInitializeable();
        //masterReleaseAccessManager.initialize(address(this));
          //masterReleaseAccessManager.disable();
        //_releaseAccessManagerCodeAddress = address(masterReleaseAccessManager);
    }

    /// @dev skips previous release if was not activated
    /// sets next release into state SCHEDULED
    function createNextRelease()
        external
        restricted() // GIF_ADMIN_ROLE
        returns(VersionPart)
    {
        _next = VersionPartLib.toVersionPart(_next.toInt() + 1);
        _servicesToRegister = 0;
        _registeredServices = 0;
        _state[_next] = getInitialState(RELEASE());

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

        version = _next;
        StateId state = _state[version];
        StateId newState = DEPLOYING();

        // verify release manager is in proper state to start deploying a next release
        if (!isValidTransition(RELEASE(), state, newState)) {
            revert ErrorReleaseManagerReleasePreparationDisallowed(version, state);
        }

        // verify prepareNextRelease is only called once per release
        if(_servicesToRegister > 0) {
            revert ErrorReleaseManagerReleaseAlreadyPrepared(version, state);
        }

        // ensures unique salt
        // TODO CreateX have clones capability also
        // what would releaseSalt look like if used with CreateX in pemissioned mode?
        releaseSalt = keccak256(
            bytes.concat(
                bytes32(version.toInt()),
                salt));

        authority = _admin.authority();
        _serviceAuthorization[_next] = serviceAuthorization;
        _releaseAccessManager[_next] = authority;
        _servicesToRegister = serviceDomainsCount;
        _state[version] = newState;
/*
        _releaseInfo[version].version = version;
        _releaseInfo[version].salt = releaseSalt;
        _releaseInfo[version].addresses = addresses;
        _releaseInfo[version].names = names;
        _releaseInfo[version].serviceRoles = serviceRoles;
        _releaseInfo[version].serviceRoleNames = serviceRoleNames;
        _releaseInfo[version].functionRoles = functionRoles;
        _releaseInfo[version].functionRoleNames = functionRoleNames;
        _releaseInfo[version].selectors = selectors;
*/

        emit LogReleaseCreation(version, releaseSalt, authority);
    }

    // TODO this function can have 0 args -> use stored addresses from prepareNextRelease()
    // TODO given precomputed and stored here addresses we can check address.codeHash == expectedCodeHash
    //      expected hash is provided in prepareNextRelease() and stored here
    function registerService(IService service) 
        external
        restricted // GIF_MANAGER_ROLE
        returns(NftId nftId)
    {
        VersionPart releaseVersion = _next;
        StateId state = _state[releaseVersion];

        // release in state DEPLOYING
        if (!isValidTransition(RELEASE(), state, DEPLOYING())) {
            // TOOD name must represent failed state transition
            revert ErrorReleaseManagerServiceRegistrationDisallowed(state);
        }

        // not all services are registered
        if (_servicesToRegister == _registeredServices) {
            revert ErrorReleaseManagerNoServiceRegistrationExpected();
        }

        // service can work with release manager
        (
            IRegistry.ObjectInfo memory info,
            ObjectType serviceDomain,
            VersionPart serviceVersion
        ) = _verifyService(service);

        // service domain matches defined in release config
        ObjectType expectedDomain = _serviceAuthorization[releaseVersion].getServiceDomain(_registeredServices);
        if (serviceDomain != expectedDomain) {
            revert ErrorReleaseManagerServiceDomainMismatch(expectedDomain, serviceDomain);
        }

        // service address matches defined in release config
        /*address expectedAddress = _serviceAuthorization[releaseVersion].getServiceAddress(expectedDomain);
        if(address(service) != expectedAddress) {
            //revert ErrorReleaseManagerServiceAddressMismatch(expectedAddress, address(service));
        }*/

        // checked in registry
        _releaseInfo[releaseVersion].domains.push(serviceDomain);

        _state[releaseVersion] = DEPLOYING();
        _registeredServices++;

        // setup service authorization
        _admin.authorizeService(
            _serviceAuthorization[releaseVersion], 
            service);

        // TODO consider to extend this to REGISTRY
        // special roles for registry/staking/pool service
        if (serviceDomain == STAKING() || serviceDomain == POOL()) {
            // TODO rename to grantServiceDomainRole()
            _admin.grantServiceRoleForAllVersions(service, serviceDomain);
        }

        // register service with registry
        nftId = _registry.registerService(info, serviceVersion, serviceDomain);
        service.linkToRegisteredNftId();
    }


    function activateNextRelease() 
        external 
        restricted // GIF_ADMIN_ROLE
    {
        VersionPart version = _next;
        StateId state = _state[version];
        StateId newState = ACTIVE();

        if (!isValidTransition(RELEASE(), state, newState)) {
            revert ErrorReleaseManagerReleaseActivationDisallowed(version, state);
        }

        // release fully deployed
        if(_registeredServices < _servicesToRegister) {
            revert ErrorReleaseManagerReleaseRegistrationNotFinished(version, _servicesToRegister - _registeredServices);
        }

        // release exists, registry service MUST exist
        address service = _registry.getServiceAddress(REGISTRY(), version);
        if(service == address(0)) {
            revert ErrorReleaseManagerReleaseNotCreated(version);
        }

        // release is not activated -> redundant with state transition check
        /*if(_releaseInfo[version].activatedAt.gtz()) {
            revert ErrorReleaseManagerReleaseAlreadyActivated(version);
        }*/

        _latest = version;
        _state[version] = newState;

        _releaseVersionByAddress[service] = version;
        _releaseInfo[version].activatedAt = TimestampLib.blockTimestamp();

        emit LogReleaseActivation(version);
    }

    // release becomes disabled after delay expiration (can be reenabled before that)
    function disableRelease(VersionPart version, Seconds disableDelay)
        external
        restricted // GIF_ADMIN_ROLE
    {
        // TODO add state check / change -> check with matthias branch?
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

    function getState(VersionPart version) external view returns (StateId stateId) {
        return _state[version];
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
            revert ErrorReleaseManagerNotService(address(service));
        }

        address owner = msg.sender;
        address serviceAuthority = service.authority();
        serviceVersion = service.getVersion().toMajorPart();
        serviceDomain = service.getDomain();// checked in registry
        serviceInfo = service.getInitialInfo();

        _verifyServiceInfo(service, serviceInfo, owner);

        VersionPart releaseVersion = _next; // never 0
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

        if(info.objectType != SERVICE()) {
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

