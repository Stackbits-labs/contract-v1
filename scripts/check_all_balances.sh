#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/check_all_balances.sh [contract_address] [account_file] [output_file] [network]
# Example: ./scripts/check_all_balances.sh 0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d deployments/accounts_collection.json deployments/balance_check_all.json mainnet

CONTRACT_ADDRESS=${1:-0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d}
ACCOUNT_FILE=${2:-deployments/accounts_collection.json}
OUTPUT_FILE=${3:-deployments/balance_check_all.json}
NETWORK=${4:-mainnet}

echo "Checking balance for all accounts..."
echo "Contract: $CONTRACT_ADDRESS"
echo "Network: $NETWORK"
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

# Get all accounts
ACCOUNTS=$(jq '.' "$ACCOUNT_FILE")
ACCOUNT_COUNT=$(echo "$ACCOUNTS" | jq 'length')

if [ "$ACCOUNT_COUNT" -eq 0 ]; then
    echo "No accounts found in $ACCOUNT_FILE"
    exit 0
fi

echo "Found $ACCOUNT_COUNT accounts to check"
echo ""

# Initialize results array
RESULTS="[]"

# Check balance for each account
SUCCESS_COUNT=0
FAIL_COUNT=0
ZERO_BALANCE_COUNT=0

for i in $(seq 0 $((ACCOUNT_COUNT - 1))); do
    ACCOUNT=$(echo "$ACCOUNTS" | jq ".[$i]")
    ACCOUNT_NAME=$(echo "$ACCOUNT" | jq -r '.name')
    ACCOUNT_ADDRESS=$(echo "$ACCOUNT" | jq -r '.address')
    
    echo "[$((i+1))/$ACCOUNT_COUNT] Checking balance for $ACCOUNT_NAME ($ACCOUNT_ADDRESS)..."
    
    # Call balanceOf function
    set +e
    BALANCE_OUTPUT=$(sncast call \
        --network "$NETWORK" \
        --contract-address "$CONTRACT_ADDRESS" \
        --function balanceOf \
        --calldata "$ACCOUNT_ADDRESS" 2>&1)
    BALANCE_EXIT_CODE=$?
    set -e
    
    if [ $BALANCE_EXIT_CODE -eq 0 ]; then
        # Extract balance from output
        # sncast output format: "command: ... result: [0x...]"
        BALANCE=$(echo "$BALANCE_OUTPUT" | grep -iE "(result|balance)" | grep -oE "0x[a-fA-F0-9]+" | head -1 || echo "")
        
        if [ -z "$BALANCE" ]; then
            # Try to extract any hex value that looks like a balance
            BALANCE=$(echo "$BALANCE_OUTPUT" | grep -oE "0x[a-fA-F0-9]{1,64}" | head -1 || echo "")
        fi
        
        if [ -n "$BALANCE" ]; then
            # Check if balance is zero
            # Remove 0x prefix and check if all digits are 0
            BALANCE_CLEAN=$(echo "$BALANCE" | tr '[:upper:]' '[:lower:]' | sed 's/^0x//')
            
            # Remove leading zeros and check if empty or just zeros
            BALANCE_STRIPPED=$(echo "$BALANCE_CLEAN" | sed 's/^0*//')
            
            # Check if balance is zero
            if [ -z "$BALANCE_STRIPPED" ] || [ "$BALANCE_STRIPPED" = "" ]; then
                STATUS="fail"
                FAIL_COUNT=$((FAIL_COUNT + 1))
                ZERO_BALANCE_COUNT=$((ZERO_BALANCE_COUNT + 1))
                echo "  ✗ FAIL: Balance is 0 ($BALANCE)"
            else
                STATUS="success"
                SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
                echo "  ✓ Success: Balance = $BALANCE"
            fi
            
            # Add to results
            TIMESTAMP=$(date -Iseconds)
            RESULT_ENTRY=$(jq -n \
                --arg name "$ACCOUNT_NAME" \
                --arg address "$ACCOUNT_ADDRESS" \
                --arg balance "$BALANCE" \
                --arg status "$STATUS" \
                --arg timestamp "$TIMESTAMP" \
                '{
                    name: $name,
                    address: $address,
                    balance: $balance,
                    status: $status,
                    timestamp: $timestamp
                }')
            
            RESULTS=$(echo "$RESULTS" | jq --argjson entry "$RESULT_ENTRY" '. + [$entry]')
        else
            echo "  ⚠ Warning: Could not extract balance from output"
            echo "  Output: $BALANCE_OUTPUT"
            
            # Still log it as unknown
            TIMESTAMP=$(date -Iseconds)
            RESULT_ENTRY=$(jq -n \
                --arg name "$ACCOUNT_NAME" \
                --arg address "$ACCOUNT_ADDRESS" \
                --arg timestamp "$TIMESTAMP" \
                --arg output "$BALANCE_OUTPUT" \
                '{
                    name: $name,
                    address: $address,
                    timestamp: $timestamp,
                    status: "unknown",
                    output: $output
                }')
            
            RESULTS=$(echo "$RESULTS" | jq --argjson entry "$RESULT_ENTRY" '. + [$entry]')
        fi
    else
        echo "  ✗ Failed to call balanceOf! Error: $BALANCE_OUTPUT"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        
        # Log failure
        TIMESTAMP=$(date -Iseconds)
        RESULT_ENTRY=$(jq -n \
            --arg name "$ACCOUNT_NAME" \
            --arg address "$ACCOUNT_ADDRESS" \
            --arg timestamp "$TIMESTAMP" \
            --arg error "$BALANCE_OUTPUT" \
            '{
                name: $name,
                address: $address,
                timestamp: $timestamp,
                status: "fail",
                error: $error
            }')
        
        RESULTS=$(echo "$RESULTS" | jq --argjson entry "$RESULT_ENTRY" '. + [$entry]')
    fi
    
    # Save results after each check (for safety)
    mkdir -p deployments
    echo "$RESULTS" | jq '.' > "$OUTPUT_FILE"
    
    # Small delay to avoid rate limiting
    sleep 0.5
done

echo ""
echo "=========================================="
echo "Balance Check Summary:"
echo "  Total accounts checked: $ACCOUNT_COUNT"
echo "  Success (balance > 0): $SUCCESS_COUNT"
echo "  Failed (balance = 0): $ZERO_BALANCE_COUNT"
echo "  Other failures: $((FAIL_COUNT - ZERO_BALANCE_COUNT))"
echo "  Results saved to: $OUTPUT_FILE"
echo "=========================================="

# List accounts with zero balance
if [ "$ZERO_BALANCE_COUNT" -gt 0 ]; then
    echo ""
    echo "Accounts with zero balance (FAILED):"
    echo "$RESULTS" | jq -r '.[] | select(.status == "fail" and .balance != null) | "  - \(.name): \(.address) (balance: \(.balance))"'
fi

