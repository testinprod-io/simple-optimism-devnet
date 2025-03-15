#!/bin/bash

set -e
set -o pipefail

# Get the absolute path of the project root
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

# Paths & Environment Variables
ENV_PATH="${ROOT_DIR}/envs/devnet/config"
GENESIS_DIR="${ENV_PATH}/genesis"
GENESIS_PATH="${ENV_PATH}/genesis"
DEVNET_CONFIG_PATH="${ENV_PATH}/devnetL1.json"
ALLOCS_L1_PATH="${ENV_PATH}/allocs-l1.json"
ADDRESSES_JSON_PATH="${ENV_PATH}/addresses.json"
L2_ALLOCS_PATH="${ENV_PATH}/allocs-l2.json"
GENESIS_L1_PATH="${GENESIS_PATH}/genesis-l1.json"
GENESIS_L2_PATH="${GENESIS_PATH}/genesis-l2.json"
ROLLUP_CONFIG_PATH="${GENESIS_PATH}/rollup.json"

# Scripts & File Name
SCRIPTS_DIR="${ROOT_DIR}/scripts/devnet"
SCRIPTS_DIR="${ROOT_DIR}/scripts/devnet"
DEVNET_COMPOSE_FILE="docker-compose.yml"

# Retry settings for L1 RPC
MAX_RETRIES=30
RETRY_COUNT=0

echo "🔧 Starting Devnet Setup..."

### Check for Genesis Directory
if [ ! -d "$GENESIS_DIR" ]; then
    echo "🔧 Creating missing genesis directory..."
    mkdir -p "$GENESIS_DIR"
fi

### L1 Genesis Setup
if [ -f "$GENESIS_L1_PATH" ]; then
    echo "✅ L1 genesis already generated."
else
    echo "🚀 Generating L1 genesis..."

    # Update the L1 deploy config with the current timestamp
    TIMESTAMP=$(date +%s)
    TIMESTAMP_HEX=$(printf '0x%x\n' "$TIMESTAMP")
    jq --arg ts "$TIMESTAMP_HEX" '.l1GenesisBlockTimestamp = $ts' "$DEVNET_CONFIG_PATH" > "$DEVNET_CONFIG_PATH.tmp" && mv "$DEVNET_CONFIG_PATH.tmp" "$DEVNET_CONFIG_PATH"

    # Remove the temporary file
    rm -rf "$DEVNET_CONFIG_PATH.tmp"

    echo "📜 Running L1 Genesis Script..."
    cd "$SCRIPTS_DIR"
    go run genesis/main.go genesis l1 \
        --deploy-config "$DEVNET_CONFIG_PATH" \
        --l1-allocs "$ALLOCS_L1_PATH" \
        --l1-deployments "$ADDRESSES_JSON_PATH" \
        --outfile.l1 "$GENESIS_L1_PATH"

    echo "📜 Running Beacon Chain Genesis..."

    # Generate the beacon chain genesis
    sh l1-generate-beacon-genesis.sh
fi

### Start L1 Services
echo "🚀 Starting L1 nodes..."
cd "$ROOT_DIR"
docker compose -f "$DEVNET_COMPOSE_FILE" up -d l1 l1-bn l1-vc

# Wait for L1 RPC to be up
echo "⏳ Waiting for L1 RPC (port 8545) to be ready..."
until curl -s http://127.0.0.1:8545 > /dev/null; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; then
        echo "❌ L1 RPC did not start after $MAX_RETRIES retries. Exiting."
        exit 1
    fi
    echo "🔄 Retry $RETRY_COUNT/$MAX_RETRIES..."
    sleep 2
done
echo "✅ L1 RPC is up."

### L2 Genesis Setup
if [ -f "$GENESIS_L2_PATH" ]; then
    echo "✅ L2 genesis and rollup configs already generated."
else
    echo "🚀 Generating L2 genesis and rollup configs..."

    echo "📜 Running L2 Genesis Script..."
    cd "$SCRIPTS_DIR"
    go run genesis/main.go genesis l2 \
        --l1-rpc "http://localhost:8545" \
        --deploy-config "$DEVNET_CONFIG_PATH" \
        --l2-allocs "$L2_ALLOCS_PATH" \
        --l1-deployments "$ADDRESSES_JSON_PATH" \
        --outfile.l2 "$GENESIS_L2_PATH" \
        --outfile.rollup "$ROLLUP_CONFIG_PATH"
fi

### Start L2 Services
echo "🚀 Bringing up L2..."
cd "$ROOT_DIR"
docker compose -f "$DEVNET_COMPOSE_FILE" up -d l2 op-node op-batcher op-proposer

# Wait for L2 RPC to be up
echo "⏳ Waiting for L2 RPC (port 8546) to be ready..."
until curl -s http://127.0.0.1:8546 > /dev/null; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; then
        echo "❌ L2 RPC did not start after $MAX_RETRIES retries. Exiting."
        exit 1
    fi
    echo "🔄 Retry $RETRY_COUNT/$MAX_RETRIES..."
    sleep 2
done
echo "✅ L2 RPC is up."

### Start da-server
echo "🚀 Starting da-server..."
cd "$ROOT_DIR"
docker compose -f "$DEVNET_COMPOSE_FILE" up -d celestia-app celestia-bridge da-server prometheus grafana






echo "✅ Devnet setup complete!"
