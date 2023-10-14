import json

from web3 import Web3

# In the video, we forget to `install_solc`
# from solcx import compile_standard
from solcx import compile_standard, install_solc
import os
from dotenv import load_dotenv
from web3.middleware import geth_poa_middleware

load_dotenv()


with open("./SimpleStorage.sol", "r") as file:
    simple_storage_file = file.read()

# We add these two lines that we forgot from the video!
print("Installing...")
install_solc("0.6.0")

# Solidity source code
compiled_sol = compile_standard(
    {
        "language": "Solidity",
        "sources": {"SimpleStorage.sol": {"content": simple_storage_file}},
        "settings": {
            "outputSelection": {
                "*": {
                    "*": ["abi", "metadata", "evm.bytecode", "evm.bytecode.sourceMap"]
                }
            }
        },
    },
    solc_version="0.6.0",
)

with open("compiled_code.json", "w") as file:
    json.dump(compiled_sol, file)

# get bytecode
bytecode = compiled_sol["contracts"]["SimpleStorage.sol"]["SimpleStorage"]["evm"][
    "bytecode"
]["object"]

# get abi
abi = json.loads(
    compiled_sol["contracts"]["SimpleStorage.sol"]["SimpleStorage"]["metadata"]
)["output"]["abi"]

# w3 = Web3(Web3.HTTPProvider(os.getenv("SEPOLIA_RPC_URL")))
# chain_id = 4
#
# For connecting to ganache
# w3 = Web3(Web3.HTTPProvider("http://127.0.0.1:8545"))
w3 = Web3(
    Web3.HTTPProvider("https://sepolia.infura.io/v3/0913ed98eb5d4e8d94c9acdc6f126dfc")
)
chain_id = 11155111
private_key = os.getenv("PRIVATE_KEY")

if chain_id == 11155111:
    w3.middleware_onion.inject(geth_poa_middleware, layer=0)
    # print(w3.clientVersion)
# Added print statement to ensure connection suceeded as per
# https://web3py.readthedocs.io/en/stable/middleware.html#geth-style-proof-of-authority

# my_address = "0xac945F34af0f0245DC1f2C39e4357A9fE27431Eb"
# private_key = "8a63f5a3608d032ba652a323d62f333f71a895d253d6aa9f5defc16a43e4d7f1"

my_address = "0x619F1c757a7F3f22Bb8E8398bE6eACe782804cd0"

# Create the contract in Python
SimpleStorage = w3.eth.contract(abi=abi, bytecode=bytecode)
# Get the latest transaction
nonce = w3.eth.get_transaction_count(my_address)
# Submit the transaction that deploys the contract
transaction = SimpleStorage.constructor().build_transaction(
    {
        "chainId": chain_id,
        "gasPrice": w3.eth.gas_price,
        "from": my_address,
        "nonce": nonce,
    }
)
# Sign the transaction
signed_txn = w3.eth.account.sign_transaction(transaction, private_key=private_key)
print("Deploying Contract!")
# Send it!
tx_hash = w3.eth.send_raw_transaction(signed_txn.rawTransaction)
# Wait for the transaction to be mined, and get the transaction receipt
print("Waiting for transaction to finish...")
tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
print(f"Done! Contract deployed to {tx_receipt.contractAddress}")


# Working with deployed Contracts
# simple_storage = w3.eth.contract(address=tx_receipt.contractAddress, abi=abi)
simple_storage = w3.eth.contract(address="address", abi=abi)
print(f"Initial Stored Value {simple_storage.functions.retrieve().call()}")
greeting_transaction = simple_storage.functions.store(15).build_transaction(
    {
        "chainId": chain_id,
        "gasPrice": w3.eth.gas_price,
        "from": my_address,
        "nonce": nonce + 1,
    }
)
signed_greeting_txn = w3.eth.account.sign_transaction(
    greeting_transaction, private_key=private_key
)
tx_greeting_hash = w3.eth.send_raw_transaction(signed_greeting_txn.rawTransaction)
print("Updating stored Value...")
tx_receipt = w3.eth.wait_for_transaction_receipt(tx_greeting_hash)

print(simple_storage.functions.retrieve().call())
