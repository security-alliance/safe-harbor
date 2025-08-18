#!/usr/bin/env python3
"""
Safe Harbor V2 Adoption Checker
Checks Safe Harbor V2 agreement details directly from an agreement contract address.
"""

from web3 import Web3
from eth_abi import decode
import sys

def query_agreement_details(rpc_url, agreement_address):
    """Query agreement details directly from the agreement contract address"""
    
    print(f"Connecting to {rpc_url}...")
    w3 = Web3(Web3.HTTPProvider(rpc_url))
    
    if not w3.is_connected():
        print(f"❌ Failed to connect to {rpc_url}")
        return None
    
    print(f"✅ Connected successfully")
    print(f"🔍 Querying agreement: {agreement_address}")
    print()
    
    try:
        # Ensure address is checksummed
        checksummed_agreement_address = w3.to_checksum_address(agreement_address)
        
        # Step 1: Get agreement owner
        print("Step 1: Getting agreement owner...")
        owner_function_selector = w3.keccak(text="owner()")[:4]
        
        try:
            owner_result = w3.eth.call({
                'to': checksummed_agreement_address,
                'data': owner_function_selector
            })
            
            owner_address = decode(['address'], owner_result)[0]
            print(f"✅ Agreement Owner: {w3.to_checksum_address(owner_address)}")
            
        except Exception as owner_error:
            print(f"⚠️  Could not get owner: {owner_error}")
        
        # Step 2: Get agreement details
        print("Step 2: Getting agreement details...")
        function_selector = w3.keccak(text="getDetails()")[:4]
        
        result = w3.eth.call({
            'to': checksummed_agreement_address,
            'data': function_selector
        })
        
        print(f"✅ Got agreement details ({len(result)} bytes)")
        return result
        
    except Exception as e:
        print(f"❌ Error querying agreement: {e}")
        return None

def decode_v2_agreement(result_bytes):
    """Decode V2 agreement details from raw bytes"""
    
    print("Final Step: Decoding V2 agreement details...")
    
    # Define the ABI type for AgreementDetailsV2 struct
    # V2 structure: (string, Contact[], Chain[], BountyTerms, string)
    # Contact: (string, string)
    # Chain: (string, Account[], string) - caip2ChainId is now string, not uint256
    # Account: (string, uint8)
    # BountyTerms: (uint256, uint256, bool, uint8, string, uint256)
    
    agreement_details_v2_type = '(string,(string,string)[],(string,(string,uint8)[],string)[],(uint256,uint256,bool,uint8,string,uint256),string)'

    try:
        # Handle different input types
        if isinstance(result_bytes, str):
            if result_bytes.startswith('0x'):
                result_bytes = bytes.fromhex(result_bytes[2:])
            else:
                result_bytes = bytes.fromhex(result_bytes)
        # If already bytes, use as-is
        
        # Decode the result
        decoded = decode([agreement_details_v2_type], result_bytes)[0]
        
        print("✅ Successfully decoded V2 agreement!")
        print("=" * 50)
        print("🏛️  SAFE HARBOR V2 AGREEMENT DETAILS")
        print("=" * 50)
        print(f"📝 Protocol Name: {decoded[0]}")
        print()
        
        print("👥 Contact Details:")
        for i, contact in enumerate(decoded[1]):
            print(f"  📞 Contact {i+1}:")
            print(f"    Name: {contact[0]}")
            print(f"    Info: {contact[1]}")
        print()
        
        print("⛓️  Chains:")
        chains_data = decoded[2]
        
        if len(chains_data) == 0:
            print("  ⚠️  No chains configured in this agreement yet.")
            print("     The agreement owner needs to add chains using the addChains() function.")
        else:
            for i, chain in enumerate(chains_data):
                print(f"  🔗 Chain {i+1}:")
                print(f"    Asset Recovery Address: {chain[0]}")
                print(f"    CAIP-2 Chain ID: {chain[2]}")
                print(f"    Accounts ({len(chain[1])}):") 
                for j, account in enumerate(chain[1]):
                    print(f"      🏠 Account {j+1}:")
                    print(f"        Address: {account[0]}")
                    scope_names = ['None', 'ExistingOnly', 'All', 'FutureOnly']
                    scope_name = scope_names[account[1]] if account[1] < len(scope_names) else f"Unknown({account[1]})"
                    print(f"        Child Contract Scope: {account[1]} ({scope_name})")
                print()
        
        print("💰 Bounty Terms:")
        bounty_terms = decoded[3]
        print(f"  📊 Bounty Percentage: {bounty_terms[0]}%")
        print(f"  💵 Bounty Cap (USD): ${bounty_terms[1]:,}")
        print(f"  🔄 Retainable: {bounty_terms[2]}")
        identity_names = ['Anonymous', 'Pseudonymous', 'Named']
        identity_name = identity_names[bounty_terms[3]] if bounty_terms[3] < len(identity_names) else f"Unknown({bounty_terms[3]})"
        print(f"  🆔 Identity Requirements: {bounty_terms[3]} ({identity_name})")
        print(f"  📋 Diligence Requirements: {bounty_terms[4]}")
        print(f"  🎯 Aggregate Bounty Cap: ${bounty_terms[5]:,}" if bounty_terms[5] > 0 else "  🎯 Aggregate Bounty Cap: No limit")
        print()
        
        print("📄 Agreement URI:")
        print(f"  🔗 {decoded[4]}")
        print("=" * 50)
        
        return decoded
        
    except Exception as e:
        print(f"❌ Error decoding V2 agreement: {e}")
        print(f"Raw data length: {len(result_bytes)} bytes")
        if len(result_bytes) > 0:
            print(f"Raw data (first 100 bytes): {result_bytes[:100].hex()}")
        return None

if __name__ == "__main__":
    if len(sys.argv) == 3:
        # Direct agreement query mode: python script.py <rpc_url> <agreement_address>
        rpc_url = sys.argv[1]
        agreement_address = sys.argv[2]
        
        print("🔒 Safe Harbor V2 Agreement Details")
        print("=" * 40)
        
        result = query_agreement_details(rpc_url, agreement_address)
        if result:
            decode_v2_agreement(result)
        else:
            print("Error querying agreement")
            sys.exit(1)
    else:
        print("Usage:")
        print("  python check_adoption_details_v2.py <rpc_url> <agreement_address>")
        print("")
        print("Examples:")
        print("  python check_adoption_details_v2.py https://sepolia.gateway.tenderly.co 0xef726071a86b2B31caa035eE3e69c567762c7364")
        print("  python check_adoption_details_v2.py https://gateway.tenderly.co/public/mainnet 0x1234...")
        sys.exit(1)