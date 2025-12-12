
# StepCurve – Phase A Refactor Spec (inside `path-look` repo)

## Goal

Refactor the existing `path-look` repository so that:

1. The **Bezier path drawing logic** is moved into a small, *abstract* contract called **`StepCurve`**.
2. The **PATH‑specific** contract **`PathLook`** becomes a *domain* compositor that:
   - uses `pprf` for randomness, and
   - calls `StepCurve` to render the strands for THOUGHT / WILL / AWA.
3. Both contracts live in the **same repo** and work together on devnet / sepolia.
4. No repo split yet – that is **Phase B** (creating a dedicated `step-curve` repo).

This spec only covers **Phase A**.

---

## 1. Current State (before Phase A)

In `PathLook` (single contract):

- Storage:
  - `pprf_address: ContractAddress`
- Public ABI (`IPathLook`):
  - `generate_svg(token_id, if_thought_minted, if_will_minted, if_awa_minted) -> ByteArray`
  - `generate_svg_data_uri(...) -> ByteArray`
  - `get_token_metadata(...) -> ByteArray`
- Internal logic:
  - `_random_range` calling `rng::pseudo_random_range(pprf_address, ...)`
  - `_find_targets` – picks interior “target” points inside the canvas
  - `_find_steps` – perturbs each target to build one strand’s ordered nodes
  - `_to_cubic_bezier` – converts ordered `Step[]` into a `d="M… C… C…"` path string
  - hard‑coded:
    - canvas size: `WIDTH = 1024`, `HEIGHT = 1024`
    - colors: THOUGHT (blue), WILL (red), AWA (green)
    - blur strength: `sigma = 30` if no strand minted, else `3`
- `generate_svg` builds the **entire** SVG:
  - `<svg …>`
  - `<defs>` with `<filter id="lightUp">`
  - `<g id="thought-src">…<path d="..."/>…</g>` etc.
  - `<use href="#thought-src" …>` etc.

Everything (geometry, randomness, PATH domain, SVG composition) is bundled in one contract.

---

## 2. Target Architecture (Phase A)

After Phase A, in the same repo:

- **Contract 1 – `StepCurve`** (abstract glyph)
  - Minimal contract responsible only for:
    - taking:
      - canvas size,
      - stroke style,
      - ordered nodes (start…end),
      - sharpness,
    - returning:
      - a **`<path …>` SVG fragment** as raw text.
  - No randomness, no PATH logic, no pprf, no THOUGHT/WILL/AWA.

- **Contract 2 – `PathLook`** (new domain contract)
  - Still implements the existing `IPathLook` ABI.
  - Still uses `pprf` and the RNG helpers for:
    - `step_number`, padding, targets, dx/dy, etc.
  - But no longer constructs cubic paths itself:
    - instead, it calls the **`StepCurve` contract** with ordered nodes and style.
  - Composes:
    - `<defs>` + filter,
    - `<g id="thought-src">` / `will-src` / `awa-src`,
    - `<use>` elements,
    - background `<rect>`,
    - and metadata JSON.

Once this works, Phase B will move `StepCurve` into its own repo and wire addresses on sepolia.

---

## 3. New Abstract Contract: `StepCurve`

### 3.1 File and Module

- New file: `contracts/src/step_curve.cairo`
- New contract:

  ```cairo
  #[starknet::contract]
  mod StepCurve {
      use core::array::ArrayTrait;
      use core::byte_array::ByteArrayTrait;

      #[derive(Copy, Drop)]
      struct Step {
          x: i128,
          y: i128,
      }

      #[storage]
      struct Storage {
          // No storage – StepCurve is stateless in Phase A.
      }

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
              nodes: Span<felt252>, // [x0, y0, x1, y1, ..., xN-1, yN-1] as i128 in felts
          ) -> ByteArray {
              // 1. Decode `nodes` into Array<Step>.
              // 2. Run cubic Bezier logic to build the `d="M … C …"` string.
              // 3. Build a `<path>` element string:
              //    <path d="..." stroke="rgb(r,g,b)" stroke-width="..." fill="none"
              //           stroke-linecap="round" stroke-linejoin="round" />
              // 4. Return that full <path ...> as ByteArray.
          }
      }

      #[starknet::interface]
      trait IStepCurve<TContractState> {
          fn render_path(
              self: @TContractState,
              width: u32,
              height: u32,
              stroke_r: u32,
              stroke_g: u32,
              stroke_b: u32,
              stroke_width: u32,
              sharpness: u32,
              nodes: Span<felt252>,
          ) -> ByteArray;
      }
  }
  ```

