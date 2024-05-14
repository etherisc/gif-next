// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";

import {AccessManagerUpgradeableInitializeable} from "../shared/AccessManagerUpgradeableInitializeable.sol";
import {ILifecycle} from "../shared/ILifecycle.sol";
import {INftOwnable} from "../shared/INftOwnable.sol";
import {IRegisterable} from "../shared/IRegisterable.sol";
import {IRegistry} from "./IRegistry.sol";
import {IRegistryLinked} from "../shared/IRegistryLinked.sol";
import {IRegistryService} from "./IRegistryService.sol";
import {IService} from "../shared/IService.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, ObjectTypeLib, zeroObjectType, RELEASE, REGISTRY, SERVICE, STAKING} from "../type/ObjectType.sol";
import {Registry} from "./Registry.sol";
import {RegistryAccessManager} from "./RegistryAccessManager.sol";
import {RoleId, ADMIN_ROLE} from "../type/RoleId.sol";
import {ServiceAuthorizationsLib} from "./ServiceAuthorizationsLib.sol";
import {StateId, INITIAL, SCHEDULED, DEPLOYING, ACTIVE} from "../type/StateId.sol";
import {Timestamp, TimestampLib} from "../type/Timestamp.sol";
import {TokenRegistry} from "./TokenRegistry.sol";
import {Version, VersionLib, VersionPart, VersionPartLib} from "../type/Version.sol";

    // gif admin is not technical, should sent simple txs
    // foundation creates
    // other guy deployes
    // other guy checks (can precompute addresses and compare with what deployed)
    // foundation activates
// TODO add function to deactivate releases
// TODO in next pr add getVersion() to releaseAccessManager only, set in initialize()
// TODO in next pr make single base for registry access manager, release access manager and instance access manager

