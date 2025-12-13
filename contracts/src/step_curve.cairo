#[starknet::contract]
pub mod StepCurve {
    use core::array::{ArrayTrait, Span};
    use core::byte_array::ByteArrayTrait;
    use core::traits::TryInto;

    #[derive(Copy, Drop, Serde)]
    pub struct Point {
        pub x: i128,
        pub y: i128,
    }

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl StepCurveImpl of IStepCurve<ContractState> {
        /// Convert ordered nodes into SVG path-data ("d").
        /// `tension` controls handle distance; values <= 0 default to 3 to avoid div-by-zero.
        fn d_from_nodes(self: @ContractState, nodes: Span<Point>, tension: u32) -> ByteArray {
            let safe_tension = if tension == 0_u32 { 3_u32 } else { tension };
            self._to_cubic_bezier(nodes, safe_tension)
        }
    }

    #[starknet::interface]
    pub trait IStepCurve<TContractState> {
        /// Convert ordered nodes into SVG path-data.
        fn d_from_nodes(self: @TContractState, nodes: Span<Point>, tension: u32) -> ByteArray;
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _to_cubic_bezier(self: @ContractState, nodes: Span<Point>, tension: u32) -> ByteArray {
            let len = nodes.len();
            if len < 2_usize {
                return Default::default();
            }

            let mut d: ByteArray = Default::default();
            let first = *nodes.at(0_usize);
            d.append(@"M ");
            d.append(@self._i128_to_string(first.x));
            d.append(@" ");
            d.append(@self._i128_to_string(first.y));
            d.append(@"\n");

            let mut i: usize = 0_usize;
            let last_index = len - 1_usize;
            while i < last_index {
                let p0 = if i == 0_usize {
                    *nodes.at(0_usize)
                } else {
                    *nodes.at(i - 1_usize)
                };
                let p1 = *nodes.at(i);
                let p2 = *nodes.at(i + 1_usize);
                let p3 = if i + 2_usize < len {
                    *nodes.at(i + 2_usize)
                } else {
                    *nodes.at(last_index)
                };

                let delta_x1 = p2.x - p0.x;
                let delta_y1 = p2.y - p0.y;
                let delta_x2 = p3.x - p1.x;
                let delta_y2 = p3.y - p1.y;

                let cp1x = p1.x + self._div_round(delta_x1, tension);
                let cp1y = p1.y + self._div_round(delta_y1, tension);
                let cp2x = p2.x - self._div_round(delta_x2, tension);
                let cp2y = p2.y - self._div_round(delta_y2, tension);

                d.append(@" C ");
                d.append(@self._i128_to_string(cp1x));
                d.append(@" ");
                d.append(@self._i128_to_string(cp1y));
                d.append(@", ");
                d.append(@self._i128_to_string(cp2x));
                d.append(@" ");
                d.append(@self._i128_to_string(cp2y));
                d.append(@", ");
                d.append(@self._i128_to_string(p2.x));
                d.append(@" ");
                d.append(@self._i128_to_string(p2.y));
                d.append(@"\n");

                i = i + 1_usize;
            }

            d
        }

        fn _div_round(self: @ContractState, value: i128, denominator: u32) -> i128 {
            let denom: i128 = denominator.into();
            if denom == 0_i128 {
                return 0_i128;
            }

            if value >= 0_i128 {
                (value + denom / 2_i128) / denom
            } else {
                (value - denom / 2_i128) / denom
            }
        }

        fn _u128_to_string(self: @ContractState, value: u128) -> ByteArray {
            if value == 0_u128 {
                return "0";
            }

            let mut num = value;
            let mut digits: Array<u8> = array![];

            while num != 0_u128 {
                let digit: u8 = (num % 10_u128).try_into().unwrap();
                digits.append(digit);
                num = num / 10_u128;
            }

            let mut result: ByteArray = Default::default();
            let mut i = digits.len();
            while i > 0_usize {
                i = i - 1_usize;
                let digit = *digits.at(i);
                let digit_char = digit + 48_u8;
                result.append_byte(digit_char);
            }

            result
        }

        fn _i128_to_string(self: @ContractState, value: i128) -> ByteArray {
            if value >= 0_i128 {
                let unsigned: u128 = value.try_into().unwrap();
                return self._u128_to_string(unsigned);
            }

            let positive: u128 = (0_i128 - value).try_into().unwrap();
            let mut result: ByteArray = Default::default();
            result.append(@"-");
            let digits = self._u128_to_string(positive);
            result.append(@digits);
            result
        }
    }
}
