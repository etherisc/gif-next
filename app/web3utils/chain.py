
from web3 import Web3

class Chain:
    """Simple class to query network."""

    w3:Web3|None = None

    def __init__(self, w3:Web3) -> None:
        """Create a new chain query object.
        """
        self.w3 = w3

    def id(self) -> int:
        """Get the network ID."""
        chain_id = self.w3.net.version
        try:
            return int(chain_id)
        except Exception as e:
            raise ValueError(f"Chain Id {chain_id} is not an integer. Error: {e}")

    def latest_block(self) -> int:
        """Get the number of the latest block."""
        self.w3.eth.block_number

    def block(self, block_id='latest') -> dict:
        """Get a block by its ID."""
        return dict(self.w3.eth.get_block(block_id))

    def timestamp(self, block_number='latest') -> int:
        """Get the timestamp of a block."""
        return self.w3.eth.get_block(block_number)['timestamp']