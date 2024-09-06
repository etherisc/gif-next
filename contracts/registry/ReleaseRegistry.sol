// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";

import {IAccessAdmin} from "../authorization/IAccessAdmin.sol";
import {AccessManagerCloneable} from "../authorization/AccessManagerCloneable.sol";
import {IRegistry} from "./IRegistry.sol";
import {IRelease} from "./IRelease.sol";
import {IRegistryLinked} from "../shared/IRegistryLinked.sol";
import {IService} from "../shared/IService.sol";
import {IServiceAuthorization} from "../authorization/IServiceAuthorization.sol";

import {ContractLib} from "../shared/ContractLib.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, ObjectTypeLib, COMPONENT, POOL, RELEASE, REGISTRY, SERVICE, STAKING} from "../type/ObjectType.sol";
import {RegistryAdmin} from "./RegistryAdmin.sol";
import {Registry} from "./Registry.sol";
import {ReleaseAdmin} from "./ReleaseAdmin.sol";
import {ReleaseLifecycle} from "./ReleaseLifecycle.sol";
import {Seconds} from "../type/Seconds.sol";
import {StateId, SCHEDULED, DEPLOYING, DEPLOYED, SKIPPED, ACTIVE, PAUSED} from "../type/StateId.sol";
import {TimestampLib, zeroTimestamp} from "../type/Timestamp.sol";
import {VersionPart, VersionPartLib} from "../type/Version.sol";

