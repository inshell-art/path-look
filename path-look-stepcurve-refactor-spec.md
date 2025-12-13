# Path Look · StepCurve refactor spec (Phase A continuation)

Inshell — this spec turns **StepCurve** into a *pure path-data converter*:

> **nodes + tension → SVG `d` string**

…and keeps **PathLook** as the *domained* composer that wraps the returned `d` into `<path …/>`, `<svg …>`, filters, colors, and series logic (THOUGHT / WILL / AWA).

---

## 1) Registry “kind” for StepCurve

**Recommended `kind`: `svg`**

- StepCurve’s output is *SVG path-data* (the `d` attribute string).  
- Making a new kind like `d` is **too granular** and will fragment the registry taxonomy.
- If you want more specificity, keep `kind: svg` and add **one extra descriptor** in metadata / YAML, e.g.:
  - `output: path_d` (or `format: path_d`)
  - `element: path` (or `shape: path`)

Example stanza fields you can evolve toward:

```yml
- name: step_curve
  kind: svg
  output: path_d
  repo: https://github.com/inshell-art/path-look
  networks:
    sepolia: 0x...
```

---

## 2) What StepCurve should return

### What you want
StepCurve should return **only the `d` string**, like:

```
M -50 512
C  10 400, 100 700, 200 520
C  ...
```

### What it should NOT return
- NOT the full `<svg>` wrapper
- NOT a full `<path …/>` element (no stroke/color/filter/background)
- NOT `<g>` groups, filters, `<defs>`, `<rect>`, etc.

**Reason:** returning *just `d`* is the cleanest composable unit.  
Callers can wrap it however they want (their own stroke, filter, blend mode, etc).

---

## 3) StepCurve contract API (new)

### New concept naming
- **`tension`** is the generic knob (public / reusable).
- **`sharpness`** can stay as PathLook’s *domain word*, but it maps 1:1 to `tension` (or can map non-linearly later).

### Suggested interface

Create/keep `contracts/src/step_curve.cairo` as a standalone contract with:

- a shared `Point`/`Step` struct
- a public function that accepts nodes and returns `d`

```cairo
#[derive(Copy, Drop, Serde)]
struct Point {
    x: i128,
    y: i128,
}

#[starknet::interface]
trait IStepCurve<TContractState> {
    /// Convert ordered nodes into SVG path-data.
    /// `tension` controls handle distance (higher = sharper).
    fn d_from_nodes(
        self: @TContractState,
        nodes: Span<Point>,
        tension: u32,
    ) -> ByteArray;
}
```

Notes:
- `Span<Point>` is the cleanest “nodes” input for contract calls.
- Keep `i128` to preserve negative coords (your `-50` start point).  
  If you later want easier frontend encoding, you can add a second function that takes `Span<felt252>` flattened pairs.

### Implementation requirements

Inside `StepCurve`:
- implement `d_from_nodes` using the *existing* Catmull-Rom-ish / cardinal conversion you already have in PathLook today:

For segment `p1 → p2`, with neighbor points `p0, p3`:

```
cp1 = p1 + (p2 - p0) / tension
cp2 = p2 - (p3 - p1) / tension
```

- If `tension == 0`, clamp to `1` (or default to `3`) to avoid division-by-zero.
- Output format: newline-friendly, but must be valid inside an attribute.  
  (Newlines are fine; browsers accept them, and it stays readable.)

---

## 4) PathLook changes (compose `<path>` yourself)

### Current situation (what you have)
PathLook builds:
- nodes (targets + jitter steps)
- cubic Bézier control points
- the full `d` (via `_to_cubic_bezier`)
- then wraps `d` into `<path …>`

### Required change
PathLook should:
1. build nodes
2. decide **domain sharpness**
3. call StepCurve with `nodes + tension`
4. receive **`d`**
5. wrap it into `<path …/>` with PathLook’s styling

### Contract wiring pattern

PathLook storage already (or should) contain `step_curve_address`.

```cairo
#[storage]
struct Storage {
    pprf_address: ContractAddress,
    step_curve_address: ContractAddress,
}
```

Use a dispatcher (pattern example):

```cairo
use step_curve::IStepCurveDispatcher;
use step_curve::IStepCurveDispatcherTrait;

fn _curve_d(self: @ContractState, nodes: @Array<Step>, sharpness: u32) -> ByteArray {
    let addr = self.step_curve_address.read();
    let dispatcher = IStepCurveDispatcher { contract_address: addr };
    // Convert Array -> Span if needed
    dispatcher.d_from_nodes(nodes.span(), sharpness)
}
```

### Composition example inside PathLook

Replace:

```cairo
let thought_path = self._to_cubic_bezier(@thought_steps, sharpness);
```

with:

```cairo
let thought_d = self._curve_d(@thought_steps, sharpness);
```

Then:

```cairo
defs.append(@"<path id="path_thought" d="");
defs.append(@thought_d);
defs.append(@""/>
");
```

(Do **not** move stroke/filter rules into StepCurve — keep them in PathLook.)

---

## 5) Keep “domain PathLook” domained

These should stay in **PathLook** (domain contract):
- series gating logic: hide strand when minted
- RGB assignment for THOUGHT / WILL / AWA
- stroke width decisions (`stroke_w = max(1, round_div(100, step_number))`)
- filter decisions (`sigma = 30 or 3`)
- canvas size (`WIDTH/HEIGHT`) and background `<rect>`
- RNG and `pprf_address` usage
- metadata JSON + external_url

These should live in **StepCurve** (pure converter):
- `nodes + tension → d` conversion

---

## 6) README updates (path-look repo)

Update README to reflect the new split:

- StepCurve is **path-data generator** (returns `d`)
- PathLook is **SVG composer** (wraps `d` into `<path>`, then `<svg>`)

Add a short example snippet in README:

```xml
<svg viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <path d="M … C …" stroke="white" fill="none"/>
</svg>
```

---

## 7) Backwards compatibility

If you already deployed StepCurve / PathLook class hashes:
- This is a breaking change at ABI level (StepCurve output changes, PathLook call path changes).
- Treat it as a **new class hash** deployment.

---

## 8) Acceptance checklist

- [ ] `scarb build` succeeds
- [ ] PathLook still returns a valid full SVG string
- [ ] StepCurve can be called standalone and its output works when wrapped into `<path d="…"/>`
- [ ] No styling (stroke/filter) lives inside StepCurve
- [ ] PathLook still deterministic given (token_id, minted flags) and the configured `pprf_address`

---

## 9) Quick decisions summary

- StepCurve **kind**: `svg`
- StepCurve **output**: `path_d`
- StepCurve role: *pure converter*
- PathLook role: *domain composer*

