#[starknet::contract]
mod PathLook {
    use core::array::ArrayTrait;
    use core::byte_array::ByteArrayTrait;
    use path_look::rng;
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    const LABEL_STEP_COUNT: felt252 = 'STEP';
    const LABEL_SHARPNESS: felt252 = 'SHRP';
    const LABEL_PADDING: felt252 = 'PADD';
    const LABEL_TARGET_X: felt252 = 'TRGX';
    const LABEL_TARGET_Y: felt252 = 'TRGY';
    const LABEL_THOUGHT_DX: felt252 = 'THDX';
    const LABEL_THOUGHT_DY: felt252 = 'THDY';
    const LABEL_WILL_DX: felt252 = 'WIDX';
    const LABEL_WILL_DY: felt252 = 'WIDY';
    const LABEL_AWA_DX: felt252 = 'AWDX';
    const LABEL_AWA_DY: felt252 = 'AWDY';

    #[storage]
    struct Storage {
        pprf_address: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, pprf_address: ContractAddress) {
        self.pprf_address.write(pprf_address);
    }

    #[derive(Copy, Drop)]
    struct Step {
        x: i128,
        y: i128,
    }

    #[abi(embed_v0)]
    impl PathLookImpl of super::IPathLook<ContractState> {
        fn generate_svg(
            self: @ContractState,
            token_id: felt252,
            if_thought_minted: bool,
            if_will_minted: bool,
            if_awa_minted: bool,
        ) -> ByteArray {
            const WIDTH: u32 = 1024;
            const HEIGHT: u32 = 1024;

            let step_number = self._random_range(token_id, LABEL_STEP_COUNT, 0, 1, 50);

            let sharpness = self._random_range(token_id, LABEL_SHARPNESS, 0, 1, 7);

            let stroke_w = self._max_u32(1, self._round_div(100, step_number));

            let targets = self._find_targets(token_id, WIDTH, HEIGHT, step_number);

            let thought_steps = self
                ._find_steps(token_id, @targets, WIDTH, HEIGHT, LABEL_THOUGHT_DX, LABEL_THOUGHT_DY);
            let thought_path = self._to_cubic_bezier(@thought_steps, sharpness);

            let will_steps = self
                ._find_steps(token_id, @targets, WIDTH, HEIGHT, LABEL_WILL_DX, LABEL_WILL_DY);
            let will_path = self._to_cubic_bezier(@will_steps, sharpness);

            let awa_steps = self
                ._find_steps(token_id, @targets, WIDTH, HEIGHT, LABEL_AWA_DX, LABEL_AWA_DY);
            let awa_path = self._to_cubic_bezier(@awa_steps, sharpness);

            let all_not_minted = (!if_thought_minted) && (!if_will_minted) && (!if_awa_minted);
            let sigma = if all_not_minted {
                30_u32
            } else {
                3_u32
            };

            let mut defs: ByteArray = Default::default();
            if if_thought_minted { // Minted token hides this strand.
            } else {
                defs.append(@"<g id=\"thought-src\"\n");
                defs.append(@"stroke=\"rgb(0,0,255)\"\n");
                defs.append(@"stroke-width=\"");
                defs.append(@self._u32_to_string(stroke_w));
                defs
                    .append(
                        @"\"\nfill=\"none\"\nstroke-linecap=\"round\"\nstroke-linejoin=\"round\"\nfilter=\"url(#lightUp)\">\n",
                    );
                defs.append(@"<path id=\"path_thought\" d=\"");
                defs.append(@thought_path);
                defs.append(@"\">\n</path>\n</g>\n");
            }

            if if_will_minted { // Minted token hides this strand.
            } else {
                defs.append(@"<g id=\"will-src\"\n");
                defs.append(@"stroke=\"rgb(255,0,0)\"\n");
                defs.append(@"stroke-width=\"");
                defs.append(@self._u32_to_string(stroke_w));
                defs
                    .append(
                        @"\"\nfill=\"none\"\nstroke-linecap=\"round\"\nstroke-linejoin=\"round\"\nfilter=\"url(#lightUp)\">\n",
                    );
                defs.append(@"<path id=\"path_will\" d=\"");
                defs.append(@will_path);
                defs.append(@"\">\n</path>\n</g>\n");
            }

            if if_awa_minted { // Minted token hides this strand.
            } else {
                defs.append(@"<g id=\"awa-src\"\n");
                defs.append(@"stroke=\"rgb(0,255,0)\"\n");
                defs.append(@"stroke-width=\"");
                defs.append(@self._u32_to_string(stroke_w));
                defs
                    .append(
                        @"\"\nfill=\"none\"\nstroke-linecap=\"round\"\nstroke-linejoin=\"round\"\nfilter=\"url(#lightUp)\">\n",
                    );
                defs.append(@"<path id=\"path_awa\" d=\"");
                defs.append(@awa_path);
                defs.append(@"\">\n</path>\n</g>\n");
            }

            defs
                .append(
                    @"<filter id=\"lightUp\"\nfilterUnits=\"userSpaceOnUse\"\nx=\"-100%\" y=\"-100%\" width=\"200%\" height=\"200%\"\ncolor-interpolation-filters=\"sRGB\">\n\n<feGaussianBlur in=\"SourceGraphic\"\nstdDeviation=\"",
                );
            defs.append(@self._u32_to_string(sigma));
            defs
                .append(
                    @"\" \nresult=\"blur\">\n</feGaussianBlur>\n\n<feMerge>\n<feMergeNode in=\"blur\"/>\n<feMergeNode in=\"blur\"/>\n<feMergeNode in=\"SourceGraphic\"/>\n</feMerge>\n</filter> ",
                );

            let mut uses: ByteArray = Default::default();
            if if_thought_minted { // Minted token hides this strand.
            } else {
                uses
                    .append(
                        @"    <use href=\"#thought-src\" style=\"mix-blend-mode:lighten;\"/>\n",
                    );
            }
            if if_will_minted { // Minted token hides this strand.
            } else {
                uses.append(@"    <use href=\"#will-src\" style=\"mix-blend-mode:lighten;\"/>\n");
            }
            if if_awa_minted { // Minted token hides this strand.
            } else {
                uses.append(@"    <use href=\"#awa-src\" style=\"mix-blend-mode:lighten;\"/>\n");
            }

            let mut svg: ByteArray = Default::default();
            svg.append(@"<svg width=\"");
            svg.append(@self._u32_to_string(WIDTH));
            svg.append(@"\" height=\"");
            svg.append(@self._u32_to_string(HEIGHT));
            svg.append(@"\" viewBox=\"0 0 ");
            svg.append(@self._u32_to_string(WIDTH));
            svg.append(@" ");
            svg.append(@self._u32_to_string(HEIGHT));
            svg
                .append(
                    @"\"\n     xmlns=\"http://www.w3.org/2000/svg\"\n     style=\"background:#000; isolation:isolate\">\n\n<defs>\n",
                );
            svg.append(@defs);
            svg.append(@"\n</defs>\n\n<rect width='1024' height='1024' fill='#000'/>\n\n  <g>\n");
            svg.append(@uses);
            svg.append(@"  </g>\n\n\n</svg>");

            svg
        }

