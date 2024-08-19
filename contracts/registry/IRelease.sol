// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IServiceAuthorization} from "../authorization/IServiceAuthorization.sol";

import {StateId} from "../type/StateId.sol";
import {Timestamp} from "../type/Timestamp.sol";
import {VersionPart} from "../type/Version.sol";

/// @title Marks contracts that are linked to a specific GIF release version.
interface IRelease {

    struct ReleaseInfo {
        StateId state;
        VersionPart version;
        bytes32 salt;
        IServiceAuthorization auth;
        address releaseAdmin;
        Timestamp activatedAt;
        Timestamp disabledAt;
    }

    /// @dev Registers a registry contract for a specified chain.
    /// Only one chain registry may be registered per chain
    function getRelease() external view returns (VersionPart release);
}