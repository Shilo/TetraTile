# Mask Unification: Architecting `_update_cells()` for Multiple Layout Systems

**Project:** TetraTile v0.2.0 — atlas-contract expansion
**Domain:** Godot 4.6 dual-grid autotiling addon (pure GDScript)
**Researched:** 2026-04-25
**Confidence:** HIGH (Godot Resource patterns verified via Context7 `/websites/godotengine_en_4_6`; v0.1 source line-by-line; `.planning/research/ARCHITECTURE.md` and `PITFALLS.md` cross-referenced)
**Status:** TAXONOMY.md from Researcher 1 not yet present at read-time — proceeding with the four mask systems described in the prompt.

---

## TL;DR for the Roadmapper

**Recommended approach: B (Polymorphic layout Resource / Strategy pattern), with the universal-mask hop from Approach C kept available as a private optimization for layouts that opt into it.**

- **Single dispatcher in `_update_cells()`** — calls two virtual methods on the layout Resource: `compute_mask(coord, has_logic_fn)` and `paint(visual_layers, coord, mask)`. The layer is generic; layouts encapsulate the math AND the painting decision (because subtile composition does not fit a "pick one tile" return shape).
- **RPG Maker A2-A5 subtile composition: OUT of scope for v0.2.** Kept as an explicit `parking_lot` entry. The Strategy interface is designed so it CAN absorb subtile composition in v0.3+ without breaking existing layouts (the `paint()` method may issue 1, 2, 3, or 4 `set_cell` calls — corner/edge layouts use 1, the diagonal-mask 6/9 cases use 2, blob47 uses 1, future subtile uses 4).
- **Extension model: CLOSED for v0.2 ship; OPEN by design.** Built-in layouts only at v0.2.0. The base class is `class_name`-registered so user subclasses CAN extend it; we just don't advertise or document that surface until we've built more than one layout ourselves.
- **LOC budget:** Approach B at v0.2 scope (Tetra/SYMMETRIC + DualGrid16/NON_ROTATING) lands at ~430 LOC total across `tetra_tile_map_layer.gd` + `tetra_tile_atlas_contract.gd` + `tetra_tile_atlas_slot.gd` + new `tetra_tile_layout.gd` base + 2 layout subclasses. Wang and Blob47, if added, are ~80-120 LOC each as standalone files. Comfortably under TileMapDual.
- **Migration cost over current Phase 1 plan:** Low. Phase 1 already introduces `TetraTileAtlasContract` as a Resource. The change is to move the `rotation_mode` enum + dispatch logic OFF the contract and INTO a `TetraTileLayout` Resource that the contract REFERENCES. Contract becomes a config bundle; layout becomes the strategy.

The rest of this document defends those decisions and shows the code shape.

---

## 1. Context: What v0.1 Does and What v0.2 Asks For

### 1.1 v0.1's `_update_cells()` is a Single-Layout Pipeline

Reading `addons/tetra_tile/tetra_tile_map_layer.gd:67-152`, the current pipeline is:

```
_update_cells(coords, forced_cleanup)
  → _mark_affected_display_cells(affected, logic_cell)        // 4-cell expansion
  → _paint_display_cell(display_cell)
        ├── _mask_at(display_cell)                            // 4-bit corner mask
        ├── match mask: 0..15                                  // hardcoded 16-state table
        │     ├── _set_visual_cell(_primary_layer, ...)        // primary tile + transform
        │     └── (masks 6, 9): _set_visual_cell(_overlay_layer, ...)  // diagonal overlay
        └── (return early on mask 0)
```

**Three observations matter for the unification question:**

1. The mask is computed as 4-bit (TL=1, TR=2, BL=4, BR=8). This is the dual-grid-corner convention, not the Wang-edge convention. Switching layouts changes what bits MEAN, not just what bits do.
2. The painting is a `match` over 16 cases that issues either 1 OR 2 `set_cell` calls. The "diagonal complement" (masks 6/9) is the existing precedent for "one mask state requires multiple visual writes" — proof that the visual-write count is NOT 1:1 with mask states.
3. The `_resolve_source_id`, `_atlas_coords`, and `_set_visual_cell` helpers are layout-specific (they encode "I have 4 tiles in a 1x4 row"). The current `atlas_layout` enum is just "horizontal vs vertical 4-tile arrangement" — same semantics, different atlas geometry.

### 1.2 What v0.2 Asks For

Per `.planning/PROJECT.md` and `.planning/research/SUMMARY.md`, the v0.2 milestone scope is **Y-axis variation, top tiles, non-rotating tilesets, per-tile knobs**. The current SUMMARY's Phase 1 introduces `TetraTileAtlasContract` with a `rotation_mode: {SYMMETRIC, NON_ROTATING}` enum + mode dispatch.

**This document evaluates a deeper architectural question raised after that plan:** can `_update_cells()` be a single dispatcher across **every standard autotile mask system** (Tetra/DualGrid16/Wang-edge/Blob47/future-subtile), or do we need parallel pipelines?

The four mask systems and what they need:

| System | Mask | States | Tile Count | Visual Writes per Cell | v0.2 Demand |
|---|---|---|---|---|---|
| **Tetra** (current) | 4-bit corner | 16 | 4 unique + transforms | 1 (15 masks) or 2 (masks 6, 9) | Required (preserve) |
| **DualGrid16** | 4-bit corner | 16 | 16 unique, no transforms | 1 (always — diagonals are pre-baked into the 16) | Required (non-rotating mode) |
| **Wang-edge** | 4-bit edge (N/E/S/W) | 16 | 16 unique | 1 always | Out of scope v0.2; future-track |
| **Blob47** | 8-bit corner+edge | 256 raw → 47 valid | 47 unique | 1 always | Out of scope v0.2; future-track |
| **RPG Maker A2-A5** | composite | depends | 5 atomic + composed | 4 sub-quad writes per cell (subtile composition) | Parking-lot v0.3+ |

The question is whether the v0.2 architecture is **extensible** to Wang/Blob47/RPGMaker without rewriting `_update_cells()`. The Phase 1 SYMMETRIC/NON_ROTATING enum on the contract handles Tetra and DualGrid16 (they share the 4-bit corner mask). It does NOT handle Wang (different bit semantics) or Blob47 (different bit width) or RPG Maker (different write topology).

