// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {NftId} from "../type/NftId.sol";
import {RoleId, RoleIdLib, ADMIN_ROLE, PUBLIC_ROLE} from "../type/RoleId.sol";
import {ObjectType, ObjectTypeLib, POOL, RELEASE, REGISTRY, SERVICE, STAKING} from "../type/ObjectType.sol";
import {Version, VersionLib, VersionPart, VersionPartLib} from "../type/Version.sol";
import {Timestamp, TimestampLib, zeroTimestamp, ltTimestamp} from "../type/Timestamp.sol";
import {Seconds, SecondsLib} from "../type/Seconds.sol";
import {StateId, INITIAL, SCHEDULED, DEPLOYING, SKIPPED, ACTIVE, PAUSED, CLOSED} from "../type/StateId.sol";
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

contract ReleaseRegistry is 
    AccessManaged,
    ReleaseLifecycle, 
    IRegistryLinked
{
    using ObjectTypeLib for ObjectType;

    uint256 public constant INITIAL_GIF_VERSION = 3;// first active version  

    event LogReleaseCreation(VersionPart version, bytes32 salt); 
    event LogReleaseActivation(VersionPart version);
    event LogReleaseDisabled(VersionPart version);
    event LogReleaseEnabled(VersionPart version);

    // constructor
    error ErrorReleaseRegistryNotRegistry(Registry registry);

    // createNextRelease
    error ErrorReleaseRegistryReleaseCreationDisallowed(VersionPart version, StateId currentStateId);

    // prepareRelease
    error ErrorReleaseRegistryReleasePreparationDisallowed(VersionPart version, StateId currentStateId);
    error ErrorReleaseRegistryReleaseAlreadyPrepared(VersionPart version, StateId currentStateId);
    error ErrorReleaseRegistryVersionMismatch(VersionPart expected, VersionPart actual);
    error ErrorReleaseRegistryNoDomains(VersionPart version);

    // registerService
    error ErrorReleaseRegistryNoServiceRegistrationExpected();
    error ErrorReleaseRegistryServiceRegistrationDisallowed(StateId currentStateId);
    error ErrorReleaseRegistryServiceDomainMismatch(ObjectType expectedDomain, ObjectType actualDomain);
    error ErrorReleaseRegistryNotService(address notService);
    error ErrorReleaseRegistryServiceAddressMismatch(address expected, address actual);

    // activateNextRelease
    error ErrorReleaseRegistryReleaseActivationDisallowed(VersionPart releaseVersion, StateId currentStateId);
    error ErrorReleaseRegistryReleaseNotCreated(VersionPart releaseVersion);
    error ErrorReleaseRegistryReleaseRegistrationNotFinished(VersionPart releaseVersion, uint awaitingRegistration);
    error ErrorReleaseRegistryReleaseAlreadyActivated(VersionPart releaseVersion);

    // disableRelease
    error ErrorReleaseRegistryReleaseNotActivated(VersionPart releaseVersion);
    error ErrorReleaseRegistryReleaseAlreadyDisabled(VersionPart releaseVersion);

    // _verifyService
    error ErrorReleaseRegistryServiceReleaseAuthorityMismatch(IService service, address serviceAuthority, address releaseAuthority);
    error ErrorReleaseRegistryServiceReleaseVersionMismatch(IService service, VersionPart serviceVersion, VersionPart releaseVersion);

    // _verifyServiceInfo
    error ErrorReleaseRegistryServiceInfoAddressInvalid(IService service, address expected);
    error ErrorReleaseRegistryServiceInfoInterceptorInvalid(IService service, bool isInterceptor);
    error ErrorReleaseRegistryServiceInfoTypeInvalid(IService service, ObjectType expected, ObjectType found);
    error ErrorReleaseRegistryServiceInfoOwnerInvalid(IService service, address expected, address found);
    error ErrorReleaseRegistryServiceSelfRegistration(IService service);
    error ErrorReleaseRegistryServiceOwnerRegistered(IService service, address owner);

    Seconds public constant MIN_DISABLE_DELAY = Seconds.wrap(60 * 24 * 365); // 1 year

    RegistryAdmin public immutable _admin;
    Registry public immutable _registry;
    IRegisterable private _staking;
    address private _stakingOwner;

    mapping(VersionPart version => IRegistry.ReleaseInfo info) internal _releaseInfo;

    VersionPart internal _latest; // latest active version
    VersionPart internal _next; // version to create and activate 

    uint256 internal _registeredServices;
    uint256 internal _servicesToRegister;

    constructor(Registry registry)
        AccessManaged(msg.sender)
    {
        // TODO move this part to RegistryLinked constructor
        if(!_isRegistry(address(registry))) {
            revert ErrorReleaseRegistryNotRegistry(registry);
        }

        setAuthority(registry.getAuthority());

        _registry = registry;
        _admin = RegistryAdmin(_registry.getRegistryAdminAddress());

        _next = VersionPartLib.toVersionPart(INITIAL_GIF_VERSION - 1);
    }

    /// @dev skips previous release if was not activated
    /// sets next release into state SCHEDULED
    function createNextRelease()
        external
        restricted() // GIF_ADMIN_ROLE
        returns(VersionPart)
    {
        VersionPart version = _next;

        if(isValidTransition(RELEASE(), _releaseInfo[version].state, SKIPPED())) {
            // set previous release into SKIPPED state if was created but not activated
            _releaseInfo[version].state == SKIPPED();
        }

        version = VersionPartLib.toVersionPart(version.toInt() + 1);

        _next = version;
        _releaseInfo[version].state = getInitialState(RELEASE());
        _servicesToRegister = 0;
        _registeredServices = 0;

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
            VersionPart releaseVersion, 
            bytes32 releaseSalt
        )
    {
        authority = _admin.authority();
        releaseVersion = _next;
        StateId state = _releaseInfo[releaseVersion].state;
        StateId newState = DEPLOYING();

        // ensures unique salt
        // TODO CreateX have clones capability also
        // what would releaseSalt look like if used with CreateX in pemissioned mode?
        releaseSalt = keccak256(
            bytes.concat(
                bytes32(releaseVersion.toInt()),
                salt));

        // verify release in state SCHEDULED or DEPLOYING
        if (!isValidTransition(RELEASE(), state, newState)) {
            revert ErrorReleaseRegistryReleasePreparationDisallowed(releaseVersion, state);
        }

        // verify authorizaion contract release matches with expected version
        VersionPart authVersion = serviceAuthorization.getRelease();
        if (releaseVersion != authVersion) {
            revert ErrorReleaseRegistryVersionMismatch(releaseVersion, authVersion);
        }

        // sanity check to ensure service domain list is not empty
        uint256 serviceDomainsCount = serviceAuthorization.getServiceDomains().length;
        if (serviceDomainsCount == 0) {
            revert ErrorReleaseRegistryNoDomains(releaseVersion);
        }

        // verify prepareNextRelease is only called once per release, in state SCHEDULED
        if(_servicesToRegister > 0) {
            revert ErrorReleaseRegistryReleaseAlreadyPrepared(releaseVersion, state);
        }

        _servicesToRegister = serviceDomainsCount;
        // TODO allow for the same serviceAuthorization address to be used for multiple releases????
        _releaseInfo[releaseVersion].auth = serviceAuthorization;
        _releaseInfo[releaseVersion].state = newState;

        emit LogReleaseCreation(releaseVersion, releaseSalt);
    }

    function registerService(IService service) 
        external
        restricted // GIF_MANAGER_ROLE
        returns(NftId nftId)
    {
        VersionPart releaseVersion = _next;
        StateId state = _releaseInfo[releaseVersion].state;
        StateId newState = DEPLOYING();
        IServiceAuthorization auth = _releaseInfo[releaseVersion].auth;

        // verify release in state DEPLOYING
        if (!isValidTransition(RELEASE(), state, newState)) {
            // TOOD name must represent failed state transition
            revert ErrorReleaseRegistryServiceRegistrationDisallowed(state);
        }

        // not all services are registered
        if (_servicesToRegister == _registeredServices) {
            revert ErrorReleaseRegistryNoServiceRegistrationExpected();
        }

        // service can work with release registry and release version
        (
            IRegistry.ObjectInfo memory info,
            ObjectType serviceDomain,
            VersionPart serviceVersion
        ) = _verifyService(service);

        // service domain matches defined in release config
        ObjectType expectedDomain = auth.getServiceDomain(_registeredServices);
        if (serviceDomain != expectedDomain) {
            revert ErrorReleaseRegistryServiceDomainMismatch(expectedDomain, serviceDomain);
        }

        // TODO: service address matches defined in release auth

        // setup service authorization
        _admin.authorizeService(
            auth, 
            service,
            serviceDomain,
            releaseVersion);

        // special roles for registry/staking/pool service
        if (
            serviceDomain == REGISTRY() ||
            serviceDomain == STAKING() ||
            serviceDomain == POOL()) 
        {
            _admin.grantServiceRoleForAllVersions(service, serviceDomain);
        }

        _releaseInfo[releaseVersion].state = newState;
        //_releaseInfo[releaseVersion].addresses.push(address(service)); // TODO get this info from auth contract?
        //_releaseInfo[releaseVersion].domains.push(serviceDomain);
        //_releaseInfo[releaseVersion].names.push(service.getName()); // TODO if needed read name in _verifyService()?

        _registeredServices++;

        // register service with registry
        nftId = _registry.registerService(info, serviceVersion, serviceDomain);
        service.linkToRegisteredNftId();
    }


    function activateNextRelease() 
        external 
        restricted // GIF_ADMIN_ROLE
    {
        VersionPart version = _next;
        StateId state = _releaseInfo[version].state;
        StateId newState = ACTIVE();

        // verify release in state DEPLOYING
        if (!isValidTransition(RELEASE(), state, newState)) {
            revert ErrorReleaseRegistryReleaseActivationDisallowed(version, state);
        }

        // release fully deployed
        if(_registeredServices < _servicesToRegister) {
            revert ErrorReleaseRegistryReleaseRegistrationNotFinished(version, _servicesToRegister - _registeredServices);
        }

        // release exists, registry service MUST exist
        address service = _registry.getServiceAddress(REGISTRY(), version);
        if(service == address(0)) {
            revert ErrorReleaseRegistryReleaseNotCreated(version);
        }

        _latest = version;
        _releaseInfo[version].state = newState;
        _releaseInfo[version].activatedAt = TimestampLib.blockTimestamp();

        emit LogReleaseActivation(version);
    }

    /// @dev stop all operations with release services
    function pauseRelease(VersionPart version)
        external
        restricted // GIF_ADMIN_ROLE
    {
        StateId state = _releaseInfo[version].state;
        StateId newState = PAUSED();

        // verify release in state ACTIVE
        if (!isValidTransition(RELEASE(), state, newState)) {
            revert ErrorReleaseRegistryReleaseActivationDisallowed(version, state);
        }

        // TODO may run out of gas
        // TODO test how many service roles can be revoked in one transaction -> add to docs + each release must test for this -> add to release registry tests, call in test with some gas limit?
        _revokeReleaseRoles(version);

        _releaseInfo[version].state = newState;
        _releaseInfo[version].disabledAt = TimestampLib.blockTimestamp();

        emit LogReleaseDisabled(version);
    }

    /// @dev resume operations with release services
    function unpauseRelease(VersionPart version)
        external
        restricted // GIF_ADMIN_ROLE
    {
        StateId state = _releaseInfo[version].state;
        StateId newState = ACTIVE();

        // verify release in state PAUSED
        if (!isValidTransition(RELEASE(), state, newState)) {
            revert ErrorReleaseRegistryReleaseActivationDisallowed(version, state);
        }

        _grantReleaseRoles(version);
        
        _releaseInfo[version].state = newState;
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

    function isActiveRelease(VersionPart version) public view returns(bool) {
        return _releaseInfo[version].state == ACTIVE();
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

    function getState(VersionPart version) external view returns (StateId stateId) {
        return _releaseInfo[version].state;
    }

    function getRemainingServicesToRegister() external view returns (uint256 services) {
        return _servicesToRegister - _registeredServices;
    }

    function getServiceAuthorization(VersionPart version)
        external
        view
        returns (IServiceAuthorization serviceAuthorization)
    {
        return _releaseInfo[version].auth;
    }

    function getRegistryAdmin() external view returns (address) {
        return address(_admin);
    }

    //--- IRegistryLinked ------------------------------------------------------//

    function getRegistry() external view returns (IRegistry) {
        return _registry;
    }

    //--- private functions ----------------------------------------------------//

    function _revokeReleaseRoles(VersionPart version)
        private
    {
        address service;
        ObjectType domain;
        IServiceAuthorization auth = _releaseInfo[version].auth;

        ObjectType[] memory domains = auth.getServiceDomains();
        for(uint idx = 0; idx < domains.length; idx++)
        {
            domain = domains[idx];
            service = _registry.getServiceAddress(domain, version);
            _admin.revokeServiceRole(IService(service), domain, version);

            // special roles for registry/staking/pool service
            if(
                domain == REGISTRY() ||
                domain == STAKING() ||
                domain == POOL()
            )
            {
                _admin.revokeServiceRoleForAllVersions(IService(service), domain);
            }
        }
    }

    function _grantReleaseRoles(VersionPart version)
        private
    {
        address service;
        ObjectType domain;
        IServiceAuthorization auth = _releaseInfo[version].auth;

        ObjectType[] memory domains = auth.getServiceDomains();
        for(uint idx = 0; idx < domains.length; idx++)
        {
            domain = domains[idx];
            service = _registry.getServiceAddress(domain, version);
            _admin.grantServiceRole(IService(service), domain, version);

            // special roles for registry/staking/pool service
            if(
                domain == REGISTRY() ||
                domain == STAKING() ||
                domain == POOL()
            )
            {
                _admin.grantServiceRoleForAllVersions(IService(service), domain);
            }
        }
    }

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
            revert ErrorReleaseRegistryNotService(address(service));
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
            revert ErrorReleaseRegistryServiceReleaseAuthorityMismatch(
                service,
                serviceAuthority,
                expectedAuthority);
        }

        if(serviceVersion != releaseVersion) {
            revert ErrorReleaseRegistryServiceReleaseVersionMismatch(
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
            revert ErrorReleaseRegistryServiceInfoAddressInvalid(service, address(service));
        }

        if(info.isInterceptor != false) { // service is never interceptor
            revert ErrorReleaseRegistryServiceInfoInterceptorInvalid(service, info.isInterceptor);
        }

        if(info.objectType != SERVICE()) {
            revert ErrorReleaseRegistryServiceInfoTypeInvalid(service, SERVICE(), info.objectType);
        }

        address owner = info.initialOwner;

        if(owner != expectedOwner) { // registerable owner protection
            revert ErrorReleaseRegistryServiceInfoOwnerInvalid(service, expectedOwner, owner); 
        }

        if(owner == address(service)) {
            revert ErrorReleaseRegistryServiceSelfRegistration(service);
        }
        
        if(_registry.isRegistered(owner)) { 
            revert ErrorReleaseRegistryServiceOwnerRegistered(service, owner);
        }
    }

    /// @dev returns true iff a the address passes some simple proxy tests.
    function _isRegistry(address registryAddress) internal view returns (bool) {

        // zero address is certainly not registry
        if (registryAddress == address(0)) {
            return false;
        }
        // TODO try catch and return false in case of revert or just panic
        // check if contract returns a zero nft id for its own address
        if (IRegistry(registryAddress).getNftIdForAddress(registryAddress).eqz()) {
            return false;
        }

        return true;
    }
}

