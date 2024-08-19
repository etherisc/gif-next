// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IBundle} from "../module/IBundle.sol";
import {IInstance} from "../IInstance.sol";
import {IRisk} from "../module/IRisk.sol";
import {NftId} from "../../type/NftId.sol";
import {RiskId} from "../../type/RiskId.sol";


library ObjectSetHelperLib {

    function getRiskInfo(address instanceAddress, RiskId riskId) public view returns (IRisk.RiskInfo memory) {

        return IInstance(instanceAddress).getInstanceReader().getRiskInfo(riskId);
    }

    function getProductNftId(address instanceAddress, RiskId riskId) public view returns (NftId) {
        return getRiskInfo(instanceAddress, riskId).productNftId;
    }

    function getBundleInfo(address instanceAddress, NftId bundleNftId) public view returns (IBundle.BundleInfo memory) {
        return IInstance(instanceAddress).getInstanceReader().getBundleInfo(bundleNftId);
    }

    function getPoolNftId(address instanceAddress, NftId bundleNftId) public view returns (NftId) {
        return getBundleInfo(instanceAddress, bundleNftId).poolNftId;
    }

}
