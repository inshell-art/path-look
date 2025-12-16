#[starknet::contract]
pub mod PathLook {
    use core::array::ArrayTrait;
    use core::byte_array::ByteArrayTrait;
    use core::option::OptionTrait;
    use path_look::rng;
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use step_curve::StepCurve::StepCurve::{IStepCurveDispatcher, IStepCurveDispatcherTrait, Point};

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
        step_curve_address: ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, pprf_address: ContractAddress, step_curve_address: ContractAddress,
    ) {
        self.pprf_address.write(pprf_address);
        self.step_curve_address.write(step_curve_address);
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
            let raw_thought_path = self._curve_d(@thought_steps, sharpness);
            let thought_path = self._strip_newlines(@raw_thought_path);

            let will_steps = self
                ._find_steps(token_id, @targets, WIDTH, HEIGHT, LABEL_WILL_DX, LABEL_WILL_DY);
            let raw_will_path = self._curve_d(@will_steps, sharpness);
            let will_path = self._strip_newlines(@raw_will_path);

            let awa_steps = self
                ._find_steps(token_id, @targets, WIDTH, HEIGHT, LABEL_AWA_DX, LABEL_AWA_DY);
            let raw_awa_path = self._curve_d(@awa_steps, sharpness);
            let awa_path = self._strip_newlines(@raw_awa_path);

            let all_not_minted = (!if_thought_minted) && (!if_will_minted) && (!if_awa_minted);
            let sigma = if all_not_minted {
                30_u32
            } else {
                3_u32
            };

            let mut defs: ByteArray = Default::default();
            if if_thought_minted { // Minted token hides this strand.
            } else {
                defs.append(@"<g id='thought-src' filter='url(#lightUp)'><path id='path_thought' d='");
                defs.append(@thought_path);
                defs.append(@"' stroke='rgb(0,0,255)' stroke-width='");
                defs.append(@self._u32_to_string(stroke_w));
                defs.append(@"' fill='none' stroke-linecap='round' stroke-linejoin='round' /></g>");
            }

            if if_will_minted { // Minted token hides this strand.
            } else {
                defs.append(@"<g id='will-src' filter='url(#lightUp)'><path id='path_will' d='");
                defs.append(@will_path);
                defs.append(@"' stroke='rgb(255,0,0)' stroke-width='");
                defs.append(@self._u32_to_string(stroke_w));
                defs.append(@"' fill='none' stroke-linecap='round' stroke-linejoin='round' /></g>");
            }

            if if_awa_minted { // Minted token hides this strand.
            } else {
                defs.append(@"<g id='awa-src' filter='url(#lightUp)'><path id='path_awa' d='");
                defs.append(@awa_path);
                defs.append(@"' stroke='rgb(0,255,0)' stroke-width='");
                defs.append(@self._u32_to_string(stroke_w));
                defs.append(@"' fill='none' stroke-linecap='round' stroke-linejoin='round' /></g>");
            }

            defs.append(
                @"<filter id='lightUp' filterUnits='userSpaceOnUse' x='-100%' y='-100%' width='200%' height='200%' color-interpolation-filters='sRGB'>",
            );
            defs.append(@"<feGaussianBlur in='SourceGraphic' stdDeviation='");
            defs.append(@self._u32_to_string(sigma));
            defs.append(@"' result='blur'></feGaussianBlur>");
            defs.append(@"<feMerge><feMergeNode in='blur'/><feMergeNode in='blur'/><feMergeNode in='SourceGraphic'/></feMerge></filter>");

            let mut uses: ByteArray = Default::default();
            if if_thought_minted { // Minted token hides this strand.
            } else {
                uses.append(@"<use href='#thought-src' style='mix-blend-mode:lighten;'/>");
            }
            if if_will_minted { // Minted token hides this strand.
            } else {
                uses.append(@"<use href='#will-src' style='mix-blend-mode:lighten;'/>");
            }
            if if_awa_minted { // Minted token hides this strand.
            } else {
                uses.append(@"<use href='#awa-src' style='mix-blend-mode:lighten;'/>");
            }

            let mut svg: ByteArray = Default::default();
            svg.append(@"<svg width='");
            svg.append(@self._u32_to_string(WIDTH));
            svg.append(@"' height='");
            svg.append(@self._u32_to_string(HEIGHT));
            svg.append(@"' viewBox='0 0 ");
            svg.append(@self._u32_to_string(WIDTH));
            svg.append(@" ");
            svg.append(@self._u32_to_string(HEIGHT));
            svg.append(@"' xmlns='http://www.w3.org/2000/svg' style='background:#000; isolation:isolate'>");
            svg.append(@"<defs>");
            svg.append(@defs);
            svg.append(@"</defs>");
            svg.append(@"<rect width='1024' height='1024' fill='#000'/>");
            svg.append(@"<g>");
            svg.append(@uses);
            svg.append(@"</g></svg>");

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
            let encoded = self._percent_encode(@svg);
            let mut data_uri: ByteArray = Default::default();
            data_uri.append(@"data:image/svg+xml;charset=UTF-8,");
            data_uri.append(@encoded);
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
            let data_uri = self
                .generate_svg_data_uri(token_id, if_thought_minted, if_will_minted, if_awa_minted);

            metadata.append(@"{\"name\":\"PATH #");
            metadata.append(@token_id_str);
            metadata
                .append(@"\",\"description\":\"PATH NFT with dynamic on-chain SVG\",\"image\":\"");
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

        fn _curve_d(self: @ContractState, steps: @Array<Step>, sharpness: u32) -> ByteArray {
            let addr = self.step_curve_address.read();
            let mut nodes: Array<Point> = array![];
            let mut i: usize = 0_usize;
            while i < steps.len() {
                let s = *steps.at(i);
                nodes.append(Point { x: s.x, y: s.y });
                i = i + 1_usize;
            }
            let dispatcher = IStepCurveDispatcher { contract_address: addr };
            dispatcher.d_from_nodes(nodes.span(), sharpness)
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

        fn _strip_newlines(self: @ContractState, svg: @ByteArray) -> ByteArray {
            let mut out: ByteArray = Default::default();
            let mut i: usize = 0_usize;
            let len = svg.len();
            while i < len {
                let b = svg.at(i).unwrap();
                if b == 10_u8 || b == 13_u8 {
                    out.append_byte(32_u8);
                } else {
                    out.append_byte(b);
                }
                i = i + 1_usize;
            }
            out
        }

        fn _is_unreserved(self: @ContractState, b: u8) -> bool {
            (b >= 48_u8 && b <= 57_u8) // 0-9
                || (b >= 65_u8 && b <= 90_u8) // A-Z
                || (b >= 97_u8 && b <= 122_u8) // a-z
                || b == 45_u8 // -
                || b == 46_u8 // .
                || b == 95_u8 // _
                || b == 126_u8 // ~
        }

        fn _hex_nibble(self: @ContractState, n: u8) -> u8 {
            if n < 10_u8 {
                48_u8 + n
            } else {
                55_u8 + n
            }
        }

        fn _append_pct_encoded(self: @ContractState, ref out: ByteArray, b: u8) {
            out.append(@"%");
            let hi = b / 16_u8;
            let lo = b % 16_u8;
            out.append_byte(self._hex_nibble(hi));
            out.append_byte(self._hex_nibble(lo));
        }

        fn _percent_encode(self: @ContractState, svg: @ByteArray) -> ByteArray {
            let mut out: ByteArray = Default::default();
            let mut i: usize = 0_usize;
            let len = svg.len();
            while i < len {
                let b = svg.at(i).unwrap();
                if self._is_unreserved(b) {
                    out.append_byte(b);
                } else {
                    self._append_pct_encoded(ref out, b);
                }
                i = i + 1_usize;
            }
            out
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
pub trait IPathLook<TContractState> {
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