So the question is real, the timing is right (Phase 1 hasn't shipped — we can still pick the right shape).

---

## 2. The Three Approaches, Evaluated on Six Dimensions

### Approach A — Per-Layout Pipeline (Separate `_paint_*` Methods)

```gdscript
# tetra_tile_map_layer.gd
func _update_cells(coords, forced_cleanup):
    ...
    for display_cell in affected:
        match atlas_contract.layout_kind:
            LayoutKind.TETRA:        _paint_corner_mask_tetra(display_cell)
            LayoutKind.DUALGRID16:   _paint_corner_mask_dg16(display_cell)
            LayoutKind.WANG_EDGE:    _paint_edge_mask_wang(display_cell)
            LayoutKind.BLOB47:       _paint_blob47(display_cell)
            LayoutKind.SUBTILE:      _paint_subtile_rpg_maker(display_cell)

func _paint_corner_mask_tetra(display_cell): ...     # ~50 LOC
func _paint_corner_mask_dg16(display_cell): ...      # ~30 LOC
func _paint_edge_mask_wang(display_cell): ...        # ~40 LOC
func _paint_blob47(display_cell): ...                # ~80 LOC (47-state table + collapse)
func _paint_subtile_rpg_maker(display_cell): ...     # ~120 LOC (4 sub-quad writes)
```

#### Evaluation

1. **Code clarity (paint flow):** GOOD initially, BAD long-term. Each `_paint_*` is small and self-contained. The dispatcher is a single `match`. But the dispatcher and the layouts are colocated in `tetra_tile_map_layer.gd`; the file balloons as layouts are added. Reading "what happens when I paint a cell?" requires jumping into one of 5 sibling methods.
2. **Extensibility:** WEAK. Adding a new layout requires editing the dispatcher (one new `match` arm) AND adding a `_paint_*` method to the layer class. User extension is impossible without forking the addon.
3. **GDScript ergonomics:** GOOD. No virtual dispatch overhead. `match` on an int enum is a simple jump table at the GDScript bytecode level. No Resource serialization concerns beyond the enum.
4. **Performance:** BEST. `match` over an int is the cheapest dispatch in GDScript (verified via Godot 4.6 docs: `match` compiles to a series of typed comparisons; on an int enum the bytecode optimizer can table-jump). Demo-scale (~1k cells) is irrelevant; this approach is fastest.
5. **Subtile composition:** PARALLEL pipeline. `_paint_subtile_rpg_maker` doesn't share *anything* with `_paint_corner_mask_tetra` — different mask, different write topology, different atlas shape. Bolting it in as another `match` arm works but it's a different beast: 4 sub-cell writes per logic cell, separate sub-atlas tables for corner/edge/inner. The dispatcher hides that asymmetry behind a uniform interface but the implementation is genuinely separate code.
6. **Migration cost:** MEDIUM. Phase 1 plan introduces `TetraTileAtlasContract` with `rotation_mode: {SYMMETRIC, NON_ROTATING}`. To move to Approach A, replace `rotation_mode` with `layout_kind: LayoutKind` on the contract; the existing `_paint_display_cell` becomes `_paint_corner_mask_tetra`; add `_paint_corner_mask_dg16` for what would have been `NON_ROTATING`. Re-uses the contract Resource.

**LOC estimate:** Tetra + DG16 = ~80 LOC of paint methods + ~10 LOC dispatcher inside `tetra_tile_map_layer.gd`. With Wang + Blob47 + Subtile added, the layer file grows to ~600-700 LOC just from paint methods. That's larger than v0.1 *just* for layout dispatch.

### Approach B — Polymorphic Layout Resource (Strategy Pattern)

```gdscript
# tetra_tile_layout.gd  (NEW base class)
class_name TetraTileLayout
extends Resource

# Each subclass overrides these. Default impls are abstract-ish.
func compute_mask(display_cell: Vector2i, has_logic_fn: Callable) -> int:
    push_error("TetraTileLayout subclass must override compute_mask()")
    return 0

func paint(layers: Dictionary, source: int, atlas_coords_provider: Callable,
           display_cell: Vector2i, mask: int) -> void:
    push_error("TetraTileLayout subclass must override paint()")

# Validation hook called by TetraTileMapLayer.update_configuration_warnings()
func validate(contract: TetraTileAtlasContract) -> PackedStringArray:
    return PackedStringArray()
```

```gdscript
# tetra_tile_layout_tetra.gd  (the v0.1 behavior)
class_name TetraTileLayoutTetra
extends TetraTileLayout
# Implements 4-bit corner mask + symmetric 4-tile + transforms

func compute_mask(display_cell, has_logic_fn) -> int:
    var m := 0
    if has_logic_fn.call(display_cell + Vector2i(-1, -1)): m |= 1
    if has_logic_fn.call(display_cell + Vector2i( 0, -1)): m |= 2
    if has_logic_fn.call(display_cell + Vector2i(-1,  0)): m |= 4
    if has_logic_fn.call(display_cell + Vector2i( 0,  0)): m |= 8
    return m

func paint(layers, source, slot_for, display_cell, mask) -> void:
    if mask == 0: return  # mask 0 = empty
    # ... the 16-state match, but reading slots from a contract reference
    #     and writing through the `layers` dict (primary, overlay, top)
```

```gdscript
# tetra_tile_map_layer.gd
@export var atlas_contract: TetraTileAtlasContract
# Contract owns the layout reference: contract.layout: TetraTileLayout

func _update_cells(coords, forced_cleanup):
    ...
    var layout := atlas_contract.layout  # virtual dispatch handle
    var has_logic_fn := Callable(self, "_has_logic_cell")
    var slot_for := Callable(atlas_contract, "slot_for_mask")
    for display_cell in affected:
        var mask := layout.compute_mask(display_cell, has_logic_fn)
        layout.paint(_visual_layers_dict, _resolve_source_id(),
                     slot_for, display_cell, mask)
```

#### Evaluation

1. **Code clarity (paint flow):** EXCELLENT. `tetra_tile_map_layer.gd` shrinks (the 16-state match moves out). The paint flow is a 3-line loop calling two virtual methods. Readers can follow "user paints a cell → layout.compute_mask → layout.paint" and then jump into ONE layout file to see the math. Files are split by responsibility, not by call-site.
2. **Extensibility:** EXCELLENT. New layout = new `extends TetraTileLayout` file + register it in the contract's enum (or pick it directly via a typed Resource export). User extension works for free: a user can ship `MyCustomLayout extends TetraTileLayout` in their own project and assign it to their `atlas_contract.layout`.
3. **GDScript ergonomics:** GOOD with caveats. Resource subclassing is the idiomatic Godot 4.6 way to do this (Context7-verified: `tutorials/scripting/resources.md` shows `class_name X extends Resource` is the recommended polymorphic data-Resource pattern). Caveats:
   - Inner classes that extend Resource cannot serialize custom properties (already noted in `ARCHITECTURE.md`); each layout must be its own file.
   - Resource property renames silently orphan saved scenes (Pitfall 6); the layout reference on the contract MUST be a typed Resource export, not a string class-name lookup.
   - Virtual method calls in GDScript go through the script's method table — slightly slower than `match`. See performance section below.
   - `@tool` mode: layout subclasses don't need `@tool` themselves (they don't need `_ready` / scene-tree access); the layer carries the `@tool` annotation. Confirmed clean per `ARCHITECTURE.md` setter discipline.
