#!/usr/bin/env bash
# Check every enode in metadata/enodes.yaml: well-formed URL, unique node id,
# and a TCP connection to its advertised port.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILE="$ROOT/metadata/enodes.yaml"
TIMEOUT="${TIMEOUT:-8}"

fail=0
ok()  { printf '  \033[32mOK\033[0m   %s\n' "$1"; }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=1; }

if [ ! -f "$FILE" ]; then
  printf '  %-22s %s\n' "skipped" "no metadata/enodes.yaml (no bootnodes published)"
  exit 0
fi

seen=""
count=0
while IFS= read -r enode; do
  count=$((count + 1))
  if ! [[ "$enode" =~ ^enode://([0-9a-f]{128})@([0-9a-zA-Z.:-]+):([0-9]+)$ ]]; then
    bad "malformed enode: $enode"
    continue
  fi
  id="${BASH_REMATCH[1]}"; host="${BASH_REMATCH[2]}"; port="${BASH_REMATCH[3]}"

  case " $seen " in
    *" $id "*) bad "duplicate node id ${id:0:16}…"; continue ;;
  esac
  seen="$seen $id"

  if nc -z -w "$TIMEOUT" "$host" "$port" >/dev/null 2>&1; then
    ok "$host:$port reachable (${id:0:16}…)"
  else
    bad "$host:$port unreachable (${id:0:16}…)"
  fi
done < <(sed -n 's/^-[[:space:]]*\(enode:\/\/[^[:space:]#]*\).*$/\1/p' "$FILE")

[ "$count" -gt 0 ] || bad "no enodes found in $FILE"

exit $fail
