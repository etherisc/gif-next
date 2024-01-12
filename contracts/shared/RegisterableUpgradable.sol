// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Registerable} from "./Registerable.sol";
import {Versionable} from "./Versionable.sol";

/// @dev base contract for upgradable objects like services and upgradable components
/// deriving contracs need to call _initializeRegisterable
/// TODO internalizes versionable here, a non-registerable versionalbe might itself have some value but is outside the scope of the gif
/// after this merge versionable will no longer exist on its own in gif
/// only registerable and upgradable (which is a registerable too) will remain
abstract contract RegisterableUpgradable is 
    Registerable,
    Versionable
{
}