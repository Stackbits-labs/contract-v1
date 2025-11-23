#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/transfer_to_accounts.sh [contract_address] [amount] [account_file] [log_file] [account_name]
# Example: ./scripts/transfer_to_accounts.sh 0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d 10000000000000000 deployments/accounts_collection.json deployments/transfer_log.json starknet-mainnet

CONTRACT_ADDRESS=${1:-0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d}
AMOUNT=${2:-10000000000000000}
ACCOUNT_FILE=${3:-deployments/accounts_collection.json}
LOG_FILE=${4:-deployments/transfer_log.json}
ACCOUNT_NAME=${5:-starknet-mainnet}
NETWORK=${6:-mainnet}

# Amount low and high (for u256)
AMOUNT_LOW=$AMOUNT
AMOUNT_HIGH=0

echo "Transferring tokens to accounts..."
echo "Contract: $CONTRACT_ADDRESS"
echo "Amount: $AMOUNT"
echo "Network: $NETWORK"
echo "Account: $ACCOUNT_NAME"
echo ""

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Please install jq first." >&2
    exit 1
fi

# Check if account file exists
if [ ! -f "$ACCOUNT_FILE" ]; then
    echo "Error: Account file not found: $ACCOUNT_FILE" >&2
    exit 1
fi

# Initialize log file
mkdir -p deployments
LOG_ARRAY="[]"

# Check if log file exists, load it
if [ -f "$LOG_FILE" ]; then
    LOG_ARRAY=$(cat "$LOG_FILE")
fi

# Get all accounts except stackbits1
ACCOUNTS=$(jq '[.[] | select(.name != "stackbits1")]' "$ACCOUNT_FILE")
ACCOUNT_COUNT=$(echo "$ACCOUNTS" | jq 'length')

echo "Found $ACCOUNT_COUNT accounts to transfer to (excluding stackbits1)"
echo ""

# Process each account
SUCCESS_COUNT=0
FAIL_COUNT=0

for i in $(seq 0 $((ACCOUNT_COUNT - 1))); do
    ACCOUNT=$(echo "$ACCOUNTS" | jq ".[$i]")
    ACCOUNT_NAME_ITEM=$(echo "$ACCOUNT" | jq -r '.name')
    ACCOUNT_ADDRESS=$(echo "$ACCOUNT" | jq -r '.address')
    
    echo "[$((i+1))/$ACCOUNT_COUNT] Transferring to $ACCOUNT_NAME_ITEM ($ACCOUNT_ADDRESS)..."
    
    # Invoke transfer
    set +e
    TRANSACTION_OUTPUT=$(sncast --account "$ACCOUNT_NAME" invoke \
        --network "$NETWORK" \
        --contract-address "$CONTRACT_ADDRESS" \
        --function transfer \
        --calldata "$ACCOUNT_ADDRESS" "$AMOUNT_LOW" "$AMOUNT_HIGH" 2>&1)
    TRANSACTION_EXIT_CODE=$?
    set -e
    
    if [ $TRANSACTION_EXIT_CODE -eq 0 ]; then
        # Extract transaction hash from output
        # sncast output format: "command: ... transaction_hash: 0x..."
        TX_HASH=$(echo "$TRANSACTION_OUTPUT" | grep -iE "(transaction_hash|hash)" | grep -oE "0x[a-fA-F0-9]+" | head -1 || echo "")
        
        if [ -z "$TX_HASH" ]; then
            # Try to extract from any hex pattern
            TX_HASH=$(echo "$TRANSACTION_OUTPUT" | grep -oE "0x[a-fA-F0-9]{64}" | head -1 || echo "")
        fi
        
        if [ -n "$TX_HASH" ]; then
            echo "  ✓ Success! Transaction hash: $TX_HASH"
            
            # Add to log
            TIMESTAMP=$(date -Iseconds)
            LOG_ENTRY=$(jq -n \
                --arg name "$ACCOUNT_NAME_ITEM" \
                --arg address "$ACCOUNT_ADDRESS" \
                --arg tx_hash "$TX_HASH" \
                --arg timestamp "$TIMESTAMP" \
                --arg amount "$AMOUNT" \
                '{
                    name: $name,
                    address: $address,
                    transactionHash: $tx_hash,
                    amount: $amount,
                    timestamp: $timestamp,
                    status: "success"
                }')
            
            LOG_ARRAY=$(echo "$LOG_ARRAY" | jq --argjson entry "$LOG_ENTRY" '. + [$entry]')
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            echo "  ⚠ Warning: Transaction may have succeeded but hash not found in output"
            echo "  Output: $TRANSACTION_OUTPUT"
            
            # Still log it
            TIMESTAMP=$(date -Iseconds)
            LOG_ENTRY=$(jq -n \
                --arg name "$ACCOUNT_NAME_ITEM" \
                --arg address "$ACCOUNT_ADDRESS" \
                --arg timestamp "$TIMESTAMP" \
                --arg amount "$AMOUNT" \
                --arg output "$TRANSACTION_OUTPUT" \
                '{
                    name: $name,
                    address: $address,
                    amount: $amount,
                    timestamp: $timestamp,
                    status: "unknown",
                    output: $output
                }')
            
            LOG_ARRAY=$(echo "$LOG_ARRAY" | jq --argjson entry "$LOG_ENTRY" '. + [$entry]')
        fi
    else
        echo "  ✗ Failed! Error: $TRANSACTION_OUTPUT"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        
        # Log failure
        TIMESTAMP=$(date -Iseconds)
        LOG_ENTRY=$(jq -n \
            --arg name "$ACCOUNT_NAME_ITEM" \
            --arg address "$ACCOUNT_ADDRESS" \
            --arg timestamp "$TIMESTAMP" \
            --arg amount "$AMOUNT" \
            --arg error "$TRANSACTION_OUTPUT" \
            '{
                name: $name,
                address: $address,
                amount: $amount,
                timestamp: $timestamp,
                status: "failed",
                error: $error
            }')
        
        LOG_ARRAY=$(echo "$LOG_ARRAY" | jq --argjson entry "$LOG_ENTRY" '. + [$entry]')
    fi
    
    # Save log after each transaction
    echo "$LOG_ARRAY" | jq '.' > "$LOG_FILE"
    
    # Small delay to avoid rate limiting
    sleep 1
done

echo ""
echo "=========================================="
echo "Transfer Summary:"
echo "  Total accounts: $ACCOUNT_COUNT"
echo "  Successful: $SUCCESS_COUNT"
echo "  Failed: $FAIL_COUNT"
echo "  Log file: $LOG_FILE"
echo "=========================================="

