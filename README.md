# JOC mainnet metadata

Japan Open Chain mainnet — chain ID `81`, Clique proof-of-authority, 5-second
blocks, live since 2018-11-26.

This directory contains the chain metadata, configuration parameters and
genesis information for JOC mainnet, execution and consensus layer both. The
beacon chain is live — genesis fired 2026-09-18T11:44:51Z. **The merge is not
scheduled:** `TERMINAL_TOTAL_DIFFICULTY` is max uint64, so the execution layer
still runs Clique and follows its own head.

Everything in [`metadata/`](metadata/) is verified against the live network by
CI.

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

## Deposit contract

```yaml
address:    0x6A5452FC9a733FF4634aB562Dcec440c5f3d52f5
block:      26016124          # 2026-09-18T04:26:45Z
block_hash: 0xe288afeaebab82d7d95fecfbbc5098f2eadc682fe62e55e42702dda3e56cfd2a
```

It holds the 8 deposits that seeded the beacon chain, 32 JOC each, made in
blocks `26019717` – `26020178`.

That it is a genuine deposit contract was not assumed: its own
`get_deposit_root()` (`0x17b05591…da4e`) is reproducible offline from the 8
`DepositEvent` logs it emitted, through the spec's `DepositData` hash tree and
the contract's zero-hash ladder. The 8 pubkeys in those logs are also, in the
same order, the 8 validators in [`metadata/genesis.ssz`](metadata/genesis.ssz)
— so the contract, the deposits and the beacon genesis are one chain of
evidence rather than three separate claims. The live beacon node agrees on the
address: `/eth/v1/config/deposit_contract` answers `chain_id 81`, this address.

### Finding the deployment block took some care

The obvious route does not work. This node prunes state — `eth_getCode` at the
deployment block fails with `missing trie node`, so a binary search over
history is out.

The explorer names creation transaction `0xaf9ef541…13dc5`, and the node's own
receipt confirms that transaction and its block. But that receipt's
`contractAddress` is `0x2bff8c48…f09e`, a **factory**, not the deposit
contract, and the deposit contract is not among the addresses that emitted logs
in the transaction. It was created by an internal `CREATE`, which no public RPC
on this node will show.

So it was confirmed arithmetically instead. A `CREATE` address is
`keccak256(rlp([creator, nonce]))[12:]`, and from that factory:

```
nonce 1 -> 0x27125dca…d71e   [emitted a log in the tx]
nonce 2 -> 0xc59e59c4…c122   [emitted a log in the tx]
nonce 3 -> 0x6a5452fc…52f5   <- the deposit contract
nonce 4 -> 0x51075842…dd8f   [emitted a log in the tx]
```

Nonces 1, 2 and 4 are three of the addresses that emitted logs in that
transaction, per the node's own receipt. Nonces are sequential, so the nonce-3
creation cannot have happened later than the nonce-4 one — the deposit contract
was created in that transaction, in block `26016124`. Only the list of internal
creations came from the explorer; everything load-bearing came from the node.

Reproduce the derivation with:

```bash
cast compute-address --nonce 3 0x2bff8c480e30b49c5564eda74130c8384c6af09e
```

## Files

