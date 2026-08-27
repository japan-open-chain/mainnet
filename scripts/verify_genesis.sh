#!/usr/bin/env bash
# Verify that metadata/genesis.json reproduces the genesis block this network is
# actually running, and that metadata/genesis_details.yaml agrees with both.
#
# Requires: docker (to run geth init), curl, jq.
set -euo pipefail

GETH_IMAGE="${GETH_IMAGE:-ethereum/client-go:v1.13.5}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
META="$ROOT/metadata"

fail=0
note() { printf '  %-22s %s\n' "$1" "$2"; }
ok()   { printf '  \033[32mOK\033[0m   %s\n' "$1"; }
bad()  { printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=1; }

# Read a top-level `key: value` scalar out of a simple YAML file.
yaml_get() {
  sed -n "s/^$2:[[:space:]]*\([^[:space:]#]*\).*$/\1/p" "$1" | head -n1
}

# Run `geth init` on the genesis file in a throwaway container. Extra args are
# global geth flags and must precede the subcommand.
geth_init() {
  docker run --rm -v "$META/genesis.json:/genesis.json:ro" \
    "$GETH_IMAGE" "$@" init --datadir /tmp/d /genesis.json 2>&1 || true
}

rpc_call() {
  curl -sS -m 20 -X POST -H 'Content-Type: application/json' \
    --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"$2\",\"params\":$3}" "$1"
}

expected_hash="$(yaml_get "$META/genesis_details.yaml" genesis_hash)"
expected_chain_id="$(jq -r '.chainId' "$META/chain.json")"
rpc="$(jq -r '.rpc[0]' "$META/chain.json")"
note "expected genesis" "$expected_hash"

# 1. Recompute the genesis hash locally from genesis.json.
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  # geth's terminal logger abbreviates hashes ("1b54bf..566733"). Its JSON log
  # handler prints them in full, so ask for JSON first and fall back to the
  # abbreviated form if this geth build has no --log.format.
  out="$(geth_init --log.format json)"
  computed="$(printf '%s\n' "$out" | grep -oiE '0x[0-9a-f]{64}' | tail -n1 | tr 'A-F' 'a-f')"
  if [ -z "$computed" ]; then
    out="$(geth_init)"
    computed="$(printf '%s\n' "$out" | grep -oiE '0x[0-9a-f]{64}' | tail -n1 | tr 'A-F' 'a-f')"
  fi

  if [ -n "$computed" ]; then
    if [ "$computed" = "$expected_hash" ]; then
      ok "geth init reproduces $computed"
    else
      bad "geth init gave $computed, genesis_details.yaml says $expected_hash"
    fi
  else
    # Fallback: geth prints the first and last 3 bytes either side of "..".
    abbrev="$(printf '%s\n' "$out" \
              | sed -n 's/.*hash=\([0-9a-f]\{6\}\)\.\.\([0-9a-f]\{6\}\).*/\1 \2/p' | tail -n1)"
    if [ -z "$abbrev" ]; then
      bad "geth init produced no genesis hash; output was:"; printf '%s\n' "$out" | tail -n5
    else
      got_head="${abbrev%% *}"; got_tail="${abbrev##* }"; want="${expected_hash#0x}"
      if [ "$got_head" = "${want:0:6}" ] && [ "$got_tail" = "${want: -6}" ]; then
        ok "geth init reproduces ${got_head}..${got_tail} (abbreviated by geth; matches $expected_hash)"
      else
        bad "geth init gave ${got_head}..${got_tail}, genesis_details.yaml says $expected_hash"
      fi
    fi
  fi
else
  note "skipped" "docker unavailable — cannot recompute genesis hash locally"
fi

# 2. Compare against the live network.
live_hash="$(rpc_call "$rpc" eth_getBlockByNumber '["0x0",false]' | jq -r '.result.hash // empty')"
live_chain_id="$(rpc_call "$rpc" eth_chainId '[]' | jq -r '.result // empty')"

if [ -z "$live_hash" ]; then
  bad "no genesis block from $rpc"
elif [ "$live_hash" = "$expected_hash" ]; then
  ok "$rpc serves the same genesis block"
else
  bad "$rpc serves $live_hash, expected $expected_hash"
fi

if [ -n "$live_chain_id" ] && [ "$((live_chain_id))" -eq "$expected_chain_id" ]; then
  ok "chain id $expected_chain_id"
else
  bad "chain id mismatch: chain.json says $expected_chain_id, $rpc says ${live_chain_id:-none}"
fi

# 3. genesis.json's own chainId must agree with chain.json.
gj_chain_id="$(jq -r '.config.chainId' "$META/genesis.json")"
if [ "$gj_chain_id" = "$expected_chain_id" ]; then
  ok "genesis.json config.chainId matches chain.json"
else
  bad "genesis.json config.chainId=$gj_chain_id, chain.json=$expected_chain_id"
fi

exit $fail
