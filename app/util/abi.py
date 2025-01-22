import json
import os
import sys
from typing import Any, Dict    

from web3 import Web3

FOUNDRY_OUT = "./out"
SOLIDITY_EXT = "sol"

def load_abi(contract:str, out_path:str = FOUNDRY_OUT) -> Dict[str, Any]:
    """
    Loads the ABI from a given contract.
    """
    try:
        abi_path = f"{out_path}/{contract}.{SOLIDITY_EXT}/{contract}.json"

        with open(abi_path, "r") as abi_file:
            contract_json = json.load(abi_file)
            abi = contract_json.get("abi")

            if abi is None:
                raise ValueError(f"ABI not found in the JSON file {abi_path}.")

        return abi

    except FileNotFoundError:
        raise ValueError(f"Error: The file {abi_path} does not exist.")

    except json.JSONDecodeError:
        raise ValueError(f"Error: The file {abi_path} is not a valid JSON file.")

    except ValueError as ve:
        ValueError(f"Error: {ve}")
