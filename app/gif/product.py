from typing import List

from web3 import Web3
from web3utils.contract import Contract


def from_product(
        w3:Web3, 
        contract_name:str, 
        contract_address:str
) -> List[Contract]:
    product = Contract(w3, contract_name, contract_address)
    token = Contract(w3, "IERC20Metadata", product.getToken())
    instance = Contract(w3, "Instance", product.getInstance())
    admin = Contract(w3, "InstanceAdmin", instance.getInstanceAdmin())
    reader = Contract(w3, "InstanceReader", instance.getInstanceReader())
    registry = Contract(w3, "Registry", instance.getRegistry())
    return [product, token, instance, admin, reader, registry]

def pool_for_product(
        registry:Contract,
        reader:Contract,
        product:Contract,
        pool_contract_name:str
) -> Contract:
    pool_nft = reader.getProductInfo(product.getNftId())[5]
    pool_address = registry.getObjectAddress(pool_nft)
    return Contract(reader.w3, pool_contract_name, pool_address)
