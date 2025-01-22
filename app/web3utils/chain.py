
from web3 import Web3

class Chain:
    """Simple class to query network."""

    w3:Web3|None = None

    def __init__(self, w3:Web3) -> None:
        """Create a new chain query object.
        """
        self.w3 = w3

    def id(self) -> str:
        """Get the network ID."""
        return self.w3.net.version

    def latest_block(self) -> int:
        """Get the number of the latest block."""
        return self.w3.eth.block_number

    def block(self, block_id='latest') -> dict:
        """Get a block by its ID."""
        return dict(self.w3.eth.get_block(block_id))

    def timestamp(self, block_number='latest') -> int:
        """Get the timestamp of a block."""
        return self.w3.eth.get_block(block_number)['timestamp']