#!/bin/bash

echo "🤝 Safe Harbor Adoption Example"
echo "==============================="

# Set environment for testnet
export ANCHOR_PROVIDER_URL=https://api.testnet.solana.com
export ANCHOR_WALLET=~/.config/solana/id.json

# Step 1: Create your agreement details file
echo "📝 Creating agreement details..."
cat > my-protocol-agreement.json << EOF
{
  "protocolName": "MyDeFiProtocol",
  "agreementUri": "https://mydefiprotocol.com/security-policy",
  "chains": [
    {
      "caip2ChainId": "eip155:1",
      "accounts": [
        {
          "accountType": "Treasury",
          "accountAddress": "0x742d35Cc6634C0532925a3b8D4C5C1e8e1166b8e"
        },
        {
          "accountType": "Governance",
          "accountAddress": "0x1234567890123456789012345678901234567890"
        }
      ]
    },
    {
      "caip2ChainId": "eip155:137",
      "accounts": [
        {
          "accountType": "Treasury",
          "accountAddress": "0x987fEdCbA9876543210987654321098765432109"
        }
      ]
    }
  ],
  "contactDetails": [
    {
      "contactType": "Email",
      "contact": "security@mydefiprotocol.com"
    },
    {
      "contactType": "Discord",
      "contact": "https://discord.gg/myprotocol"
    }
  ],
  "bountyTerms": {
    "bountyPercentage": 10,
    "bountyCapUsd": 1000000,
    "retainable": true,
    "aggregateBountyCapUsd": 0
  }
}
EOF

# Step 2: Set the agreement file path
export AGREEMENT_DATA_PATH=./my-protocol-agreement.json

# Step 3: Create and adopt the agreement
echo "🚀 Creating and adopting Safe Harbor agreement..."
npm run adopt

echo "✅ Adoption complete!"
echo ""
echo "📋 What happened:"
echo "1. Created a new Agreement account with your protocol details"
echo "2. Associated your wallet with this agreement in the registry"
echo "3. Emitted SafeHarborAdoption event"
echo ""
echo "🔍 Check status:"
echo "npm run query"
