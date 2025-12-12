use core::array::{ArrayTrait, Span, SpanTrait};
use path_look::PathLook::{IPathLookDispatcher, IPathLookDispatcherTrait};
use snforge_std::{declare, deploy, ContractClass, ContractInstance};
use starknet::ContractAddress;

#[starknet::contract]
mod MockPprf {
    #[storage]
    struct Storage {
        value: u32,
    }

    #[constructor]
    fn constructor(ref self: ContractState, value: u32) {
        self.value.write(value);
    }

    #[external]
    fn pprf(self: @ContractState, _params: Span<felt252>) -> u32 {
        self.value.read()
    }
}

fn deploy_mock_pprf(value: u32) -> ContractInstance {
    let mock_class = declare("MockPprf");
    // constructor calldata: value
    deploy(mock_class.class_hash, array![value.into()].span())
}

fn deploy_step_curve() -> ContractInstance {
    let class = declare("StepCurve");
    deploy(class.class_hash, array![].span())
}

fn deploy_path_look(
    pprf_address: ContractAddress, step_curve_address: ContractAddress,
) -> ContractInstance {
    let class = declare("PathLook");
    // constructor calldata: pprf_address, step_curve_address
    deploy(
        class.class_hash, array![pprf_address.into(), step_curve_address.into()].span()
    )
}

fn byte_array_is_empty(bytes: core::byte_array::ByteArray) -> bool {
    bytes.data.len() == 0_usize && bytes.pending_word_len == 0_u32
}

#[test]
fn generate_svg_returns_payload() {
    let mock = deploy_mock_pprf(111_111_u32);
    let step_curve = deploy_step_curve();
    let contract = deploy_path_look(mock.contract_address, step_curve.contract_address);
    let dispatcher = IPathLookDispatcher { contract_address: contract.contract_address };

    let svg = dispatcher.generate_svg(1, false, false, false);
    assert(!byte_array_is_empty(svg), 'generate_svg should return content');
}

#[test]
fn metadata_returns_payload() {
    let mock = deploy_mock_pprf(222_222_u32);
    let step_curve = deploy_step_curve();
    let contract = deploy_path_look(mock.contract_address, step_curve.contract_address);
    let dispatcher = IPathLookDispatcher { contract_address: contract.contract_address };

    let metadata = dispatcher.get_token_metadata(5, false, true, false);
    assert(!byte_array_is_empty(metadata), 'get_token_metadata should return content');
}
