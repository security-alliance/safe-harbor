#!/bin/bash

# Sets up anvil and deploys the SafeHarborRegistry smart contract

# Function to clean up background processes on exit
cleanup() {
    echo "Stopping all processes..."
    kill $anvil_pid $http_server_pid
}

# Set the trap to call cleanup on script exit
trap cleanup EXIT

# Change to the desired working directory for anvil and forge
cd ../registry-contracts

# Launch anvil in the background
anvil --block-time 1 --port 8545 &
anvil_pid=$!

# Wait a bit to ensure anvil is up
sleep 2

# Deploy the smart contract
export REGISTRY_DEPLOYER_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
forge script script/SafeHarborRegistryDeploy.s.sol:SafeHarborRegistryDeploy --rpc-url http://localhost:8545 --broadcast

# execute the JS test
cd ../js

npm test
