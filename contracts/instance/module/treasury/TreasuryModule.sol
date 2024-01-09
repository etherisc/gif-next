// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IDistributionComponent} from "../../../components/IDistributionComponent.sol";
import {IPoolComponent} from "../../../components/IPoolComponent.sol";
import {IProductComponent} from "../../../components/IProductComponent.sol";

import {NftId} from "../../../types/NftId.sol";
import {TREASURY} from "../../../types/ObjectType.sol";
import {Fee, FeeLib} from "../../../types/Fee.sol";
import {UFixed, UFixedLib} from "../../../types/UFixed.sol";
import {TokenHandler} from "./TokenHandler.sol";
import {IKeyValueStore} from "../../base/IKeyValueStore.sol";
import {ITreasuryModule} from "./ITreasury.sol";
import {ModuleBase} from "../../base/ModuleBase.sol";

abstract contract TreasuryModule is
    ModuleBase,
    ITreasuryModule
{
    // relation of distributor and pool nft map to product nft
    mapping(NftId componentNftId => NftId productNftId) internal _productNft;
    // relation of component nft to token hanlder
    mapping(NftId componentNftId => TokenHandler tokenHandler) internal _tokenHandler;
    Fee internal _zeroFee;
    
    modifier onlyComponentOwnerService() virtual {
        require(
            msg.sender == address(this.getComponentOwnerService()),
            "ERROR:CMP-001:NOT_COPONENT_OWNER_SERVICE"
        );
        _;
    }

    function _initializeTreasuryModule(IKeyValueStore keyValueStore) internal {
        //_initializeModuleBase(keyValueStore);
        _initialize(keyValueStore);
        _zeroFee = FeeLib.zeroFee();
    }

    function registerProductSetup(
        NftId productNftId,
        TreasuryInfo memory setup
    ) 
        external
        onlyComponentOwnerService
    {
        NftId poolNftId = setup.poolNftId;
        NftId distributionNftId = setup.distributionNftId;

        require(address(_tokenHandler[productNftId]) == address(0), "ERROR:TRS-012:TOKEN_HANDLER_ALREADY_REGISTERED");
        require(_productNft[poolNftId].eqz(), "ERROR:TRS-013:POOL_ALREADY_LINKED");
        require(_productNft[distributionNftId].eqz(), "ERROR:TRS-014:COMPENSATION_ALREADY_LINKED");

        // TODO deploy TokenHandler with separate contract to save space
        // deploy product specific handler contract
        _tokenHandler[productNftId] = new TokenHandler(productNftId, address(setup.token));
        _productNft[distributionNftId] = productNftId;
        _productNft[poolNftId] = productNftId;

        _create(TREASURY(), productNftId, abi.encode(setup));
    }

    function setTreasuryInfo(
        NftId productNftId,
        TreasuryInfo memory info
    )
        external
        // TODO add authz (only component module)
        override
    {
        _updateData(TREASURY(), productNftId, abi.encode(info));
    }

    function getProductNftId(
        NftId componentNftId
    ) external view returns (NftId productNftId) {
        return _productNft[componentNftId];
    }

    function getTokenHandler(
        NftId componentNftId
    ) external view override returns (TokenHandler tokenHandler) {
        return _tokenHandler[componentNftId];
    }

    function hasTreasuryInfo(
        NftId productNftId
    ) public view override returns (bool hasInfo) {
        return _exists(TREASURY(), productNftId);
    }

    function getTreasuryInfo(
        NftId productNftId
    ) public view override returns (TreasuryInfo memory info) {
        return abi.decode(_getData(TREASURY(), productNftId), (TreasuryInfo));
    }

    function calculateFeeAmount(
        uint256 amount,
        Fee memory fee
    ) public pure override returns (uint256 feeAmount, uint256 netAmount) {
        return FeeLib.calculateFee(fee, amount);
    }

    function getFee(
        UFixed fractionalFee, 
        uint256 fixedFee
    ) external pure override returns (Fee memory fee) {
        return FeeLib.toFee(fractionalFee, fixedFee);
    }

    function getZeroFee() external view override returns (Fee memory fee) {
        return _zeroFee;
    }

    function getUFixed(
        uint256 a
    ) external pure override returns (UFixed) {
        return UFixedLib.toUFixed(a);
    }

    function getUFixed(
        uint256 a, 
        int8 exp
    ) external pure returns (UFixed)
    {
        return UFixedLib.toUFixed(a, exp);
    }
}