The layout follows [eth-clients](https://github.com/eth-clients/mainnet), the
same one [`japan-open-chain/testnet`](https://github.com/japan-open-chain/testnet)
and [`gu-corp/sandbox1`](https://github.com/gu-corp/sandbox1) use.

| File | Contents |
|---|---|
| [`metadata/genesis.json`](metadata/genesis.json) | Execution-layer genesis. Feed to `geth init`. |
| [`metadata/genesis_details.yaml`](metadata/genesis_details.yaml) | Genesis hash, state root, clique params, fork blocks, allocation summary |
| [`metadata/config.yaml`](metadata/config.yaml) | Beacon chain config. Feed to a consensus client. |
| [`metadata/genesis.ssz`](metadata/genesis.ssz) | Beacon genesis state. Feed to a consensus client. |
| [`metadata/chain.json`](metadata/chain.json) | EIP-155 chain metadata — id, RPC endpoints, native currency, explorer |
| [`metadata/enodes.yaml`](metadata/enodes.yaml) | Execution-layer bootnode enode URLs |
| [`metadata/bootstrap_nodes.yaml`](metadata/bootstrap_nodes.yaml) | Consensus-layer bootnode ENRs |
| [`metadata/deposit_contract.txt`](metadata/deposit_contract.txt) | Deposit contract address |
| [`metadata/deposit_contract_block.txt`](metadata/deposit_contract_block.txt) | Eth1 block it was deployed in |
| [`metadata/deposit_contract_block_hash.txt`](metadata/deposit_contract_block_hash.txt) | Hash of that block |
| [`scripts/discv5_probe.py`](scripts/discv5_probe.py) | Proves a discv5 node is alive by making it answer `WHOAREYOU` |

### How the bootnodes are checked

The two layers are held to **different** standards, and it is worth knowing
which is which.

The consensus bootnodes in
[`metadata/bootstrap_nodes.yaml`](metadata/bootstrap_nodes.yaml) are **proven**
alive. A TCP connect only shows a port is open, and discovery runs over UDP
where a connect shows nothing at all — there is no handshake, so `nc -zu`
reports success against a black hole. Instead
[`scripts/discv5_probe.py`](scripts/discv5_probe.py) sends a real discv5
packet. Its masking key is the *recipient's* node id, keccak256 of the public
key in the ENR, so only a node that agrees its id is that can unmask it — and
it must answer `WHOAREYOU`. Getting that reply binds the key in the record to
whatever is actually listening.

The execution bootnodes in [`metadata/enodes.yaml`](metadata/enodes.yaml) get a
**weaker** check. There is no cheap equivalent of the `WHOAREYOU` trick for
devp2p: proving a node id belongs to an address needs a full RLPx handshake,
ECIES over secp256k1 ECDH. So they are only checked for a well-formed URL and a
port that accepts TCP — enough to catch rot, not enough to prove identity.

`scripts/check_bootnodes.sh` runs both, and CI runs it weekly, so a bootnode
going away surfaces on its own.

## Beacon chain

**Live.** `MIN_GENESIS_TIME` elapsed before the 8th deposit, so genesis fired at
the eth1 block carrying that deposit (block `26020178`) plus `GENESIS_DELAY` —
confirmed both by computing that sum and by the node.

| | |
|---|---|
| `genesis_time` | `1789731891` — 2026-09-18T11:44:51Z |
| `genesis_validators_root` | `0x6da68464e42d4347f9b45e640bd35ba5e87c07736b3288e8e38c9853b46a13cb` |
| Validators at genesis | `8` (= `MIN_GENESIS_ACTIVE_VALIDATOR_COUNT`) |
| `GENESIS_FORK_VERSION` | `0x00000051` — low bytes are chain id `81` |
| Forks active | Altair epoch 5, Bellatrix epoch 10 — both long passed |
| Forks disabled | Capella onwards, at `2**64-1` |
| `TERMINAL_TOTAL_DIFFICULTY` | `2**64-1` — unreachable, so the merge is not scheduled |

The chain finalizes: all 8 validators are `active_ongoing`, and the node reports
a finalized checkpoint tracking the head.

**The merge is not scheduled.** Bellatrix is active on the beacon chain, but a
beacon chain at Bellatrix does not merge anything until the execution layer
passes `TERMINAL_TOTAL_DIFFICULTY`, and that is parked at max uint64 in
[`metadata/config.yaml`](metadata/config.yaml) — the running node's
`/eth/v1/config/spec` reports the same value. [`metadata/genesis.json`](metadata/genesis.json)
accordingly carries no merge fields. Scheduling the merge means setting a real
TTD in both files; JOC's Clique layer accumulates 1 difficulty per 5-second
block, which is what makes a date out of a number.

### The published ENRs belong to this chain

The beacon-node ENR in
[`metadata/bootstrap_nodes.yaml`](metadata/bootstrap_nodes.yaml) carries an
`eth2` entry with fork digest `0x4fdcccde`. That is not taken on faith — it is
the Bellatrix fork version over this chain's `genesis_validators_root`:

```bash
python3 -c "
import hashlib
gvr = bytes.fromhex('6da68464e42d4347f9b45e640bd35ba5e87c07736b3288e8e38c9853b46a13cb')
print('0x' + hashlib.sha256(bytes.fromhex('02000051') + b'\x00'*28 + gvr).digest()[:4].hex())"
# 0x4fdcccde
```

A node on any other network — or on this one with a different validators root —
computes a different digest and will not gossip with these peers.

### `PRESET_BASE` is `gnosis`

Consensus clients compile the preset in; it cannot be overridden from a config
file. JOC produces a block every 5 seconds, matching Gnosis Chain rather than
Ethereum mainnet's 12s. The preset sets `SLOTS_PER_EPOCH` to 16, so an epoch is
80 seconds, not 384 — worth remembering when reading the fork epochs above.

- https://github.com/gnosischain/specs/tree/master/consensus/preset/gnosis
- https://github.com/sigp/lighthouse/tree/stable/consensus/types/presets/gnosis

### `genesis.ssz` comes from the node, not from a script

[`metadata/genesis.ssz`](metadata/genesis.ssz) is the beacon node's own genesis
state, taken from `/eth/v2/debug/beacon/states/genesis` (Lighthouse v7.0.1) —
not rebuilt from the eth1 deposits. Its decoded header (`genesis_time`,
`genesis_validators_root`, fork version `0x00000051`, slot 0) matches the node's
`/eth/v1/beacon/genesis`, and every key
[`config.yaml`](metadata/config.yaml) sets that the node reports in
`/eth/v1/config/spec` — 59 of them — comes back with the same value.

`genesis_validators_root` domain-separates every signature on the network, so a
wrong file here would make clients compute fork digests matching no peer.

## Endpoints

| | |
|---|---|
| RPC | `https://rpc-1.japanopenchain.org:8545` (all endpoints in [`metadata/chain.json`](metadata/chain.json)) |
| Explorer | https://explorer.japanopenchain.org |

## Run a node

The execution layer is Clique PoA and follows the head on its own; the merge is
not scheduled (see [Beacon chain](#beacon-chain)), so a consensus client is
needed only to follow or validate on the beacon chain.

### Execution layer

```bash
geth init --datadir ~/.joc metadata/genesis.json
geth --datadir ~/.joc --networkid 81 --syncmode full \
     --bootnodes "$(sed -n 's/^-[[:space:]]*\(enode:\/\/[^[:space:]#]*\).*$/\1/p' \
                    metadata/enodes.yaml | paste -sd, -)"
```

### Consensus layer

```bash
lighthouse beacon_node \
  --testnet-dir metadata \
  --boot-nodes "$(sed -n 's/^-[[:space:]]*\(enr:[^[:space:]#]*\).*$/\1/p' \
                  metadata/bootstrap_nodes.yaml | paste -sd, -)" \
  --execution-endpoint http://localhost:8551 \
  --execution-jwt ~/.joc/jwt.hex
```

`--testnet-dir metadata` picks up `config.yaml` and `genesis.ssz` from this
repo. Other clients want the same two files under different flag names.

### Verify

```bash
scripts/verify_genesis.sh    # geth init reproduces the genesis hash
scripts/check_bootnodes.sh   # published bootnodes are well-formed and answer
```

## License

CC0 1.0 Universal. See [`LICENSE`](LICENSE).
