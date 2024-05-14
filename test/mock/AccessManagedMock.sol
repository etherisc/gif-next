// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";

contract AccessManagedMock is AccessManaged {

    constructor(address initialAuthority) AccessManaged(initialAuthority)
    // solhint-disable-next-line no-empty-blocks
    {}
}