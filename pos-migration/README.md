# PoA → PoS migration (draft)

**Nothing in this directory is active.** JOC mainnet runs Clique proof-of-authority
today. The configuration that actually drives the live network is in
[`../metadata/`](../metadata/).

This directory holds the working draft of the consensus-layer (beacon chain)
configuration for the planned migration to proof of stake. It is kept out of
`metadata/` on purpose: in the
[eth-clients](https://github.com/eth-clients/mainnet) layout this repo follows,
`metadata/config.yaml` is the *live* beacon config, and a draft in that slot
would be read as authoritative by tooling. When the migration parameters are
final, these files move into `../metadata/`.

## Contents

| File | Contents |
|---|---|
| [`config.yaml`](config.yaml) | Beacon chain config |
| [`genesis.json`](genesis.json) | Execution genesis with the merge fields added |
| [`deposit_contract_block.txt`](deposit_contract_block.txt) | Block the deposit contract is deployed at |
| [`presets.md`](presets.md) | Which spec preset the config is based on, and why |

## `genesis.json`

The merge does not change the genesis block — it only adds fork-activation
fields to `config`. This file is therefore the live
[`../metadata/genesis.json`](../metadata/genesis.json) plus exactly five keys:

```
terminalTotalDifficulty   shanghaiTime   cancunTime   pragueTime   depositContractAddress
```

[`../scripts/check_pos_migration.sh`](../scripts/check_pos_migration.sh)
enforces that invariant in CI: if the draft ever diverges from the genesis the
chain is actually running — a changed `alloc`, a moved fork block, an unexpected
config key — the build fails.

The placeholders are the string `"TBD"` rather than `null` on purpose. It keeps
the file valid JSON, and geth hard-fails parsing a string into `*big.Int` /
`*uint64` instead of quietly reading `null` as "terminal total difficulty zero",
which would mean *merge immediately*.

## What is still open

Every value marked `TBD` in `config.yaml` is undecided — 7 of them, alongside
4 forks parked at the max-uint64 stub.

The undecided values include everything that defines the chain's
identity: `TERMINAL_TOTAL_DIFFICULTY`, `MIN_GENESIS_TIME`,
`MIN_GENESIS_ACTIVE_VALIDATOR_COUNT`, `DEPOSIT_CONTRACT_ADDRESS`, and the
Altair / Bellatrix / Capella fork epochs.

Also still to be produced:

- `bootstrap_nodes.yaml` — consensus-layer bootnodes (ENRs)
- `deposit_contract.txt` — deposit contract address (also `DEPOSIT_CONTRACT_ADDRESS` in `config.yaml`)
- `genesis.ssz` — beacon chain genesis state
- Genesis details: fork digest, validators root, genesis time

### Why there is no `genesis.ssz`

`genesis.ssz` is the beacon chain genesis state, derived from the deposit
contract's contents at a chosen block. None of its inputs exist yet:
`MIN_GENESIS_TIME`, `MIN_GENESIS_ACTIVE_VALIDATOR_COUNT`, `GENESIS_FORK_VERSION`
and `DEPOSIT_CONTRACT_ADDRESS` are all `TBD`, and no validator has deposited.

A generated stand-in would carry a `genesis_validators_root` that is pure
fiction — and that value is what every signature on the network is
domain-separated by. Shipping one publicly is worse than shipping nothing:
clients would compute fork digests that match no peer, and anything signed
against it would be signed under the wrong domain. It gets committed when the
migration parameters are real, not before.

## Do not use

These files cannot be verified — there is no beacon chain to check them
against, which is why they sit outside the CI-verified `metadata/` directory.
Do not point a production beacon node at them.
