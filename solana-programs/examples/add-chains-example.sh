#!/bin/bash

echo "🔗 Adding Valid Chains to Safe Harbor Registry"
echo "============================================="

# Set environment for testnet
export ANCHOR_PROVIDER_URL=https://api.testnet.solana.com
export ANCHOR_WALLET=~/.config/solana/id.json

# Add multiple chains at once
echo "📝 Adding Ethereum mainnet and Polygon..."
npm run manage-chains add eip155:1 eip155:137

# Add more chains
echo "📝 Adding Arbitrum and Optimism..."
npm run manage-chains add eip155:42161 eip155:10

# List all valid chains
echo "📋 Current valid chains:"
npm run manage-chains list

# Remove a chain (if needed)
echo "🗑️  Removing test chain..."
npm run manage-chains remove eip155:999

echo "✅ Chain management complete!"
