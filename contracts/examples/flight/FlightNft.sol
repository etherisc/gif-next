// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IRegistry} from "../../registry/IRegistry.sol";

import {ChainNft} from "../../registry/ChainNft.sol";
import {FlightProduct} from "./FlightProduct.sol";
import {InstanceReader} from "../../instance/InstanceReader.sol";
import {NftId, NftIdLib} from "../../type/NftId.sol";
import {RiskId} from "../../type/RiskId.sol";


/**
 * @title FlightNft
 * @dev FlightNft provides NFT data for flight delay policies.
 */
// contract FlightNft is IERC721Metadata {
contract FlightNft is
    ERC721, 
    Ownable
{

    ChainNft private _chainNft;
    FlightProduct private _flightProduct;
    InstanceReader private _reader;
    IRegistry private _registry;
    string private _baseUri;


    constructor(
        address flightProductAddress,
        string memory nftName,
        string memory nftSymbol,
        string memory baseUri
    ) 
        ERC721(nftName, nftSymbol)
        Ownable(msg.sender)
    {
        _flightProduct = FlightProduct(flightProductAddress);
        _registry = _flightProduct.getRegistry();
        _chainNft = ChainNft(_registry.getChainNftAddress());
        _reader = _flightProduct.getInstance().getInstanceReader();
        _baseUri = baseUri;
    }


    /**
     * Set the base URI to the specified value.
     * Once set, this results in tokenURI() to return <baseUri><tokenId>.
     */
    function setBaseURI(string memory baseUri)
        public 
        onlyOwner()
    {
        _baseUri = baseUri;
    }


    /**
     * @dev Return the NFT token URI for the specified token.
     * No check is performed to ensure the token exists.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string.concat(baseURI, toString(tokenId)) : "";
    }


    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal override view returns (string memory) {
        return _baseUri;
    }


    function approve(address to, uint256 tokenId) public override { _revert(); }
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override { _revert(); }
    function setApprovalForAll(address operator, bool approved) public override { _revert(); }
    function transferFrom(address from, address to, uint256 tokenId) public override { _revert(); }

    function balanceOf(address owner) public override view returns (uint256 balance) {
        return _chainNft.balanceOf(owner);
    }

    function getApproved(uint256 tokenId) public override view returns (address operator) {
        return _chainNft.getApproved(tokenId);
    }

    function isApprovedForAll(address owner, address operator) public override view returns (bool) {
        return _chainNft.isApprovedForAll(owner, operator);
    }

    function ownerOf(uint256 tokenId) public override view returns (address owner) {
        return _chainNft.ownerOf(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public override view returns (bool) {
        return _chainNft.supportsInterface(interfaceId);
    }


    // /**
    //  * @dev See {IERC721Metadata-name}.
    //  */    
    // function name() public override view returns (string memory) {
    //     return _nftName;
    // }


    // /**
    //  * @dev See {IERC721Metadata-name}.
    //  */    
    // function symbol() public override view returns (string memory) {
    //     return _nftSymbol;
    // }


    /**
     * @dev Return the NFT metadata in JSON format.
     * examples:
     * - https://basescan.org/address/0x4ed83635e2309a7c067d0f98efca47b920bf79b1#readContract
     *   {"name":"No-Punk #7580","image":"https://gateway.irys.xyz/InMDGHEx3L1YyRz6boihZGDHw4CKCRlLBlKnW6D83i4/7580.png","attributes":[{"trait_type":"Hair","value":"Cap"},{"trait_type":"Mouth","value":"Purple Lipstick"},{"trait_type":"Type","value":"Female"}]}
     * - ,
     *   {"name":"My NFT","description": "A unique digital asset", "image": "https://example.com/nft/1.png" }
     */    
    function getMetadataJson(uint256 tokenId) external view returns (string memory) {
        (
            , // risk id
            string memory flightData,
            string memory departureTimeLocal,
            string memory arrivalTimeLocal,
            , // status
            // delay minutes
        ) = getRiskData(NftIdLib.toNftId(tokenId));

        return string(
            abi.encodePacked(
                "{\"name\":\"Flight Delay Policy #",
                toString(tokenId),
                "\",\"description\":\"Flight: ",
                flightData,
                ", Scheduled Departure: ",
                departureTimeLocal,
                ", Scheduled Arrival: ",
                arrivalTimeLocal,
                "\"}"
                ));
    }


    function getRiskData(NftId policyNftId)
        public
        view
        returns (
            RiskId riskId,
            string memory flightData,
            string memory departureTimeLocal,
            string memory arrivalTimeLocal,
            bytes1 status,
            int256 delayMinutes
        )
    {
        riskId = _reader.getPolicyInfo(policyNftId).riskId;
        bytes memory data = _reader.getRiskInfo(riskId).data;

        if (data.length > 0) {
            FlightProduct.FlightRisk memory flightRisk = _flightProduct.decodeFlightRiskData(data);
            flightData = flightRisk.flightData.toString();
            departureTimeLocal = flightRisk.departureTimeLocal;
            arrivalTimeLocal = flightRisk.arrivalTimeLocal;
            status = flightRisk.status;
            delayMinutes = flightRisk.delayMinutes;
        }
    }


    /**
     * returns the flight product address.
     */
    function getChainNft() external view returns (address) {
        return address(_chainNft);
    }


    /**
     * returns the flight product address.
     */
    function getFlightProduct() external view returns (address) {
        return address(_flightProduct);
    }


    function toString(uint256 value) public pure returns (string memory) {
        if (value == 0) {
            return "0";
        }

        uint256 temp = value;
        uint256 digits = 0;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);
        uint index = digits - 1;

        temp = value;
        while (temp != 0) {
            buffer[index] = bytes1(uint8(48 + temp % 10));
            temp /= 10;

            if (index > 0) {
                index--;
            }
        }

        return string(buffer);
    }

    function _revert() private pure {
        revert("FlightNft: Use GIF Chain NFT contract to interact with NFTs. See function getChainNft()");
    }
}