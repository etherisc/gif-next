import json
import logging

from typing import Any, Dict

from web3 import Web3
from web3.contract import Contract as Web3Contract
from web3.exceptions import TimeExhausted
from web3.types import FilterParams

from web3utils.wallet import Wallet

class Contract:

    FOUNDRY_OUT = "../artifacts_forge"
    SOLIDITY_EXT = "sol"
    GAS = 1000000
    TX_TIMEOUT_SECONDS = 120

    name:str|None = None
    abi:Dict[str, Any]|None = None
    address:str|None = None
    contract:Web3Contract|None = None
    w3:Web3|None = None

    def __init__(self, w3:Web3, contract_name:str, contract_address:str, out_path:str = FOUNDRY_OUT):
        self.w3 = w3
        self.name = contract_name
        self.abi = self._load_abi(contract_name, out_path)
        self.contract = w3.eth.contract(address=contract_address, abi=self.abi)
        self.address = self.contract.address
        self._setup_functions()

    def is_connected(self) -> bool:
        return self.w3.is_connected()
    
    def get_logs(self, filter_params:FilterParams|None = None) -> Any:
        if not filter_params:
            filter_params = {
                'fromBlock': 'latest',
                'address': self.address
            }

        return self.w3.eth.get_logs(filter_params=filter_params)

    def _setup_functions(self) -> None:
        for func in self.contract.abi:
            if func.get('type') == 'function':
                func_name = func['name']
                mutability = func.get('stateMutability')

                if mutability in ['nonpayable', 'payable']:
                    logging.info(f"creating {func_name}(...) tx")
                    setattr(self, func_name, self._create_write_method(func_name))
                elif mutability in ['view', 'pure']:
                    logging.info(f"creating {func_name}(...) call")
                    setattr(self, func_name, self._create_read_method(func_name))

    def _create_read_method(self, func_name: str):
        def read_method(*args, **kwargs) -> Any:
            try:
                modified_args = [arg.address if isinstance(arg, Wallet) else arg for arg in args]
                return getattr(self.contract.functions, func_name)(*modified_args, **kwargs).call()
            except Exception as e:
                logging.warn(f"Error calling function '{func_name}': {e}")
                return None

        # Optionally, add docstrings or additional attributes here
        read_method.__name__ = func_name
        read_method.__doc__ = f"Calls the '{func_name}' function of the contract."
        return read_method

    def _get_tx_params(self, args:tuple) -> Dict[str, Any]:
        if len(args) == 0:
            raise ValueError("No transaction parameters provided.")

        tx_params = args[-1]

        if not isinstance(tx_params, dict):
            raise ValueError("Transaction parameters must be provided as a dictionary.")

        if 'from' not in tx_params:
            raise ValueError("Transaction parameters must include 'from' account.")

        if not isinstance(tx_params['from'], Wallet):
            raise ValueError("Transaction 'from' account must be a Wallet instance.")

        return tx_params

    def _create_write_method(self, func_name: str):
        def write_method(*args) -> str:
            tx_params = self._get_tx_params(args)
            function_args = args[:-1]

            try:
                wallet = tx_params['from']

                # create tx properties
                chain_id = self.w3.eth.chain_id
                gas = tx_params.get('gas', self.GAS)
                gas_price = tx_params.get('gasPrice', self.w3.eth.gas_price)
                nonce = self.w3.eth.get_transaction_count(wallet.address)

                # transform wallet args to addresses (str)
                modified_args = [arg.address if isinstance(arg, Wallet) else arg for arg in function_args]

                # create tx
                txn = getattr(self.contract.functions, func_name)(*modified_args).build_transaction({
                    'chainId': chain_id,
                    'gas': gas,
                    'gasPrice': gas_price,
                    'nonce': nonce,
                })

                # sign tx
                private_key = bytes(wallet.account.key)
                signed_txn = self.w3.eth.account.sign_transaction(txn, private_key=private_key)

                # send signed transaction
                tx_hash = self.w3.eth.send_raw_transaction(signed_txn.raw_transaction)
                logging.info(f"Transaction sent: {tx_hash.hex()}")

                if 'timeout' not in tx_params:
                    timeout = self.TX_TIMEOUT_SECONDS
                else:
                    timeout = tx_params['timeout'] if tx_params['timeout'] is not None else self.TX_TIMEOUT_SECONDS

                try:
                    receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash, timeout=timeout)
                except TimeExhausted:
                    logging.warning(f"Transaction timeout after {timeout} seconds.")
                    return tx_hash.hex()

                if receipt['status'] == 1:
                    logging.info(f"Transaction successful: {receipt}")
                else:
                    logging.warning(f"Transaction failed: {receipt}")

                return tx_hash.hex()

            except Exception as e:
                logging.warning(f"Error sending transaction for function '{func_name}': {e}")
                return tx_hash.hex()

        write_method.__name__ = func_name
        write_method.__doc__ = f"Sends a transaction to the '{func_name}' function of the contract."
        return write_method

    def _load_abi(self, contract:str, out_path:str) -> Dict[str, Any]:
        try:
            abi_path = f"{out_path}/{contract}.{self.SOLIDITY_EXT}/{contract}.json"

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
