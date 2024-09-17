// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAuthorization} from "../../contracts/authorization/IAuthorization.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {Oracle} from "../../contracts/oracle/Oracle.sol";
import {RequestId} from "../../contracts/type/RequestId.sol";

contract BasicOracle is
    Oracle
{

    /// Function to provide reponse data releated to request id.
    function respond(
        RequestId requestId,
        bytes memory responseData
    )
        external
        virtual
        restricted()
    {
        _respond(requestId, responseData);
    }

    function _initializeBasicOracle(
        address registry,
        NftId instanceNftId,
        IAuthorization authorization,
        address initialOwner,
        string memory name
    )
        internal
        virtual
        onlyInitializing()
    {

        __Oracle_init(
            registry,
            instanceNftId,
            authorization,
            initialOwner,
            name);
    }
}
