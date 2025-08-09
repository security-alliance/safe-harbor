# AdoptSafeHarborV2 Script

A Foundry script to create and adopt Safe Harbor V2 agreements with configurable options.

## Features

- ✅ Configurable agreement owner (defaults to deployer address)
- ✅ Optional registry deployment (defaults to using existing contracts)
- ✅ JSON-based agreement configuration

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DEPLOYER_PRIVATE_KEY` | ✅ | - | Private key for transaction signing |
| `AGREEMENT_OWNER` | ❌ | Deployer address | Address that will own the agreement |
| `DEPLOY_REGISTRY` | ❌ | `false` | Whether to deploy registry contracts first |

## Usage Examples

### Basic Usage
Uses existing registry contracts with deployer as agreement owner:
```bash
cd registry-contracts
DEPLOYER_PRIVATE_KEY=0xYourPrivateKey \
forge script script/v2/AdoptSafeHarborV2.s.sol --broadcast
```

### Custom Owner
Specify a different address as the agreement owner:
```bash
cd registry-contracts
DEPLOYER_PRIVATE_KEY=0xYourPrivateKey \
AGREEMENT_OWNER=0xCustomOwnerAddress \
forge script script/v2/AdoptSafeHarborV2.s.sol --broadcast
```

### Deploy Registry + Adopt
Deploy registry contracts first, then create and adopt agreement:
```bash
cd registry-contracts
DEPLOYER_PRIVATE_KEY=0xYourPrivateKey \
DEPLOY_REGISTRY=true \
forge script script/v2/AdoptSafeHarborV2.s.sol --broadcast
```

### Full Configuration
Deploy registry with custom owner:
```bash
cd registry-contracts
DEPLOYER_PRIVATE_KEY=0xYourPrivateKey \
DEPLOY_REGISTRY=true \
AGREEMENT_OWNER=0xCustomOwnerAddress \
forge script script/v2/AdoptSafeHarborV2.s.sol --broadcast
```

## Configuration File

The script reads agreement details from `agreementDetailsV2.json`. Make sure this file exists and contains valid agreement configuration before running the script.

## Default Contract Addresses

The script uses these addresses:
- Registry: `0x1eaCD100B0546E433fbf4d773109cAD482c34686`
- Factory: `0x98D1594Ba4f2115f75392ac92A7e3C8A81C67Fed`
- Owner: Address of the deployer address

## Testing

Run the test suite to verify functionality:
```bash
cd registry-contracts
forge test --match-test test_adopt -vv
```