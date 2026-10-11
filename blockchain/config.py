
import os
from dotenv import load_dotenv

load_dotenv()

RPC_URL = os.getenv("RPC_URL", "http://127.0.0.1:8545")
CONTRACT_ADDRESS = os.getenv(
    "CONTRACT_ADDRESS",
    "0x5FbDB2315678afecb367f032d93F642f64180aa3"
)

ABI_PATH = os.path.join(
    os.path.dirname(os.path.dirname(__file__)),
    "artifacts",
    "PharmaShield_abi.json"
)
