# PATH SVG - On-Chain SVG Generator for Starknet

An on-chain SVG generation contract built on Starknet using Cairo 2.

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

### Contract Deployed on Devnet

- **Contract Address:** `0x04add2e03e6c61bde38205a88f2f0bc5da68f46d8d5c101bd3629d6d9436684c`
- **Class Hash:** `0x3946d0eddd52da33d6673b9279933fd04c8c9bcd66e2ac6caab658c688194ae`
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

- `contracts/src/PATH_SVG.cairo` - Main contract
- `contracts/src/random_utils.cairo` - Poseidon PRF utilities
- `contracts/src/lib.cairo` - Library utilities
- `contract_hashes.json` - Deployed contract addresses and class hashes
- `contracts/accounts.json` - Predeployed account credentials (for devnet)

## Development

See `snfoundry.toml` for Starknet Foundry configuration.

## License

MIT
