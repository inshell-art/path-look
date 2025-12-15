#!/usr/bin/env bash
set -euo pipefail

# Smoke test a devnet deployment by calling PathLook + StepCurve.

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
DEPLOY_FILE="${DEPLOY_FILE:-$REPO_ROOT/devnet-deploy.json}"
TOKEN_ID="${TOKEN_ID:-1}"

RPC_URL="${RPC_URL:-http://127.0.0.1:5050}"
CAST_PROFILE="${CAST_PROFILE:-}"

GLOBAL_FLAGS=(--json)
if [[ -n "$CAST_PROFILE" ]]; then
  GLOBAL_FLAGS=(--profile "$CAST_PROFILE" "${GLOBAL_FLAGS[@]}")
fi
TX_FLAGS=(--url "$RPC_URL")

load_from_deploy() {
  local key="$1"
  [[ -f "$DEPLOY_FILE" ]] || return 0
  python - "$key" "$DEPLOY_FILE" <<'PY'
import json
import sys

key = sys.argv[1]
path = sys.argv[2]
try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    sys.exit(0)

def find_key(obj):
    if isinstance(obj, dict):
        if key in obj:
            return obj[key]
        for v in obj.values():
            found = find_key(v)
            if found is not None:
                return found
    if isinstance(obj, list):
        for v in obj:
            found = find_key(v)
            if found is not None:
                return found
    return None

value = find_key(data)
if value is not None:
    print(value)
PY
}

decode_call_result() {
  local label="$1"
  local raw="$2"
  RAW_INPUT="$raw" python - "$label" <<'PY'
import json
import re
import sys
import os

label = sys.argv[1]
raw = os.environ.get("RAW_INPUT", "")

def to_int_list(seq):
    out = []
    for item in seq:
        if isinstance(item, str) and item.startswith("0x"):
            out.append(int(item, 16))
        else:
            out.append(int(item))
    return out

def find_list(obj):
    if isinstance(obj, list):
        return obj
    if isinstance(obj, dict):
        for v in obj.values():
            found = find_list(v)
            if found is not None:
                return found
    return None

payload = None
try:
    data = json.loads(raw)
    if isinstance(data, dict) and "response" in data and isinstance(data["response"], str):
        payload = data["response"].encode("utf-8")
    else:
        seq = find_list(data)
        if seq is not None:
            payload = bytes(to_int_list(seq))
except Exception:
    payload = None

if payload is None:
    if "<svg" in raw or "data:image/svg+xml" in raw:
        payload = raw.encode("utf-8")
    else:
        match = re.search(r"call_result:\s*\[(.*)\]", raw, re.S)
        if match:
            nums = re.findall(r"0x[0-9a-fA-F]+|\d+", match.group(1))
            payload = bytes(int(x, 16) if x.startswith("0x") else int(x) for x in nums)

if payload is None or len(payload) == 0:
    sys.exit(f"no call_result found for {label}")

text = payload.decode("utf-8", errors="ignore")
if text.startswith('"') and text.endswith('"'):
    text = text[1:-1]
if not text:
    sys.exit(f"{label} returned empty payload")
if label == "svg" and not (text.startswith("<svg") or text.startswith("data:image/svg+xml")):
    sys.exit("SVG payload does not start with <svg")
if label == "metadata" and not text.startswith("{"):
    sys.exit("Metadata payload does not start with {")

print(text)
PY
}

PPRF_ADDRESS="${PPRF_ADDRESS:-$(load_from_deploy pprf_address)}"
STEP_CURVE_ADDRESS="${STEP_CURVE_ADDRESS:-$(load_from_deploy step_curve_address)}"
PATH_LOOK_ADDRESS="${PATH_LOOK_ADDRESS:-$(load_from_deploy path_look_address)}"

if [[ -z "${PATH_LOOK_ADDRESS:-}" ]]; then
  echo "PATH_LOOK_ADDRESS is required (set env or populate $DEPLOY_FILE)."
  exit 1
fi

echo "Using sncast with url=$RPC_URL (profile $CAST_PROFILE)"
echo "PathLook @ $PATH_LOOK_ADDRESS"

SVG_CALL=$(
  sncast "${GLOBAL_FLAGS[@]}" call \
    --contract-address "$PATH_LOOK_ADDRESS" \
    --function generate_svg_data_uri \
    --calldata "$TOKEN_ID" 0 0 0 \
    "${TX_FLAGS[@]}" 2>&1
)
SVG_TEXT=$(decode_call_result "svg" "$SVG_CALL")
echo "generate_svg_data_uri ok (length ${#SVG_TEXT})"

META_CALL=$(
  sncast "${GLOBAL_FLAGS[@]}" call \
    --contract-address "$PATH_LOOK_ADDRESS" \
    --function get_token_metadata \
    --calldata "$TOKEN_ID" 0 0 0 \
    "${TX_FLAGS[@]}" 2>&1
)
META_TEXT=$(decode_call_result "metadata" "$META_CALL")
echo "get_token_metadata ok (length ${#META_TEXT})"

if [[ -n "${STEP_CURVE_ADDRESS:-}" ]]; then
  STEP_CALL=$(
    sncast "${GLOBAL_FLAGS[@]}" call \
      --contract-address "$STEP_CURVE_ADDRESS" \
      --function d_from_flattened_xy \
      --calldata 6 0 0 512 0 512 512 3 \
      "${TX_FLAGS[@]}" 2>&1
  )
  STEP_TEXT=$(decode_call_result "step_curve" "$STEP_CALL")
  echo "StepCurve d_from_flattened_xy ok (length ${#STEP_TEXT})"
fi

echo "Devnet smoke test complete for token $TOKEN_ID."
