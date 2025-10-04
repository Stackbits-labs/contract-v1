#!/bin/bash

# Setup script for starkli environment
# This script helps configure starkli for deployment

set -e

echo "Setting up starkli environment..."

# Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
    echo "Creating .env file..."
    cat << EOF > .env
# Starknet RPC URLs
STARKNET_RPC_SEPOLIA=https://starknet-sepolia.public.blastapi.io/rpc/v0_6
STARKNET_RPC_MAINNET=https://starknet-mainnet.public.blastapi.io/rpc/v0_6

# Account configuration (update these with your values)
STARKNET_ACCOUNT=
STARKNET_KEYSTORE=

# Network settings
STARKNET_NETWORK=sepolia
EOF
    echo ".env file created. Please update it with your account details."
else
    echo ".env file already exists."
fi

# Create deployments directory
mkdir -p deployments
echo "Deployments directory created."

# Make deploy script executable
chmod +x scripts/deploy.sh
echo "Deploy script made executable."

echo "Setup complete!"
echo ""
echo "Next steps:"
echo "1. Update the .env file with your account details"
echo "2. Make sure starkli is installed: curl -L https://raw.githubusercontent.com/xJonathanLEI/starkli/master/install.sh | bash"
echo "3. Run './scripts/deploy.sh' to deploy your contracts"