#[starknet::contract]
pub mod StepCurve {
    use core::array::{ArrayTrait, Span, SpanTrait};
    use core::byte_array::ByteArrayTrait;

    #[derive(Copy, Drop)]
    struct Step {
        x: i128,
        y: i128,
    }

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl StepCurveImpl of IStepCurve<ContractState> {
        fn render_path(
            self: @ContractState,
            width: u32,
            height: u32,
            stroke_r: u32,
            stroke_g: u32,
            stroke_b: u32,
            stroke_width: u32,
            sharpness: u32,
            nodes: Span<i128>,
        ) -> ByteArray {
            let steps = self._decode_nodes(nodes, width, height);
            let d = self._to_cubic_bezier(@steps, sharpness);

            let mut path: ByteArray = Default::default();
            path.append(@"<path d=\"");
            path.append(@d);
            path.append(@"\" stroke=\"rgb(");
            path.append(@self._u32_to_string(stroke_r));
            path.append(@",");
            path.append(@self._u32_to_string(stroke_g));
            path.append(@",");
            path.append(@self._u32_to_string(stroke_b));
            path.append(@")\"");
            path.append(@" stroke-width=\"");
            path.append(@self._u32_to_string(stroke_width));
            path.append(@"\" fill=\"none\"");
            path.append(@" stroke-linecap=\"round\" stroke-linejoin=\"round\" />");

            path
        }
    }

    #[starknet::interface]
    pub trait IStepCurve<TContractState> {
        fn render_path(
            self: @TContractState,
            width: u32,
            height: u32,
            stroke_r: u32,
            stroke_g: u32,
            stroke_b: u32,
            stroke_width: u32,
            sharpness: u32,
            nodes: Span<i128>,
        ) -> ByteArray;
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _decode_nodes(
            self: @ContractState, nodes: Span<i128>, width: u32, height: u32,
        ) -> Array<Step> {
            let mut steps: Array<Step> = array![];
            let len = nodes.len();
            let mut i: usize = 0_usize;
            let max_x: i128 = width.into();
            let max_y: i128 = height.into();

            while i + 1_usize < len {
                let x: i128 = *nodes.at(i);
                let y: i128 = *nodes.at(i + 1_usize);
                let clamped_x = self._clamp_i128(x, 0_i128, max_x);
                let clamped_y = self._clamp_i128(y, 0_i128, max_y);
                steps.append(Step { x: clamped_x, y: clamped_y });
                i = i + 2_usize;
            }

            steps
        }

        fn _to_cubic_bezier(
            self: @ContractState, steps: @Array<Step>, sharpness: u32,
        ) -> ByteArray {
            let len = steps.len();
            if len < 2_usize {
                return Default::default();
            }

            let mut d: ByteArray = Default::default();
            let first = *steps.at(0_usize);
            d.append(@"M ");
            d.append(@self._i128_to_string(first.x));
            d.append(@" ");
            d.append(@self._i128_to_string(first.y));
            d.append(@"\n");

            let mut i: usize = 0_usize;
            let last_index = len - 1_usize;
            while i < last_index {
                let p0 = if i == 0_usize {
                    *steps.at(0_usize)
                } else {
                    *steps.at(i - 1_usize)
                };
                let p1 = *steps.at(i);
                let p2 = *steps.at(i + 1_usize);
                let p3 = if i + 2_usize < len {
                    *steps.at(i + 2_usize)
                } else {
                    *steps.at(last_index)
                };

                let delta_x1 = p2.x - p0.x;
                let delta_y1 = p2.y - p0.y;
                let delta_x2 = p3.x - p1.x;
                let delta_y2 = p3.y - p1.y;

                let cp1x = p1.x + self._div_round(delta_x1, sharpness);
                let cp1y = p1.y + self._div_round(delta_y1, sharpness);
                let cp2x = p2.x - self._div_round(delta_x2, sharpness);
                let cp2y = p2.y - self._div_round(delta_y2, sharpness);

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

        fn _clamp_i128(
            self: @ContractState, value: i128, min_value: i128, max_value: i128,
        ) -> i128 {
            let mut result = value;
            if result < min_value {
                result = min_value;
            }
            if result > max_value {
                result = max_value;
            }
            result
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

        fn _u32_to_string(self: @ContractState, value: u32) -> ByteArray {
            if value == 0 {
                return "0";
            }

            let mut num = value;
            let mut digits: Array<u8> = array![];

            while num != 0 {
                let digit: u8 = (num % 10).try_into().unwrap();
                digits.append(digit);
                num = num / 10;
            }

            let mut result: ByteArray = Default::default();
            let mut i = digits.len();
            while i > 0 {
                i -= 1;
                let digit = *digits.at(i);
                let digit_char = digit + 48;
                result.append_byte(digit_char);
            }

            result
        }
    }
}
