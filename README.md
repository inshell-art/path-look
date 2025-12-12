# Path Look - On-Chain SVG Generator for Starknet

Path Look is an on-chain SVG generation contract built on Starknet using Cairo 2. The Scarb package is `path_look` and the deployed contract name is `PathLook`. The repository also contains the `StepCurve` contract that renders cubic Bézier SVG paths used by Path Look.

## Quick Start

### Prerequisites
- Rust (for Scarb build)
- sncast (Starknet Foundry CLI)
- Local Starknet Devnet (running on `http://127.0.0.1:5050`)

### Build

```bash
cd contracts
scarb build
```

### Deploy (devnet)

1. Deploy `StepCurve` and record its address.
2. Deploy `PathLook` with constructor calldata `[pprf_address, step_curve_address]`.

### Contract Deployed on Devnet

- **PathLook Contract Address:** `0x04add2e03e6c61bde38205a88f2f0bc5da68f46d8d5c101bd3629d6d9436684c`
- **PathLook Class Hash:** `0x3946d0eddd52da33d6673b9279933fd04c8c9bcd66e2ac6caab658c688194ae`
- **Network:** Local Devnet (`http://127.0.0.1:5050`)

### Call the Contract

Generate an SVG with custom parameters:

```bash
sncast call \
  --contract-address 0x04add2e03e6c61bde38205a88f2f0bc5da68f46d8d5c101bd3629d6d9436684c \
  --function generate_svg \
  --calldata 1 1 0 0 \
  --url http://127.0.0.1:5050
```

Parameters (calldata):
- `token_id` (u32): Token identifier
- `if_thought_minted` (bool): 1 or 0
- `if_will_minted` (bool): 1 or 0
- `if_awa_minted` (bool): 1 or 0

### Extract SVG Output

The contract returns an SVG string. Extract it from the response:

```bash
sncast call \
  --contract-address 0x04add2e03e6c61bde38205a88f2f0bc5da68f46d8d5c101bd3629d6d9436684c \
  --function generate_svg \
  --calldata 1 1 0 0 \
  --url http://127.0.0.1:5050 | \
  sed -n '/<svg/,/<\/svg>/p' | \
  sed -e '/Account address/d' -e '/Private key/d'
```

## Project Structure

- `contracts/src/PathLook.cairo` - Main contract (uses `StepCurve` for path rendering)
- `contracts/src/step_curve.cairo` - Standalone path-rendering contract
- `contracts/src/rng.cairo` - Poseidon PRF utilities
- `contracts/src/lib.cairo` - Module exports
- `contract_hashes.json` - Deployed contract addresses and class hashes
- `contracts/accounts.json` - Predeployed account credentials (for devnet)

## Development

See `snfoundry.toml` for Starknet Foundry configuration.

## License

MIT