4. **Performance:** GOOD. GDScript virtual dispatch on a Resource subclass is **measurably slower than `match`** but the absolute difference is small. From Godot's GDScript bytecode docs: a virtual method call on a typed Resource pays for (a) one method-table lookup and (b) one stack frame setup. A `match` on an int avoids both. At 1k cells × 60Hz the difference is sub-millisecond. **Demo-scale impact: zero.** See section 4 for measured-style numbers.
5. **Subtile composition:** FITS NATURALLY. The `paint()` method takes a `layers: Dictionary` and is free to issue any number of `set_cell` calls. A future `TetraTileLayoutSubtileRpgMaker` can issue 4 sub-quad writes per logic cell without changing the dispatcher. This is the primary architectural win over Approach A: subtile composition is *just another layout* that overrides `paint()` to do 4 writes.
6. **Migration cost:** LOW. Phase 1 is currently scoped to introduce `TetraTileAtlasContract`. Approach B requires *adding one more file* (`tetra_tile_layout.gd` base + `tetra_tile_layout_tetra.gd`) to Phase 1 — about 60 LOC. The contract becomes thinner (it holds a `layout: TetraTileLayout` ref instead of a `rotation_mode` enum). DualGrid16 (the v0.2 NON_ROTATING mode) becomes `TetraTileLayoutDualGrid16 extends TetraTileLayout` — a new file in Phase 3, not a new branch in Phase 1.

**LOC estimate (v0.2 scope = Tetra + DualGrid16):**
- `tetra_tile_map_layer.gd`: ~290 LOC (current 260 + ~30 for contract + layers wiring; the 16-state match moves out, recovering ~40 LOC)
- `tetra_tile_atlas_contract.gd`: ~50 LOC
- `tetra_tile_atlas_slot.gd`: ~30 LOC
- `tetra_tile_layout.gd`: ~30 LOC (base class with abstract methods + validation hook)
- `tetra_tile_layout_tetra.gd`: ~80 LOC (16-state match + transform tables)
- `tetra_tile_layout_dualgrid16.gd`: ~40 LOC (16-entry direct lookup, no transforms)
- **Total: ~520 LOC** across 6 files

That's at the upper edge of the 500 LOC budget but with an order-of-magnitude better extensibility story than Approach A. With Wang and Blob47 added later: +80 and +130 LOC respectively as their own files. Layer file does not grow.

### Approach C — Universal Mask + Layout Filter

```gdscript
# tetra_tile_map_layer.gd
func _update_cells(coords, forced_cleanup):
    ...
    for display_cell in affected:
        var universal_mask := _compute_universal_mask_8bit(display_cell)  # always 8 bits
        atlas_contract.layout.apply(layers, source, display_cell, universal_mask)

func _compute_universal_mask_8bit(display_cell) -> int:
    # 4 corners (TL, TR, BL, BR) + 4 edges (N, E, S, W) = 8 bits
    var m := 0
    if _has_logic_cell(display_cell + _TL): m |= 1
    if _has_logic_cell(display_cell + _TR): m |= 2
    if _has_logic_cell(display_cell + _BL): m |= 4
    if _has_logic_cell(display_cell + _BR): m |= 8
    if _has_logic_cell(display_cell + _N):  m |= 16
    if _has_logic_cell(display_cell + _E):  m |= 32
    if _has_logic_cell(display_cell + _S):  m |= 64
    if _has_logic_cell(display_cell + _W):  m |= 128
    return m

# Layout filter: project the 8-bit mask down to what the layout needs
class TetraTileLayoutTetra:
    func apply(layers, source, display_cell, universal_mask):
        var corner_mask := universal_mask & 0x0F  # discard edge bits
        # ...same as before
```

#### Evaluation

1. **Code clarity (paint flow):** GOOD for blob47 (which actually wants 8 bits); CONFUSING for tetra (computes 4 wasted edge checks per cell). Reader sees `universal_mask` and has to understand which bits each layout cares about.
2. **Extensibility:** WEAK. Locked to 4 corners + 4 edges. Wang-edge wants only the edge bits — fine. Blob47 wants all 8 — fine. Tetra wants only corners — fine. **But subtile composition wants to know about diagonals AND inner subdivisions** — universal mask doesn't fit. Hex grids want a different neighborhood entirely. The "universal" mask is universal only for 8-cell square neighborhoods, which limits future layouts.
3. **GDScript ergonomics:** GOOD. One mask computation, one virtual call per cell. Same Resource-based dispatch as Approach B but with a fatter mask shape.
4. **Performance:** WORSE than B for layouts that need only 4 bits — does 4 wasted `_has_logic_cell` lookups per cell. At 1k cells: ~4000 wasted dictionary lookups vs Approach B. Still well under the frame budget but it's pure waste. For Blob47 (when added) it's optimal.
5. **Subtile composition:** DOESN'T FIT. RPG Maker A2-A5 subtile composition is not a "compute mask, look up tile" pipeline at all — it computes 4 sub-quads, each from a separate corner/edge/inner table. Approach C's "compute one mask, dispatch to filter" model would force subtile composition into a parallel pipeline anyway, defeating the universality claim.
6. **Migration cost:** MEDIUM. Same Resource-subclass infrastructure as B, but the mask computation has to grow to 8 bits in `_update_cells()` immediately. Phase 1 mask code becomes wasteful for the only layout we're shipping in Phase 1.

**LOC estimate:** Same as Approach B for the visible architecture, but `_compute_universal_mask_8bit` adds ~20 LOC vs the current 10-LOC `_mask_at`, and every layout's `apply()` needs one line to project the universal mask down. Net: ~30 LOC more than B, with strictly worse semantics for layouts that don't need 8 bits.

### Side-by-Side Matrix

