# JOC mainnet metadata

Japan Open Chain mainnet — chain ID `81`, Clique proof-of-authority, 5-second
blocks, live since 2018-11-26.

This directory contains the chain metadata, configuration parameters and
genesis information for JOC mainnet. Everything in [`metadata/`](metadata/) is
verified against the live network by CI.

## Genesis information

```yaml
chain_id: 81
network_id: 81                # geth --networkid
genesis_time: 1543235253      # 2018-11-26T12:27:33Z
genesis_hash: 0x1b54bfa6846a13aacc57066840ec10d1b74b06870539bbc8a3d1b19bdc566733
genesis_state_root: 0xd2d0aea6aeaecae665789341c002816e8636c868cfe9d19eed375bc78338a900
gas_limit: 470000000
clique:
  period: 5
  epoch: 30000
  genesis_signers:
    - 0x32a082eef14ce3842c695832fd3217081b3380f4
berlin_block: 7970411
london_block: 7970411
```

The full machine-readable form, including every fork block and the allocation
summary, is [`metadata/genesis_details.yaml`](metadata/genesis_details.yaml).
Reproduce it from `genesis.json` with `scripts/verify_genesis.sh`.

## Genesis allocation

256 placeholder accounts at `0x00…00` – `0x00…ff` holding 1 wei each, plus a
single funded account:

```
0xa3b77d1fa25c01486e2394bdd4c72c44a99e77c1   1,000,000,000 JOC
```

## Files

| File | Contents |
|---|---|
| [`metadata/genesis.json`](metadata/genesis.json) | Execution-layer genesis. Feed to `geth init`. |
| [`metadata/genesis_details.yaml`](metadata/genesis_details.yaml) | Genesis hash, state root, clique params, fork blocks, allocation summary |
| [`metadata/enodes.yaml`](metadata/enodes.yaml) | Execution-layer bootnodes |
| [`metadata/chain.json`](metadata/chain.json) | EIP-155 chain metadata — id, RPC endpoints, native currency, explorer |

Proof-of-stake configuration for the planned PoA → PoS migration is a draft and
lives in [`pos-migration/`](pos-migration/), outside the CI-verified `metadata/`
directory.

## Endpoints

| | |
|---|---|
| RPC | `https://rpc-1.japanopenchain.org:8545` (all endpoints in [`metadata/chain.json`](metadata/chain.json)) |
| Explorer | https://explorer.japanopenchain.org |

## Run a node

```bash
geth init --datadir ~/.joc metadata/genesis.json
geth --datadir ~/.joc --networkid 81 --syncmode full \
     --bootnodes "$(sed -n 's/^-[[:space:]]*\(enode:\/\/[^[:space:]#]*\).*$/\1/p' \
                    metadata/enodes.yaml | paste -sd, -)"
```

## License

CC0 1.0 Universal. See [`LICENSE`](LICENSE).
