use core::array::Array;
use glyph_pprf::{IPprfDispatcher, IPprfDispatcherTrait};
use starknet::ContractAddress;


/// Scope identifier appended to every `PathLook` PRF request.
const SCOPE_PATH: felt252 = 'PATH';
/// PPRF outputs values in [0, 999_999]; used to normalize into ranges.
const NORMALIZED_MAX: u256 = 1_000_000;

fn call_pprf(
    pprf_address: ContractAddress, token_id: felt252, label: felt252, occurrence: u32,
) -> u32 {
    let dispatcher = IPprfDispatcher { contract_address: pprf_address };
    let params: Array<felt252> = array![SCOPE_PATH, token_id, label, occurrence.into()];
    dispatcher.pprf(params.span())
}

/// Generate pseudo-random `u32` in range [min, max] (inclusive) using the shared `pprf` contract.
pub fn pseudo_random_range(
    pprf_address: ContractAddress,
    token_id: felt252,
    label: felt252,
    occurrence: u32,
    min: u32,
    max: u32,
) -> u32 {
    assert(min <= max, 'min must be <= max');
    let normalized = call_pprf(pprf_address, token_id, label, occurrence);
    let normalized_u256: u256 = normalized.into();

    let range = max - min + 1;
    let scaled = (normalized_u256 * range.into()) / NORMALIZED_MAX;

    min + scaled.try_into().unwrap()
}