        fn generate_svg_data_uri(
            self: @ContractState,
            token_id: felt252,
            if_thought_minted: bool,
            if_will_minted: bool,
            if_awa_minted: bool,
        ) -> ByteArray {
            let svg = self.generate_svg(token_id, if_thought_minted, if_will_minted, if_awa_minted);
            let mut data_uri: ByteArray = Default::default();
            data_uri.append(@"data:image/svg+xml;charset=UTF-8,");
            data_uri.append(@svg);
            data_uri
        }

        fn get_token_metadata(
            self: @ContractState,
            token_id: felt252,
            if_thought_minted: bool,
            if_will_minted: bool,
            if_awa_minted: bool,
        ) -> ByteArray {
            let token_id_str = self._felt_to_string(token_id);

            const WIDTH: u32 = 1024;
            const HEIGHT: u32 = 1024;

            let step_number = self._random_range(token_id, LABEL_STEP_COUNT, 0, 1, 50);
            let targets = self._find_targets(token_id, WIDTH, HEIGHT, step_number);
            let point_count = targets.len().try_into().unwrap();

            let mut metadata: ByteArray = Default::default();
            metadata.append(@"{\"name\":\"PATH #");
            metadata.append(@token_id_str);
            metadata
                .append(@"\",\"description\":\"PATH NFT with dynamic on-chain SVG\",\"image\":\"");

            let data_uri = self
                .generate_svg_data_uri(token_id, if_thought_minted, if_will_minted, if_awa_minted);
            metadata.append(@data_uri);
            metadata.append(@"\",\"external_url\":\"https://path.design/token/");
            metadata.append(@token_id_str);
            metadata.append(@"\",\"attributes\":[");

            metadata.append(@"{\"trait_type\":\"Thought Minted\",\"value\":");
            metadata.append(@self._bool_to_string(if_thought_minted));
            metadata.append(@"},");

            metadata.append(@"{\"trait_type\":\"Will Minted\",\"value\":");
            metadata.append(@self._bool_to_string(if_will_minted));
            metadata.append(@"},");

            metadata.append(@"{\"trait_type\":\"Awa Minted\",\"value\":");
            metadata.append(@self._bool_to_string(if_awa_minted));
            metadata.append(@"},");

            metadata.append(@"{\"trait_type\":\"Point Count\",\"value\":\"");
            metadata.append(@self._u32_to_string(point_count));
            metadata.append(@"\"}]");

            metadata.append(@"}");

            metadata
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _random_range(
            self: @ContractState,
            token_id: felt252,
            label: felt252,
            occurrence: u32,
            min: u32,
            max: u32,
        ) -> u32 {
            let address = self.pprf_address.read();
            rng::pseudo_random_range(address, token_id, label, occurrence, min, max)
        }

        fn _pow2(self: @ContractState, exponent: u32) -> u32 {
            let mut result = 1_u32;
            let mut i = 0_u32;
            while i < exponent {
                result = result * 2_u32;
                i = i + 1_u32;
            }
            result
        }

        fn _max_u32(self: @ContractState, a: u32, b: u32) -> u32 {
            if a >= b {
                a
            } else {
                b
            }
        }

        fn _round_div(self: @ContractState, numerator: u32, denominator: u32) -> u32 {
            if denominator == 0_u32 {
                return 0_u32;
            }

            (numerator + (denominator / 2_u32)) / denominator
        }

        fn _find_targets(
            self: @ContractState, token_id: felt252, width: u32, height: u32, interior_count: u32,
        ) -> Array<Step> {
            let padding_min = width / 10_u32;
            let padding_max = width / 3_u32;
            let padding = self._random_range(token_id, LABEL_PADDING, 0, padding_min, padding_max);

            let edge_pad = padding;
            let inner_w = width - 2_u32 * edge_pad;
            let inner_h = height - 2_u32 * edge_pad;

            let mut interior: Array<Step> = array![];
            let target_len_goal: usize = interior_count.try_into().unwrap();
            while interior.len() < target_len_goal {
                let idx: u32 = interior.len().try_into().unwrap();
                let x_offset = self._random_range(token_id, LABEL_TARGET_X, idx, 0_u32, inner_w);
                let y_offset = self._random_range(token_id, LABEL_TARGET_Y, idx, 0_u32, inner_h);

                let x_val: u32 = edge_pad + x_offset;
                let y_val: u32 = edge_pad + y_offset;
                interior.append(Step { x: x_val.into(), y: y_val.into() });
            }

            let mut points: Array<Step> = array![];
            let scale: i128 = width.into();
            let offset: i128 = (height / 2_u32).into();
            let start_x: i128 = -50_i128;
            let start_y: i128 = offset;
            points.append(Step { x: start_x, y: start_y });

            let mut i: usize = 0_usize;
            while i < interior.len() {
                points.append(*interior.at(i));
                i = i + 1_usize;
            }

            let end_x: i128 = scale + 50_i128;
            let end_y: i128 = offset;
            points.append(Step { x: end_x, y: end_y });

            points
        }

        fn _find_steps(
            self: @ContractState,
            token_id: felt252,
            targets: @Array<Step>,
            width: u32,
            height: u32,
            dx_label: felt252,
            dy_label: felt252,
        ) -> Array<Step> {
            let mut steps: Array<Step> = array![];
            let len = targets.len();
            let max_dx = width / 100_u32;
            let max_dy = height / 100_u32;
            let max_x: i128 = width.into();
            let max_y: i128 = height.into();

            let mut i: usize = 0_usize;
            while i < len {
                let target = *targets.at(i);
                let occurrence: u32 = i.try_into().unwrap();
                let dx = self._random_range(token_id, dx_label, occurrence, 0_u32, max_dx);
                let dy = self._random_range(token_id, dy_label, occurrence, 0_u32, max_dy);

                let x = self._clamp_i128(target.x + dx.into(), 0_i128, max_x);
                let y = self._clamp_i128(target.y + dy.into(), 0_i128, max_y);

                steps.append(Step { x, y });

                i = i + 1_usize;
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

        fn _felt_to_string(self: @ContractState, value: felt252) -> ByteArray {
            if value == 0 {
                return "0";
            }

            // Convert felt252 to u256 for easier manipulation
            let num_u256: u256 = value.into();
            let mut num = num_u256;
            let mut digits: Array<u8> = array![];

            // Extract digits
            while num != 0 {
                let digit: u8 = (num % 10).try_into().unwrap();
                digits.append(digit);
                num = num / 10;
            }

            // Reverse and convert to string
            let mut result: ByteArray = Default::default();
            let mut i = digits.len();
            while i > 0 {
                i -= 1;
                let digit = *digits.at(i);
                let digit_char = digit + 48; // ASCII '0' = 48
                result.append_byte(digit_char);
            }

            result
        }

        fn _u32_to_string(self: @ContractState, value: u32) -> ByteArray {
            if value == 0 {
                return "0";
            }

            let mut num = value;
            let mut digits: Array<u8> = array![];

            // Extract digits
            while num != 0 {
                let digit: u8 = (num % 10).try_into().unwrap();
                digits.append(digit);
                num = num / 10;
            }

            // Reverse and convert to string
            let mut result: ByteArray = Default::default();
            let mut i = digits.len();
            while i > 0 {
                i -= 1;
                let digit = *digits.at(i);
                let digit_char = digit + 48; // ASCII '0' = 48
                result.append_byte(digit_char);
            }

            result
        }

        fn _bool_to_string(self: @ContractState, value: bool) -> ByteArray {
            if value {
                "true"
            } else {
                "false"
            }
        }
    }
}

#[starknet::interface]
trait IPathLook<TContractState> {
    /// Generate raw SVG code for a given token_id and minting status
    fn generate_svg(
        self: @TContractState,
        token_id: felt252,
        if_thought_minted: bool,
        if_will_minted: bool,
        if_awa_minted: bool,
    ) -> ByteArray;

    /// Generate SVG as data URI
    fn generate_svg_data_uri(
        self: @TContractState,
        token_id: felt252,
        if_thought_minted: bool,
        if_will_minted: bool,
        if_awa_minted: bool,
    ) -> ByteArray;

    /// Get complete token metadata in JSON format
    fn get_token_metadata(
        self: @TContractState,
        token_id: felt252,
        if_thought_minted: bool,
        if_will_minted: bool,
        if_awa_minted: bool,
    ) -> ByteArray;
}
