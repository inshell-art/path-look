#!/usr/bin/env bash
set -euo pipefail

# Deploy pprf + step-curve + path-look to a local devnet using sncast.

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
CONTRACTS_DIR="$REPO_ROOT/contracts"
SUMMARY_FILE="${SUMMARY_FILE:-$REPO_ROOT/devnet-deploy.json}"

RPC_URL="${RPC_URL:-http://127.0.0.1:5050}"
ACCOUNT_NAME="${ACCOUNT_NAME:-predeployed}"
ACCOUNTS_FILE="${ACCOUNTS_FILE:-$REPO_ROOT/accounts.devnet.json}"

CAST_FLAGS=(--url "$RPC_URL" --account "$ACCOUNT_NAME" --accounts-file "$ACCOUNTS_FILE" --wait --json)

extract_json_field() {
  local key="$1"
  python - "$key" <<'PY'
import json
import re
import sys

key = sys.argv[1]
raw = sys.stdin.read()
try:
    data = json.loads(raw)
except Exception:
    data = None

def find_key(obj):
    if isinstance(obj, dict):
        if key in obj:
            return obj[key]
        for v in obj.values():
            found = find_key(v)
            if found is not None:
                return found
    if isinstance(obj, list):
        for item in obj:
            found = find_key(item)
            if found is not None:
                return found
    return None

value = find_key(data) if data is not None else None
if value is None:
    match = re.search(rf"{key}:\s*([^\s]+)", raw)
    value = match.group(1) if match else ""
if isinstance(value, list):
    value = value[0] if value else ""
print(value)
PY
}

log_summary() {
  echo "Writing deployment summary to $SUMMARY_FILE"
  cat >"$SUMMARY_FILE" <<EOF
{
  "rpc_url": "$RPC_URL",
  "account": "$ACCOUNT_NAME",
  "pprf_class_hash": "$PPRF_CLASS_HASH",
  "pprf_address": "$PPRF_ADDRESS",
  "step_curve_class_hash": "$STEP_CURVE_CLASS_HASH",
  "step_curve_address": "$STEP_CURVE_ADDRESS",
  "path_look_class_hash": "$PATH_LOOK_CLASS_HASH",
  "path_look_address": "$PATH_LOOK_ADDRESS"
}
EOF
}

echo "Using sncast with url=$RPC_URL, account=$ACCOUNT_NAME, accounts=$ACCOUNTS_FILE"
echo "Building dependencies..."
(cd "$REPO_ROOT/../pprf" && scarb build)
(cd "$REPO_ROOT/../step-curve" && scarb build)
(cd "$CONTRACTS_DIR" && scarb build)

echo "Declaring Pprf..."
PPRF_DECLARE=$(cd "$REPO_ROOT/../pprf" && sncast "${CAST_FLAGS[@]}" declare --contract-name Pprf --package glyph_pprf)
PPRF_CLASS_HASH=$(extract_json_field "class_hash" <<<"$PPRF_DECLARE")
[[ -n "$PPRF_CLASS_HASH" ]] || { echo "Failed to parse Pprf class hash"; exit 1; }

echo "Deploying Pprf..."
PPRF_DEPLOY=$(sncast "${CAST_FLAGS[@]}" deploy --class-hash "$PPRF_CLASS_HASH")
PPRF_ADDRESS=$(extract_json_field "contract_address" <<<"$PPRF_DEPLOY")
[[ -n "$PPRF_ADDRESS" ]] || { echo "Failed to parse Pprf contract address"; exit 1; }

echo "Declaring StepCurve..."
STEP_CURVE_DECLARE=$(cd "$REPO_ROOT/../step-curve" && sncast "${CAST_FLAGS[@]}" declare --contract-name StepCurve --package step_curve)
STEP_CURVE_CLASS_HASH=$(extract_json_field "class_hash" <<<"$STEP_CURVE_DECLARE")
[[ -n "$STEP_CURVE_CLASS_HASH" ]] || { echo "Failed to parse StepCurve class hash"; exit 1; }

echo "Deploying StepCurve..."
STEP_CURVE_DEPLOY=$(sncast "${CAST_FLAGS[@]}" deploy --class-hash "$STEP_CURVE_CLASS_HASH")
STEP_CURVE_ADDRESS=$(extract_json_field "contract_address" <<<"$STEP_CURVE_DEPLOY")
[[ -n "$STEP_CURVE_ADDRESS" ]] || { echo "Failed to parse StepCurve contract address"; exit 1; }

echo "Declaring PathLook..."
PATH_LOOK_DECLARE=$(cd "$CONTRACTS_DIR" && sncast "${CAST_FLAGS[@]}" declare --contract-name PathLook --package path_look)
PATH_LOOK_CLASS_HASH=$(extract_json_field "class_hash" <<<"$PATH_LOOK_DECLARE")
[[ -n "$PATH_LOOK_CLASS_HASH" ]] || { echo "Failed to parse PathLook class hash"; exit 1; }

echo "Deploying PathLook..."
PATH_LOOK_DEPLOY=$(
  sncast "${CAST_FLAGS[@]}" \
    deploy \
    --class-hash "$PATH_LOOK_CLASS_HASH" \
    --constructor-calldata "$PPRF_ADDRESS" "$STEP_CURVE_ADDRESS"
)
PATH_LOOK_ADDRESS=$(extract_json_field "contract_address" <<<"$PATH_LOOK_DEPLOY")
[[ -n "$PATH_LOOK_ADDRESS" ]] || { echo "Failed to parse PathLook contract address"; exit 1; }

log_summary

echo ""
echo "Deployed on devnet:"
echo "  Pprf:        $PPRF_ADDRESS (class $PPRF_CLASS_HASH)"
echo "  StepCurve:   $STEP_CURVE_ADDRESS (class $STEP_CURVE_CLASS_HASH)"
echo "  PathLook:    $PATH_LOOK_ADDRESS (class $PATH_LOOK_CLASS_HASH)"
