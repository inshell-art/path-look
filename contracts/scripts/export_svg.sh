#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: export_svg.sh <token_id> <thought_flag> <will_flag> <awa_flag> [output_file]

Exports the literal output of the generate_svg entrypoint.
Flags should be 1 (true) or 0 (false). If output_file is omitted the script writes
to ../exports/path_<token_id>.svg relative to the repo root.
USAGE
}

if [[ $# -lt 4 || $# -gt 5 ]]; then
  usage
  exit 1
fi

TOKEN_ID="$1"
THOUGHT_FLAG="$2"
WILL_FLAG="$3"
AWA_FLAG="$4"

# Optional: override sncast connection/account flags, defaults to using the devnet profile.
SNCAST_ARGS="${SNCAST_ARGS:---profile devnet}"
SNCAST_RPC="${SNCAST_RPC:-http://127.0.0.1:5050}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "${SCRIPT_DIR}")")"
DEFAULT_RELATIVE_OUTPUT="../exports/path_${TOKEN_ID}.svg"
RAW_OUTPUT="${5:-${DEFAULT_RELATIVE_OUTPUT}}"

for flag in "$THOUGHT_FLAG" "$WILL_FLAG" "$AWA_FLAG"; do
  if [[ "$flag" != "0" && "$flag" != "1" ]]; then
    echo "Error: flags must be either 0 or 1." >&2
    exit 1
  fi
done

CONTRACT_HASHES_PATH="${PROJECT_ROOT}/contract_hashes.json"

if [[ ! -f "${CONTRACT_HASHES_PATH}" ]]; then
  echo "Error: contract_hashes.json not found at ${CONTRACT_HASHES_PATH}" >&2
  exit 1
fi

CONTRACT_ADDRESS=$(python3 - "${CONTRACT_HASHES_PATH}" <<'PY'
import json, sys, pathlib
path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text())
try:
    address = data["devnet"]["path_look_contract_address"]
except KeyError as exc:
    raise SystemExit(f"Missing devnet path_look_contract_address in {path}") from exc
if not address:
    raise SystemExit("path_look_contract_address is empty; update contract_hashes.json")
print(address)
PY
)

OUTPUT_FILE=$(python3 - "${PROJECT_ROOT}" "${RAW_OUTPUT}" <<'PY'
import pathlib, sys
root = pathlib.Path(sys.argv[1])
raw = pathlib.Path(sys.argv[2]).expanduser()
target = raw if raw.is_absolute() else (root / raw)
print(target.resolve(strict=False))
PY
)

mkdir -p "$(dirname "${OUTPUT_FILE}")"

TMP_JSON=$(mktemp)
trap 'rm -f "$TMP_JSON"' EXIT

(cd "${PROJECT_ROOT}" && \
  sncast --json ${SNCAST_ARGS} call \
    --contract-address "${CONTRACT_ADDRESS}" \
    --function generate_svg \
    --url "${SNCAST_RPC}" \
    --calldata "${TOKEN_ID}" "${THOUGHT_FLAG}" "${WILL_FLAG}" "${AWA_FLAG}" \
    >"${TMP_JSON}")

python3 - "${TMP_JSON}" "${OUTPUT_FILE}" <<'PY'
import json, pathlib, sys

json_path = pathlib.Path(sys.argv[1])
output_path = pathlib.Path(sys.argv[2])
data = json.loads(json_path.read_text())
svg = data.get("response", "")
if svg.startswith('"') and svg.endswith('"'):
    svg = svg[1:-1]
output_path.write_text(svg)
PY

echo "Saved SVG to ${OUTPUT_FILE}"
