#!/usr/bin/env python3
"""
Safe Harbor V2 Adoption Checker
Checks if a protocol has adopted Safe Harbor V2 and displays the agreement details.
"""

from web3 import Web3
from eth_abi import encode, decode
import sys

def check_v2_adoption(rpc_url, registry_address, protocol_address):
    """Check if a protocol has adopted Safe Harbor V2"""
    
    print(f"Connecting to {rpc_url}...")
    w3 = Web3(Web3.HTTPProvider(rpc_url))
    
    if not w3.is_connected():
        print(f"❌ Failed to connect to {rpc_url}")
        return None
    
    print(f"✅ Connected successfully")
    print(f"🔍 Checking protocol: {protocol_address}")
    print(f"📋 Using V2 registry: {registry_address}")
    print()
    
    try:
        # Step 1: Get agreement address from registry
        print("Step 1: Getting agreement address from registry...")
        function_selector = w3.keccak(text="getAgreement(address)")[:4]
        protocol_address_param = encode(['address'], [protocol_address])
        call_data = function_selector + protocol_address_param
        
        try:
            result = w3.eth.call({
                'to': registry_address,
                'data': call_data
            })
            
            agreement_address = decode(['address'], result)[0]
            
            if agreement_address == '0x0000000000000000000000000000000000000000':
                print(f"❌ No V2 adoption found for {protocol_address}")
                return None
                
        except Exception as registry_error:
            # Handle contract revert (likely NoAgreement() error)
            error_str = str(registry_error)
            if '0x843cbfa9' in error_str:  # NoAgreement() error selector
                print(f"❌ No V2 adoption found for {protocol_address} (NoAgreement)")
                return None
            else:
                print(f"❌ Registry error: {registry_error}")
                return None
        
        print(f"✅ Found V2 adoption! Agreement at: {w3.to_checksum_address(agreement_address)}")
        
        # Ensure address is checksummed
        checksummed_agreement_address = w3.to_checksum_address(agreement_address)
        
        # Step 2: Get agreement owner
        print("Step 2: Getting agreement owner...")
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
        
        # Step 3: Get agreement details
        print("Step 3: Getting agreement details...")
        function_selector = w3.keccak(text="getDetails()")[:4]
        
        result = w3.eth.call({
            'to': checksummed_agreement_address,
            'data': function_selector
        })
        
        print(f"✅ Got agreement details ({len(result)} bytes)")
        return result
        
    except Exception as e:
        print(f"❌ Error checking adoption: {e}")
        return None

def query_agreement_directly(rpc_url, agreement_address):
    """Query agreement details directly from the agreement contract address"""
    
    print(f"Connecting to {rpc_url}...")
    w3 = Web3(Web3.HTTPProvider(rpc_url))
    
    if not w3.is_connected():
        print(f"❌ Failed to connect to {rpc_url}")
        return None
    
    print(f"✅ Connected successfully")
    print(f"🔍 Querying agreement directly: {agreement_address}")
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

def main():
    """Main function to test V2 adoption checking"""
    
    print("🔒 Safe Harbor V2 Adoption Checker")
    print("=" * 40)
    
    # Test configurations for registry lookup
    registry_test_configs = [
        {
            "name": "Ensuro",
            "rpc_url": "https://gateway.tenderly.co/public/mainnet",
            "registry_address": "0x7Bc48ED9069BE078Da305893A5953435a2d5e2F1",
            "protocol_address": "0x4a0E7e97e51b3203FA8D9aC2C045060248D15ca7"
        },
    ]
    
    # Test configurations for direct agreement queries
    direct_agreement_configs = [
        {
            "name": "Direct Agreement Query Example",
            "rpc_url": "https://gateway.tenderly.co/public/mainnet",
            "agreement_address": "0x1234567890123456789012345678901234567890"  # Replace with actual agreement address
        }
    ]
    
    # Test registry lookup method
    for config in registry_test_configs:
        print(f"\n🌐 Testing {config['name']} (Registry Lookup)...")
        print("-" * 50)
        
        result = check_v2_adoption(
            config['rpc_url'],
            config['registry_address'],
            config['protocol_address']
        )

        if result:
            decode_v2_agreement(result)
        else:
            print("No adoption found or error occurred")
        
        print("\n" + "=" * 60)
    
    # Test direct agreement query method
    for config in direct_agreement_configs:
        print(f"\n🌐 Testing {config['name']} (Direct Query)...")
        print("-" * 50)
        
        result = query_agreement_directly(
            config['rpc_url'],
            config['agreement_address']
        )

        if result:
            decode_v2_agreement(result)
        else:
            print("Error querying agreement directly")
        
        print("\n" + "=" * 60)

if __name__ == "__main__":
    if len(sys.argv) == 3:
        # Direct agreement query mode: python script.py <rpc_url> <agreement_address>
        rpc_url = sys.argv[1]
        agreement_address = sys.argv[2]
        
        print("🔒 Safe Harbor V2 Direct Agreement Query")
        print("=" * 45)
        
        result = query_agreement_directly(rpc_url, agreement_address)
        if result:
            decode_v2_agreement(result)
        else:
            print("Error querying agreement directly")
            
    elif len(sys.argv) == 1:
        # Default mode: run predefined test configurations
        main()
    else:
        print("Usage:")
        print("  python check_adoption_details_v2.py                              # Run predefined tests")
        print("  python check_adoption_details_v2.py <rpc_url> <agreement_address> # Query specific agreement")
        print("")
        print("Examples:")
        print("  python check_adoption_details_v2.py https://gateway.tenderly.co/public/mainnet 0x1234...")
        sys.exit(1) 