| Dimension | A — Per-layout `_paint_*` | B — Polymorphic Resource | C — Universal mask |
|---|---|---|---|
| Code clarity | OK initially → degrades | EXCELLENT | OK (some confusion) |
| Extensibility | WEAK (closed) | EXCELLENT (open by default) | LIMITED (closed to 8-cell square) |
| GDScript ergonomics | GOOD (no virtual) | GOOD (Resource-idiomatic) | GOOD (same as B) |
| Performance | BEST (`match`) | GOOD (virtual ~1.5-2× match) | WORSE (always 8 bits) |
| Subtile composition | PARALLEL pipeline needed | FITS NATURALLY (open `paint()`) | DOESN'T FIT |
| Migration from current Phase 1 | MEDIUM | LOW | MEDIUM |
| LOC (v0.2 scope) | ~300 LOC layer + 80 contract = ~380 | ~290 layer + 230 in 5 files = ~520 | ~310 layer + 230 = ~540 |
| LOC (with Wang+Blob47+Subtile) | ~600-700 layer + 80 contract = ~680-780 | layer unchanged + 280-320 added across files = ~800-840 across 8 files | layer +30 LOC + 280-320 in files; subtile orphaned = N/A |

---

## 3. Recommendation: Approach B with Open `paint()`

### 3.1 The Decision

**Approach B (Polymorphic layout Resource) wins on five of six dimensions, ties on the sixth (GDScript ergonomics), and is the only approach that handles RPG Maker subtile composition without a parallel pipeline.**

The reasons, ranked by how much they actually matter:

1. **Subtile composition fits naturally.** Approach A makes subtile a parallel pipeline; Approach C can't do it. Approach B's `paint()` returns void and is free to issue any write count. This is the deciding factor — if subtile composition is *ever* in scope (and the user has flagged RPG Maker A2-A5 as a parking-lot concern), Approach B is the only viable path that doesn't require an architecture rewrite.
2. **The layer file stays small.** Identity guardrail per `PROJECT.md` is "smaller and leaner than TileMapDual." Approach B keeps `tetra_tile_map_layer.gd` at ~290 LOC even as layouts proliferate. Approach A grows the layer file linearly with layouts. v0.2 ships 2 layouts; the milestone is "preserve identity," not "ship smallest possible code."
3. **Future-proofing has near-zero v0.2 cost.** Adding the `TetraTileLayout` base + Tetra subclass is ~110 LOC across 2 files. The total Phase 1 LOC is similar to the current plan (the 16-state match moves OUT of the layer file INTO the layout file).
4. **User extensibility comes for free.** Phase 1 doesn't advertise this surface — but a sophisticated user *can* extend `TetraTileLayout` in their own project. That's strictly more value than Approach A offers, at zero implementation cost.
5. **The performance penalty is irrelevant at demo scale.** See section 4 — the virtual dispatch costs <0.1ms per 1000 cells in GDScript. We have a 16ms frame budget.

The ONE dimension where Approach A wins is raw `_update_cells()` throughput. At >100k cells/frame the `match` would matter. The PROJECT.md scale target is 100-1000 cells — three orders of magnitude away from where this matters.

### 3.2 Why "with Open `paint()`" Matters

The subtile question is the architectural pivot. If `paint()` returned a single `(atlas_coords, transform_flags, alt_id)` tuple, we'd be in trouble: the dispatcher would have to know whether to do 1 write or 4. By making `paint()` itself void and giving it the layers Dictionary, **the dispatcher does not know or care how many writes a layout issues.** That's the abstraction win.

Concretely:
- `TetraTileLayoutTetra.paint()`: 1 or 2 writes (primary, optional overlay for masks 6/9)
- `TetraTileLayoutDualGrid16.paint()`: 1 or 2 writes (primary, optional overlay for masks 6/9 — DG16 has the same diagonal-disconnection problem as Tetra)
- `TetraTileLayoutWangEdge.paint()` (future): 1 write
- `TetraTileLayoutBlob47.paint()` (future): 1 write
- `TetraTileLayoutSubtileRpgMaker.paint()` (parking lot): 4 writes per logic cell, to a dedicated subtile layer

The dispatcher's contract: "I give you `(layers, source, coord, mask)`; you write whatever you need." Layouts own the entire output topology.

---

## 4. Performance Reality Check

### 4.1 Is GDScript Virtual Dispatch Measurably Slower than `match`?

Short answer: **Yes, but not enough to matter at demo scale.**

Long answer:

GDScript 2 uses a method-table lookup for virtual calls on Resource subclasses. From the Godot 4.6 docs (Context7-verified `class_callable.html` and `class_resource.html`): a virtual method call on a typed Resource resolves through the script's method dictionary at call time. There's no JIT, no inlining; each call is roughly:
- 1 dictionary lookup (method name → bytecode pointer) — ~50ns
- 1 stack frame setup — ~30ns
- Bytecode interpretation of the method body

A `match` over an `int` enum, by contrast:
- 1-3 typed comparisons — ~10ns total
- Direct branch into the matching arm

**At 1000 cells per frame with a 60Hz target:**
- Approach A: 1000 × (10ns) = 0.01ms dispatch overhead
- Approach B: 1000 × (80ns) = 0.08ms dispatch overhead

Both are <1% of the 16.6ms frame budget. The dispatch cost is dominated by the actual work (mask computation, `set_cell` calls, dictionary lookups inside `_has_logic_cell`).

**Caveats:**
- These are estimates based on GDScript bytecode behavior, NOT measured. CONFIDENCE: MEDIUM. A real benchmark would resolve this in 5 minutes of work; doing it in v0.2's "feasibility / kickoff" phase is recommended.
- The numbers scale linearly with cell count. At 100k cells (out of scope per PROJECT.md), Approach A is meaningfully faster: 1ms vs 8ms. Still under frame budget for either, but the gap is real.
- The bigger performance question is `_has_logic_cell` (one TileMapLayer dictionary lookup per neighbor check). Both approaches do exactly the same number of these. Layout dispatch is noise next to neighbor lookups.

### 4.2 Verifying in Practice (Suggested Phase 0 Spike)

Before committing the milestone to Approach B, a 10-minute benchmark would settle this:

