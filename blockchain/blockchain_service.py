
import json
from web3 import Web3
from blockchain.config import RPC_URL, CONTRACT_ADDRESS, ABI_PATH

# Connect to the local Hardhat blockchain
web3 = Web3(Web3.HTTPProvider(RPC_URL))

if not web3.is_connected():
    raise ConnectionError(
        f"Cannot connect to blockchain at {RPC_URL}. "
        "Make sure the Hardhat node is running."
    )

# Load the contract ABI
with open(ABI_PATH, "r", encoding="utf-8") as abi_file:
    contract_abi = json.load(abi_file)

contract = web3.eth.contract(
    address=Web3.to_checksum_address(CONTRACT_ADDRESS),
    abi=contract_abi
)


def register_batch(
    sender_private_key,
    batch_id,
    medicine_name,
    batch_number,
    expiry_timestamp,
    quantity,
    seal_id
):
    account = web3.eth.account.from_key(sender_private_key)

    function = contract.functions.registerBatch(
        batch_id,
        medicine_name,
        batch_number,
        int(expiry_timestamp),
        int(quantity),
        seal_id
    )

    return _send_transaction(function, account)


def transfer_batch(sender_private_key, batch_id, receiver, new_seal_id):
    account = web3.eth.account.from_key(sender_private_key)
    receiver = Web3.to_checksum_address(receiver)

    function = contract.functions.transferBatch(
        batch_id,
        receiver,
        new_seal_id
    )

    return _send_transaction(function, account)


def inspect_batch(sender_private_key, batch_id, notes, new_seal_id):
    account = web3.eth.account.from_key(sender_private_key)

    function = contract.functions.inspectBatch(
        batch_id,
        notes,
        new_seal_id
    )

    return _send_transaction(function, account)


def get_batch(batch_id):
    result = contract.functions.getBatch(batch_id).call()

    return {
        "batchId": result[0],
        "medicineName": result[1],
        "batchNumber": result[2],
        "expiryDate": result[3],
        "quantity": result[4],
        "sealId": result[5]
    }


def get_batch_history(batch_id):
    batch, holder, transfers, inspections = (
        contract.functions.getBatchHistory(batch_id).call()
    )

    return {
        "batch": {
            "batchId": batch[0],
            "medicineName": batch[1],
            "batchNumber": batch[2],
            "expiryDate": batch[3],
            "quantity": batch[4],
            "sealId": batch[5]
        },
        "currentHolder": holder,
        "transfers": [
            {
                "sender": item[0],
                "receiver": item[1],
                "quantity": item[2],
                "timestamp": item[3],
                "previousSealId": item[4],
                "newSealId": item[5]
            }
            for item in transfers
        ],
        "inspections": [
            {
                "inspector": item[0],
                "timestamp": item[1],
                "notes": item[2],
                "previousSealId": item[3],
                "newSealId": item[4]
            }
            for item in inspections
        ]
    }


def _send_transaction(function, account):
    nonce = web3.eth.get_transaction_count(account.address)

    transaction = function.build_transaction({
        "from": account.address,
        "nonce": nonce,
        "chainId": web3.eth.chain_id,
        "gas": 1_000_000,
        "gasPrice": web3.eth.gas_price
    })

    signed = account.sign_transaction(transaction)
    tx_hash = web3.eth.send_raw_transaction(signed.raw_transaction)
    receipt = web3.eth.wait_for_transaction_receipt(tx_hash)

    if receipt.status != 1:
        raise RuntimeError(
            f"Transaction failed: {tx_hash.hex()}"
        )

    return {
        "transactionHash": tx_hash.hex(),
        "blockNumber": receipt.blockNumber,
        "status": "success"
    }


if __name__ == "__main__":
    print("Connected to Hardhat successfully!")
    print("Chain ID:", web3.eth.chain_id)
    print("Contract address:", contract.address)
    print("Contract owner:", contract.functions.owner().call())
