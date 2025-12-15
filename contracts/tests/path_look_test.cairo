use core::array::{ArrayTrait, Span};
use core::result::ResultTrait;
use path_look::PathLook::{IPathLookDispatcher, IPathLookDispatcherTrait};
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
use starknet::ContractAddress;
use step_curve::StepCurve::StepCurve;

#[starknet::contract]
mod StepCurveMock {
    use super::StepCurve::IStepCurve;

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl MockImpl of IStepCurve<ContractState> {
        fn d_from_nodes(
            self: @ContractState, nodes: Span<super::StepCurve::Point>, handle_scale: u32,
        ) -> ByteArray {
            let _ = nodes;
            let _ = handle_scale;
            let mut path: ByteArray = Default::default();
            path.append(@"M 0 0");
            path
        }

        fn d_from_flattened_xy(
            self: @ContractState, nodes_xy: Span<felt252>, handle_scale: u32,
        ) -> ByteArray {
            let _ = nodes_xy;
            let _ = handle_scale;
            let mut path: ByteArray = Default::default();
            path.append(@"M 0 0");
            path
        }
    }
}

#[starknet::contract]
mod MockPprf {
    use core::array::ArrayTrait;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use glyph_pprf::IGlyph;

    #[storage]
    struct Storage {
        value: u32,
    }

    #[constructor]
    fn constructor(ref self: ContractState, value: u32) {
        self.value.write(value);
    }

    #[abi(embed_v0)]
    impl GlyphMock of IGlyph<ContractState> {
        fn render(self: @ContractState, params: Span<felt252>) -> Array<felt252> {
            let mut data: Array<felt252> = array![];
            data.append(self.value.read().into());
            data
        }

        fn metadata(self: @ContractState) -> Span<felt252> {
            array![].span()
        }
    }
}

fn deploy_mock_pprf(value: u32) -> ContractAddress {
    let declared = declare("MockPprf").unwrap();
    let class = declared.contract_class();
    // constructor calldata: value
    let mut calldata = array![value.into()];
    let result = class.deploy(@calldata).unwrap();
    let (address, _) = result;
    address
}

fn deploy_step_curve() -> ContractAddress {
    let class = declare("StepCurveMock").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    let result = class.deploy(@calldata).unwrap();
    let (address, _) = result;
    address
}

fn deploy_path_look(
    pprf_address: ContractAddress, step_curve_address: ContractAddress,
) -> ContractAddress {
    let class = declare("PathLook").unwrap().contract_class();
    // constructor calldata: pprf_address, step_curve_address
    let mut calldata = array![pprf_address.into(), step_curve_address.into()];
    let result = class.deploy(@calldata).unwrap();
    let (address, _) = result;
    address
}

#[test]
fn generate_svg_returns_payload() {
    let mock = deploy_mock_pprf(111_111_u32);
    let step_curve = deploy_step_curve();
    let contract = deploy_path_look(mock, step_curve);
    let dispatcher = IPathLookDispatcher { contract_address: contract };

    let svg = dispatcher.generate_svg(1, false, false, false);
    assert(svg.len() > 0_u32, 'svg empty');
}

#[test]
fn metadata_returns_payload() {
    let mock = deploy_mock_pprf(222_222_u32);
    let step_curve = deploy_step_curve();
    let contract = deploy_path_look(mock, step_curve);
    let dispatcher = IPathLookDispatcher { contract_address: contract };

    let metadata = dispatcher.get_token_metadata(5, false, true, false);
    assert(metadata.len() > 0_u32, 'meta empty');
}
