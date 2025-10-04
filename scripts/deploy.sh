#!/bin/bash

# Deploy script using starkli
# Usage: ./deploy.sh [network] [contract_name]

set -e

NETWORK=${1:-"sepolia"}
CONTRACT_NAME=${2:-"stackbits_vault"}

echo "Deploying $CONTRACT_NAME to $NETWORK network..."

# Build the project first
echo "Building project..."
scarb build

# Check if starkli is installed
if ! command -v starkli &> /dev/null; then
    echo "Error: starkli is not installed. Please install starkli first."
    exit 1
fi

# Declare the contract
echo "Declaring contract..."
SIERRA_FILE="target/dev/${CONTRACT_NAME}_${CONTRACT_NAME}.contract_class.json"
CASM_FILE="target/dev/${CONTRACT_NAME}_${CONTRACT_NAME}.compiled_contract_class.json"

if [ ! -f "$SIERRA_FILE" ]; then
    echo "Error: Sierra file not found at $SIERRA_FILE"
    echo "Make sure to run 'scarb build' first"
    exit 1
fi

CLASS_HASH=$(starkli declare "$SIERRA_FILE" --casm-file "$CASM_FILE" --network "$NETWORK" --compiler-version "2.1.0")

echo "Contract declared with class hash: $CLASS_HASH"

# Deploy the contract
echo "Deploying contract..."
CONTRACT_ADDRESS=$(starkli deploy "$CLASS_HASH" --network "$NETWORK")

echo "Contract deployed successfully!"
echo "Contract Address: $CONTRACT_ADDRESS"
echo "Class Hash: $CLASS_HASH"
echo "Network: $NETWORK"

# Save deployment info
mkdir -p deployments
echo "{
  \"network\": \"$NETWORK\",
  \"contract_name\": \"$CONTRACT_NAME\", 
  \"class_hash\": \"$CLASS_HASH\",
  \"contract_address\": \"$CONTRACT_ADDRESS\",
  \"deployed_at\": \"$(date -Iseconds)\"
}" > "deployments/${NETWORK}_${CONTRACT_NAME}.json"

echo "Deployment info saved to deployments/${NETWORK}_${CONTRACT_NAME}.json"