> **Note:** In Phase A we keep a *simple, direct ABI* returning `ByteArray`.  
> We do **not** require `IGlyph` yet; that can be added in Phase B when
> we move StepCurve into its own GLYPH repo.

### 3.2 Implementation Details

- **Decoding `nodes`**
  - `nodes` is a flat list of felts:
    - `nodes = [x0, y0, x1, y1, x2, y2, ...]`
  - Each felt is interpreted as `i128`:
    - `let xi: i128 = nodes[i].into();`
    - `let yi: i128 = nodes[i+1].into();`
  - Construct `Array<Step>` in order.

- **Bezier logic**
  - Move the existing helpers from `PathLook` into `StepCurve`:
    - `_to_cubic_bezier(steps: @Array<Step>, sharpness: u32) -> ByteArray`
    - `_div_round(value: i128, denominator: u32) -> i128`
    - `_clamp_i128(value: i128, min: i128, max: i128) -> i128`
    - `_u128_to_string`, `_i128_to_string`, `_u32_to_string`
  - `_to_cubic_bezier` should:
    - Generate `d="M x0 y0
 C cp1x cp1y, cp2x cp2y, x2 y2
 …"` exactly as in the current contract.

- **Path element construction**
  - After computing the `d` string, wrap it:

    ```xml
    <path d="...computed D..."
          stroke="rgb(stroke_r,stroke_g,stroke_b)"
          stroke-width="stroke_width"
          fill="none"
          stroke-linecap="round"
          stroke-linejoin="round" />
    ```

  - Build this as `ByteArray` using `ByteArrayTrait::append` and the string helpers.

- **No randomness**
  - StepCurve must not call `pprf` or any RNG.
  - StepCurve simply draws the path it is instructed to draw.

---

## 4. Changes to `PathLook` Contract (Domain Layer)

All changes in `contracts/src/path_look.cairo` (or wherever `PathLook` lives today).

### 4.1 Storage

Extend storage to include a reference to StepCurve:

```cairo
#[storage]
struct Storage {
    pprf_address: ContractAddress,
    step_curve_address: ContractAddress,
}
```

### 4.2 Constructor

Extend the constructor to accept the StepCurve address:

```cairo
#[constructor]
fn constructor(
    ref self: ContractState,
    pprf_address: ContractAddress,
    step_curve_address: ContractAddress,
) {
    self.pprf_address.write(pprf_address);
    self.step_curve_address.write(step_curve_address);
}
```

> **Note:** This is a breaking change for existing deployments and scripts.
> For Phase A, it is acceptable to redeploy on devnet. For sepolia, update
> deployment scripts accordingly.

### 4.3 New Internal Helper: `_render_step_curve`

Add a helper in `InternalImpl` to delegate drawing to StepCurve:

```cairo
use step_curve::StepCurve::IStepCurveDispatcher; // or correct import path

impl InternalImpl of InternalTrait {
    fn _render_step_curve(
        self: @ContractState,
        steps: @Array<Step>,
        width: u32,
        height: u32,
        stroke_r: u32,
        stroke_g: u32,
        stroke_b: u32,
        stroke_width: u32,
        sharpness: u32,
    ) -> ByteArray {
        let addr = self.step_curve_address.read();

        let mut nodes = Array::<felt252>::new();
        let mut i: usize = 0_usize;
        while i < steps.len() {
            let s = *steps.at(i);
            nodes.append(s.x.into());
            nodes.append(s.y.into());
            i = i + 1_usize;
        }
        let span = nodes.span();

        let dispatcher = IStepCurveDispatcher { contract_address: addr };
        let path_bytes = dispatcher.render_path(
            width,
            height,
            stroke_r,
            stroke_g,
            stroke_b,
            stroke_width,
            sharpness,
            span,
        );

        path_bytes
    }
}
```

This helper encapsulates the cross‑contract call and returns **a complete `<path …>` fragment** as `ByteArray`.

### 4.4 Replace Direct Bezier Construction in `generate_svg`

Currently, `generate_svg` does:

```cairo
let thought_steps = self._find_steps(...LABEL_THOUGHT_DX, LABEL_THOUGHT_DY);
let thought_path = self._to_cubic_bezier(@thought_steps, sharpness);

// and then builds <path id="path_thought" d="...thought_path...">
```

Change this to use `_render_step_curve` for each strand:

