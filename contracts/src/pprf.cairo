use core::array::Span;

#[starknet::interface]
pub trait IPprf<TState> {
    /// Matches the standalone `pprf` contract so dispatchers can call it.
    fn pprf(self: @TState, params: Span<felt252>) -> u32;
}
