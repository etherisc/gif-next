import pytest
import brownie

from brownie.network.account import Account

from brownie import (
    history,
    interface,
    web3,
    ChainNft,
    Registry
)

from test_brownie.const import (
    ZERO_ADDRESS,
    ADDRESS,
    NFT_ID,
)

from test_brownie.util import contract_from_address

# enforce function isolation for tests below
@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass


def test_chain_nft_from_registry(
    registry_owner: Account,
    registry: Registry,
    outsider: Account
):

    # check number of tokens after deploy
    nft = contract_from_address(ChainNft, registry.getChainNft())

    assert nft.name() == 'Dezentralized Insurance Protocol Registry'
    assert nft.symbol() == 'DIPR'

    nfts = 2 if web3.chain_id == 1 else 3
    assert nft.totalSupply() == nfts
    assert nft.balanceOf(registry_owner) == nfts

    protocol_nft_id = 1101
    assert nft.PROTOCOL_NFT_ID() == protocol_nft_id
    assert nft.exists(protocol_nft_id)

    global_registry_nft_id = 2101
    assert nft.GLOBAL_REGISTRY_ID() == global_registry_nft_id
    assert nft.exists(global_registry_nft_id)

    if web3.chain_id == 1337:
        assert nft.exists(2133704)


def test_registry_initial_setup(
    registry_owner: Account,
    registry: Registry,
    chain_nft: ChainNft,
    outsider: Account
):
    assert registry.getOwner() == registry_owner

    assert registry.getChainNft() == chain_nft
    assert chain_nft.getRegistryAddress() == registry

    assert registry.isRegistered[ADDRESS](registry)

    registry_nft_id = registry.getNftId(registry)
    assert registry.isRegistered[NFT_ID](registry_nft_id)

    info = registry.getObjectInfo(registry_nft_id).dict()
    assert info['initialOwner'] == registry_owner
    assert info['nftId'] == registry_nft_id
    assert info['objectAddress'] == registry
    assert info['objectType'] == 20 #REGISTRY(

    if web3.chain_id == 1:
        assert info['parentNftId'] == 1101 # the protocol nft
    else:
        assert info['parentNftId'] == 2101 # the global registry nft

    assert False