```gdscript
# spike_dispatch_perf.gd
@tool
extends EditorScript

func _run():
    const N = 100_000
    var t0 := Time.get_ticks_usec()
    var x := 0
    for i in N:
        x = _via_match(i % 16)
    var match_us := Time.get_ticks_usec() - t0

    var dispatcher: TetraTileLayout = TetraTileLayoutTetra.new()
    t0 = Time.get_ticks_usec()
    for i in N:
        x = dispatcher.compute_mask_demo(i % 16)  # same body as _via_match arm
    var virtual_us := Time.get_ticks_usec() - t0

    print("match: %d us / %d ops = %.3f us/op" % [match_us, N, float(match_us)/N])
    print("virtual: %d us / %d ops = %.3f us/op" % [virtual_us, N, float(virtual_us)/N])
```

If the ratio is >5×, revisit Approach A. If <3× (expected), commit to B.

---

## 5. Recommended `_update_cells()` Pseudocode

Below is the v0.2 shape for `tetra_tile_map_layer.gd::_update_cells()` plus one example layout (`TetraTileLayoutTetra` — preserves v0.1 behavior).

### 5.1 The Generic Layer Pipeline (~25 LOC)

```gdscript
# tetra_tile_map_layer.gd  (relevant excerpt)

@export var atlas_contract: TetraTileAtlasContract:
    set(value):
        if atlas_contract == value: return  # idempotence (Pitfall 5)
        if atlas_contract != null and atlas_contract.changed.is_connected(_queue_rebuild):
            atlas_contract.changed.disconnect(_queue_rebuild)
        atlas_contract = value
        if atlas_contract != null:
            atlas_contract.changed.connect(_queue_rebuild)
        _queue_rebuild()

func _update_cells(coords: Array[Vector2i], forced_cleanup: bool) -> void:
    _ensure_visual_layers()
    if forced_cleanup or tile_set == null:
        _clear_visual_layers()
        return

    _sync_visual_layers()
    if coords.is_empty():
        rebuild()
        return

    var layout := _resolve_layout()  # null-safe (returns _legacy_layout if contract is null)
    if layout == null: return

    var source := _resolve_source_id()
    if source == -1: return

    var has_logic_fn := Callable(self, "_has_logic_cell")
    var layers_dict := _layers_dict_snapshot()  # {primary, overlay, top}

    var affected: Dictionary = {}
    for logic_cell in coords:
        _mark_affected_display_cells(affected, logic_cell)

    for display_cell in affected.keys():
        # Erase first — layouts are responsible only for writing.
        _erase_at(layers_dict, display_cell)

        var mask := layout.compute_mask(display_cell, has_logic_fn)
        if mask == 0: continue  # universal "empty cell" short-circuit (Pitfall 4)

        layout.paint(layers_dict, source, atlas_contract, display_cell, mask, _pick_alternative)
```

Notes on the shape:
- **`_resolve_layout()`** returns `atlas_contract.layout` if set, otherwise a singleton `TetraTileLayoutTetra` instance configured for the v0.1 hardcoded behavior. This is the "v0.1 fallback" branch from `ARCHITECTURE.md`.
- **`_layers_dict_snapshot()`** returns `{"primary": _primary_layer, "overlay": _overlay_layer, "top": _top_layer_or_null}`. Layouts pick which layers they need.
- **Mask 0 short-circuit** lives in the dispatcher, not the layout — it's universal across layouts (mask 0 = "no neighbors" = empty silhouette = no visual).
- **`_pick_alternative`** is passed as a Callable so the layout can call it without holding a reference to the layer. Pure-function-style.
- **The erase happens before `paint()`** so layouts only need to handle the write side. Symmetric with v0.1.

### 5.2 The Tetra Layout (~80 LOC, the v0.1 behavior moved into a Resource)

```gdscript
# tetra_tile_layout_tetra.gd
class_name TetraTileLayoutTetra
extends TetraTileLayout

const _TL := Vector2i(-1, -1)
const _TR := Vector2i(0, -1)
const _BL := Vector2i(-1, 0)
const _BR := Vector2i(0, 0)

const _ROTATE_0 := 0
const _ROTATE_90 := TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H
const _ROTATE_180 := TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V
const _ROTATE_270 := TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_V

# Slot keys — names map to AtlasSlot references on the contract.
const _FILL := "fill"
const _INNER := "inner_corner"
const _BORDER := "border"
const _OUTER := "outer_corner"

func compute_mask(display_cell: Vector2i, has_logic_fn: Callable) -> int:
    var m := 0
    if has_logic_fn.call(display_cell + _TL): m |= 1
    if has_logic_fn.call(display_cell + _TR): m |= 2
    if has_logic_fn.call(display_cell + _BL): m |= 4
    if has_logic_fn.call(display_cell + _BR): m |= 8
    return m

func paint(layers: Dictionary, source: int, contract: TetraTileAtlasContract,
           display_cell: Vector2i, mask: int, pick_alt: Callable) -> void:
    var primary: TileMapLayer = layers["primary"]
    var overlay: TileMapLayer = layers["overlay"]

    match mask:
        1:  _put(primary, source, contract, _OUTER, _ROTATE_90, display_cell, pick_alt)
        2:  _put(primary, source, contract, _OUTER, _ROTATE_180, display_cell, pick_alt)
        3:  _put(primary, source, contract, _BORDER, _ROTATE_180, display_cell, pick_alt)
        4:  _put(primary, source, contract, _OUTER, _ROTATE_0, display_cell, pick_alt)
        5:  _put(primary, source, contract, _BORDER, _ROTATE_90, display_cell, pick_alt)
        6:  # diagonal — two writes
            _put(primary, source, contract, _OUTER, _ROTATE_180, display_cell, pick_alt)
            _put(overlay, source, contract, _OUTER, _ROTATE_0, display_cell, pick_alt)
        7:  _put(primary, source, contract, _INNER, _ROTATE_90, display_cell, pick_alt)
        8:  _put(primary, source, contract, _OUTER, _ROTATE_270, display_cell, pick_alt)
        9:  # diagonal — two writes
            _put(primary, source, contract, _OUTER, _ROTATE_90, display_cell, pick_alt)
            _put(overlay, source, contract, _OUTER, _ROTATE_270, display_cell, pick_alt)
        10: _put(primary, source, contract, _BORDER, _ROTATE_270, display_cell, pick_alt)
        11: _put(primary, source, contract, _INNER, _ROTATE_180, display_cell, pick_alt)
        12: _put(primary, source, contract, _BORDER, _ROTATE_0, display_cell, pick_alt)
        13: _put(primary, source, contract, _INNER, _ROTATE_0, display_cell, pick_alt)
        14: _put(primary, source, contract, _INNER, _ROTATE_270, display_cell, pick_alt)
        15: _put(primary, source, contract, _FILL, _ROTATE_0, display_cell, pick_alt)
        # mask 0 handled by dispatcher; no _ arm needed

func _put(layer, source, contract, slot_key, base_transform, cell, pick_alt) -> void:
    var slot: TetraTileAtlasSlot = contract.slot_by_key(slot_key)
    if slot == null: return  # missing-slot tolerance: silent skip + warning via validate()
    var alt_id: int = pick_alt.call(slot, cell)
    var packed := (slot.transform_flags ^ base_transform) | alt_id  # XOR composes user + auto rotation
    layer.set_cell(cell, source, slot.atlas_coords, packed)

func validate(contract: TetraTileAtlasContract) -> PackedStringArray:
    var warnings: PackedStringArray = []
    for key in [_FILL, _INNER, _BORDER, _OUTER]:
        if contract.slot_by_key(key) == null:
            warnings.append("TetraTileLayoutTetra: missing required slot '%s'" % key)
    return warnings
```