contract ReleaseManager is
    AccessManaged,
    Initializable,
    ILifecycle
{
    using ObjectTypeLib for ObjectType;

    uint256 public constant INITIAL_GIF_VERSION = 3;

    event LogReleaseCreation(VersionPart version, bytes32 salt, AccessManagerUpgradeableInitializeable accessManager); 
    event LogReleaseActivation(VersionPart version);

    // constructor
    error ErrorReleaseManagerNotRegistry(address registry);

    // createNextRelease
    error ErrorReleaseManagerReleaseCreationDisallowed(StateId currentStateId);

    // prepareRelease
    error ErrorReleaseManagerReleasePreparationDisallowed(StateId currentStateId);
    error ErrorReleaseManagerReleaseEmpty();
    error ErrorReleaseManagerReleaseAlreadyCreated(VersionPart version);
    
    // register staking
    error ErrorReleaseManagerStakingAlreadySet(address stakingAddress);

    // registerService
    error ErrorReleaseManagerNoServiceRegistrationExpected();
    error ErrorReleaseManagerServiceRegistrationDisallowed(StateId currentStateId);
    error ErrorReleaseManagerNotService(IService service);
    error ErrorReleaseManagerServiceAddressInvalid(IService given, address expected);

    // activateNextRelease
    error ErrorReleaseManagerActivationDisallowed(StateId currentStateId);
    error ErrorReleaseManagerReleaseNotCreated(VersionPart releaseVersion);
    error ErrorReleaseManagerReleaseRegistrationNotFinished(VersionPart releaseVersion, uint awaitingRegistration);
    error ErrorReleaseManagerReleaseAlreadyActivated(VersionPart releaseVersion);

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

    // _verifyServiceAuthorizations
    error ErrorReleaseManagerServiceRoleInvalid(address service, RoleId role);

    RegistryAccessManager public immutable _accessManager;
    Registry public immutable _registry;
    IRegisterable private _staking;
    address private _stakingOwner;

    mapping(VersionPart version => AccessManagerUpgradeableInitializeable accessManager) internal _releaseAccessManager;
    mapping(VersionPart version => IRegistry.ReleaseInfo info) internal _releaseInfo;
    mapping(address registryService => bool isActive) internal _active;// have access to registry

    VersionPart immutable internal _initial;// first active version    
    VersionPart internal _latest; // latest active version
    VersionPart internal _next; // version to create and activate 
    StateId internal _state; // current state of release manager

    uint256 internal _awaitingRegistration; // "services left to register" counter

    // deployer of this contract must be gif admin
    constructor(
        address gifAdmin,
        address gifManager,
        address registry
    )
        AccessManaged(msg.sender)
    {
        if(!_isRegistry(registry)) {
            revert ErrorReleaseManagerNotRegistry(registry);
        }

        _registry = Registry(registry);
        _accessManager = new RegistryAccessManager(
            gifAdmin,
            gifManager);

        setAuthority(address(_accessManager.authority()));

        _initial = VersionPartLib.toVersionPart(INITIAL_GIF_VERSION);
        _next = VersionPartLib.toVersionPart(INITIAL_GIF_VERSION - 1);
        _state = getInitialState(RELEASE());
    }


    function registerStaking(
        address stakingAddress
    )
        external
        restricted() // GIF_ADMIN_ROLE
    {
        INftOwnable staking = INftOwnable(stakingAddress);
        _registry.registerStaking(stakingAddress);
        staking.linkToRegisteredNftId();
    }


    /// @dev skips previous release if was not activated
    /// sets release manager into state SCHEDULED
    function createNextRelease()
        external
        restricted() // GIF_ADMIN_ROLE
        returns(VersionPart version)
    {
        if (!isValidTransition(RELEASE(), _state, SCHEDULED())) {
            revert ErrorReleaseManagerReleaseCreationDisallowed(_state);
        }

        _next = VersionPartLib.toVersionPart(_next.toInt() + 1);
        _awaitingRegistration = 0;
        _state = SCHEDULED();
    }


    function prepareNextRelease(
        address[] memory addresses, 
        RoleId[][] memory serviceRoles, 
        RoleId[][] memory functionRoles, 
        bytes4[][][] memory selectors, 
        bytes32 salt
    )
        external
        restricted() // GIF_MANAGER_ROLE
        returns(
            address releaseAccessManagerAddress, 
            VersionPart version, 
            bytes32 releaseSalt
        )
    {
        if (!isValidTransition(RELEASE(), _state, DEPLOYING())) {
            revert ErrorReleaseManagerReleasePreparationDisallowed(_state);
        }

        if(addresses.length == 0) {
            revert ErrorReleaseManagerReleaseEmpty();
        }

        if(_awaitingRegistration > 0) {
            revert ErrorReleaseManagerReleaseAlreadyCreated(version);
        }

        _verifyReleaseAuthorizations(addresses, serviceRoles, functionRoles, selectors);

        version = getNextVersion();

        _releaseInfo[version].version = version;
        _releaseInfo[version].addresses = addresses;
        _releaseInfo[version].serviceRoles = serviceRoles;
        _releaseInfo[version].functionRoles = functionRoles;
        _releaseInfo[version].selectors = selectors;
        _awaitingRegistration = addresses.length;
        _state = DEPLOYING();

        version = getNextVersion();
        // ensures unique salt
        releaseSalt = keccak256(
            bytes.concat(
                bytes32(version.toInt()),
                salt));

        releaseAccessManagerAddress = Clones.cloneDeterministic(_accessManager.authority(), releaseSalt);
        AccessManagerUpgradeableInitializeable releaseAccessManager = AccessManagerUpgradeableInitializeable(releaseAccessManagerAddress);
        
        _releaseAccessManager[version] = releaseAccessManager;
        
        releaseAccessManager.initialize(address(this));

        emit LogReleaseCreation(version, releaseSalt, releaseAccessManager);
    }


    function registerService(IService service) 
        external
        restricted // GIF_MANAGER_ROLE
        returns(NftId nftId)
    {
        if (!isValidTransition(RELEASE(), _state, DEPLOYING())) {
            revert ErrorReleaseManagerServiceRegistrationDisallowed(_state);
        }

        (
            IRegistry.ObjectInfo memory info,
            ObjectType domain,
            VersionPart version
        ) = _verifyService(service);

        if (_awaitingRegistration == 0) {
            revert ErrorReleaseManagerNoServiceRegistrationExpected();
        }

        uint serviceIdx = _awaitingRegistration - 1;
        address serviceAddress = _releaseInfo[version].addresses[serviceIdx];
        // TODO temp, while typescript addresses computation is not implemented 
        /*if(address(service) != serviceAddress) {
            revert ErrorReleaseManagerServiceAddressInvalid(service, serviceAddress);
        }*/

        _setServiceAuthorizations(
            _releaseAccessManager[version],
            // TODO temp, while typescript addresses computation is not implemented
            address(service),//serviceAddress, 
            _releaseInfo[version].serviceRoles[serviceIdx],
            _releaseInfo[version].functionRoles[serviceIdx],
            _releaseInfo[version].selectors[serviceIdx]);

        // TODO decide for one of the approaches
        // // service to service authorization
        // ServiceAuthorizationsLib.ServiceAuthorization memory authz = ServiceAuthorizationsLib.getAuthorizations(domain);
        // for(uint8 idx = 0; idx < authz.authorizedRole.length; idx++) {
        //     _accessManager.setTargetFunctionRole(
        //         address(service), 
        //         authz.authorizedSelectors[idx], 
        //         authz.authorizedRole[idx]);
        // }

        _awaitingRegistration = serviceIdx;
        _state = DEPLOYING();

        // checked in registry
        _releaseInfo[version].domains.push(domain);

        nftId = _registry.registerService(info, version, domain);

        service.linkToRegisteredNftId();
    }


    function activateNextRelease() 
        external 
        restricted // GIF_ADMIN_ROLE
    {
        if (!isValidTransition(RELEASE(), _state, ACTIVE())) {
            revert ErrorReleaseManagerActivationDisallowed(_state);
        }

        VersionPart version = _next;
        address service = _registry.getServiceAddress(REGISTRY(), version);

        // release exists, registry service is a MUST
        //if(_releaseAccessManager[version] == address(0)) {
        if(service == address(0)) {
            revert ErrorReleaseManagerReleaseNotCreated(version);
        }

        // release fully deployed
        if(_awaitingRegistration > 0) {
            revert ErrorReleaseManagerReleaseRegistrationNotFinished(version, _awaitingRegistration);
        }

        // release is not activated
        if(_releaseInfo[version].activatedAt.gtz()) {
            revert ErrorReleaseManagerReleaseAlreadyActivated(version);
        }

        _latest = version;
        _state = ACTIVE();

        _active[service] = true;
        _releaseInfo[version].activatedAt = TimestampLib.blockTimestamp();

        emit LogReleaseActivation(version);
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
        return _active[service];
    }

    function isValidRelease(VersionPart version) external view returns(bool) {
        return _releaseInfo[version].activatedAt.gtz();
    }

    function getRegistryAddress() external view returns(address) {
        return (address(_registry));
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
        return _awaitingRegistration;
    }

    function getReleaseAccessManager(VersionPart version) external view returns(AccessManagerUpgradeableInitializeable) {
        return _releaseAccessManager[version];
    }

    function getRegistryAccessManager() external view returns (RegistryAccessManager) {
        return _accessManager;
    }

    //--- IRegistryLinked ------------------------------------------------------//

    function getRegistry() external view returns (IRegistry) {
        return _registry;
    }

    //--- ILifecycle -----------------------------------------------------------//

    function hasLifecycle(ObjectType objectType) external view returns (bool) { return objectType == RELEASE(); }

    function getInitialState(ObjectType objectType) public view returns (StateId stateId) { 
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
        view 
        returns (bool isValid)
    {
        if (objectType != RELEASE()) { return false; }

        if (fromId == INITIAL() && toId == SCHEDULED()) { return true; }
        if (fromId == SCHEDULED() && toId == DEPLOYING()) { return true; }
        if (fromId == DEPLOYING() && toId == SCHEDULED()) { return true; }
        if (fromId == DEPLOYING() && toId == DEPLOYING()) { return true; }
        if (fromId == DEPLOYING() && toId == ACTIVE()) { return true; }

        return false;
    }

    //--- private functions ----------------------------------------------------//

    function _verifyService(IService service)
        internal
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


    function _verifyReleaseAuthorizations(
        address[] memory serviceAddress,
        RoleId[][] memory serviceRoles,
        RoleId[][] memory functionRoles,
        bytes4[][][] memory selectors
    )
        internal
        view
    {
        for(uint serviceIdx = 0; serviceIdx < serviceAddress.length; serviceIdx++)
        {
            for(uint roleIdx = 0; roleIdx < serviceRoles[serviceIdx].length; roleIdx++)
            {
                RoleId role = serviceRoles[serviceIdx][roleIdx];
                if(role == ADMIN_ROLE()) {
                    revert ErrorReleaseManagerServiceRoleInvalid(serviceAddress[serviceIdx], role);
                }
            }
        }

        // TODO no duplicate service "domain" role per release
        // TODO no duplicate service roles per service
        // TODO no duplicate service function roles per service
        // TODO no duplicate service function selectors per service
    }

    function _setServiceAuthorizations(
        IAccessManager accessManager,
        address serviceAddress,
        RoleId[] memory serviceRoles,
        RoleId[] memory functionRoles,
        bytes4[][] memory selectors
    )
        internal
    {
        for(uint idx = 0; idx < functionRoles.length; idx++)
        {
            accessManager.setTargetFunctionRole(
                serviceAddress, 
                selectors[idx],
                functionRoles[idx].toInt());

            // TODO check/figure out which approach to take
            // ObjectType domain = config[idx].serviceDomain;
            // // not "registry service" / zero domain
            // if(
            //     domain == REGISTRY() ||
            //     domain.eqz()
            // ) { revert ConfigServiceDomainInvalid(idx, domain); } 

            // bytes4[] memory selectors = config[idx].authorizedSelectors;

            // // TODO can be zero -> e.g. duplicate domain, first with zero selector, second with non zero selector -> need to check _release[version].domains.contains(domain) instead
            // // no overwrite
            // if(_selectors[version][domain].length > 0) {
            //     revert SelectorAlreadyExists(version, domain); 
            // }
            
            // _selectors[version][domain] = selectors;
            // _release[version].domains.push(domain);
        }

        for(uint idx = 0; idx < serviceRoles.length; idx++)
        {
            accessManager.grantRole(
                serviceRoles[idx].toInt(),
                serviceAddress, 
                0);
        }
    }

    // returns true iff a the address passes some simple proxy tests.
    function _isRegistry(address registryAddress) internal view returns (bool) {

        // zero address is certainly not registry
        if (registryAddress == address(0)) {
            return false;
        }

        // check if contract returns a zero nft id for its own address
        if (IRegistry(registryAddress).getNftId(registryAddress).eqz()) {
            return false;
        }

        return true;
    }
}
