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
import {StateId, INITIAL, SCHEDULED, DEPLOYING, ACTIVE, PAUSED, CLOSED} from "../type/StateId.sol";
import {Version, VersionLib, VersionPart, VersionPartLib} from "../type/Version.sol";

import {IService} from "../shared/IService.sol";
import {ILifecycle} from "../shared/ILifecycle.sol";
import {INftOwnable} from "../shared/INftOwnable.sol";
import {IRegisterable} from "../shared/IRegisterable.sol";

import {IRegistry} from "./IRegistry.sol";
import {IRegistryLinked} from "../shared/IRegistryLinked.sol";
import {IRegistryService} from "./IRegistryService.sol";
import {IServiceAuthorization} from "../authorization/IServiceAuthorization.sol";
import {IAccessAdmin} from "../authorization/IAccessAdmin.sol";
import {RegistryAdmin} from "./RegistryAdmin.sol";
import {Registry} from "./Registry.sol";
import {TokenRegistry} from "./TokenRegistry.sol";
import {ReleaseLifecycle} from "./ReleaseLifecycle.sol";

// TODO rename to something that does not end with 'Manager' 
// everywhere else *Manager points to an upgradeable contract
contract ReleaseManager is 
    AccessManaged,
    ReleaseLifecycle, 
    IRegistryLinked
{
    using ObjectTypeLib for ObjectType;

    uint256 public constant INITIAL_GIF_VERSION = 3;

    event LogReleaseCreation(VersionPart version, bytes32 salt); 
    event LogReleaseActivation(VersionPart version);
    event LogReleaseDisabled(VersionPart version);
    event LogReleaseEnabled(VersionPart version);

    // constructor
    error ErrorReleaseManagerNotRegistry(Registry registry);

    // createNextRelease
    error ErrorReleaseManagerReleaseCreationDisallowed(VersionPart version, StateId currentStateId);

    // prepareRelease
    error ErrorReleaseManagerReleasePreparationDisallowed(VersionPart version, StateId currentStateId);
    error ErrorReleaseManagerReleaseAlreadyPrepared(VersionPart version, StateId currentStateId);
    error ErrorReleaseManagerVersionMismatch(VersionPart expected, VersionPart actual);
    error ErrorReleaseManagerNoDomains(VersionPart version);

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

    RegistryAdmin public immutable _admin;
    Registry public immutable _registry;
    IRegisterable private _staking;
    address private _stakingOwner;

    mapping(VersionPart version => IRegistry.ReleaseInfo info) internal _releaseInfo;
    mapping(VersionPart version => IServiceAuthorization authz) internal _serviceAuthorization;

    // TODO check where/why this is used
    mapping(address registryService => VersionPart version) _releaseVersionByAddress;

    VersionPart private _initial;// first active version    
    VersionPart internal _latest; // latest active version
    VersionPart internal _next; // version to create and activate 
    mapping(VersionPart verson => StateId releaseState) private _state;

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
        authority = _admin.authority();
        version = _next;

        // ensures unique salt
        // TODO CreateX have clones capability also
        // what would releaseSalt look like if used with CreateX in pemissioned mode?
        releaseSalt = keccak256(
            bytes.concat(
                bytes32(version.toInt()),
                salt));

        // verify release in state SCHEDULED
        if (!isValidTransition(RELEASE(), _state[version], DEPLOYING())) {
            revert ErrorReleaseManagerReleasePreparationDisallowed(version, _state[version]);
        }

        _state[version] = DEPLOYING();

        // verify authorizaion contract release matches with expected version
        VersionPart releaseVersion = serviceAuthorization.getRelease();
        if (releaseVersion != version) {
            revert ErrorReleaseManagerVersionMismatch(version, releaseVersion);
        }


        // sanity check to ensure service domain list is not empty
        uint256 serviceDomainsCount = serviceAuthorization.getServiceDomains().length;
        if (serviceDomainsCount == 0) {
            revert ErrorReleaseManagerNoDomains(version);
        }

        // verify prepareNextRelease is only called once per release
        if(_servicesToRegister > 0) {
            revert ErrorReleaseManagerReleaseAlreadyPrepared(version, _state[version]);
        }

        _servicesToRegister = serviceDomainsCount;
        _serviceAuthorization[version] = serviceAuthorization;

        emit LogReleaseCreation(version, releaseSalt);
    }

    // TODO this function can have 0 args -> use stored addresses from prepareNextRelease()
    function registerService(IService service) 
        external
        restricted // GIF_MANAGER_ROLE
        returns(NftId nftId)
    {
        VersionPart releaseVersion = _next;
        StateId state = _state[releaseVersion];

        // verify release in state DEPLOYING
        if (!isValidTransition(RELEASE(), state, DEPLOYING())) {
            // TOOD name must represent failed state transition
            revert ErrorReleaseManagerServiceRegistrationDisallowed(state);
        }

        _state[releaseVersion] = DEPLOYING();

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

        // register service with registry
        nftId = _registry.registerService(info, serviceVersion, serviceDomain);
        service.linkToRegisteredNftId();
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
    }


    function activateNextRelease() 
        external 
        restricted // GIF_ADMIN_ROLE
    {
        VersionPart version = _next;
        StateId state = _state[version];
        StateId newState = ACTIVE();

        // verify release in state DEPLOYING
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

        _latest = version;
        _state[version] = newState;

        _releaseVersionByAddress[service] = version;
        _releaseInfo[version].activatedAt = TimestampLib.blockTimestamp();

        emit LogReleaseActivation(version);
    }

    /// @dev stop all operations with release services
    function pauseRelease(VersionPart version)
        external
        restricted // GIF_ADMIN_ROLE
    {
        StateId state = _state[version];
        StateId newState = PAUSED();

        // verify release in state ACTIVE
        if (!isValidTransition(RELEASE(), state, newState)) {
            revert ErrorReleaseManagerReleaseActivationDisallowed(version, state);
        }

        // TODO come up with a substitute
        //_releaseAccessManager[version].disable();

        _state[version] = newState;
        _releaseInfo[version].disabledAt = TimestampLib.blockTimestamp();

        emit LogReleaseDisabled(version);
    }

    // TODO consider revert if some delay is expired -> becomes disabled automatically
    /// @dev resume operations with release services
    function unpauseRelease(VersionPart version)
        external
        restricted // GIF_ADMIN_ROLE
    {
        StateId state = _state[version];
        StateId newState = ACTIVE();

        // verify release in state PAUSED
        if (!isValidTransition(RELEASE(), state, newState)) {
            revert ErrorReleaseManagerReleaseActivationDisallowed(version, state);
        }

        // TODO come up with a substitute
        // _releaseAccessManager[version].enable();
        
        _state[version] = newState;
        _releaseInfo[version].disabledAt = zeroTimestamp();

        emit LogReleaseEnabled(version);
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
        return _state[version] == ACTIVE();
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

    function getServiceAuthorization(VersionPart version)
        external
        view
        returns (IServiceAuthorization serviceAuthorization)
    {
        return _serviceAuthorization[version];
    }

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
        address expectedAuthority = _admin.authority(); // can be zero if registering service when release is not created

        // IMPORTANT: can not guarantee service access is actually controlled by authority
        if(serviceAuthority != expectedAuthority) {
            revert ErrorReleaseManagerServiceReleaseAuthorityMismatch(
                service,
                serviceAuthority,
                expectedAuthority);
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
        // or just panic
        // check if contract returns a zero nft id for its own address
        if (IRegistry(registryAddress).getNftId(registryAddress).eqz()) {
            return false;
        }

        return true;
    }
}

