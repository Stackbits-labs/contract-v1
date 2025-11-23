#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/collect_accounts.sh [prefix] [count] [output_file]
# Example: ./scripts/collect_accounts.sh stackbits 100 deployments/accounts_collection.json

PREFIX=${1:-stackbits}
COUNT=${2:-100}
OUTFILE=${3:-deployments/accounts_collection.json}

mkdir -p deployments

echo "Collecting account information for ${PREFIX}1-${PREFIX}${COUNT}..."

# Run sncast account list and capture output
ACCOUNT_LIST=$(sncast account list --display-private-keys)

# Initialize JSON array
JSON_ARRAY="["
FIRST=true

# Process each account
for i in $(seq 1 "$COUNT"); do
  NAME="${PREFIX}${i}"
  
  # Check if account exists in the list (format: "- account-name:")
  if ! echo "$ACCOUNT_LIST" | grep -qE "^- ${NAME}:"; then
    echo "Warning: Account $NAME not found in sncast account list" >&2
    continue
  fi
  
  # Extract account block using awk - from account name line until next account name or end
  ACCOUNT_BLOCK=$(echo "$ACCOUNT_LIST" | awk -v name="$NAME" '
    BEGIN { found=0; in_block=0 }
    /^- [a-zA-Z0-9_-]+:/ { 
      if ($0 ~ "^- " name ":") { 
        found=1; in_block=1 
      } else if (in_block && found) { 
        exit 
      }
    }
    found && in_block { print }
  ')
  
  # Extract each field (handle both "key:" and "  key:" formats)
  NETWORK=$(echo "$ACCOUNT_BLOCK" | grep -E "^\s*network:" | sed -E 's/^\s*network:\s*//' | tr -d ' ')
  PUBLIC_KEY=$(echo "$ACCOUNT_BLOCK" | grep -E "^\s*public key:" | sed -E 's/^\s*public key:\s*//' | tr -d ' ')
  PRIVATE_KEY=$(echo "$ACCOUNT_BLOCK" | grep -E "^\s*private key:" | sed -E 's/^\s*private key:\s*//' | tr -d ' ')
  ADDRESS=$(echo "$ACCOUNT_BLOCK" | grep -E "^\s*address:" | sed -E 's/^\s*address:\s*//' | tr -d ' ')
  SALT=$(echo "$ACCOUNT_BLOCK" | grep -E "^\s*salt:" | sed -E 's/^\s*salt:\s*//' | tr -d ' ')
  CLASS_HASH=$(echo "$ACCOUNT_BLOCK" | grep -E "^\s*class hash:" | sed -E 's/^\s*class hash:\s*//' | tr -d ' ')
  DEPLOYED=$(echo "$ACCOUNT_BLOCK" | grep -E "^\s*deployed:" | sed -E 's/^\s*deployed:\s*//' | tr -d ' ')
  LEGACY=$(echo "$ACCOUNT_BLOCK" | grep -E "^\s*legacy:" | sed -E 's/^\s*legacy:\s*//' | tr -d ' ')
  TYPE=$(echo "$ACCOUNT_BLOCK" | grep -E "^\s*type:" | sed -E 's/^\s*type:\s*//' | tr -d ' ')
  
  # Validate that we got the required fields
  if [ -z "$ADDRESS" ] || [ -z "$PUBLIC_KEY" ] || [ -z "$PRIVATE_KEY" ]; then
    echo "Warning: Missing required fields for account $NAME" >&2
    continue
  fi
  
  # Add comma if not first item
  if [ "$FIRST" = true ]; then
    FIRST=false
  else
    JSON_ARRAY="${JSON_ARRAY},"
  fi
  
  # Add account object to JSON array
  JSON_ARRAY="${JSON_ARRAY}
  {
    \"name\": \"${NAME}\",
    \"network\": \"${NETWORK}\",
    \"publicKey\": \"${PUBLIC_KEY}\",
    \"privateKey\": \"${PRIVATE_KEY}\",
    \"address\": \"${ADDRESS}\",
    \"salt\": \"${SALT}\",
    \"classHash\": \"${CLASS_HASH}\",
    \"deployed\": ${DEPLOYED},
    \"legacy\": ${LEGACY},
    \"type\": \"${TYPE}\"
  }"
done

JSON_ARRAY="${JSON_ARRAY}
]"

# Write to file with pretty formatting using jq if available, otherwise write as-is
if command -v jq &> /dev/null; then
  echo "$JSON_ARRAY" | jq '.' > "$OUTFILE"
else
  echo "$JSON_ARRAY" > "$OUTFILE"
fi

echo "Collected account information saved to $OUTFILE"

