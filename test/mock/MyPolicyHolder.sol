// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {NftId} from "../../contracts/type/NftId.sol";
import {PolicyHolder} from "../../contracts/shared/PolicyHolder.sol";
import {Timestamp} from "../../contracts/type/Timestamp.sol";

contract MyPolicyHolder is PolicyHolder {

    event LogMyPolicyHolderPolicyActivated(NftId policyNftId, Timestamp activatedAt);
    event LogMyPolicyHolderPolicyExpired(NftId policyNftId, Timestamp expiredAt);

    mapping(NftId => Timestamp activatedAt) public activatedAt;
    mapping(NftId => Timestamp expiredAt) public expiredAt;

    constructor (address registryAddress){
        _initialize(registryAddress);
    }

    function _initialize(address registryAddress) internal initializer() {
        _initializePolicyHolder(registryAddress);
    }

    function policyActivated(
        NftId policyNftId, 
        Timestamp activated
    )
        external
        override
    {
        activatedAt[policyNftId] = activated;
        emit LogMyPolicyHolderPolicyActivated(policyNftId, activated);
    }

    function policyExpired(
        NftId policyNftId, 
        Timestamp expired
    )
        external
        override
    {
        expiredAt[policyNftId] = expired;
        emit LogMyPolicyHolderPolicyExpired(policyNftId, expired);
    }

}