```cairo
let thought_steps = self
    ._find_steps(token_id, @targets, WIDTH, HEIGHT, LABEL_THOUGHT_DX, LABEL_THOUGHT_DY);
let thought_svg_path = self._render_step_curve(
    @thought_steps,
    WIDTH,
    HEIGHT,
    0_u32,   // stroke_r   (blue)
    0_u32,   // stroke_g
    255_u32, // stroke_b
    stroke_w,
    sharpness,
);

let will_steps = self
    ._find_steps(token_id, @targets, WIDTH, HEIGHT, LABEL_WILL_DX, LABEL_WILL_DY);
let will_svg_path = self._render_step_curve(
    @will_steps,
    WIDTH,
    HEIGHT,
    255_u32, // red
    0_u32,
    0_u32,
    stroke_w,
    sharpness,
);

let awa_steps = self
    ._find_steps(token_id, @targets, WIDTH, HEIGHT, LABEL_AWA_DX, LABEL_AWA_DY);
let awa_svg_path = self._render_step_curve(
    @awa_steps,
    WIDTH,
    HEIGHT,
    0_u32,
    255_u32, // green
    0_u32,
    stroke_w,
    sharpness,
);
```

Then, in the `<defs>` assembly, instead of building `<path>` manually, insert the fragments:

```cairo
if if_thought_minted {
    // Minted token hides this strand (unchanged).
} else {
    defs.append(@"<g id="thought-src"
");
    defs.append(@"filter="url(#lightUp)">
");
    defs.append(@thought_svg_path); // the full <path .../> from StepCurve
    defs.append(@"
</g>
");
}

if if_will_minted {
} else {
    defs.append(@"<g id="will-src"
");
    defs.append(@"filter="url(#lightUp)">
");
    defs.append(@will_svg_path);
    defs.append(@"
</g>
");
}

if if_awa_minted {
} else {
    defs.append(@"<g id="awa-src"
");
    defs.append(@"filter="url(#lightUp)">
");
    defs.append(@awa_svg_path);
    defs.append(@"
</g>
");
}
```

The rest of `generate_svg` (filter definition, `<rect>`, `<use>` nodes, background, metadata) remains unchanged.

### 4.5 Optional Cleanup

Once StepCurve is in place and used:

- `_to_cubic_bezier`, `_div_round` and related helpers may no longer be needed inside `PathLook`.
- You can:
  - either keep them temporarily,
  - or move them entirely into `StepCurve` and delete the copies from `PathLook`.

For Phase A, cleanup is optional; main requirement is that **PathLook no longer builds the path curve itself**.

---

## 5. Testing Plan (Phase A)

1. **Unit sanity on StepCurve**
   - Deploy `StepCurve` to local devnet.
   - Call `render_path` with:
     - `width = 1024`, `height = 1024`
     - `(stroke_r, stroke_g, stroke_b) = (0, 0, 255)`
     - `stroke_width = 4`
     - `sharpness = 3`
     - `nodes = [0, 512, 512, 128, 1024, 512]`
   - Confirm the returned `ByteArray`:
     - is valid UTF‑8,
     - contains a `<path d="M 0 512 ..."/>` with expected attributes.

2. **Integration test with `PathLook`**
   - Deploy `StepCurve` and record its address.
   - Deploy `PathLook` with:
     - `pprf_address` = address of pprf glyph on devnet (or a stub for tests),
     - `step_curve_address` = address of StepCurve.
   - Call `generate_svg(token_id, false, false, false)` for a few token ids.
   - Verify:
     - The SVG structure is still:
       - `<svg>`, `<defs>`, `<filter id="lightUp">`, `<g id="thought-src">`, `<use href="#thought-src">`, etc.
     - Paths inside `thought-src`, `will-src`, `awa-src` are generated by StepCurve:
       - The `<path>` fragments should match what you’d expect from StepCurve alone.

3. **Metadata checks**
   - Ensure `get_token_metadata(...)` still returns valid JSON with:
     - `"name": "PATH #<id>"`
     - `"image": "data:image/svg+xml;charset=UTF-8,..."` matching `generate_svg_data_uri`.

---

## 6. Phase B (Out of Scope Here, but for Awareness)

Phase B (separate spec) will:

- Move `StepCurve` into its own repo (`inshell-art/step-curve`).
- Possibly adapt it to the GLYPH `IGlyph` interface (`render(params) -> Array<felt252>`).
- Deploy `StepCurve` to sepolia as a standalone glyph.
- Register it in `glyph-registry/glyphs.yml`.
- Update `PathLook` to use the sepolia `StepCurve` address in production.

Phase A only needs:

- StepCurve contract written and working **inside** `path-look`.
- PathLook successfully delegating curve drawing to StepCurve.