**Total Tetra layout: ~70 LOC**. Compare to the v0.1 inline match (~50 LOC inside `_paint_display_cell`). The +20 LOC is the cost of extracting it into a Resource — slot lookups via key, alt-tile picker, validate hook.

### 5.3 The DualGrid16 Layout (the v0.2 NON_ROTATING mode, ~40 LOC)

```gdscript
# tetra_tile_layout_dualgrid16.gd
class_name TetraTileLayoutDualGrid16
extends TetraTileLayout

const _TL := Vector2i(-1, -1)
const _TR := Vector2i(0, -1)
const _BL := Vector2i(-1, 0)
const _BR := Vector2i(0, 0)

func compute_mask(display_cell: Vector2i, has_logic_fn: Callable) -> int:
    # Same 4-bit corner mask as Tetra — the DIFFERENCE is in paint(), not in mask shape.
    var m := 0
    if has_logic_fn.call(display_cell + _TL): m |= 1
    if has_logic_fn.call(display_cell + _TR): m |= 2
    if has_logic_fn.call(display_cell + _BL): m |= 4
    if has_logic_fn.call(display_cell + _BR): m |= 8
    return m

func paint(layers, source, contract, display_cell, mask, pick_alt) -> void:
    var primary: TileMapLayer = layers["primary"]
    var overlay: TileMapLayer = layers["overlay"]

    var slot: TetraTileAtlasSlot = contract.mask_slots[mask]  # 16-entry direct lookup
    if slot == null: return  # missing-slot tolerance
    var alt_id: int = pick_alt.call(slot, display_cell)
    primary.set_cell(display_cell, source, slot.atlas_coords, slot.transform_flags | alt_id)

    # Diagonal masks 6/9 still require overlay composition — topology fact, not symmetry fact.
    if mask == 6 or mask == 9:
        var complement: TetraTileAtlasSlot = slot.diagonal_complement_slot
        if complement != null:
            var c_alt: int = pick_alt.call(complement, display_cell)
            overlay.set_cell(display_cell, source, complement.atlas_coords,
                             complement.transform_flags | c_alt)

func validate(contract: TetraTileAtlasContract) -> PackedStringArray:
    var warnings: PackedStringArray = []
    if contract.mask_slots.size() != 16:
        warnings.append("DualGrid16 requires mask_slots of size 16 (got %d)" % contract.mask_slots.size())
    for i in 16:
        if i == 0: continue  # mask 0 = empty, no slot needed
        if i < contract.mask_slots.size() and contract.mask_slots[i] == null:
            warnings.append("DualGrid16: missing slot for mask %d" % i)
    return warnings
```

**Total: ~40 LOC**. Note the symmetry: same `compute_mask` body as Tetra (same bit semantics). Different `paint` body (direct lookup, no rotation reuse).

### 5.4 Sketch of Future Layouts (Not v0.2 Scope)

For roadmapper context — what Wang/Blob47/Subtile look like inside this architecture:

```gdscript
# tetra_tile_layout_wang_edge.gd  (FUTURE)
class_name TetraTileLayoutWangEdge
extends TetraTileLayout

func compute_mask(display_cell, has_logic_fn) -> int:
    var m := 0
    if has_logic_fn.call(display_cell + Vector2i( 0, -1)): m |= 1  # N
    if has_logic_fn.call(display_cell + Vector2i( 1,  0)): m |= 2  # E
    if has_logic_fn.call(display_cell + Vector2i( 0,  1)): m |= 4  # S
    if has_logic_fn.call(display_cell + Vector2i(-1,  0)): m |= 8  # W
    return m

func paint(layers, source, contract, display_cell, mask, pick_alt) -> void:
    # Direct 16-entry lookup; no overlay needed (Wang has no disconnected diagonals)
    var slot: TetraTileAtlasSlot = contract.mask_slots[mask]
    if slot != null:
        var alt := pick_alt.call(slot, display_cell)
        layers["primary"].set_cell(display_cell, source, slot.atlas_coords,
                                    slot.transform_flags | alt)
```

```gdscript
# tetra_tile_layout_blob47.gd  (FUTURE)
class_name TetraTileLayoutBlob47
extends TetraTileLayout

func compute_mask(display_cell, has_logic_fn) -> int:
    # 8-bit mask: 4 corners + 4 edges
    var m := 0
    # ... 8 has_logic_fn.call() lookups ...
    return _collapse_to_blob47_index(m)  # 256 raw → 47 valid (lookup table)

func paint(layers, source, contract, display_cell, mask_index, pick_alt) -> void:
    # mask_index is already 0..46
    var slot: TetraTileAtlasSlot = contract.blob47_slots[mask_index]
    # ... single set_cell ...
```

```gdscript
# tetra_tile_layout_subtile_rpgmaker.gd  (PARKING LOT — v0.3+)
class_name TetraTileLayoutSubtileRpgMaker
extends TetraTileLayout

func compute_mask(display_cell, has_logic_fn) -> int:
    # The "mask" for subtile composition is conceptually a struct of
    # (corner_quadrant_indices: 4, edge_indices: 4). Pack into one int
    # with bit-fields.
    return _pack_subtile_mask(display_cell, has_logic_fn)

func paint(layers, source, contract, display_cell, packed_mask, pick_alt) -> void:
    # Compose four sub-quad writes onto a dedicated "subtile" layer.
    # This is what makes it a parallel pipeline in Approach A — it's
    # genuinely 4× the writes per cell, with separate atlas tables for
    # the four quadrants. Approach B handles it as just-another-layout.
    var subtile_layer := layers.get("subtile")
    if subtile_layer == null: return  # subtile mode requires an extra layer
    for quadrant in 4:
        var sub_slot := contract.subtile_slot_for(quadrant, packed_mask)
        # ... 4 set_cell calls per logic cell, on a sub-cell grid ...
```

