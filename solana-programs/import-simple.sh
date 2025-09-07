#!/bin/bash

echo "🔑 Simple Phantom Wallet Import"
echo "================================"

if [ -z "$1" ]; then
    echo "Usage: ./import-simple.sh <your-private-key>"
    echo ""
    echo "To get your private key from Phantom:"
    echo "1. Open Phantom wallet"
    echo "2. Go to Settings → Export Private Key"
    echo "3. Copy the private key and paste it here"
    exit 1
fi

PRIVATE_KEY="$1"

# Create a temporary Python script to handle the conversion
cat > /tmp/convert_key.py << EOF
import json
import sys

# Simple base58 decoder (no external deps needed)
def base58_decode(s):
    alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'
    decoded = 0
    multi = 1
    for char in reversed(s):
        decoded += multi * alphabet.index(char)
        multi *= 58
    
    # Convert to bytes
    h = hex(decoded)[2:]
    if len(h) % 2:
        h = '0' + h
    
    result = []
    for i in range(0, len(h), 2):
        result.append(int(h[i:i+2], 16))
    
    return result

try:
    private_key = sys.argv[1]
    key_array = base58_decode(private_key)
    
    # Ensure it's 64 bytes (Solana keypair format)
    if len(key_array) != 64:
        print(f"Error: Expected 64 bytes, got {len(key_array)}")
        sys.exit(1)
    
    with open('/home/artemis/.config/solana/phantom-keypair.json', 'w') as f:
        json.dump(key_array, f)
    
    print("✅ Successfully imported Phantom wallet!")
    print("Saved to: ~/.config/solana/phantom-keypair.json")
    
except Exception as e:
    print(f"❌ Error: {e}")
    print("Make sure you copied the private key correctly from Phantom")
    sys.exit(1)
EOF

# Run the conversion
python3 /tmp/convert_key.py "$PRIVATE_KEY"

# Clean up
rm /tmp/convert_key.py

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 Wallet imported successfully!"
    echo "You can now proceed with deployment."
fi
