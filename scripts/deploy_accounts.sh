#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/deploy_accounts.sh [prefix] [count] [network] [log_file]
# Example: ./scripts/deploy_accounts.sh stackbits 100 mainnet deployments/deploy_log.json

PREFIX=${1:-stackbits}
COUNT=${2:-100}
NETWORK=${3:-mainnet}
LOG_FILE=${4:-deployments/deploy_log.json}

echo "Deploying $COUNT accounts ($PREFIX 1-$PREFIX $COUNT)..."
echo "Network: $NETWORK"
echo ""

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Please install jq first." >&2
    exit 1
fi

# Initialize log file
mkdir -p deployments
LOG_ARRAY="[]"

# Check if log file exists, load it
if [ -f "$LOG_FILE" ]; then
    LOG_ARRAY=$(cat "$LOG_FILE")
fi

# Process each account
SUCCESS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

for i in $(seq 1 "$COUNT"); do
    NAME="${PREFIX}${i}"
    
    # Check if already deployed in log
    if echo "$LOG_ARRAY" | jq -e --arg name "$NAME" '.[] | select(.name == $name and .status == "success")' > /dev/null 2>&1; then
        echo "[$i/$COUNT] Skipping $NAME (already deployed successfully)"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        continue
    fi
    
    echo "[$i/$COUNT] Deploying account $NAME..."
    
    # Deploy account
    set +e
    DEPLOY_OUTPUT=$(sncast account deploy \
        --network="$NETWORK" \
        --name="$NAME" 2>&1)
    DEPLOY_EXIT_CODE=$?
    set -e
    
    if [ $DEPLOY_EXIT_CODE -eq 0 ]; then
        # Extract transaction hash from output
        # sncast output format: "command: ... transaction_hash: 0x..."
        TX_HASH=$(echo "$DEPLOY_OUTPUT" | grep -iE "(transaction_hash|hash)" | grep -oE "0x[a-fA-F0-9]+" | head -1 || echo "")
        
        if [ -z "$TX_HASH" ]; then
            # Try to extract from any hex pattern
            TX_HASH=$(echo "$DEPLOY_OUTPUT" | grep -oE "0x[a-fA-F0-9]{64}" | head -1 || echo "")
        fi
        
        if [ -n "$TX_HASH" ]; then
            echo "  ✓ Success! Transaction hash: $TX_HASH"
            
            # Add to log
            TIMESTAMP=$(date -Iseconds)
            LOG_ENTRY=$(jq -n \
                --arg name "$NAME" \
                --arg tx_hash "$TX_HASH" \
                --arg timestamp "$TIMESTAMP" \
                --arg network "$NETWORK" \
                '{
                    name: $name,
                    transactionHash: $tx_hash,
                    network: $network,
                    timestamp: $timestamp,
                    status: "success"
                }')
            
            LOG_ARRAY=$(echo "$LOG_ARRAY" | jq --argjson entry "$LOG_ENTRY" '. + [$entry]')
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            echo "  ⚠ Warning: Deployment may have succeeded but hash not found in output"
            echo "  Output: $DEPLOY_OUTPUT"
            
            # Still log it
            TIMESTAMP=$(date -Iseconds)
            LOG_ENTRY=$(jq -n \
                --arg name "$NAME" \
                --arg timestamp "$TIMESTAMP" \
                --arg network "$NETWORK" \
                --arg output "$DEPLOY_OUTPUT" \
                '{
                    name: $name,
                    network: $network,
                    timestamp: $timestamp,
                    status: "unknown",
                    output: $output
                }')
            
            LOG_ARRAY=$(echo "$LOG_ARRAY" | jq --argjson entry "$LOG_ENTRY" '. + [$entry]')
        fi
    else
        echo "  ✗ Failed! Error: $DEPLOY_OUTPUT"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        
        # Log failure
        TIMESTAMP=$(date -Iseconds)
        LOG_ENTRY=$(jq -n \
            --arg name "$NAME" \
            --arg timestamp "$TIMESTAMP" \
            --arg network "$NETWORK" \
            --arg error "$DEPLOY_OUTPUT" \
            '{
                name: $name,
                network: $network,
                timestamp: $timestamp,
                status: "failed",
                error: $error
            }')
        
        LOG_ARRAY=$(echo "$LOG_ARRAY" | jq --argjson entry "$LOG_ENTRY" '. + [$entry]')
    fi
    
    # Save log after each deployment
    echo "$LOG_ARRAY" | jq '.' > "$LOG_FILE"
    
    # Small delay to avoid rate limiting
    sleep 3
done

echo ""
echo "=========================================="
echo "Deployment Summary:"
echo "  Total accounts: $COUNT"
echo "  Successful: $SUCCESS_COUNT"
echo "  Failed: $FAIL_COUNT"
echo "  Skipped (already deployed): $SKIP_COUNT"
echo "  Log file: $LOG_FILE"
echo "=========================================="

# List failed accounts if any
if [ "$FAIL_COUNT" -gt 0 ]; then
    echo ""
    echo "Failed accounts:"
    echo "$LOG_ARRAY" | jq -r '.[] | select(.status == "failed") | "  - \(.name): \(.error // "Unknown error")"'
fi