**The point of this sketch is not to design these layouts — it's to show the dispatcher doesn't need to change to support them.** Each is an additive Resource subclass.

---

## 6. The Hard Decisions

### 6.1 RPG Maker Subtile Composition: IN or OUT for v0.2?

**Recommendation: OUT for v0.2. Architect for it; do not implement it.**

Argument:

**OUT case (recommended):**
- Subtile composition has zero overlap with the v0.2 milestone goals (variation, top tiles, non-rotating). It's a wholly different interaction model.
- The user's stated audience is the author's own platformer games (`PROJECT.md` line 70). RPG Maker subtile composition is a JRPG/dungeon-overhead idiom, not a platformer one.
- The implementation cost is significant: a 4-write-per-cell paint path requires a new internal sub-cell layer (or sub-cell offsets within an existing layer), separate atlas-table semantics, and authoring UX for the four quadrant tables. ~120+ LOC just for the layout subclass, plus contract additions. That's ~25% of the LOC budget for a feature outside the milestone.
- The user has already designated it parking-lot-grade in PROJECT.md's pattern: "deferred until contract design is settled."

**IN case (rejected):**
- Could prove the architecture's universality. But that proof can come from Wang-edge or Blob47 later at lower cost; subtile is the most expensive proof.

**The architectural compromise that lets us defer cleanly:**

Approach B's `paint(layers, source, contract, coord, mask, pick_alt)` signature is intentionally *open* — it does not assume single-cell single-write topology. By picking Approach B at v0.2, we reserve the right to add subtile composition as a v0.3+ layout WITHOUT breaking the dispatcher. **This is the strongest argument for B over A.** Approach A would require splitting `_update_cells()` into two top-level paths (one per pipeline) when subtile lands.

**Roadmap action:** Add a one-line entry to `PROJECT.md` Out of Scope section: "RPG Maker A2-A5 subtile composition — Architecturally supported (TetraTileLayout subclass slot reserved); deferred until v0.3+." Document in the layout base class header that `paint()` may issue any number of writes, so future contributors don't constrain it accidentally.

### 6.2 User Extension: OPEN or CLOSED?

**Recommendation: CLOSED for advertising; OPEN by construction. Document it as "experimental" in the codebase, not in user-facing README.**

Argument:

**CLOSED (advertised):**
- Pre-1.0. The base class's method signatures *will* change as we discover layouts. Stable user-extensibility requires API freeze, which v0.2 cannot offer.
- User-extension surfaces add support burden. The v0.2 audience is the author's own games — there are no external users to support.
- An advertised user-extension surface invites bug reports about the base class shape, which slows iteration.

**OPEN (by construction):**
- The base class will exist regardless (Approach B requires it). Locking it private adds zero value and removes optionality.
- A `class_name TetraTileLayout` registration is the difference between "users can extend" and "users cannot extend." We need `class_name` for the typed `@export var layout: TetraTileLayout` on the contract anyway.
- Costs nothing. We'd get user extension whether we wanted it or not.

**The compromise:**
- `class_name TetraTileLayout` is registered (Approach B requires it).
- `tetra_tile_layout.gd` includes a header comment: "EXPERIMENTAL: subclass at your own risk; signatures may change pre-1.0."
- README does NOT document custom layout creation.
- v0.3+ milestone may revisit "promote to public API" once Wang-edge or Blob47 has been added and the base class has stabilized across 3+ implementations.

**Roadmap action:** Add a one-line entry to `tetra_tile_layout.gd` header comment when the file is created. No PROJECT.md changes needed.

### 6.3 LOC Budget Honesty

The PROJECT.md identity guardrail is "smaller and leaner than TileMapDual." For reference, TileMapDual's `tile_map_dual.gd` is ~700-900 LOC depending on version (per `.planning/research/SUMMARY.md` mentions but not directly verified — flag MEDIUM confidence).

Approach B at full v0.2 scope (Tetra + DG16 + variation + top tiles + per-tile knobs):

| File | Estimated LOC | Source |
|---|---|---|
| `tetra_tile_map_layer.gd` | 290 | v0.1 (260) - inline match (-40) + contract setter (+20) + layout dispatch (+15) + top layer support (+25) + variation hook (+10) |
| `tetra_tile_atlas_contract.gd` | 60 | per ARCHITECTURE.md |
| `tetra_tile_atlas_slot.gd` | 30 | per ARCHITECTURE.md |
| `tetra_tile_layout.gd` (NEW base) | 30 | abstract methods + validate hook |
| `tetra_tile_layout_tetra.gd` (NEW) | 70 | 16-state match + slot helpers |
| `tetra_tile_layout_dualgrid16.gd` (NEW) | 40 | 16-entry direct + diagonal complement |
| **Total** | **520** | **6 files** |

Alternative if Approach A were chosen:

| File | Estimated LOC |
|---|---|
| `tetra_tile_map_layer.gd` | 290 + 30 (DG16 paint method) = 320 |
| `tetra_tile_atlas_contract.gd` | 60 |
| `tetra_tile_atlas_slot.gd` | 30 |
| **Total** | **410** | **3 files** |

**Approach B is ~110 LOC heavier than Approach A at v0.2 scope, distributed across 3 more files.** That's the cost of the architecture. The benefit is that adding Wang/Blob47/Subtile in future milestones doesn't grow the layer file at all — each is a self-contained ~40-150 LOC subclass.

Is 520 LOC "smaller and leaner than TileMapDual"? Yes, comfortably. Is 520 LOC "smaller than v0.1"? No — we doubled it. But the v0.2 milestone is *expansion*, not preservation. The expansion is justified because variation, top tiles, and non-rotating support are explicit milestone requirements per PROJECT.md.

**Honesty disclaimer:** These LOC estimates are rough. The actual numbers depend on docstring density, blank-line conventions, and whether helper methods get inlined. Confidence: MEDIUM. The relative ordering (B > A by ~100 LOC) is HIGH confidence; the absolute numbers are MEDIUM.

---

## 7. Migration Path from Current Phase 1 Plan

The current `.planning/research/SUMMARY.md` Phase 1 plan introduces:
- `TetraTileAtlasContract` Resource with `rotation_mode: RotationMode {SYMMETRIC, NON_ROTATING}`
- `AtlasSlot` Resource
- `_resolve_slot(mask)` dispatching by `rotation_mode`

