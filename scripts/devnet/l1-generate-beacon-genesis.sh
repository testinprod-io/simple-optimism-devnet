#!/bin/sh

set -eu

echo "eth2-testnet-genesis path: $(which eth2-testnet-genesis)"

eth2-testnet-genesis deneb \
  --config=../../envs/devnet/beacon-data/config.yaml \
  --preset-phase0=minimal \
  --preset-altair=minimal \
  --preset-bellatrix=minimal \
  --preset-capella=minimal \
  --preset-deneb=minimal \
  --eth1-config=../../envs/devnet/config/genesis/genesis-l1.json \
  --state-output=../../envs/devnet/config/genesis/genesis-l1.ssz \
  --tranches-dir=../../envs/devnet/config/genesis/tranches \
  --mnemonics=../../envs/devnet/keys/mnemonics.yaml \
  --eth1-withdrawal-address=0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
  --eth1-match-genesis-time
