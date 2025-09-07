#!/bin/bash

echo "🚀 Deploying Safe Harbor Registry to Solana Testnet"
echo "=================================================="

# Check balance
echo "💰 Checking wallet balance..."
BALANCE=$(solana balance --output json | jq -r '.value')
if (( $(echo "$BALANCE < 1" | bc -l) )); then
    echo "❌ Insufficient balance: $BALANCE SOL"
    echo "💡 Get testnet SOL from: https://faucet.solana.com"
    exit 1
fi
echo "✅ Balance: $BALANCE SOL"

# Build program
echo "🔨 Building program..."
anchor build
if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

# Deploy to testnet
echo "🚀 Deploying to testnet..."
anchor deploy --provider.cluster testnet
if [ $? -ne 0 ]; then
    echo "❌ Deployment failed"
    exit 1
fi

echo "✅ Deployment successful!"
echo ""
echo "📋 Next steps:"
echo "1. Update your .env file with testnet settings:"
echo "   ANCHOR_PROVIDER_URL=https://api.testnet.solana.com"
echo "   ANCHOR_WALLET=~/.config/solana/id.json"
echo ""
echo "2. Initialize the registry:"
echo "   npm run deploy"
echo ""
echo "3. Query registry status:"
echo "   npm run query"