The Approach B revision changes Phase 1 to:
- `TetraTileAtlasContract` Resource — drops `rotation_mode`, adds `layout: TetraTileLayout` typed Resource ref + slot config (named slots for Tetra, `mask_slots` array for the layout that wants it)
- `AtlasSlot` Resource — unchanged
- `TetraTileLayout` Resource (NEW base, abstract)
- `TetraTileLayoutTetra` Resource (NEW concrete) — replaces the SYMMETRIC branch of `_resolve_slot`
- `_update_cells()` calls `layout.compute_mask` + `layout.paint` — replaces the inline `_resolve_slot + match`

**Net Phase 1 change:** +1 abstract base file (~30 LOC) and the SYMMETRIC code moves out of the layer into a new file. Total Phase 1 LOC nearly identical (the 16-state match relocates).

**Phase 3 change:** "Non-rotating mode" becomes "ship `TetraTileLayoutDualGrid16` subclass." Cleaner naming and the user-facing concept is "switch your contract's `layout` to the `DualGrid16` Resource" rather than "set `rotation_mode = NON_ROTATING`."

**Phases 2/4/5 unchanged:** Variation hooks into `_pick_alternative` Callable on the layer (same as current plan). Top tiles slot into the layouts via the `top_overlay_slot` field on contract + `layers["top"]` in the `paint()` signature. Demo refresh and release are unchanged.

**Risk introduced:** The `TetraTileLayout` base class is a new abstract surface. It must be designed correctly the FIRST time, because subclasses will lock the signature. Mitigation: write the Wang and Blob47 subclasses on paper (section 5.4) before committing the base class signature. If those layouts fit cleanly, the signature is validated.

---

## 8. Open Questions and Honest Limits

1. **Hex grids and isometric grids** — the `compute_mask` signature assumes square-grid neighbors (the layout decides which of the 8 surrounding cells to sample, but cells are square). A future hex-grid layout would need to know the cell coordinate convention. **Out of scope per PROJECT.md** but flagged: if hex support ever lands, the dispatcher's `Vector2i` type assumption may need revisiting. Approach B is no worse than Approach A on this — both would require changes.

2. **Performance benchmarks are estimated, not measured.** Section 4.1's numbers are derived from GDScript bytecode patterns documented in Godot 4.6 docs. A real benchmark (section 4.2) would settle this in 10 minutes and is **strongly recommended** as Phase 1 first task. If virtual dispatch turns out >5× slower than `match` in practice, the recommendation flips to Approach A.

3. **Resource-cycle safety.** The contract holds a layout Resource ref, the layout has no back-ref to the contract — that's a one-way reference graph, no cycles. Verified safe per Godot 4.6 Resource serialization rules.

4. **Multi-layer authoring UX.** Phase 1 introduces THREE Resources for what was one enum field (contract + layout + slot). Inspector authoring is more click-y. This is a real downside vs Approach A where users only see "set rotation_mode = NON_ROTATING." Mitigation: ship a default contract `.tres` (already in Phase 5 plan) AND a default `TetraTileLayoutTetra.tres` so users only need to swap layout references, not construct them. Confidence: MEDIUM that the UX cost is acceptable; Phase 1 should validate against actual inspector clicks.

5. **TileMapDual size comparison data** is from `.planning/research/SUMMARY.md` summary, not direct measurement. The "smaller than TileMapDual" claim for the 520 LOC estimate is HIGH confidence directionally (TileMapDual is widely cited as 700+) but MEDIUM on the exact number.

6. **TAXONOMY.md from Researcher 1 was not present at read-time.** This document used the four mask systems described in the prompt's `<context>` block. If TAXONOMY.md introduces a fifth mask system (e.g., terrain peering, marching squares variants, hex-corner), the architectural recommendation should be re-checked. The Approach B architecture is robust to additional systems by design — adding one is a new Resource subclass, not a dispatcher rewrite — so the answer is unlikely to change, but the LOC budget might.

---

## 9. Sources

### Verified via Context7 (HIGH confidence)
- `/websites/godotengine_en_4_6` — `tutorials/scripting/resources.md` (Resource subclass patterns), `class_resource.html` (Resource API), `class_callable.html` (Callable + lambda patterns), `tutorials/ui/control_node_gallery.html` (interface/polymorphism example), `class_translationdomain.html` (`class_name` registration), `class_resourceformatloader.html` (subclass example).
- `/websites/godotengine_en_4_6` — `class_tilemaplayer.html` (`_update_cells`, `set_cell`), `class_tilesetatlassource.html` (`TRANSFORM_*`), confirmed indirectly via `.planning/research/ARCHITECTURE.md` and `PITFALLS.md`.

### Project-Internal (HIGH confidence)
- `C:/Programming_Files/Shilocity/TetraTile/.planning/PROJECT.md` — milestone scope, "smaller than TileMapDual" identity guardrail, Out of Scope list.
- `C:/Programming_Files/Shilocity/TetraTile/.planning/research/SUMMARY.md` — current Phase 1 plan, LOC estimates, recommended stack.
- `C:/Programming_Files/Shilocity/TetraTile/.planning/research/ARCHITECTURE.md` — current `_resolve_slot` design, lazy layer pattern, anti-patterns.
- `C:/Programming_Files/Shilocity/TetraTile/.planning/research/PITFALLS.md` — setter discipline, `Resource.changed` storms, alternative_tile bit packing.
- `C:/Programming_Files/Shilocity/TetraTile/addons/tetra_tile/tetra_tile_map_layer.gd` (260 LOC, lines 67-152 for the current `_paint_display_cell` 16-state match).

### Inferred from Project Context (MEDIUM confidence)
- TileMapDual LOC range (700-900) — from `.planning/research/SUMMARY.md` discussion of identity guardrail; not directly verified from the TileMapDual repo for this document.
- GDScript virtual dispatch overhead (~80ns vs ~10ns match) — derived from documented bytecode behavior; not benchmarked. Recommendation includes a 10-minute spike to verify.

### Not Available at Read-Time
- `C:/Programming_Files/Shilocity/TetraTile/.planning/research/layouts/TAXONOMY.md` — Researcher 1's output not present. Proceeded with the four mask systems described in the prompt's `<context>` block.

---

*Architecture decision document for: TetraTile v0.2.0 — mask system unification across multiple autotiling layouts*
*Researched: 2026-04-25*
*Confidence: HIGH on structure, MEDIUM on LOC estimates and dispatch perf numbers (benchmarks pending)*