/// @dev The ReleaseRegistry manages the lifecycle of major GIF releases and their services.
/// The creation of a new GIF release is a multi-step process:
/// 1. The creation of a new GIF release is initiated by the GIF admin.
/// 2. A GIF manager then prepares the release by setting up the service authorization contract.
/// 3. The GIF manager deploys and registers all related service contracts with the release registry.
/// 4. The GIF admin verifies and activates the release.
/// 3. The GIF admin may pause and resume a release.
contract ReleaseRegistry is 
    AccessManaged,
    ReleaseLifecycle, 
    IRegistryLinked
{
    uint256 public constant INITIAL_GIF_VERSION = 3;// first active release version  

    event LogReleaseCreation(IAccessAdmin admin, VersionPart release, bytes32 salt); 
    event LogReleaseActivation(VersionPart release);
    event LogReleaseDisabled(VersionPart release);
    event LogReleaseEnabled(VersionPart release);

    // constructor
    error ErrorReleaseRegistryNotRegistry(Registry registry);

    // _verifyServiceAuthorization
    error ErrorReleaseRegistryNotServiceAuth(address notAuth);
    error ErrorReleaseRegistryServiceAuthVersionMismatch(IServiceAuthorization auth, VersionPart expected, VersionPart actual);
    error ErrorReleaseRegistryServiceAuthDomainsZero(IServiceAuthorization auth, VersionPart release);

    // registerService
    error ErrorReleaseRegistryServiceAddressMismatch(address expected, address actual);

    // activateNextRelease
    error ErrorReleaseRegistryRegistryServiceMissing(VersionPart releaseVersion);

    // _verifyService
    error ErrorReleaseRegistryNotService(address notService);
    error ErrorReleaseRegistryServiceAuthorityMismatch(IService service, address expectedAuthority, address actualAuthority);
    error ErrorReleaseRegistryServiceDomainMismatch(IService service, ObjectType expectedDomain, ObjectType actualDomain);

    // _verifyServiceInfo
    error ErrorReleaseRegistryServiceInfoAddressInvalid(IService service, address expected);
    error ErrorReleaseRegistryServiceInfoInterceptorInvalid(IService service, bool isInterceptor);
    error ErrorReleaseRegistryServiceInfoTypeInvalid(IService service, ObjectType expected, ObjectType found);
    error ErrorReleaseRegistryServiceInfoVersionMismatch(IService service, VersionPart expected, VersionPart actual);
    error ErrorReleaseRegistryServiceInfoOwnerInvalid(IService service, address expected, address found);
    error ErrorReleaseRegistryServiceSelfRegistration(IService service);
    error ErrorReleaseRegistryServiceOwnerRegistered(IService service, address owner);

    RegistryAdmin public immutable _registryAdmin;
    Registry public immutable _registry;

    mapping(VersionPart release => IRelease.ReleaseInfo info) internal _releaseInfo;
    VersionPart [] internal _release; // array of all created releases    
    ReleaseAdmin internal _masterReleaseAdmin;

    VersionPart internal _latest; // latest active release
    VersionPart internal _next; // release version to create and activate 

    // counters per release
    uint256 internal _registeredServices = 0;
    uint256 internal _servicesToRegister = 0;

    // TODO move master relase admin outside constructor (same construction as for registry admin)
    constructor(Registry registry)
        AccessManaged(msg.sender)
    {
        if (!ContractLib.isRegistry(address(registry))) {
            revert ErrorReleaseRegistryNotRegistry(registry);
        }

        setAuthority(registry.getAuthority());

        _registry = registry;
        _registryAdmin = RegistryAdmin(_registry.getRegistryAdminAddress());
        _masterReleaseAdmin = new ReleaseAdmin(
            _cloneNewAccessManager());

        _next = VersionPartLib.toVersionPart(INITIAL_GIF_VERSION - 1);
    }

    /// @dev Initiates the creation of a new GIF release by the GIF admin.
    /// Sets previous release into SKIPPED state if it was created but not activated.
    /// Sets the new release into state SCHEDULED.
    function createNextRelease()
        external
        restricted() // GIF_ADMIN_ROLE
        returns(VersionPart)
    {
        VersionPart release = _next;

        if(isValidTransition(RELEASE(), _releaseInfo[release].state, SKIPPED())) {
            _releaseInfo[release].state = SKIPPED();
        }

        release = VersionPartLib.toVersionPart(release.toInt() + 1);
        _release.push(release);

        _next = release;
        _releaseInfo[release].version = release;
        _releaseInfo[release].state = getInitialState(RELEASE());
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
            ReleaseAdmin releaseAdmin, 
            VersionPart releaseVersion, 
            bytes32 releaseSalt
        )
    {
        releaseVersion = _next;

        // release can transition into DEPLOYING state
        checkTransition(_releaseInfo[releaseVersion].state, RELEASE(), SCHEDULED(), DEPLOYING());

        // verify authorizations
        uint256 serviceDomainsCount = _verifyServiceAuthorization(serviceAuthorization, releaseVersion, salt);

        // create and initialize release admin
        releaseAdmin = _cloneNewReleaseAdmin(serviceAuthorization, releaseVersion);
        releaseSalt = salt;

        // ensures unique salt
        // TODO CreateX have clones capability also
        // what would releaseSalt look like if used with CreateX in pemissioned mode?
        /*releaseSalt = keccak256(
            bytes.concat(
                bytes32(releaseVersion.toInt()),
                salt));*/

        _servicesToRegister = serviceDomainsCount;
        _releaseInfo[releaseVersion].state = DEPLOYING();
        _releaseInfo[releaseVersion].salt = releaseSalt;
        // TODO allow for the same serviceAuthorization address to be used for multiple releases?
        _releaseInfo[releaseVersion].auth = serviceAuthorization;
        _releaseInfo[releaseVersion].releaseAdmin = address(releaseAdmin);

        emit LogReleaseCreation(releaseAdmin, releaseVersion, releaseSalt);
    }

    function registerService(IService service) 
        external
        restricted // GIF_MANAGER_ROLE
        returns(NftId nftId)
    {
        VersionPart releaseVersion = _next;

        // release can transition to DEPLOYED state
        checkTransition(_releaseInfo[releaseVersion].state, RELEASE(), DEPLOYING(), DEPLOYED());

        address releaseAuthority = ReleaseAdmin(_releaseInfo[releaseVersion].releaseAdmin).authority();
        IServiceAuthorization releaseAuthz = _releaseInfo[releaseVersion].auth;
        ObjectType expectedDomain = releaseAuthz.getServiceDomain(_registeredServices);
        address expectedOwner = msg.sender;

        // service can work with release registry and release version
        (
            IRegistry.ObjectInfo memory info,
            bytes memory data,
            ObjectType serviceDomain
        ) = _verifyService(
            service, 
            expectedOwner,
            releaseAuthority, 
            releaseVersion, 
            expectedDomain
        );

        _registeredServices++; // TODO use releaseInfo.someArray.length instead of _registeredServices

        // release fully deployed
        if(_servicesToRegister == _registeredServices) {
            _releaseInfo[releaseVersion].state = DEPLOYED();
        }

        // TODO: service address matches defined in release auth (precalculated one)
        // revert ErrorReleaseRegistryServiceAddressMismatch()

        // setup service authorization
        ReleaseAdmin releaseAdmin = ReleaseAdmin(_releaseInfo[releaseVersion].releaseAdmin);
        releaseAdmin.setReleaseLocked(false);
        releaseAdmin.authorizeService(
            service,
            serviceDomain,
            releaseVersion);
        releaseAdmin.setReleaseLocked(true); 

        // register service with registry
        nftId = _registry.registerService(info, expectedOwner, serviceDomain, data);
        service.linkToRegisteredNftId();
    }


    // TODO return activated version
    function activateNextRelease() 
        external 
        restricted // GIF_ADMIN_ROLE
    {
        VersionPart release = _next;

        // release can transition to ACTIVE state
        checkTransition(_releaseInfo[release].state, RELEASE(), DEPLOYED(), ACTIVE());

        _latest = release;
        _releaseInfo[release].state = ACTIVE();
        _releaseInfo[release].activatedAt = TimestampLib.current();
        _releaseInfo[release].disabledAt = TimestampLib.max();

        // grant special roles for registry/staking/pool services
        // this will enable access to core contracts functions

        // registry service MUST be registered for each release
        address service = _registry.getServiceAddress(REGISTRY(), release);
        if(service == address(0)) {
            revert ErrorReleaseRegistryRegistryServiceMissing(release);
        }

        _registryAdmin.grantServiceRoleForAllVersions(IService(service), REGISTRY());

        service = _registry.getServiceAddress(STAKING(), release);
        if(service != address(0)) {
            _registryAdmin.grantServiceRoleForAllVersions(IService(service), STAKING());
        }

        service = _registry.getServiceAddress(COMPONENT(), release);
        if(service != address(0)) {
            _registryAdmin.grantServiceRoleForAllVersions(IService(service), COMPONENT());
        }

        service = _registry.getServiceAddress(POOL(), release);
        if(service != address(0)) {
            _registryAdmin.grantServiceRoleForAllVersions(IService(service), POOL());
        }

        _setReleaseLocked(release, false);

        emit LogReleaseActivation(release);
    }

    /// @dev stop/resume operations with restricted functions
    function setActive(VersionPart release, bool active) 
        public
        restricted
    {
        StateId state = _releaseInfo[release].state;

        if(active) {
            checkTransition(state, RELEASE(), PAUSED(), ACTIVE());
            _releaseInfo[release].state = ACTIVE();
            _releaseInfo[release].disabledAt = TimestampLib.max();
            emit LogReleaseEnabled(release);
        } else {
            checkTransition(state, RELEASE(), ACTIVE(), PAUSED());
            _releaseInfo[release].state = PAUSED();
            _releaseInfo[release].disabledAt = TimestampLib.current();
            emit LogReleaseDisabled(release);
        }

        _setReleaseLocked(release, !active);
    }

    //--- view functions ----------------------------------------------------//

    function predictDeterministicAddress(
        address implementation,
        bytes32 salt,
        address deployer
    ) external pure returns (address predicted) {
        return Clones.predictDeterministicAddress(implementation, salt, deployer);
    }

    function isActiveRelease(VersionPart release) public view returns(bool) {
        return _releaseInfo[release].state == ACTIVE();
    }

    function getReleaseInfo(VersionPart release) external view returns(IRelease.ReleaseInfo memory) {
        return _releaseInfo[release];
    }

    /// @dev Returns the number of created releases.
    /// Releases might be in another state than ACTIVE.
    function releases() external view returns (uint) {
        return _release.length;
    }

    /// @dev Returns the n-th release version.
    /// Valid values for idx [0 .. releases() - 1]
    function getVersion(uint256 idx) external view returns (VersionPart release) {
        // return _releases;
        return _release[idx];
    }

    function getNextVersion() public view returns(VersionPart) {
        return _next;
    }

    /// @dev Returns the latest activated relase version.
    /// There is no guarantee that the release is not currently paused.
    function getLatestVersion() external view returns(VersionPart) {
        return _latest;
    }

    function getState(VersionPart release) external view returns (StateId stateId) {
        return _releaseInfo[release].state;
    }

    function getRemainingServicesToRegister() external view returns (uint256 services) {
        return _servicesToRegister - _registeredServices;
    }

    function getServiceAuthorization(VersionPart release)
        external
        view
        returns (IServiceAuthorization serviceAuthorization)
    {
        return _releaseInfo[release].auth;
    }

    function getRegistryAdmin() external view returns (address) {
        return address(_registryAdmin);
    }

    //--- IRegistryLinked ------------------------------------------------------//

    function getRegistry() external view returns (IRegistry) {
        return _registry;
    }

    //--- private functions ----------------------------------------------------//

    function _setReleaseLocked(VersionPart release, bool locked)
        private
    {
        ReleaseAdmin(
            _releaseInfo[release].releaseAdmin).setReleaseLocked(locked);
    }

    function _cloneNewReleaseAdmin(
        IServiceAuthorization serviceAuthorization,
        VersionPart release
    )
        private
        returns (ReleaseAdmin clonedAdmin)
    {
        // clone and setup release specific release admin
        clonedAdmin = ReleaseAdmin(
            Clones.clone(address(_masterReleaseAdmin)));

        string memory releaseAdminName = string(
            abi.encodePacked(
                "ReleaseAdminV", 
                release.toString()));

        clonedAdmin.initialize(
            address(_cloneNewAccessManager()),
            releaseAdminName);

        clonedAdmin.completeSetup(
            address(_registry), 
            address(serviceAuthorization),
            release,
            address(this)); // release registry (this contract)

        // lock release (remains locked until activation)
        clonedAdmin.setReleaseLocked(true);
    }


    function _cloneNewAccessManager()
        private
        returns (address accessManager)
    {
        return Clones.clone(address(_registryAdmin.authority()));
    }


    function _verifyServiceAuthorization(
        IServiceAuthorization serviceAuthorization,
        VersionPart releaseVersion,
        bytes32 salt
    )
        private
        view
        returns (uint256 serviceDomainsCount)
    {
        // authorization contract supports IServiceAuthorization interface
        if(!ContractLib.supportsInterface(address(serviceAuthorization), type(IServiceAuthorization).interfaceId)) {
            revert ErrorReleaseRegistryNotServiceAuth(address(serviceAuthorization));
        }

        // authorizaions contract version matches with release version
        VersionPart authVersion = serviceAuthorization.getRelease();
        if (releaseVersion != authVersion) {
            revert ErrorReleaseRegistryServiceAuthVersionMismatch(serviceAuthorization, releaseVersion, authVersion);
        }

        // sanity check to ensure service domain list is not empty
        serviceDomainsCount = serviceAuthorization.getServiceDomains().length;
        if (serviceDomainsCount == 0) {
            revert ErrorReleaseRegistryServiceAuthDomainsZero(serviceAuthorization, releaseVersion);
        }
    }

    // TODO get service names 
    function _verifyService(
        IService service,
        address expectedOwner,
        address expectedAuthority, 
        VersionPart expectedVersion,
        ObjectType expectedDomain
    )
        internal
        view
        returns(
            IRegistry.ObjectInfo memory info,
            bytes memory data,
            ObjectType domain
        )
    {
        if(!service.supportsInterface(type(IService).interfaceId)) {
            revert ErrorReleaseRegistryNotService(address(service));
        }

        address authority = service.authority();
        domain = service.getDomain();// checked in registry

        (info,, data) = _verifyServiceInfo(
            service,
            expectedOwner,
            expectedVersion);

        if(authority != expectedAuthority) {
            revert ErrorReleaseRegistryServiceAuthorityMismatch(
                service,
                expectedAuthority,
                authority);
        }

        if(domain != expectedDomain) {
            revert ErrorReleaseRegistryServiceDomainMismatch(
                service,
                expectedDomain,
                domain);
        }
    }


    function _verifyServiceInfo(
        IService service,
        address expectedOwner, // assume always valid, can not be 0
        VersionPart expectedVersion
    )
        internal
        view
        returns (
            IRegistry.ObjectInfo memory info,
            address initialOwner,
            bytes memory data
        )
    {
        (info, initialOwner, data) = service.getInitialInfo();

        if(info.objectAddress != address(service)) {
            revert ErrorReleaseRegistryServiceInfoAddressInvalid(service, info.objectAddress);
        }

        if(info.isInterceptor != false) { // service is never interceptor
            revert ErrorReleaseRegistryServiceInfoInterceptorInvalid(service, info.isInterceptor);
        }

        if(info.objectType != SERVICE()) {
            revert ErrorReleaseRegistryServiceInfoTypeInvalid(service, SERVICE(), info.objectType);
        }

        if(info.objectRelease != expectedVersion) {
            revert ErrorReleaseRegistryServiceInfoVersionMismatch(
                service,
                expectedVersion,
                info.objectRelease);            
        }

        if(initialOwner != expectedOwner) { // registerable owner protection
            revert ErrorReleaseRegistryServiceInfoOwnerInvalid(service, expectedOwner, initialOwner); 
        }

        if(initialOwner == address(service)) {
            revert ErrorReleaseRegistryServiceSelfRegistration(service);
        }
        
        if(_registry.isRegistered(initialOwner)) { 
            revert ErrorReleaseRegistryServiceOwnerRegistered(service, initialOwner);
        }
    }
}

