// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IServiceAuthorization} from "../authorization/IServiceAuthorization.sol";

import {StateId} from "../type/StateId.sol";
import {Timestamp} from "../type/Timestamp.sol";
import {VersionPart} from "../type/Version.sol";

/// @title Marks contracts that are linked to a specific GIF release version.
interface IRelease {

    struct ReleaseInfo {
        // slot 0
        address releaseAdmin;
        StateId state;
        VersionPart version;
        Timestamp activatedAt;
        Timestamp disabledAt;
        // slot 1
        IServiceAuthorization auth;
        // slot 2
        bytes32 salt;
    }

}