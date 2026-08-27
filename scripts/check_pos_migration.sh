#!/usr/bin/env bash
# The merge does not change the genesis block — it only adds fork-activation
# fields to `config`. So pos-migration/genesis.json must stay identical to the
# live metadata/genesis.json apart from those added keys. This catches the draft
# silently drifting away from the chain it is supposed to migrate.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$ROOT" <<'PY'
import json, sys

ALLOWED = {"terminalTotalDifficulty", "shanghaiTime", "cancunTime",
           "pragueTime", "depositContractAddress"}
root = sys.argv[1]
fail = False

def ok(m):  print(f"  \033[32mOK\033[0m   {m}")
def bad(m):
    global fail
    print(f"  \033[31mFAIL\033[0m {m}"); fail = True

live = json.load(open(f"{root}/metadata/genesis.json"))
draft = json.load(open(f"{root}/pos-migration/genesis.json"))

extra = set(draft["config"]) - set(live["config"])
missing = set(live["config"]) - set(draft["config"])

if missing:
    bad(f"draft is missing config keys present on the live chain: {sorted(missing)}")
if extra - ALLOWED:
    bad(f"draft adds config keys that are not merge fields: {sorted(extra - ALLOWED)}")
elif extra:
    ok(f"adds only merge fields: {', '.join(sorted(extra))}")

stripped = dict(draft, config={k: v for k, v in draft["config"].items() if k not in extra})
if stripped == live:
    ok("genesis block and all other config identical to the live chain")
else:
    for key in sorted(set(stripped) | set(live)):
        if stripped.get(key) != live.get(key):
            if key == "alloc":
                bad("alloc differs from the live chain")
            elif key == "config":
                for c in sorted(set(stripped["config"]) | set(live["config"])):
                    if stripped["config"].get(c) != live["config"].get(c):
                        bad(f"config.{c}: draft={stripped['config'].get(c)!r} live={live['config'].get(c)!r}")
            else:
                bad(f"{key}: draft={stripped.get(key)!r} live={live.get(key)!r}")

sys.exit(1 if fail else 0)
PY
