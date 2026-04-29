# Phase 3: Public-Convention Layouts (Blob47 + Tilesetter) — Research

**Researched:** 2026-04-28
**Domain:** Godot 4.6 autotile addon — public-convention layout subclasses (Blob47Godot, TilesetterWang15, TilesetterBlob47) + TBT design-inspiration audit
**Confidence:** **MEDIUM-HIGH overall.** HIGH on Phase 2 pipeline audit (read-from-source). HIGH on BorisTheBrave 47-blob math (verified across 3 sources). **LOW on Tilesetter slot tables — D-86 GATE BLOCKED, see §3.**

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-72**: Phase rename TileBitTools-Sourced → "Public-Convention Layouts (Blob47 + Tilesetter)." Plan-phase MUST update ROADMAP.md, REQUIREMENTS.md (rewrite TBT-04 + DOC-05 — drop ATTRIBUTION.md, replace with 1-line README footnote), STATE.md. Directory rename optional.
- **D-73**: NO code copy. NO data lift. TBT is design-inspiration only. No `_decode_tbt_templates.py`. No vendored `.tres`. No `addons/penta_tile/ATTRIBUTION.md`. Each layout's slot table sourced from the FORMAT's own primary reference. The audit (`03-TBT-DEEP-AUDIT.md`) reads TBT source but produces only ideas/recommendations; any pattern adopted is reimplemented from scratch in PentaTile's style.
- **D-74**: `PentaTileLayoutBlob47Godot` slot table sourced from BorisTheBrave's published 47-blob reference at https://www.boristhebrave.com/permanent/24/06/cr31/stagecast/wang/blob.html. The "Godot" suffix reflects "the convention common in the Godot ecosystem"; the canonical mathematical description is BorisTheBrave's. Plan-phase locks atlas dimensions (~12×4 with 1 cell gap, but plan-phase confirms).
- **D-75**: `PentaTileLayoutTilesetterWang15` + `PentaTileLayoutTilesetterBlob47` slot tables sourced via plan-phase web research. Atlas dimensions: TilesetterWang15 = 5×3 + 1 stray-fill slot; TilesetterBlob47 = 11×5 with sub-block gaps.
- **D-76**: 8-bit Moore mask convention: cardinal-anchored. `N=1, E=2, S=4, W=8, NE=16, SE=32, SW=64, NW=128`. Same ordering for both Blob47Godot and TilesetterBlob47. **NOT** the canonical CR31 clockwise ordering — see §4 for the conversion.
- **D-77**: `compute_mask` stays local per-layout. No shared 8-bit Moore helper on `PentaTileLayout` base.
- **D-78**: 256→47 collapse via BorisTheBrave's algorithmic rule: "A corner bit only matters if both adjacent edges are set." `compute_mask` returns raw 8-bit Moore; `mask_to_atlas` applies collapse first, then dispatches via 47-entry `const _MASK_TO_ATLAS` dict. **Plan-phase MUST add unit test enumerating all 256 masks → assert every collapse hits a valid dict entry.**
- **D-79**: TilesetterWang15 reserves a 16th 'stray fill' slot at suggested `Vector2i(5, 0)` (first cell past 5×3). `mask_to_atlas(0)` returns this slot. Bundled PNG includes pre-greyboxed stray-fill slot.
- **D-80**: 47-blob layouts — `mask_to_atlas(0)` maps to the isolated-cell slot from the 47 valid configurations. Collapse rule covers it; no reserved fallback needed.
- **D-81**: All Pitfall #9 dispatch lives in each layout's `mask_to_atlas`. No layer-side null-handling added.
- **D-82**: All 3 layouts: `is_dual_grid()` returns `false` (single-grid).
- **D-83 + D-87**: Phase 2's single-grid pipeline (commit `81813cd`'s mask=0 default-atlas dispatch) preserved as the contract. **Plan-phase MUST audit pipeline against 47-blob 8-Moore needs**: (1) neighbor-affected radius — sample 8 not 4; (2) mask=0 dispatch reaches logic-painted 47-blob cells; (3) erase semantics re-render 8 neighbors. **See §5 Pipeline Audit Findings.**
- **D-84**: 03-TBT-DEEP-AUDIT.md is the Wave 0 deliverable. Per-pattern table (ADOPT/PARTIAL/REJECT), TileMapDual cross-reference, backlog seeds for PARTIAL/ADOPT-deferred patterns, NO code lift.
- **D-85**: Extend `_generate_bitmasks.py`. New 47-blob silhouette helper (8-bit Moore quadrants + edge strips, applies BorisTheBrave collapse rule for valid configurations only). Reuse Phase 2's `draw_corner_mask` and `draw_edge_mask` for TilesetterWang15. Atlas-occupancy gaps stay transparent.
- **D-86**: Plan-phase MUST resolve Tilesetter primary source before Wave 1 task generation. Three explicit gates if inconclusive: (a) user runs Tilesetter and provides a sample export; (b) defer Tilesetter layouts to v0.3+; (c) accept best-effort transcription with "Empirical" tag.

### Claude's Discretion

- Exact filename slug for renamed phase directory (`03-public-convention-layouts` vs keeping `03-tilebittools-sourced-layouts`) — plan-phase decides based on rename overhead vs documentation hygiene.
- Exact stray-fill atlas coord for TilesetterWang15 (`Vector2i(5, 0)` is the suggestion; plan-phase locks).
- Whether the 47-blob silhouette helper in `_generate_bitmasks.py` is a single function or split into corners-helper + edges-helper composed.
- Wave breakdown structure (suggested: Wave 0 audit + Tilesetter research, Wave 1 Blob47Godot, Wave 2 Tilesetter Wang/Blob, Wave 3 PNGs + README footnote + closeout — but planner has freedom).

### Deferred Ideas (OUT OF SCOPE)

- **Custom-tag vocabulary on PentaTileLayout base** — D-84 audit candidate ADOPT-deferred. Lands v0.3+ when layout count justifies a discoverability surface. Not Phase 3.
- **Project Settings keys** (TBT pattern) — defer until/unless multiple PentaTile verbosity surfaces emerge.
- **EditorInspectorPlugin polish** — explicit project-level rejection per CLAUDE.md identity guardrail. Audit will REJECT TBT's pattern.
- **256-tile blob support** — out of v0.2 entirely.
- **Multi-terrain layouts** (`tilesetter_wang_3-terrain`) — explicitly v2 backlog (MULTITERR-01..05).

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| **TBT-01** | `PentaTileLayoutTilesetterWang15` subclass — 5×3 atlas + stray-fill, 4-bit corner mask. **Original wording said "transcribed from `tile_bit_tools/tilesetter_wang.tres`" — REWRITE per D-72/D-73 to "slot table sourced via plan-phase web research from Tilesetter's manual + tutorials."** | §3 (D-86 GATE BLOCKED — research inconclusive); §6 (TBT source-tree map for the audit, NOT for data lift) |
| **TBT-02** | `PentaTileLayoutTilesetterBlob47` subclass — 11×5 atlas with sub-block gaps, 8-bit Moore mask. **Original wording said "transcribed from `tile_bit_tools/tilesetter_blob.tres`" — REWRITE per D-72/D-73.** | §3 (D-86 GATE BLOCKED); §4 (BorisTheBrave 47-blob math foundation, but Tilesetter uses its own slot order) |
| **TBT-03** | `PentaTileLayoutBlob47Godot` subclass — 8-bit Moore Moore mask, 47 unique configurations. **Original wording said "transcribed from the matching TBT template" — REWRITE per D-72/D-73 to "slot table sourced from BorisTheBrave's 47-blob reference."** | §4 (BorisTheBrave 47-blob — the only confidently-sourced slot table this phase) |
| **TBT-04** | **MUST BE REWRITTEN by plan-phase.** Original: `addons/penta_tile/ATTRIBUTION.md` credits TileBitTools. Per D-72/D-73: "addons/penta_tile/README.md acknowledges TBT as design inspiration in a 1-line footnote. NO ATTRIBUTION.md is created." | §10 (open questions for the planner — wording proposal) |
| **TEMPLATE-02** | 3 bundled bitmask PNGs co-located next to layout `.gd` files: `penta_tile_layout_blob_47_godot.png`, `penta_tile_layout_tilesetter_wang_15.png`, `penta_tile_layout_tilesetter_blob_47.png`. Greybox-only, 32-px tile, transparent gaps. | §7 (bitmask PNG generator spec for `_generate_bitmasks.py` D-85 extension) |
| **DOC-05** | **MUST BE REWRITTEN by plan-phase** alongside TBT-04. Original: ATTRIBUTION.md called out as a doc deliverable. Per D-72/D-73: replace with 1-line README footnote. | §10 (open questions — wording proposal) |

</phase_requirements>

---

## TL;DR / Recommended Implementation Approach

In wave-order, each task citing the D-IDs that lock its scope:

1. **Wave 0a — Tilesetter primary-source gate (D-86, BLOCKING).** Plan-phase reports: §3 of this research is **INCONCLUSIVE** for Tilesetter Wang 15 + Blob 47 slot tables. Tilesetter (https://www.tilesetter.org) does not publish a canonical mask-to-coord mapping; itsjavi/autotiler's `app.js` uses hardcoded `drawCell()` calls (image composition, not mask-table); TBT's `.tres` files contain the mapping but D-73 forbids lifting. **Plan-phase MUST surface this gate to the user with the three D-86 options before generating Wave 1 Tilesetter tasks.**
2. **Wave 0b — TBT design-audit (D-84).** Read full ~3,825 LOC of `C:\Programming_Files\Godot\tile_bit_tools-main\addons\tile_bit_tools\` and produce `03-TBT-DEEP-AUDIT.md` per the structure in §6. Pattern-table (ADOPT/PARTIAL/REJECT) cross-referenced against TileMapDual + PROJECT.md identity guardrails. NO code lift. Backlog seeds for ADOPT-deferred patterns.
3. **Wave 0c — Phase 2 pipeline audit results (D-83, D-87).** Per §5: `_mark_affected_single_grid_cells` at `penta_tile_map_layer.gd:234-239` samples ONLY 4 cardinal neighbors. **47-blob needs 8 (Moore).** A prerequisite task before Wave 1 must extend the helper to mark all 8 Moore neighbors when the active layout reports 8-Moore mask topology, OR add a layout-virtual `affected_neighbor_offsets() -> Array[Vector2i]` that the layer queries. mask=0 dispatch path and erase semantics: NO CHANGE NEEDED (already correct for 8-Moore once the affected-cell marking is fixed).
4. **Wave 1 — Blob47Godot layout (D-74, D-76, D-78, D-80).** `addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.gd`. `compute_mask` returns raw 8-bit Moore in D-76 ordering (~10 LOC). `mask_to_atlas` applies collapse rule then dispatches via `const _MASK_TO_ATLAS: Dictionary` (47 entries). Atlas grid: from BorisTheBrave's 7×7 packing (49 cells, 47 used + 2 duplicates of empty tile_0) — see §4. mask=0 → "isolated cell" entry per D-80.
5. **Wave 2 — TilesetterWang15 layout (D-75, D-79, D-86 outcome).** Only ships if D-86 resolves to (a) "user provided sample export" or (c) "accept Empirical tag." Atlas grid `Vector2i(6, 3)` (5×3 main + 1 stray-fill column). 4-bit corner mask. mask=0 dispatches to `Vector2i(5, 0)` per D-79.
6. **Wave 2 (parallel) — TilesetterBlob47 layout (D-75, D-78, D-86 outcome).** Same gate. Atlas grid `Vector2i(11, 5)` with sub-block gaps. 8-bit Moore mask + 256→47 collapse (same algorithm as Blob47Godot — different `_MASK_TO_ATLAS` dict).
7. **Wave 3 — Bitmask PNG generator (D-85, TEMPLATE-02).** Extend `_generate_bitmasks.py` per §7: new `draw_47_blob_silhouette()` helper composing 8-bit Moore silhouettes (quadrants + edge strips, collapse-rule-filtered). New `gen_blob_47_godot()`, `gen_tilesetter_wang_15()`, `gen_tilesetter_blob_47()`. Atlas-occupancy gaps stay transparent. Three new `.save()` calls in `main()`.
8. **Wave 3 (parallel) — REQUIREMENTS.md + ROADMAP.md + STATE.md rewrites (D-72).** TBT-04 + DOC-05 wording change ("ATTRIBUTION.md" → "1-line README footnote acknowledging TBT as design inspiration"). ROADMAP.md Phase 3 entry retitled. STATE.md updated. Optional: directory rename `03-tilebittools-sourced-layouts/` → `03-public-convention-layouts/`.
9. **Wave 3 (parallel) — README footnote (TBT-04 rewritten, DOC-05 rewritten).** Single line in `addons/penta_tile/README.md` acknowledging TBT as design reference. NO `ATTRIBUTION.md` file created.
10. **Wave 4 — Tests (validation architecture per §10).** Per-layout: comprehensive_bitmask_test entry + bbox/structural invariants. 47-blob layouts: 256-mask collapse-completeness unit test (per D-78). Hollow-pattern test (Phase 2 lessons). Bundled-PNG-matches-mask-table visual regression (per TEMPLATE-04 pattern from Phase 2).

---

## Architectural Responsibility Map

PentaTile is a single-tier addon (runtime GDScript inside Godot). Phase 3 doesn't introduce new architectural tiers. The "tier" mapping is which **subsystem** owns each capability:

| Capability | Primary Subsystem | Secondary Subsystem | Rationale |
|------------|-------------------|---------------------|-----------|
| `compute_mask` (8-bit Moore neighbor sample) | Layout subclass (`.gd` per layout) | — | D-77 locks per-layout — no shared base helper. |
| 256→47 collapse rule | Layout subclass `mask_to_atlas` | — | D-78: `compute_mask` returns raw mask, `mask_to_atlas` collapses and dispatches. Algorithm is ~10 LOC; doesn't deserve a base-class API. |
| `_MASK_TO_ATLAS` dispatch dict | Layout subclass (`const`) | — | Each layout's slot table is hand-locked from its primary reference (BorisTheBrave for Blob47Godot; Tilesetter primary source for the two Tilesetter layouts). |
| mask=0 default-slot dispatch | Layout subclass `mask_to_atlas` | Layer's `_paint_via_layout` (preserves Phase 2 contract) | D-79/D-80/D-81: per-layout decision; layer never null-handles. |
| Affected-cell radius (single-grid) | Layer's `_mark_affected_single_grid_cells` | Layout topology (which neighbors `compute_mask` reads) | **D-87 audit: layer needs to know whether the active layout is 8-Moore or 4-cardinal so it marks the right neighborhood.** See §5. |
| Bundled bitmask PNG generation | `_generate_bitmasks.py` (Python build script) | — | D-85: extend Phase 2's generator with 3 new slot drawers + helpers. Build-time only; not runtime. |
| 47-blob silhouette geometry | New `draw_47_blob_silhouette()` helper in `_generate_bitmasks.py` | — | Composes per-mask quadrant + edge-strip silhouettes (collapse-rule-filtered). |
| TBT design-pattern recommendations | `03-TBT-DEEP-AUDIT.md` markdown deliverable | — | D-84: research-only artifact; produces ideas, not code. |
| Phase 3 doc rewrites (TBT-04, DOC-05) | `REQUIREMENTS.md` + `ROADMAP.md` + `addons/penta_tile/README.md` | `STATE.md` | D-72: explicit policy update, no ATTRIBUTION.md. |

---

## 3. Tilesetter Slot Tables (D-86 GATE)

> **CRITICAL:** This is the highest-priority section of the entire research. The plan-phase agent uses this to decide whether to proceed with Wave 1 Tilesetter tasks or surface the D-86 gate to the user.

### Status: RESEARCH BLOCKED — Tilesetter primary source NOT located

After exhaustive search of Tilesetter's official documentation, community forums, video tutorials, and adjacent open-source tools that claim Tilesetter compatibility, **no public document publishes Tilesetter's canonical Set View → exported PNG slot order with explicit (mask → atlas_coords) mappings.**

### Sources searched

| Source | URL | Result |
|--------|-----|--------|
| Tilesetter docs index | https://www.tilesetter.org/docs/ | High-level page; no slot tables |
| Tilesetter — Generating Tilesets | https://www.tilesetter.org/docs/generating_tilesets | "Wang Sets contain 16 tiles" / "Blob Sets consist of 47 tiles" — NO atlas layout, NO bitmask convention |
| Tilesetter — Exporting | https://www.tilesetter.org/docs/exporting | "Auto-tile bitmasks are already configured for Blob and Wang sets when exporting from the Set View" — but no per-tile mapping. Page admits: *"This section is being worked on. In the meantime, information about custom format implementation can be found in our Discord server."* |
| Tilesetter — Tileset Behavior | https://www.tilesetter.org/docs/tileset_behavior | UI-relations description only; no internal layout |
| Tilesetter — Working with Tiles | https://www.tilesetter.org/docs/working_with_tiles | Set View introduction; no canonical layout |
| Steam discussion "Any success with Wang Sets?" | https://steamcommunity.com/app/1105890/discussions/0/1636417554430764528/ | User trouble-shooting; no slot table |
| Tilesetter 2.0 video tutorial | https://www.youtube.com/watch?v=04hNF4BtTUE | Video — no transcribable text-form slot table; would require frame-by-frame screenshot capture (out of plan-phase scope) |
| **itsjavi/autotiler** (Godot-export blob generator) | https://github.com/itsjavi/autotiler/blob/master/app.js | **Hardcoded `drawCell(sx, sy, dx, dy)` calls in `generateCanvasImg()` — image composition, not mask table.** README documents 5×3 input → 11×5 output dimensions, matching Tilesetter, but provides no bitmask convention or mask-to-coord mapping. |
| TilePipe / TilePipe2 | https://github.com/aleksandrbazhin/TilePipe | Different generator; doesn't claim Tilesetter compatibility |
| Blobator (Enichan) | https://github.com/Enichan/blobator | Has bit-numbering convention `topLeft=1, top=2, topRight=4, ...` but does NOT match Tilesetter's export (Blobator generates its own format). |
| **TileBitTools `tilesetter_wang.tres`** | `C:\Programming_Files\Godot\tile_bit_tools-main\addons\tile_bit_tools\templates\tilesetter_wang.tres` | **Empirically derived by dandeliondino in 2023; D-73 PROHIBITS LIFTING this data.** |
| **TileBitTools `tilesetter_blob.tres`** | (same dir) | Same — empirical, prohibited from lift. |

### Key technical findings (NOT a slot table)

- **Tilesetter is closed-source commercial software.** No mask-to-coord mapping appears in any public documentation.
- The exported atlas dimensions ARE confirmed by community evidence:
  - **Wang export: 5×3 = 15 tiles + 1 separately-painted "stray fill"** (15-tile count noted explicitly in TBT description: *"Does not include the stray single tile. Select that tile separately, and click 'Fill'."* and confirmed by itsjavi/autotiler's `inputTileCountX = 5` constant).
  - **Blob export: 11×5 with sub-block gaps = 47 tiles** (TBT atlas occupancy parses to: rows 0-1 cols 0-9 populated + rows 2-3 fully + row 4 cols 4-8 only).
- **Tilesetter's bitmask convention is undocumented externally.** TBT's `.tres` decodes from Godot's `CellNeighbor` enum (3=SE, 7=SW, 11=NW, 15=NE for corner-mode), but that's TBT's interpretation of Tilesetter's layout, not Tilesetter's documentation.
- The image composition in itsjavi/autotiler shows that Tilesetter's exported atlas is built by **slicing the 5×3 Wang input into half-tile pieces and recomposing** — meaning the output's per-cell silhouettes are GEOMETRICALLY derived from the 5×3 input, not from a published mask convention. The slot order is whatever Tilesetter's internal `generateCanvasImg`-equivalent picks.

### Recommendation for D-86 gate

**Per D-75 + D-86, plan-phase MUST surface this to the user with three options:**

| Option | What it means | Recommended? |
|--------|---------------|--------------|
| (a) **User runs Tilesetter and provides a sample export** | User downloads Tilesetter, generates a Wang and a Blob from a labeled test tileset (where each cell is uniquely identifiable by color or numbering), exports as Image, then provides the labeled exports back. Plan-phase reads the labeled exports and locks the slot tables. | **Best if user has time** — produces a primary-source artifact (the user's own Tilesetter export) that satisfies D-75 cleanly. |
| (b) **Defer Tilesetter layouts to v0.3+** | Phase 3 ships ONLY `PentaTileLayoutBlob47Godot`. Tilesetter Wang 15 + Blob 47 deferred. REQUIREMENTS.md updates: TBT-01 + TBT-02 → v0.3 backlog. ROADMAP.md adjusts cumulative scope. | **Best for shipping speed** — Blob47Godot alone gives a 47-tile public-convention layout. Tilesetter's audience (users who already use Tilesetter) doesn't yet exist for PentaTile. |
| (c) **Accept "Empirical" tag** | Plan-phase makes a best-effort transcription using a TBT-style empirical fingerprinting approach: the executor authors a labeled test atlas (e.g., 5×3 numbered cells), opens it in Tilesetter, exports Wang/Blob, and reads the export back. The slot table is tagged `"Empirical"` in the layout's class doc-comment to signal it's reverse-engineered. | **Risky** — same as (a) but plan-phase committee performs the empirical work. The risk is the executor/Claude doesn't have Tilesetter installed; the user does. (a) is strictly better than (c) in that case. |

**My recommendation to the planner:** present (a) and (b) as the primary options; flag (c) as a fallback only if the user prefers to reverse-engineer rather than use their own copy of Tilesetter. **Do NOT proceed past Wave 0 without user input on this gate.**

---

## 4. BorisTheBrave 47-Blob Reference

This section locks the math for `PentaTileLayoutBlob47Godot` (D-74). All claims here are HIGH confidence — verified across 3 sources (BorisTheBrave's permanent mirror, his "Tileset Roundup" blog post, and the cr31 archive that BorisTheBrave's mirror replicates).

### 4.1 The 256→47 collapse rule (D-78)

> *"To go from 255 possibilities to 47, you ignore corners if there is no edge tile there. i.e.: if top = 0, then top-left = 0, and top-right = 0"* — Stormcloak Games (paraphrasing CR31 / BorisTheBrave)

> *"The corner tiles are only relevant if both edge tiles are solid, so I mark them as empty in any other case."* — BorisTheBrave's "Tileset Roundup" article

**Algorithmic statement** (the form D-78 codifies):
- A corner bit (NE, SE, SW, NW) is "valid" only when **BOTH adjacent cardinal-edge bits** are set.
- For example: `NE` corner is meaningful only when both `N` AND `E` edges are set. If either is unset, `NE` is forced to 0 regardless of the actual neighbor.

**Pseudocode (≤10 LOC GDScript)** — for `mask_to_atlas` to apply BEFORE the dict lookup. Uses D-76's bit ordering (`N=1, E=2, S=4, W=8, NE=16, SE=32, SW=64, NW=128`):

```gdscript
static func _collapse_8bit_moore(raw: int) -> int:
    var n  := raw & 1
    var e  := raw & 2
    var s  := raw & 4
    var w  := raw & 8
    var collapsed := raw & 15  # keep edges as-is
    if n != 0 and e != 0 and (raw & 16)  != 0: collapsed |= 16   # NE valid
    if s != 0 and e != 0 and (raw & 32)  != 0: collapsed |= 32   # SE valid
    if s != 0 and w != 0 and (raw & 64)  != 0: collapsed |= 64   # SW valid
    if n != 0 and w != 0 and (raw & 128) != 0: collapsed |= 128  # NW valid
    return collapsed
```

This function is **total** — every input in `[0, 256)` produces an output that is a valid 47-blob mask. The 256→47 reduction is deterministic and idempotent (`_collapse(x) == _collapse(_collapse(x))`).

### 4.2 The 47 valid masks — bit-ordering conversion

**CR31/BorisTheBrave use clockwise-from-N ordering**: `N=1, NE=2, E=4, SE=8, S=16, SW=32, W=64, NW=128`.

**D-76 specifies cardinal-anchored ordering**: `N=1, E=2, S=4, W=8, NE=16, SE=32, SW=64, NW=128`.

The 47 valid CR31-ordered masks (verified from BorisTheBrave's "Tileset Roundup" lookup table):

```
{0, 2, 8, 10, 11, 16, 18, 22, 24, 26, 27, 30, 31, 64, 66, 72, 74, 75, 80, 82, 86, 88, 90, 91, 94, 95, 104, 106, 107, 120, 122, 123, 126, 127, 208, 210, 214, 216, 218, 219, 222, 223, 248, 250, 251, 254, 255}
```

Wait — **the BorisTheBrave permanent page enumerates as `{0, 1, 5, 7, 17, 21, 23, 29, 31, 85, 87, 95, 119, 127, 255}` (15 base masks × rotations).** Reconciliation: the "Tileset Roundup" enumeration is 47 distinct values; the permanent page's 15 are the base masks before applying the four 90° rotation symmetries. The 47 values cover all rotations. **Plan-phase must verify which list matches the bit-ordering it adopts** — CR31 clockwise produces a different 47 set than D-76 cardinal-anchored. Both lists describe THE SAME 47 valid configurations; they differ only in bit assignment.

**Conversion utility** for plan-phase: given a CR31-ordered mask, the D-76 mask is computed by the bit-permutation `[0:N→0, 1:NE→4, 2:E→1, 3:SE→5, 4:S→2, 5:SW→6, 6:W→3, 7:NW→7]`. In code:

```gdscript
static func _cr31_to_d76(cr31_mask: int) -> int:
    var d76 := 0
    if cr31_mask & 1   != 0: d76 |= 1    # N    bit 0 -> 0
    if cr31_mask & 4   != 0: d76 |= 2    # E    bit 2 -> 1
    if cr31_mask & 16  != 0: d76 |= 4    # S    bit 4 -> 2
    if cr31_mask & 64  != 0: d76 |= 8    # W    bit 6 -> 3
    if cr31_mask & 2   != 0: d76 |= 16   # NE   bit 1 -> 4
    if cr31_mask & 8   != 0: d76 |= 32   # SE   bit 3 -> 5
    if cr31_mask & 32  != 0: d76 |= 64   # SW   bit 5 -> 6
    if cr31_mask & 128 != 0: d76 |= 128  # NW   bit 7 -> 7
    return d76
```

Plan-phase can run this conversion against the CR31 47-mask list to produce the D-76 47-mask list ready for the `_MASK_TO_ATLAS` dict.

### 4.3 Atlas dimensions

**BorisTheBrave's permanent page documents two minimum-packing layouts** (verified verbatim):

> *"Both these minimum packing layouts were discovered by Caeles at OpenGameArt.org using an exhaustive computer search."*
>
> - **6×8 array** with one duplicate (tile-255)
> - **7×7 array** with three copies of tile-0

The page also states: *"All tiles are 32x32 pixels."*

**Plan-phase decision required:** which packing does `PentaTileLayoutBlob47Godot` adopt?

| Option | Atlas grid | Cells used | Pros | Cons |
|--------|-----------|-----------|------|------|
| 7×7 | `Vector2i(7, 7)` | 47 + 2 duplicates of empty (mask 0) | Square — visually clean for inspector preview | 2 duplicate cells (low-cost) |
| 6×8 | `Vector2i(6, 8)` | 47 + 1 duplicate of mask 255 | Tighter (only 1 duplicate) | Non-square; less aesthetic |
| ~12×4 (Context's suggestion) | `Vector2i(12, 4)` | 47 + 1 unused | Matches `godot3_3x3_minimal.tres` shape (12×4 with one gap) — Godot ecosystem-familiar | NOT a Caeles-minimum-pack; the unused cell is dead space |

**My recommendation:** the **7×7 layout with 2 duplicate empty-tile copies** is the cleanest compromise. It's BorisTheBrave's canonical reference shape, and the layout name's "Godot" suffix only refers to ecosystem-familiarity rather than format purity. The duplicate empty tiles are harmless (`mask_to_atlas(0)` returns ONE specific coord; the others are unused but not invalid). **CONFIDENCE: MEDIUM** — this is plan-phase's call. The CONTEXT.md suggestion of "~12×4 with 1 cell gap" reflects `godot3_3x3_minimal.tres` (a different layout); it's not load-bearing per D-74.

### 4.4 Per-slot silhouette description

Each of the 47 valid masks has a determined silhouette: **the union of (a) edge-strips for each set edge bit AND (b) corner-quadrants for each set corner bit (after collapse).**

For a 32×32 tile with the painted-cell at center:
- **N edge bit set** → top half (or just top edge strip) is "connected" — render as fully-opaque top strip (but for greybox, the FULL top half is grey, indicating "this side is connected to a neighbor").
- **E/S/W edge bits** → analogous right/bottom/left halves grey.
- **NE corner bit set** (after collapse — meaning N AND E are also set) → top-right quadrant is grey.
- All four corners + four edges set (mask 255 in D-76 ordering: `0xFF`) → full 32×32 grey square ("fully connected" tile).
- **Mask 0** (all bits clear) → "lonely tile" — single-cell terrain. Greybox as full 32×32 grey (per Phase 2 single-grid solidity rule).

This silhouette description directly informs `_generate_bitmasks.py`'s helper (§7).

---

## 5. Pipeline Audit Findings (D-83 + D-87)

> **Pre-condition for Wave 1.** Per D-87, plan-phase MUST audit Phase 2's single-grid pipeline against 47-blob 8-Moore needs. This section reports the audit results from reading `addons/penta_tile/penta_tile_map_layer.gd` directly.

### Finding 1 — Neighbor-affected radius — **PREREQUISITE TASK NEEDED**

**Code excerpt** (`addons/penta_tile/penta_tile_map_layer.gd:234-239`):

```gdscript
# NEW for D-06: Single-grid pipeline (logic and visual share the same grid).
# Marks cell + 4 cardinal neighbors. Phase 1 has no consumer (Penta H/V are dual-grid);
# Phase 2's Wang2Corner is the first consumer. Locked planner option (a) — ship the
# pipeline fully wired so Phase 2 layouts are pure subclass adds.
func _mark_affected_single_grid_cells(affected: Dictionary, logic_cell: Vector2i) -> void:
    affected[logic_cell] = true
    affected[logic_cell + Vector2i.UP] = true
    affected[logic_cell + Vector2i.DOWN] = true
    affected[logic_cell + Vector2i.LEFT] = true
    affected[logic_cell + Vector2i.RIGHT] = true
```

**Problem:** This marks ONLY the 4 cardinal neighbors (UP/DOWN/LEFT/RIGHT). For 47-blob layouts, when cell `C` changes, the cells at `C + (±1, ±1)` (the 4 diagonal neighbors) ALSO have masks that depend on `C` — because their `compute_mask` reads diagonal neighbors via the NE/SE/SW/NW bit positions. With only 4 cells re-rendered, those 4 diagonal neighbors keep stale masks until something else triggers a rebuild.

**Worked example (47-blob layout):**
- User paints cell `(0, 0)`. Layer marks affected: `(0,0), (0,-1), (0,1), (-1,0), (1,0)`. ✓ Cell `(0,0)` paints correctly.
- Later, cell `(1, 1)` already exists (painted earlier). Its `compute_mask` reads neighbors: at the moment user painted `(1, 1)`, cell `(0, 0)` was empty, so `(1,1)`'s NW corner bit was 0. After the user paints `(0, 0)`, `(1,1)`'s NW corner bit SHOULD become 1. But `(1, 1)` is at offset `(-1, -1)` from `(0, 0)` — a diagonal — and is NOT in the affected set. So `(1, 1)` keeps its stale mask and stale atlas slot until the next full `rebuild()` or independent re-paint.

**Symptoms in single-grid 47-blob:** painting a cell into an established region produces an incorrectly-masked diagonal cell. Visually: a corner tile that should show the new connection still shows the old "no diagonal neighbor" silhouette. The bug is silent until visual inspection.

**Fix options for plan-phase:**

| Option | Approach | Pros | Cons |
|--------|----------|------|------|
| **(A) Always mark 8 neighbors in single-grid** | Hardcode 8-Moore in `_mark_affected_single_grid_cells`. | Simple. Correct for 47-blob. | Wastes work for 4-cardinal layouts (Wang2Edge, Min3x3) — they re-render unnecessary diagonal cells whose masks didn't change. Bounded harm: a 5×5 paint causes 25 → ~36 cells marked (vs ~25 with 4-cardinal). Cost is a small constant factor; demo-scale impact negligible. |
| **(B) Layout virtual `affected_neighbor_offsets() -> Array[Vector2i]`** | Each layout declares its neighborhood. Layer queries the active layout. Wang2Edge/Min3x3 return 4-cardinal; Wang2Corner returns 4-diagonal; 47-blob returns 8-Moore. | Clean abstraction. Each layout owns its topology. No wasted re-renders. | Adds a base-class virtual (D-77 says compute_mask stays local — but D-77 is about `compute_mask` specifically; this is a different method). Slightly more API surface. |
| **(C) Always mark 8 neighbors in single-grid + accept the wasted work** | Same as (A). | Identical. | Identical. |

**My recommendation: (A) — always mark 8 Moore neighbors in single-grid.** Rationale: (1) the cost is bounded (~44% more cells marked, but those cells short-circuit early in `_paint_via_layout` via the `is_dual_grid()=false AND not sample_fn(display_cell)` guard at line 262 if they're not logic-painted); (2) avoids growing the base API; (3) simplest fix. **However**, if plan-phase prefers (B) for cleanliness, that's also acceptable and aligns with PentaTile's "no shared helpers" preference.

**One-line task description for the prerequisite Wave 0c task:** "Extend `_mark_affected_single_grid_cells` to include the 4 diagonal neighbors (NE, SE, SW, NW) so 47-blob layouts re-render correctly when a logic cell changes."

### Finding 2 — mask=0 dispatch path — **NO CHANGE NEEDED**

**Code excerpt** (`addons/penta_tile/penta_tile_map_layer.gd:262-272`):

```gdscript
# SINGLE-GRID LAYOUTS: only render cells that are themselves logic-painted.
# (...)
if not active_layout.is_dual_grid() and not sample_fn.call(display_cell):
    return

var mask := active_layout.compute_mask(display_cell, sample_fn)
# DUAL-GRID universal short-circuit (PITFALLS §4): a display cell with no
# painted corners doesn't render. Single-grid logic cells with mask=0
# (isolated cells with no painted neighbors, 1x1 paints, or 1xN lines in
# Wang2Corner where no diagonals exist) MUST still render — the layout's
# mask_to_atlas dispatches them to a default atlas slot.
if active_layout.is_dual_grid() and mask == 0:
    return
```

A logic-painted single-grid 47-blob cell with mask=0 (an isolated cell, no neighbors) reaches `mask_to_atlas(0)` correctly. The mask=0 short-circuit is gated on `is_dual_grid()`. Per D-80 the layout's `_MASK_TO_ATLAS[0]` returns the "lonely tile" slot. **No change needed.**

### Finding 3 — Erase semantics — **NO CHANGE NEEDED (assuming Finding 1 is fixed)**

**Code excerpt** (`addons/penta_tile/penta_tile_map_layer.gd:164-193`):

```gdscript
func _update_cells(coords: Array[Vector2i], forced_cleanup: bool) -> void:
    _ensure_visual_layers()
    if forced_cleanup or tile_set == null:
        _clear_visual_layers()
        return
    # (...)
    var affected: Dictionary = {}
    if active_layout.is_dual_grid():
        for logic_cell: Vector2i in coords:
            _mark_affected_display_cells(affected, logic_cell)
    else:
        for logic_cell: Vector2i in coords:
            _mark_affected_single_grid_cells(affected, logic_cell)
    for display_cell: Vector2i in affected.keys():
        _paint_via_layout(display_cell, active_layout, source, sample_fn)
```

When the user calls `erase_cell(coord)` Godot fires `_update_cells([coord], forced_cleanup=false)`. The layer marks the affected neighborhood and re-paints. Once Finding 1 is fixed (8-Moore in `_mark_affected_single_grid_cells`), the erased cell's 8 Moore neighbors all re-render correctly with their updated masks. **No additional change needed for erase.**

**One subtle point:** `_paint_via_layout` does `_primary_layer.erase_cell(display_cell)` at line 251 before the mask check, so the erased cell itself gets cleared correctly. The `_mark_affected_single_grid_cells` at line 234 also includes `affected[logic_cell] = true`, so the erased cell IS in the affected set. After the erase, the cell's `sample_fn(coord)` returns false (line 311's `_has_logic_cell` checks `get_cell_source_id(coord) != -1`), triggering the line-262 short-circuit; the cell renders nothing. ✓ Correct.

### Audit summary

| Finding | Required Action | Wave |
|---------|-----------------|------|
| 1. Single-grid affected radius is 4-cardinal, must be 8-Moore for 47-blob | **PREREQUISITE TASK** — extend `_mark_affected_single_grid_cells` to mark 4 diagonals OR add layout virtual | Wave 0c (before any 47-blob layout ships) |
| 2. mask=0 dispatch path | NO CHANGE NEEDED | — |
| 3. Erase semantics | NO CHANGE NEEDED (once Finding 1 is fixed) | — |

---

## 6. TBT Source Tree Map (input for D-84 audit task)

> **Purpose of this section:** give the planner concrete file pointers so the Wave 0b audit task (`03-TBT-DEEP-AUDIT.md`) can specify what to read where. Per D-73, this is structural mapping only — NO code lift.

### File inventory (verified read-from-disk 2026-04-28)

Total: ~3,825 LOC across **30 GDScript files** + **12 `.tres` template files** + **7 example PNGs** + 2 root files (plugin.cfg + plugin.gd).

#### Plugin entry + inspector hot-path

| File | LOC | Purpose |
|------|-----|---------|
| `plugin.gd` | 62 | EditorPlugin entry — `_enter_tree`/`_exit_tree`, registers inspector_plugin |
| `inspector_plugin.gd` | 353 | EditorInspectorPlugin — `_can_handle`, `_parse_end`, walks editor scene tree to find `TileSetEditor`/`TileSetAtlasSourceEditor`/`TileAtlasView`/`AtlasTileProxyObject` |

#### Core data layer (`core/` — ~1,180 LOC)

| File | LOC | Purpose |
|------|-----|---------|
| `core/bit_data.gd` | 245 | Base `BitData` Resource — `_tiles : Dictionary` keyed by `Vector2i` atlas coords; `terrain_set`, `terrain_mode`; getters/setters for per-tile center+peering bits |
| `core/editor_bit_data.gd` | 123 | `EditorBitData extends BitData` — extracts bit data from live `TileSet`/`TileSetAtlasSource`/`TileData` editor selection |
| `core/template_bit_data.gd` | 105 | `TemplateBitData extends BitData` — adds `version`, `template_name`, `template_description`, `_custom_tags`, `template_terrain_count`, `example_folder_path`, runtime-only `built_in` and `preview_texture` |
| `core/template_loader.gd` | 257 | Discovers .tres files in `BUILTIN_TEMPLATES_PATH`/`PROJECT_TEMPLATES_PATH`/etc.; tags + caches templates |
| `core/template_tag_data.gd` | 134 | Auto-tag definitions — `Tags` enum (`BUILT_IN`, `USER`, `MATCH_CORNERS_AND_SIDES`, `MATCH_CORNERS`, `MATCH_SIDES`); custom-tag vocabulary mechanics |
| `core/globals.gd` | 95 | Paths + `Settings` const dict — `addons/tile_bit_tools/paths/...`, `output/...`, `colors/...` Project Settings keys |
| `core/output.gd` | 160 | Verbosity-controlled output channels (USER/INFO/DEBUG) |
| `core/icons.gd` | 35 | Editor theme icon name lookups |
| `core/texts.gd` | 53 | Externalized UI strings |
| `core/context.gd` | 114 | Current tile/source/tile_set state for the active selection |

#### Plugin control + UI (`controls/tbt_plugin_control/` — ~880 LOC)

| File | LOC | Purpose |
|------|-----|---------|
| `tbt_plugin_control.gd` | 245 | Root control panel of TBT's UI |
| `tbt_plugin_control.tscn` | — | Scene |
| `template_manager.gd` | 109 | Template loader/cache wrapper |
| `tiles_manager.gd` | 133 | Apply/preview pipeline — `apply_bit_data()` mutates TileData in place |
| `theme_updater.gd` | 268 | Editor theme harmonization — recolors UI to match user's active Godot editor theme |
| `popups/template_dialog.gd` | 173 | Template picker popup |
| `popups/save_template_dialog.gd` | 75 | Save-as dialog with name/description/custom-tags fields + path selector |
| `popups/edit_template_dialog.gd` | 62 | Edit existing template metadata |

#### Inspector UI (`controls/tiles_inspector/` — ~830 LOC)

| File | LOC | Purpose |
|------|-----|---------|
| `tiles_inspector.gd` | 45 | Root inspector control |
| `template_section/templates_section.gd` | 276 | Template picker filter UI (chip-style multi-tag) |
| `template_section/template_info_panel.gd` | 126 | Selected-template metadata + preview display |
| `template_section/terrain_picker.gd` | 91 | Maps template terrains → user TileSet's terrains |
| `tool_buttons/tool_buttons.gd` | 177 | Fill / Clear / Set Bits buttons |
| (other UI tscns + selected_tag stylebox) | ~115 | Visual styling |

#### Live preview (`controls/tiles_preview/` — ~250 LOC)

| File | LOC | Purpose |
|------|-----|---------|
| `tiles_preview.gd` | 206 | SubViewport-based live overlay rendering bit colors over tile atlas |
| `tiles_view.gd` + scene + `terrain_opacity_slider.gd` | ~50 | Supporting UI |

#### Bit-color renderer (`controls/bit_data_draw/` — ~270 LOC)

| File | LOC | Purpose |
|------|-----|---------|
| `bit_data_draw.gd` | 237 | Renders peering-bit color overlays in the preview |
| `bit_data_draw_node.gd` + scene | ~30 | Supporting node |

#### Bundled templates (`templates/` — 12 `.tres` files)

| Template | Tiles | Atlas | Custom tags |
|----------|-------|-------|-------------|
| `godot3_2x2.tres` | 16 | 4×4 | `["Godot 3", "TilePipe2"]` |
| `godot3_3x3_16_tiles.tres` | 16 | 4×4 | `["Godot 3"]` |
| `godot3_3x3_minimal.tres` | 47 | 12×4 (1 gap) | `["Godot 3", "TilePipe2"]` |
| `simple_4-tile_(inside_corners).tres` | 4 | 2×2 | `["Incomplete Autotile", "Simple"]` |
| `simple_9-tile_(inside_corners).tres` | 9 | 3×3 | `["Incomplete Autotile", "Simple"]` |
| `simple_9-tile_(outside_corners).tres` | 9 | 3×3 | `["Incomplete Autotile", "Simple"]` |
| `tilesetter_blob.tres` | 47 | **11×5 with sub-block gaps** | `["Tilesetter"]` |
| `tilesetter_wang.tres` | **15** | **5×3** | `["Tilesetter"]` |
| `tilesetter_wang_3-terrain.tres` | 81 | 12×12 with gaps | `["Tilesetter"]` |
| `tilesetter_wang_3-terrain_transitions.tres` | varies | varies | `["Tilesetter", "Incomplete Autotile"]` |
| `tilepipe2_256_tile_16x16.tres` | 256 | 16×16 | `["TilePipe2", "Plugin Required"]` |
| `tilepipe2_256_tile_32x8.tres` | 256 | 32×8 | `["TilePipe2", "Plugin Required"]` |

### D-84 pattern locator table

For the audit deliverable, here's where each TBT pattern lives + my pre-audit ADOPT/PARTIAL/REJECT recommendation (the audit task itself can override these):

| TBT Pattern | Defined in | TileMapDual equivalent | Pre-audit recommendation | Reasoning |
|-------------|-----------|-------------------------|--------------------------|-----------|
| `BitData → EditorBitData / TemplateBitData` Resource hierarchy | `core/bit_data.gd`, `core/editor_bit_data.gd`, `core/template_bit_data.gd` | None — TileMapDual uses raw terrain peering bits | **PARTIAL** | PentaTile's `PentaTileLayout` base + concrete subclasses already mirror this. We don't need TBT's `BitData`/`EditorBitData` distinction (we don't have a "live editor selection" concept). Adopt the *pattern* (base + subclasses); reject the specific 3-tier split. |
| `EditorInspectorPlugin` walking Godot's internal scene tree | `inspector_plugin.gd` (lines 1-353) | None | **REJECT** | Identity guardrail: "no editor UX polish per CLAUDE.md." Walking internal class names (`TileSetEditor`, `AtlasTileProxyObject`) is fragile across Godot 4.x minor versions. PentaTile uses public APIs only. |
| `_custom_tags : Array[String]` template metadata | `core/template_bit_data.gd:_custom_tags` (line ~9), `core/template_tag_data.gd` (full file) | None | **PARTIAL ADOPT-DEFERRED** | Useful for layout discovery once layout count >5; v0.2 has 10 layouts already so this could land. **D-84 audit: add `tags : Array[StringName]` to `PentaTileLayout` base** (typed; not TBT's untyped `Array`). Vocabulary includes `"Public"`, `"Tilesetter"`, `"BorisTheBrave"`, `"Empirical"`. **Backlog seed if not adopted in v0.2:** v0.3 todo `add_layout_tags_vocabulary`. |
| `tiles_preview` SubViewport overlay | `controls/tiles_preview/tiles_preview.gd` (206 LOC) | None — TileMapDual has its own dual-display | **REJECT** | Editor-UX polish; out of scope. |
| Theme harmonization | `controls/tbt_plugin_control/theme_updater.gd` (268 LOC) | None | **REJECT** | Editor-UX polish; out of scope. PentaTile uses Godot's stock inspector preview. |
| Save Template dialog (Project / Shared / User folders) | `controls/tbt_plugin_control/popups/save_template_dialog.gd` (75 LOC) | None | **REJECT** | Custom layouts defer to v0.3+ (CLAUDE.md identity). Built-in layouts only this milestone. |
| Project Settings keys (`addons/tile_bit_tools/output/...`) | `core/globals.gd:Settings` const dict (~95 LOC) | None | **REJECT (v0.2)** — **PARTIAL (v0.3+)** | One-off `addons/penta_tile/output/show_debug_logs : bool` would be reasonable if/when PentaTile has multiple verbosity surfaces. Today it has one (`OS.is_debug_build()` gated `_rebuild_count` instrumentation). Backlog seed: `add_project_settings` for v0.3+. |
| Paul Tol color-blind-friendly palette | `core/globals.gd:Settings` (color hex codes #AA3377, #CCBB44, #228833, #66CCEE) | None | **REJECT** | PentaTile doesn't render multi-terrain previews. Audit notes the precedent for if/when terrain-coloring lands (v2 backlog MULTITERR-01). |
| The 12 bundled `.tres` files as a **curation pattern** | `templates/` folder | TileMapDual ships ZERO bundled templates (relies on user's atlas) | **ADOPT (already done)** | PentaTile v0.2 already ships per-layout greybox PNGs in `addons/penta_tile/layouts/penta_tile_layout_<slug>.png`. Phase 3 adds 3 more PNGs (TEMPLATE-02). The pattern of "ship enough samples that the addon works out of box without external assets" is shared. |

The audit deliverable converts this into a structured per-pattern report with Backlog seeds for the PARTIAL items.

---

## 7. Bitmask PNG Generator Spec (D-85, TEMPLATE-02)

Per D-85, extend `addons/penta_tile/_generate_bitmasks.py` with three new generator functions and a new helper. This section provides the Python pseudocode the executor copies into a Wave 3 task.

### 7.1 New helper: `draw_47_blob_silhouette(draw, col, row, mask)`

Draws an 8-bit Moore silhouette per slot. Mask is in D-76 ordering. Mask is assumed to already be collapse-rule-valid (caller filters; helper does not validate).

```python
def draw_47_blob_silhouette(draw: ImageDraw.ImageDraw, col: int, row: int, mask: int) -> None:
    """Fill quadrants + edge strips of slot (col, row) per an 8-bit Moore mask.

    Mask bits (D-76 ordering):
      Edges:   N=1, E=2, S=4, W=8
      Corners: NE=16, SE=32, SW=64, NW=128

    Caller must pre-collapse the mask via the BorisTheBrave rule
    ("corner only valid if both adjacent edges set"); this helper
    does not validate.

    Composition strategy for the greybox:
      - Always fill the CENTER (a 16x16 square at pixels 8..23 in both axes)
        so an isolated cell (mask=0) shows a self-contained silhouette.
      - For each set edge bit, fill a half-tile rectangle on that side.
      - For each set corner bit (post-collapse), fill the corresponding
        16x16 quadrant.

    Result: a fully-solid 32x32 only when mask=255 (0xFF after collapse,
    requires all 4 edges + all 4 corners). Other masks show partial
    silhouettes that visually communicate "which neighbors are connected."
    """
    x0, y0 = col * TILE, row * TILE
    half = TILE // 2  # = 16

    # Always-on center hint: a 16x16 core so isolated cells are visible.
    draw.rectangle((x0 + half // 2, y0 + half // 2,
                    x0 + TILE - half // 2 - 1,
                    y0 + TILE - half // 2 - 1),
                   fill=GREY)

    # Edge strips (8 px wide, overlapping the center hint to feel continuous).
    if mask & 1:    # N
        draw.rectangle((x0 + half // 2, y0,
                        x0 + TILE - half // 2 - 1, y0 + half - 1),
                       fill=GREY)
    if mask & 2:    # E
        draw.rectangle((x0 + half, y0 + half // 2,
                        x0 + TILE - 1, y0 + TILE - half // 2 - 1),
                       fill=GREY)
    if mask & 4:    # S
        draw.rectangle((x0 + half // 2, y0 + half,
                        x0 + TILE - half // 2 - 1, y0 + TILE - 1),
                       fill=GREY)
    if mask & 8:    # W
        draw.rectangle((x0, y0 + half // 2,
                        x0 + half - 1, y0 + TILE - half // 2 - 1),
                       fill=GREY)

    # Corner quadrants (16x16). Caller has pre-collapsed; if a corner bit
    # is set it implies both adjacent edges are also set.
    if mask & 16:   # NE
        draw.rectangle((x0 + half, y0, x0 + TILE - 1, y0 + half - 1), fill=GREY)
    if mask & 32:   # SE
        draw.rectangle((x0 + half, y0 + half, x0 + TILE - 1, y0 + TILE - 1), fill=GREY)
    if mask & 64:   # SW
        draw.rectangle((x0, y0 + half, x0 + half - 1, y0 + TILE - 1), fill=GREY)
    if mask & 128:  # NW
        draw.rectangle((x0, y0, x0 + half - 1, y0 + half - 1), fill=GREY)
```

**Note on the "center hint":** the always-on center 16×16 is what makes mask=0 (isolated tile) visible. Without it, an isolated cell would render as 4 transparent quadrants + 4 transparent edge strips = nothing. Phase 2's lessons-learned (UAT bug class #6 — "1×1, 1×N lines didn't render") apply here: a single-grid logic-painted cell with mask=0 MUST be visible.

**Alternative simpler design** the planner may prefer: **always draw the full 32×32 grey square** for ALL 47 valid configurations. Reasoning: per Phase 2 UAT bug class #5 (`gen_wang_2_corner` switched to fully-solid 32×32 because single-grid can't compose partial fills), single-grid layouts should ALL be fully solid. The mask is encoded by atlas POSITION, not silhouette. The silhouette is purely artist-facing.

I lean toward the **fully-solid simpler design** for consistency with `gen_wang_2_corner` and `gen_minimal_3x3` — it's strictly safer and matches Phase 2 conventions. **My recommended final form:**

```python
def draw_47_blob_silhouette(draw, col, row, mask):
    """Solid 32x32 grey silhouette per atlas slot.

    The mask is encoded by atlas POSITION only (per the layout's
    _MASK_TO_ATLAS dict). The silhouette is solid grey so single-grid
    rendering composes correctly (no transparent quadrants / edge
    artifacts). mask is unused for silhouette but kept for callsite
    symmetry (matches Phase 2's draw_edge_mask convention).
    """
    x0, y0 = col * TILE, row * TILE
    draw.rectangle((x0, y0, x0 + TILE - 1, y0 + TILE - 1), fill=GREY)
```

This matches `gen_wang_2_corner`'s solid-32×32 fill exactly. Simpler. Phase 2's UAT bug class #5 closure says: "single-grid can't compose partial fills." 47-blob is single-grid (D-82). Therefore: solid.

Plan-phase decides between the two designs. I recommend SOLID.

### 7.2 New generator functions

```python
def gen_blob_47_godot() -> Image.Image:
    """7x7 atlas (BorisTheBrave canonical packing, with 2 duplicates of empty
    tile_0). 47 used cells + 2 unused. Solid 32x32 silhouettes per slot;
    mask encoded by atlas POSITION via the layout's _MASK_TO_ATLAS dict.

    Atlas-occupancy gaps (the 2 unused cells at canonical Caeles positions)
    stay transparent.
    """
    img = new_atlas(7, 7)  # = 49 cells total
    draw = ImageDraw.Draw(img)
    # Plan-phase locks the (col, row) -> mask mapping in concert with the
    # layout's _MASK_TO_ATLAS dict. Iterate the 47 valid mask positions and
    # call draw_47_blob_silhouette(draw, col, row, mask). Skip the 2 dup-of-
    # empty-tile-0 cells (or fill them too — they harmlessly duplicate slot 0).
    for (col, row, mask) in _CANONICAL_47_BLOB_GODOT:  # plan-phase locks this list
        draw_47_blob_silhouette(draw, col, row, mask)
    return img


def gen_tilesetter_wang_15() -> Image.Image:
    """6x3 atlas (5x3 main + 1 stray-fill column at col 5). 16 cells total;
    15 main slots use Phase 2's draw_corner_mask helper, +1 stray-fill at
    Vector2i(5, 0) using draw_edge_mask (solid 32x32).

    Atlas-occupancy gaps: rows 1-2 of col 5 stay transparent.
    """
    img = new_atlas(6, 3)
    draw = ImageDraw.Draw(img)
    # 15 main slots — plan-phase locks (col, row) -> mask from the Tilesetter
    # primary source (D-86 outcome). For the 5x3 grid, iterate all (col, row)
    # in [0,5)x[0,3) and call draw_corner_mask with the mask from _MASK_TO_ATLAS.
    for (col, row, mask) in _TILESETTER_WANG_15_LAYOUT:  # plan-phase locks
        draw_corner_mask(draw, col, row, mask)
        draw_slot_outline(draw, col, row)
    # Stray-fill slot at Vector2i(5, 0) — solid 32x32.
    draw_edge_mask(draw, 5, 0, 0)  # mask unused; produces solid square
    draw_slot_outline(draw, 5, 0)
    return img


def gen_tilesetter_blob_47() -> Image.Image:
    """11x5 atlas with sub-block gaps. 47 used cells + 8 transparent gaps.

    Atlas occupancy (per Tilesetter primary source — D-86 outcome):
      col   0 1 2 3 4 5 6 7 8 9 10
      row 0 # # # # # # # # # # .
      row 1 # # # # # # # # # # .
      row 2 # # # # # # # # # # #
      row 3 # # # # # # # # # # #
      row 4 . . . . # # # # # . .
    """
    img = new_atlas(11, 5)
    draw = ImageDraw.Draw(img)
    for (col, row, mask) in _TILESETTER_BLOB_47_LAYOUT:  # plan-phase locks
        draw_47_blob_silhouette(draw, col, row, mask)
        draw_slot_outline(draw, col, row)
    return img
```

### 7.3 Updated `main()` — three new `.save()` calls

```python
# Append to main() in _generate_bitmasks.py:
gen_blob_47_godot().save(OUT_LAYOUTS / "penta_tile_layout_blob_47_godot.png")
gen_tilesetter_wang_15().save(OUT_LAYOUTS / "penta_tile_layout_tilesetter_wang_15.png")
gen_tilesetter_blob_47().save(OUT_LAYOUTS / "penta_tile_layout_tilesetter_blob_47.png")

# Update final print:
print("Generated 17 bitmask PNGs at:", OUT_LAYOUTS)
```

---

## 8. Test Pattern Recommendations

Phase 2's `comprehensive_bitmask_test.gd` exercises 16 patterns. For 47-blob coverage, all 256 masks are addressed by the unit-level collapse-completeness test (per D-78). The composed-canvas pattern matrix needs additions to exercise visual edge cases the existing 16 patterns don't hit.

### 8.1 New patterns required

| Pattern name | Cells | Why needed (which 47-blob masks it exercises) |
|--------------|-------|-----------------------------------------------|
| `corner_with_both_edges` | `[(0,0), (1,0), (0,1), (1,1)]` (2×2 block) | The center cell (e.g. cell `(0,0)` looking at `(1,1)`) has both `S` and `E` set AND `SE` set — exercises the **corner-survives-collapse** branch of D-78. The 2×2 already covers this in part, but the ADDITIONAL diagonal sample is what 47-blob layouts need. **The 16-pattern matrix already includes 2×2; this is here for emphasis only — verify the test asserts diagonal-corner correctness, not just rectangle-fill correctness.** |
| `diagonal_only_no_edge` | `[(0,0), (1,1)]` (already in matrix as `diag_pair`) | A cell at `(0,0)` looking at `(1,1)` has `SE` corner candidate but NEITHER `S` NOR `E` is set — exercises the **corner-collapses-to-zero** branch. Verify 47-blob layout still dispatches correctly (mask=0 for `(0,0)` → isolated tile slot). |
| `plus_with_diagonals` | `[(1,0), (0,1), (1,1), (2,1), (1,2), (0,0), (2,0), (0,2), (2,2)]` (3×3 full) | Center cell `(1,1)` has all 8 Moore neighbors set — mask=255 (fully connected). All edges + all corners set + all corners survive collapse. Exercises the "fully-connected" slot of the 47-blob layout. **Existing `3x3` pattern covers this**; verify the assertion specifically checks that `(1,1)` dispatches to the "fully connected" mask=255 atlas slot. |
| `hollow_3x3_ring` | `[(0,0), (1,0), (2,0), (0,1), (2,1), (0,2), (1,2), (2,2)]` (3×3 minus center) | Each ring cell has 1-2 painted neighbors with characteristic edge+corner patterns; center cell is unpainted → diagonal neighbors of corner cells (e.g. cell `(0,0)`'s `SE` neighbor at `(1,1)` is unpainted) — exercises the "corner adjacent to a hole" silhouette. **NEW pattern** — extend the matrix. |
| `large_5x5_with_hole` | `_rect(0,0,5,5)` minus `[(2,2)]` | Same shape as `penta_ground_hollow_test.gd` but for 47-blob. Center cell hole means cells around it have characteristic mask values that DON'T appear in any rectangle. **NEW pattern** — extend the matrix. Critical for 47-blob: the hole's adjacent cells exercise corner-collapse boundary cases. |

### 8.2 Test patterns NOT needed

- `1×1`, `1×N`, isolated cells — already covered by Phase 2's `1x1`, `line_h_5`, `line_v_5`, `3_isolated`. These cells have mask=0 in 47-blob layouts; the existing assertion that "every user-painted single-grid cell renders" catches the dispatch bug from Phase 2 UAT class #6.
- Most rectangles — adequately covered by Phase 2's `2x2`, `3x3`, `4x4`, `5x5`. The internal cells of each rectangle exercise different mask values in the 4 corner classes (TL, TR, BL, BR) and the 4 edge classes (T-edge, R-edge, B-edge, L-edge) and the 1 fully-interior class (mask=255).

### 8.3 Recommended new test files

| Test | What it asserts | Template |
|------|-----------------|----------|
| `blob_47_collapse_test.gd` | All 256 masks → `_collapse_8bit_moore()` produces a key in `_MASK_TO_ATLAS`. Catches dict transcription errors per D-78. | New unit test — no rendering, just mask-table validation |
| Add `Blob47Godot`, `TilesetterWang15`, `TilesetterBlob47` to `comprehensive_bitmask_test.gd`'s `layouts` array | Pattern × layout matrix coverage — bbox, solidity, no out-of-bounds | Existing test, extend |
| `blob_47_hollow_test.gd` | A 5×5 painted rectangle minus `(2,2)` — opaque-pixel bbox + hole emptiness assertions | Mirror `penta_ground_hollow_test.gd` |

---

## 9. Pitfall Crosswalk

> **CLAUDE.md "Critical Pitfalls"** is the canonical numbering used here (numbered 1-10, mapped to PITFALLS.md research where applicable but **renumbered** in CLAUDE.md). Each pitfall is mapped to its Phase 3 relevance.

| # | Pitfall | Applies to Phase 3 | Mitigation |
|---|---------|-------------------|------------|
| 1 | `alternative_tile` bit packing | **YES** (mild) — every Phase 3 layout populates `PentaTileAtlasSlot` with `transform_flags = 0` and `alternative_tile = 0`. No rotation reuse, but **the assertion `alt_id < 4096`** in `_pack_alternative` should still hold; layouts that hand-construct `PentaTileAtlasSlot` should not bypass it. | All 3 layouts set `slot.transform_flags = 0` directly — no `_pack_alternative` call needed for greybox slots. |
| 2 | Variation determinism (`randi()` shimmer) | **NO** — none of the 3 Phase 3 layouts introduce variation banks. Document the rule in each layout's class doc-comment as a forward-compat note, but no actual variation work. | Class doc-comments mention "Variation banks deferred to v2 backlog (VAR-PIXEL-01)." |
| 3 | Resource property renames orphan saved scenes | **NO** — Phase 3 introduces 3 NEW `Resource` subclasses (no renames). REQUIREMENTS.md TBT-04/DOC-05 wording change is markdown-only, no code rename. | N/A this phase. |
| 4 | Setter loops + `Resource.changed` storms | **MILD** — all 3 layouts inherit `bitmask_template` from `PentaTileLayout` base. The base already has the idempotence guard + disconnect-before-reconnect pattern (verified at `penta_tile_layout.gd:15-20`). New layouts add no new `@export` properties (no setters to worry about). | Inherited base behavior is correct. |
| 5 | Non-rotating tileset table | **MILD** — TilesetterWang15 has 15 tiles + 1 stray-fill (16 total). Blob47Godot has 47. TilesetterBlob47 has 47. All three are HAND-WRITTEN `_MASK_TO_ATLAS` tables (no rotation reuse). The mask-0 special case is the FIRST line of each `mask_to_atlas`. Hand-written tables risk transcription errors. | Plan-phase MUST add the unit test from D-78 (256-mask collapse-completeness) for both 47-blob layouts. For TilesetterWang15, add a unit test that asserts `_MASK_TO_ATLAS` has all 16 keys (0-15) populated. |
| 6 | Top-tile authoring | **NO** — Phase 3 layouts do not introduce top-tile concepts. v2 backlog. | N/A. |
| 7 | `TileMapLayer.visible = false` cleanup | **NO** — already mitigated in Phase 1/2; preserved by Phase 3. | Inherited. |
| 8 | **Single-grid layouts only render LOGIC-painted cells** | **YES, CRITICAL** — all 3 Phase 3 layouts are `is_dual_grid() == false` per D-82. The layer's `_paint_via_layout` line 262 short-circuit prevents background extension. **Plan-phase verifies this is preserved when 47-blob's 8-Moore neighbor fan-out lands** (Finding 1 from §5: 4-cardinal → 8-Moore). | Audit during Wave 0c that the affected-cell expansion (4→8 neighbors) does NOT bypass the line-262 logic-painted-only gate. The new diagonal cells in the affected set are correctly skipped at line 262 because they're not logic-painted. |
| 9 | `mask=0` is NOT "erase" for single-grid logic-painted cells | **YES, CRITICAL** — per D-79 (TilesetterWang15 dispatches mask=0 → `Vector2i(5, 0)`) and D-80 (47-blob layouts dispatch mask=0 → "lonely tile" atlas slot). All 3 Phase 3 layouts MUST handle mask=0 in `mask_to_atlas`. | Per-layout test: paint a single isolated cell (1x1 pattern) and assert the visual layer renders SOME atlas slot (not empty). Already covered by `comprehensive_bitmask_test.gd`'s `1x1` case once the new layouts are added to its `layouts` list. |
| 10 | Penta authored slots need canonical-silhouette enforcement | **NO** — Phase 3 layouts are NOT Penta. They don't use rotation flags. They don't synthesize. | N/A this phase. |

---

## 10. Validation Architecture

> Per `.planning/config.json` `workflow.nyquist_validation = true`, this section is required.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Godot 4.6 headless (`Godot --headless --script ...`) — no GUT, project policy |
| Config file | None — tests are standalone `extends SceneTree` `_initialize` scripts in `addons/penta_tile/tests/` |
| Quick run command | `.\addons\penta_tile\tests\run_tests.ps1 -Test <test_name>` |
| Full suite command | `.\addons\penta_tile\tests\run_tests.ps1` (12 tests + Wave 0+ additions) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| **TBT-03** (Blob47Godot) | mask 0..255 → `_collapse_8bit_moore` produces a key in `_MASK_TO_ATLAS` | unit | `run_tests.ps1 -Test blob_47_collapse_test` | ❌ Wave 0 / Wave 4 |
| **TBT-03** | Composed-canvas: every painted cell renders, solid 32×32, no out-of-bounds, bbox matches | rendering | `run_tests.ps1 -Test comprehensive_bitmask_test` (extended with Blob47Godot in matrix) | ✅ exists; needs Phase 3 entries |
| **TBT-03** | Hollow 5×5 ring renders correctly (no diagonal-bleed bugs) | rendering | `run_tests.ps1 -Test blob_47_hollow_test` | ❌ Wave 0 / Wave 4 |
| **TBT-01** (TilesetterWang15) | mask 0..15 → all dict keys populated; `mask_to_atlas(0)` returns `Vector2i(5, 0)` | unit | `run_tests.ps1 -Test tilesetter_wang_15_dispatch_test` | ❌ Wave 0 / Wave 4 |
| **TBT-01** | Composed-canvas matrix coverage | rendering | `comprehensive_bitmask_test` (extended) | ✅ extends |
| **TBT-02** (TilesetterBlob47) | All 256 masks → collapse → valid dict entry | unit | `run_tests.ps1 -Test tilesetter_blob_47_collapse_test` (or shared with `blob_47_collapse_test` if collapse algo is identical and only dict differs) | ❌ Wave 0 / Wave 4 |
| **TBT-02** | Composed-canvas matrix coverage | rendering | `comprehensive_bitmask_test` (extended) | ✅ extends |
| **TEMPLATE-02** | 3 bundled PNGs exist at expected paths with expected dimensions and slot positions match `_MASK_TO_ATLAS` | rendering / file | `run_tests.ps1 -Test bitmask_bounds_test` (extended with Phase 3 PNG paths) | ✅ exists; needs Phase 3 entries |
| **TBT-04** (rewritten) | `addons/penta_tile/README.md` contains the design-inspiration footnote line. NO `addons/penta_tile/ATTRIBUTION.md` exists. | file existence + grep | `Test-Path` checks (PowerShell), or in `run_tests.ps1` add a short `readme_footnote_test` | ❌ Wave 4 |
| **DOC-05** (rewritten) | Same as TBT-04 | file existence + grep | Same | ❌ Wave 4 |
| **D-87 prerequisite** | After patching `_mark_affected_single_grid_cells` to 8-Moore, painting cell `(0,0)` re-renders cells at `(±1, ±1)` | rendering | New test: `single_grid_8_moore_propagation_test` | ❌ Wave 0c |

### Sampling Rate

- **Per task commit:** `run_tests.ps1 -Test <relevant_test>` (~5-15s per test)
- **Per wave merge:** `run_tests.ps1` (full suite, ~3-5 minutes given Phase 2's 12 tests + Phase 3 additions ~6 new tests = 18 total)
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 / Wave 4 Gaps (test files missing)

- [ ] `addons/penta_tile/tests/blob_47_collapse_test.gd` — covers TBT-03 + TBT-02 collapse rule (D-78)
- [ ] `addons/penta_tile/tests/blob_47_hollow_test.gd` — covers TBT-03 hollow rendering (Phase 2 lessons)
- [ ] `addons/penta_tile/tests/tilesetter_wang_15_dispatch_test.gd` — covers TBT-01 dict completeness + stray-fill dispatch (D-79)
- [ ] `addons/penta_tile/tests/single_grid_8_moore_propagation_test.gd` — covers D-87 / Finding 1 of §5 — verifies the affected-cell loop fix
- [ ] Extend `addons/penta_tile/tests/comprehensive_bitmask_test.gd` `layouts` array with `Blob47Godot`, `TilesetterWang15`, `TilesetterBlob47` (3 entries; +5 new patterns from §8.1 if planner adopts them = 21 patterns × 8 layouts = 168 combos)
- [ ] Extend `addons/penta_tile/tests/bitmask_bounds_test.gd` with the 3 new bundled PNG paths

**Existing test infrastructure templates** (cite when implementing):
- `addons/penta_tile/tests/comprehensive_bitmask_test.gd` — pattern × layout matrix (the canonical for new layouts)
- `addons/penta_tile/tests/penta_ground_hollow_test.gd` — fixture-based hollow test (template for `blob_47_hollow_test.gd`)
- `addons/penta_tile/tests/bitmask_bounds_test.gd` — bundled PNG slot-position verification (template for TEMPLATE-02 visual regression)

---

## 11. Open Questions for the Planner

1. **D-86 gate routing.** The most critical: §3 reports Tilesetter primary-source research as INCONCLUSIVE. Plan-phase MUST surface (a)/(b)/(c) options to the user before generating Wave 1 Tilesetter tasks. **Recommendation: prefer (a) — user provides their own Tilesetter export — because it produces a primary-source artifact that satisfies D-75 cleanly.** If user prefers (b) defer-to-v0.3+, Phase 3 ships only Blob47Godot.

2. **Blob47Godot atlas dimensions** (D-74). 7×7 (BorisTheBrave canonical, 2 dup empty cells) vs 6×8 (BorisTheBrave canonical, 1 dup mask 255) vs 12×4-ish (Godot ecosystem-familiar matching `godot3_3x3_minimal.tres` shape). **Recommendation: 7×7** — see §4.3.

3. **Bit-ordering verification for the 47 valid masks.** §4.2 provides a CR31→D76 conversion utility. Plan-phase must run it (in Python or by hand) on the CR31 47-mask list to produce the D-76 47-mask list for the layout's `_MASK_TO_ATLAS` keys. **My provisional D-76 47-mask list (computed from the CR31 ordering):** plan-phase should re-derive and verify, not blindly trust. The conversion is mechanical but error-prone if done at agentic-LLM time without a unit test.

4. **47-blob silhouette: solid vs partial.** §7.1 documents two options. **Recommendation: solid 32×32** (matches `gen_wang_2_corner` and Phase 2 lessons-learned). The partial-silhouette design is more visually informative but has the same single-grid composition risk that Phase 2 UAT class #5 surfaced.

5. **Affected-cell loop fix: hardcoded 8-Moore vs layout virtual** (§5 Finding 1). **Recommendation: hardcoded 8-Moore** — the cost is bounded (the line-262 logic-painted-only gate elides waste), and the alternative (layout virtual) adds API surface that D-77's "compute_mask stays local" preference subtly disfavors.

6. **TBT-04 + DOC-05 rewrite wording.** Per D-72/D-73, the new policy is "1-line footnote in README acknowledging TBT as design inspiration." **Suggested wording for the README footnote:**
   > *"Layout patterns inspired by the design choices in [TileBitTools](https://github.com/dandeliondino/tile_bit_tools) (MIT, Godot 4 inspector plugin); slot tables sourced independently from each format's primary reference (BorisTheBrave for 47-blob; Tilesetter manual for Tilesetter Wang/Blob)."*
   
   Plan-phase locks the final phrasing.

7. **Directory rename or keep slug?** D-72 makes this Claude's discretion. **Recommendation: KEEP `03-tilebittools-sourced-layouts/`** for this phase — rename overhead (multiple file `git mv`s, link updates in adjacent docs, planner re-binding) outweighs the benefit. Future phases (e.g. v0.3+) can adopt the new slug convention without retroactively renaming Phase 3.

8. **PDF / video tutorial frame-capture as Tilesetter primary source?** If the user rejects all three D-86 options, plan-phase could propose: open the official Tilesetter 2.0 tutorial video (https://www.youtube.com/watch?v=04hNF4BtTUE), screenshot the Set View at the 3:10 timestamp where the tutorial demonstrates Wang Set creation, and use that screenshot as a primary source. **NOT my recommendation** — frame-capture is fragile (video gets re-encoded, timestamp shifts), and the screenshot doesn't encode all 47 mask configurations.

---

## Architecture Patterns (Phase 3 layouts)

### System Architecture Diagram

```
USER PAINT EVENT
     │
     ▼
PentaTileMapLayer.set_cell()    ◄─── existing v0.1 native API
     │
     ▼
Godot fires _update_cells(coords, false)
     │
     ▼
_mark_affected_single_grid_cells(affected, logic_cell)    ◄─── §5 Finding 1: NEEDS 8-Moore EXTENSION
     │   marks cell + 8 Moore neighbors (not just 4 cardinal)
     ▼
For each display_cell in affected:
     │
     ▼
_paint_via_layout(display_cell, active_layout, source, sample_fn)
     │
     ├─── line 262: if not is_dual_grid() AND not painted: return  (Pitfall #8)
     │
     ▼
mask = active_layout.compute_mask(display_cell, sample_fn)
     │   For 47-blob: returns RAW 8-bit Moore mask (D-76 ordering)
     │   For TilesetterWang15: returns 4-bit corner mask
     ▼
slot = active_layout.mask_to_atlas(mask, strip_index=0)
     │
     │   For 47-blob layouts:
     │     1. _collapse_8bit_moore(mask) per D-78
     │     2. _MASK_TO_ATLAS[collapsed_mask]
     │
     │   For TilesetterWang15:
     │     1. if mask == 0: return Vector2i(5, 0) per D-79  (Pitfall #9)
     │     2. else: _MASK_TO_ATLAS[mask]
     ▼
_paint_with_slot(_primary_layer, slot, display_cell, source)
     │
     ▼
RENDERED OUTPUT: cells with correct atlas coords + transform_flags=0
```

### Recommended File Structure (Phase 3 additions)

```
addons/penta_tile/
├── layouts/
│   ├── penta_tile_layout.gd                         # base (unchanged)
│   ├── penta_tile_layout_blob_47_godot.gd           # NEW (Phase 3 Wave 1)
│   ├── penta_tile_layout_blob_47_godot.png          # NEW (Phase 3 Wave 3, gen'd)
│   ├── penta_tile_layout_tilesetter_wang_15.gd      # NEW (Phase 3 Wave 2)
│   ├── penta_tile_layout_tilesetter_wang_15.png     # NEW (Phase 3 Wave 3, gen'd)
│   ├── penta_tile_layout_tilesetter_blob_47.gd      # NEW (Phase 3 Wave 2)
│   ├── penta_tile_layout_tilesetter_blob_47.png     # NEW (Phase 3 Wave 3, gen'd)
│   └── (other layouts unchanged)
├── _generate_bitmasks.py                            # extended (Phase 3 Wave 3)
├── penta_tile_map_layer.gd                          # 1-line patch in _mark_affected_single_grid_cells (Phase 3 Wave 0c)
├── README.md                                        # +1 line footnote (Phase 3 Wave 3)
└── tests/
    ├── comprehensive_bitmask_test.gd                # extended with 3 new layouts
    ├── bitmask_bounds_test.gd                       # extended with 3 new PNG paths
    ├── blob_47_collapse_test.gd                     # NEW
    ├── blob_47_hollow_test.gd                       # NEW
    ├── tilesetter_wang_15_dispatch_test.gd          # NEW (only if D-86 resolves to (a) or (c))
    ├── single_grid_8_moore_propagation_test.gd      # NEW
    └── run_tests.ps1                                # extended with new test names

.planning/phases/03-tilebittools-sourced-layouts/
└── 03-TBT-DEEP-AUDIT.md                             # NEW (Phase 3 Wave 0b)
```

### Anti-Patterns to Avoid

- **DO NOT lift `_tiles` data from `tile_bit_tools/templates/*.tres`** (D-73). Even though the data is empirically correct and MIT-licensed, the user policy is explicit: independent primary-source authoring.
- **DO NOT add a 47-blob runtime decoder** — the BorisTheBrave collapse algorithm is so simple (~10 LOC) that runtime computation is fine, but the dispatch dict must be pre-computed (`const _MASK_TO_ATLAS`).
- **DO NOT introduce a generic 8-Moore helper on `PentaTileLayout` base** — D-77 forbids it. Each layout inlines its own `compute_mask`.
- **DO NOT create `addons/penta_tile/ATTRIBUTION.md`** (D-73). The README footnote is the only credit.
- **DO NOT prefix Phase 3 layouts with "Penta"** in the type's _semantic_ sense (CLAUDE.md "Coined-Term Discipline"). The class names use the `PentaTile*` prefix (project namespace) but the format names ("Blob47Godot", "TilesetterWang15") describe the FORMAT, not the Penta archetype.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| 256→47 collapse algorithm | A custom rule engine or per-mask exception table | The 10-LOC pseudocode from §4.1 | The algorithmic rule is total and idempotent; a table is more error-prone. |
| `_MASK_TO_ATLAS` dict transcription | A "smart" deriver that infers slot positions from silhouette analysis | A hand-written `const Dictionary` checked in unit tests (per D-78) | Deriving the slot table from silhouettes assumes a canonical silhouette mapping that may not exist for every layout (Tilesetter doesn't publish one). |
| Bundled PNG generation | A new image-generation tool / library | Extend `_generate_bitmasks.py` (Pillow already in dependencies) | Phase 2 established the pattern; reuse it. |
| Affected-cell radius helper | Per-layout neighbor-list overrides | Hardcoded 8-Moore in `_mark_affected_single_grid_cells` (or layout virtual if planner prefers) | The cost difference between 4-cardinal and 8-Moore is bounded; the simple fix is correct. |
| Tilesetter slot tables | Empirical fingerprinting (Claude/AI infers) | User-provided Tilesetter export (D-86 option a) OR defer (D-86 option b) | Per D-75 / D-86, this is gated. NEVER fall back to TBT data lift (D-73). |

---

## Common Pitfalls (Phase 3 specific)

### Pitfall A: Bit-ordering confusion between CR31 and D-76

**What goes wrong:** plan-phase or executor copies the CR31 47-mask list verbatim into D-76's `_MASK_TO_ATLAS`. The dict has 47 entries but they're keyed on the WRONG ordering — `compute_mask` returns D-76 masks, the dict expects CR31 masks, lookup fails for ~half the configurations.

**Why it happens:** BorisTheBrave's reference uses CR31 clockwise; D-76 uses cardinal-anchored. Both describe the same 47 valid configurations, but the integer keys differ.

**How to avoid:** Use the conversion utility in §4.2 once, programmatically. Add a unit test (`blob_47_collapse_test.gd`) that enumerates all 256 D-76 masks → applies collapse → asserts the result is in `_MASK_TO_ATLAS`. If any mask fails, the dict has a transcription error.

**Warning signs:** 47-blob layout renders incorrectly for a specific subset of patterns (e.g., diagonal-only shapes work but mixed edge+corner shapes don't).

### Pitfall B: 4-cardinal affected-cell loop "works for the demo"

**What goes wrong:** §5 Finding 1's prerequisite task is skipped because the demo's painted patterns are mostly rectangles, where 4-cardinal updates happen to suffice. The 47-blob bug only surfaces for irregular paint patterns (L-shapes, plus-shapes with diagonals).

**Why it happens:** Phase 2's existing single-grid layouts (Wang2Edge, Wang2Corner, Min3x3) all use 4-cardinal-or-fewer neighborhoods. The 4-cardinal radius was never wrong; it was tested adequately. 47-blob is the FIRST 8-Moore layout. Easy to miss.

**How to avoid:** Wave 0c's prerequisite task is non-skippable. Add `single_grid_8_moore_propagation_test.gd` that paints cell `(0,0)` then asserts cell `(1,1)` (already painted) re-renders with the new mask.

**Warning signs:** Painting an L-shape produces visually-correct rectangles but visually-incorrect diagonals at the L's corner. Surfaces during pattern matrix testing.

### Pitfall C: `mask_to_atlas(0)` returns null for a 47-blob layout

**What goes wrong:** an executor reads D-80 ("isolated cell maps to a valid 47-blob slot") but their `_MASK_TO_ATLAS` dict transcription accidentally maps `0` to `null` instead of the BorisTheBrave canonical "lonely tile" coords. A logic-painted isolated cell drops at line 294 of `_paint_via_layout` and renders nothing.

**Why it happens:** D-80 is subtle — mask=0 IS a valid 47-blob configuration (the "lonely tile"). Easy to confuse with Pitfall #9 (mask=0 short-circuit) and decide "I'll let the layer handle it."

**How to avoid:** D-81 codifies "all Pitfall #9 dispatch lives in each layout's `mask_to_atlas`." The `comprehensive_bitmask_test.gd`'s `1x1` pattern catches this — every painted single-grid cell must render.

**Warning signs:** Single isolated cells (1×1 pattern) render as empty for the 47-blob layouts but render fine for Wang2Edge/Wang2Corner/Min3x3.

### Pitfall D: Tilesetter slot table guessed via TBT-style empirical inference (without user Tilesetter)

**What goes wrong:** Plan-phase doesn't surface the D-86 gate; instead it auto-routes to D-86 option (c) and the executor/agent attempts to "fingerprint" Tilesetter's export by analyzing TBT's `.tres` shape. The result is functionally identical to lifting TBT data — D-73 violation.

**Why it happens:** The path of least agentic resistance: TBT's data is right there, the math works, so why not? D-73 is the answer.

**How to avoid:** Plan-phase MUST surface D-86 explicitly. Plan-checker (per `.planning/config.json`) MUST verify no Tilesetter task references TBT `.tres` files in any code-generation step. If a Wave 1 Tilesetter task gets generated without explicit D-86 resolution, plan-checker rejects the plan.

**Warning signs:** A Phase 3 plan task description mentioning `tile_bit_tools/templates/tilesetter_*.tres` — that's the TBT data, banned from lift.

---

## Code Examples

Verified patterns from official sources and the existing PentaTile codebase.

### Example 1: Blob47Godot layout skeleton (Wave 1 task template)

```gdscript
@tool
## Blob47Godot — 47-tile blob layout, 8-bit Moore mask, single-grid.
##
## Mask convention (D-76): N=1, E=2, S=4, W=8, NE=16, SE=32, SW=64, NW=128.
## NOT the canonical CR31 clockwise ordering — see _collapse_8bit_moore for
## the conversion. The 256→47 collapse rule per BorisTheBrave's reference
## (https://www.boristhebrave.com/permanent/24/06/cr31/stagecast/wang/blob.html):
## "A corner bit only matters if both adjacent edges are set."
##
## Atlas: 7×7 (Caeles canonical packing; 2 cells duplicate the empty tile_0).
## Single-grid: yes — paints directly at the logic cell.
class_name PentaTileLayoutBlob47Godot
extends PentaTileLayout

const _N := Vector2i(0, -1)
const _E := Vector2i(1, 0)
const _S := Vector2i(0, 1)
const _W := Vector2i(-1, 0)
const _NE := Vector2i(1, -1)
const _SE := Vector2i(1, 1)
const _SW := Vector2i(-1, 1)
const _NW := Vector2i(-1, -1)

# 47 entries keyed on D-76-ordered, COLLAPSED masks → atlas (col, row) coords.
# Plan-phase locks this dict by running the CR31→D-76 conversion against
# BorisTheBrave's 47-mask list and the 7×7 Caeles packing.
const _MASK_TO_ATLAS: Dictionary = {
    0:   Vector2i(0, 0),    # mask=0 → "lonely tile" / isolated cell (D-80)
    # ... 46 more entries ...
    255: Vector2i(6, 6),    # mask=255 → "fully connected" tile
}


func is_dual_grid() -> bool:
    return false


func compute_mask(coord: Vector2i, sample_fn: Callable) -> int:
    var mask := 0
    if sample_fn.call(coord + _N):  mask |= 1
    if sample_fn.call(coord + _E):  mask |= 2
    if sample_fn.call(coord + _S):  mask |= 4
    if sample_fn.call(coord + _W):  mask |= 8
    if sample_fn.call(coord + _NE): mask |= 16
    if sample_fn.call(coord + _SE): mask |= 32
    if sample_fn.call(coord + _SW): mask |= 64
    if sample_fn.call(coord + _NW): mask |= 128
    return mask


func mask_to_atlas(mask: int, _strip_index: int = 0) -> PentaTileAtlasSlot:
    var collapsed := _collapse_8bit_moore(mask)
    var slot := PentaTileAtlasSlot.new()
    slot.atlas_coords = _MASK_TO_ATLAS.get(collapsed, Vector2i(0, 0))   # mask=0 fallback per D-80
    slot.transform_flags = 0
    slot.alternative_tile = 0
    return slot


# D-78: 256→47 collapse via BorisTheBrave's algorithmic rule.
# A corner bit only survives if both adjacent edges are set.
static func _collapse_8bit_moore(raw: int) -> int:
    var n  := raw & 1
    var e  := raw & 2
    var s  := raw & 4
    var w  := raw & 8
    var collapsed := raw & 15  # edges pass through
    if n != 0 and e != 0 and (raw & 16)  != 0: collapsed |= 16
    if s != 0 and e != 0 and (raw & 32)  != 0: collapsed |= 32
    if s != 0 and w != 0 and (raw & 64)  != 0: collapsed |= 64
    if n != 0 and w != 0 and (raw & 128) != 0: collapsed |= 128
    return collapsed


func _default_bitmask_template_path() -> String:
    return "res://addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.png"


func _fallback_atlas_grid_size() -> Vector2i:
    return Vector2i(7, 7)
```

### Example 2: TilesetterWang15 layout skeleton (Wave 2 task template, only if D-86 resolves)

```gdscript
@tool
## TilesetterWang15 — Tilesetter's exported 15-tile Wang autotile + 1 stray-fill slot.
##
## Mask convention: 4-bit corner (NE=1, SE=2, SW=4, NW=8 per CR31 conventions
## already used by Wang2Corner). Single-grid: yes. Tilesetter exports a 5×3
## main grid; PentaTile reserves a 16th 'stray fill' slot at (5, 0) per D-79.
##
## Slot table sourced from: <plan-phase locks per D-86 outcome>.
class_name PentaTileLayoutTilesetterWang15
extends PentaTileLayout

const _NE := Vector2i(1, -1)
const _SE := Vector2i(1, 1)
const _SW := Vector2i(-1, 1)
const _NW := Vector2i(-1, -1)

const _STRAY_FILL_COORDS := Vector2i(5, 0)

# 15 entries keyed on 4-bit corner masks 1..15 → atlas (col, row) in the 5×3
# main grid. mask=0 dispatches to _STRAY_FILL_COORDS per D-79.
# Plan-phase locks this dict from Tilesetter's primary source (D-86 outcome).
const _MASK_TO_ATLAS: Dictionary = {
    # 1..15 entries — plan-phase locks
}


func is_dual_grid() -> bool:
    return false


func compute_mask(coord: Vector2i, sample_fn: Callable) -> int:
    var mask := 0
    if sample_fn.call(coord + _NE): mask |= 1
    if sample_fn.call(coord + _SE): mask |= 2
    if sample_fn.call(coord + _SW): mask |= 4
    if sample_fn.call(coord + _NW): mask |= 8
    return mask


func mask_to_atlas(mask: int, _strip_index: int = 0) -> PentaTileAtlasSlot:
    var slot := PentaTileAtlasSlot.new()
    if mask == 0:
        slot.atlas_coords = _STRAY_FILL_COORDS                # D-79
    else:
        slot.atlas_coords = _MASK_TO_ATLAS.get(mask, _STRAY_FILL_COORDS)
    slot.transform_flags = 0
    slot.alternative_tile = 0
    return slot


func _default_bitmask_template_path() -> String:
    return "res://addons/penta_tile/layouts/penta_tile_layout_tilesetter_wang_15.png"


func _fallback_atlas_grid_size() -> Vector2i:
    return Vector2i(6, 3)                                     # 5×3 main + 1 stray-fill column
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Phase 1's plan to transcribe slot tables FROM TBT `.tres` files | D-72/D-73's "primary-source-only" policy | 2026-04-28 (this discuss-phase) | Phase 3 needs an extra Wave 0a (Tilesetter research) and Wave 0b (TBT design audit). Net effect: more research work, less data-lift work. Final result is independently authored, not derived. |
| ATTRIBUTION.md called out as a separate doc deliverable (TBT-04, DOC-05 originals) | Single 1-line README footnote | 2026-04-28 | Less doc surface. REQUIREMENTS.md table updates required. |
| Phase 3 originally titled "TileBitTools-Sourced Layouts" | "Public-Convention Layouts (Blob47 + Tilesetter)" | 2026-04-28 | ROADMAP.md / STATE.md updates required. Reflects the format-first framing. |
| Affected-cell radius assumed 4-cardinal sufficient for ALL single-grid layouts | 8-Moore required for 47-blob layouts | This research (2026-04-28) | 1-line `_mark_affected_single_grid_cells` extension OR new layout virtual. Wave 0c prerequisite task. |

**Deprecated/outdated:**
- The `_decode_tbt_templates.py` script — was scoped in CONTEXT.md context but D-73 deletes it. Don't write it.
- The `addons/penta_tile/ATTRIBUTION.md` file — D-73 deletes the requirement.
- The original TBT-04 wording. The original DOC-05 wording.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | BorisTheBrave's 7×7 packing is the right atlas for `Blob47Godot` (vs 6×8 or 12×4) | §4.3 | Plan-phase picks a different packing → atlas dimensions in the layout's `_fallback_atlas_grid_size()` and the bundled PNG differ. Functionally correct, just different visual layout. LOW risk. |
| A2 | The "always solid 32×32 silhouette" design wins over "partial silhouettes per mask" for 47-blob bundled PNGs | §7.1 | If partial silhouettes are chosen, the helper code is more complex but produces a more informative artist-facing greybox. Visual choice; doesn't affect runtime correctness. LOW risk. |
| A3 | Hardcoded 8-Moore in `_mark_affected_single_grid_cells` is preferred over a layout virtual `affected_neighbor_offsets` | §5 Finding 1 | If layout virtual is preferred, an extra base-class API surface is added. Slightly more code; same correctness. LOW risk. |
| A4 | The Caeles 7×7 packing has 2 duplicate empty tile_0 cells (per BorisTheBrave's permanent page) | §4.3 | If wrong, atlas occupancy is different. MEDIUM risk — verify against actual BorisTheBrave page during plan-phase. |
| A5 | The CR31→D-76 bit-permutation in §4.2 is correct | §4.2 | If wrong, the `_MASK_TO_ATLAS` dict transcription is poisoned at the source. MEDIUM-HIGH risk — plan-phase should verify by hand against a few sample masks. The `blob_47_collapse_test` catches the symptom. |
| A6 | itsjavi/autotiler's hardcoded `drawCell()` calls match Tilesetter's actual export semantically (i.e. autotiler is a faithful clone of Tilesetter's algorithm) | §3 | If autotiler drifts from Tilesetter, even option (c) "empirical fingerprinting via autotiler" wouldn't match Tilesetter. Doesn't affect Phase 3 since D-86 prefers (a) user-provided exports. LOW risk. |
| A7 | TBT's `tilesetter_wang.tres` and `tilesetter_blob.tres` accurately reflect Tilesetter 2.0's export format | §3, §6 | If TBT was empirically fingerprinted against an older Tilesetter version, the slot tables in TBT may not match modern Tilesetter exports. Doesn't affect Phase 3 since D-73 forbids lifting TBT data anyway. LOW risk. |
| A8 | Plan-phase will choose option (a) at D-86 (user provides Tilesetter export) | §3 recommendation | If plan-phase picks (b) defer or (c) empirical, the Wave structure changes. Plan-phase decides based on user's response. NO RISK to research correctness — just informs Wave layout. |

**Empty-table check:** This table has 8 entries — none of them are "[ASSUMED]" tags in the colloquial sense; they're all explicit risk-tagged decisions. The verified facts (collapse algorithm pseudocode, BorisTheBrave's bit ordering, TBT source-tree map, pipeline audit findings) are CITED with URLs or file:line citations and don't need user confirmation.

---

## Sources

### Primary (HIGH confidence)

- **`addons/penta_tile/penta_tile_map_layer.gd`** (read 2026-04-28, lines 134-616) — pipeline audit findings (§5)
- **`addons/penta_tile/layouts/penta_tile_layout.gd`** (read 2026-04-28) — base class virtuals
- **`addons/penta_tile/layouts/penta_tile_layout_wang_2_corner.gd`** (read 2026-04-28) — closest precedent for Phase 3 layout shape
- **`addons/penta_tile/layouts/penta_tile_layout_dual_grid_16.gd`** (read 2026-04-28) — dispatch dict precedent
- **`addons/penta_tile/layouts/penta_tile_layout_minimal_3x3.gd`** (read 2026-04-28) — single-grid mask=0 precedent
- **`addons/penta_tile/layouts/penta_tile_layout_wang_2_edge.gd`** (read 2026-04-28) — edge-mask precedent
- **`addons/penta_tile/_generate_bitmasks.py`** (read 2026-04-28, full file 1-283) — extension target for D-85
- **`addons/penta_tile/penta_tile_atlas_slot.gd`** (read 2026-04-28) — return type for `mask_to_atlas`
- **`addons/penta_tile/tests/comprehensive_bitmask_test.gd`** (read 2026-04-28) — pattern × layout matrix template
- **`addons/penta_tile/tests/run_tests.ps1`** (read 2026-04-28, lines 1-60) — test runner conventions
- **`C:\Programming_Files\Godot\tile_bit_tools-main\addons\tile_bit_tools\templates\tilesetter_wang.tres`** (read 2026-04-28, full file) — confirmation that TBT's `.tres` data exists; D-73 forbids lifting (but reading is allowed for the audit)
- **TBT file inventory** via `find ... | wc -l` (run 2026-04-28) — verified 30 GD files + 12 templates + LOC counts
- **`.planning/research/PITFALLS.md`** (read 2026-04-28) — Phase 1 pitfall research, confirms PITFALLS.md numbering ≠ CLAUDE.md "Critical Pitfalls" numbering
- **`.planning/research/layouts/TILEBITTOOLS.md`** (read 2026-04-28, partial — first 1100 lines) — prior TBT audit, confirms the audit deliverable (D-84) extends prior work with ADOPT/PARTIAL/REJECT classification
- **`.planning/phases/02-native-layouts/02-UAT-LESSONS-LEARNED.md`** (read 2026-04-28) — Phase 2 hard-won pitfalls #8/#9/#10
- **CLAUDE.md** (read at session start) — project conventions, "Critical Pitfalls" #1-#10, Test Methodology, Coined-Term Discipline, Breaking Changes Policy

### Primary (HIGH-MEDIUM confidence — published references)

- **BorisTheBrave 47-blob permanent page** — https://www.boristhebrave.com/permanent/24/06/cr31/stagecast/wang/blob.html — bit ordering (CR31 clockwise: N=1, NE=2, E=4, SE=8, S=16, SW=32, W=64, NW=128), 7×7 and 6×8 packings, "All tiles are 32x32 pixels"
- **BorisTheBrave "Tileset Roundup"** — https://www.boristhebrave.com/2013/07/14/tileset-roundup/ — full 47-mask list (CR31 ordering): `{0, 2, 8, 10, 11, 16, 18, 22, 24, 26, 27, 30, 31, 64, 66, 72, 74, 75, 80, 82, 86, 88, 90, 91, 94, 95, 104, 106, 107, 120, 122, 123, 126, 127, 208, 210, 214, 216, 218, 219, 222, 223, 248, 250, 251, 254, 255}`; collapse rule "The corner tiles are only relevant if both edge tiles are solid"
- **Stormcloak Games — Blob layouts and tilesets** — https://stormcloak.games/2022/02/09/blob-layouts-and-tilesets — collapse rule paraphrase: "if top = 0, then top-left = 0, and top-right = 0"

### Secondary (MEDIUM confidence)

- **Tilesetter docs** — https://www.tilesetter.org/docs/ (and `/exporting`, `/generating_tilesets`, `/tileset_behavior`, `/working_with_tiles`) — confirms Wang Sets contain 16 tiles (Tilesetter's terminology) and Blob Sets have 47 tiles, but **NO canonical mask-to-coord mapping in any public Tilesetter document**. Per-page citations:
  - "Auto-tile bitmasks are already configured for Blob and Wang sets when exporting from the Set View" — https://www.tilesetter.org/docs/exporting (confirms Tilesetter has SOME canonical layout, but doesn't publish what it is)
  - "Wang Sets contain 16 tiles" — https://www.tilesetter.org/docs/generating_tilesets (Tilesetter's "16 tiles" includes the "stray fill"; without the stray fill it's 15, matching TBT's `tilesetter_wang.tres`)
- **itsjavi/autotiler README + app.js** — https://github.com/itsjavi/autotiler — confirms 5×3 input → 11×5 output dimensions match Tilesetter; **does NOT publish a mask-to-coord table** (uses hardcoded `drawCell()` image composition)
- **Enichan/blobator** — https://github.com/Enichan/blobator — alternative bit-numbering convention (`topLeft=1, top=2, ...` — different from CR31 and from D-76); **does NOT match Tilesetter's export format** (separate generator)
- **Steam Tilesetter discussion thread** — https://steamcommunity.com/app/1105890/discussions/0/1636417554430764528/ — no slot table; confirms community lacks a published mapping

### Tertiary (LOW confidence — flagged for verification by plan-phase)

- The CR31→D-76 bit-permutation in §4.2 — derived by hand; verify with sample masks before locking the `_MASK_TO_ATLAS` dict
- The 47-mask list in D-76 ordering — derive programmatically (run §4.2's conversion against the CR31 list)
- The exact (col, row) → mask mapping for the 7×7 Blob47Godot atlas — cited as "BorisTheBrave's reference" but the per-cell layout requires reading the rendered images on the BorisTheBrave page (verifiable via screenshot if needed)

---

## Metadata

**Confidence breakdown:**
- BorisTheBrave 47-blob math (collapse rule, 47 valid masks): **HIGH** — verified across BorisTheBrave permanent page, Tileset Roundup blog, Stormcloak Games. Convergent evidence.
- Phase 2 single-grid pipeline state: **HIGH** — read directly from current `penta_tile_map_layer.gd`. Source code is authoritative.
- TBT source tree: **HIGH** — read directly from local clone at `C:\Programming_Files\Godot\tile_bit_tools-main\`.
- **Tilesetter slot tables: LOW** — D-86 GATE, no primary source located. §3 documents the search.
- Atlas-grid choice for Blob47Godot (7×7 vs 6×8 vs 12×4): **MEDIUM** — recommendation made; plan-phase decides.
- 47-blob silhouette design (solid vs partial): **MEDIUM** — recommendation made; plan-phase decides.
- Affected-cell loop fix approach (hardcoded vs virtual): **MEDIUM** — recommendation made; plan-phase decides.
- TBT design-audit pattern locator: **HIGH** for file paths and LOC counts; **MEDIUM** for ADOPT/PARTIAL/REJECT pre-classifications (audit task itself can override).

**Research date:** 2026-04-28
**Valid until:** 30 days for stable findings (BorisTheBrave reference, TBT structure, Phase 2 pipeline). 7 days for the Tilesetter D-86 finding (Tilesetter docs may be updated; if user re-runs research after a manual update, results may differ — but as of 2026-04-28 the docs explicitly state the export-format section is being worked on).

---

## RESEARCH COMPLETE (with one BLOCKED sub-finding)

**Primary status: COMPLETE.** The research delivers everything needed to plan Phase 3:
- BorisTheBrave 47-blob math (collapse rule, bit ordering conversion, atlas options) — locked
- Phase 2 single-grid pipeline audit findings — load-bearing prerequisite identified
- TBT source-tree map — concrete file pointers for the Wave 0b audit
- Bitmask PNG generator extension spec — Python pseudocode ready to copy
- Test pattern recommendations — extends Phase 2's matrix
- Pitfall crosswalk — all 10 CLAUDE.md pitfalls mapped
- Validation architecture — Phase 3-specific test files identified

**Sub-finding BLOCKED: D-86 Tilesetter primary source (§3).** No public document publishes Tilesetter's canonical mask-to-coord mapping. Plan-phase MUST surface options (a)/(b)/(c) to the user before generating Wave 1 Tilesetter tasks. Recommendation: **option (a) — user provides their own Tilesetter export** as a primary-source artifact. If the user picks (b) defer-to-v0.3+, Phase 3 ships only `PentaTileLayoutBlob47Godot` and the Tilesetter requirements move to backlog.

The planner has sufficient information to generate a Wave 0 (audit + research-gate-resolution) and to draft Wave 1 (Blob47Godot — fully unblocked) tasks. Wave 2 (Tilesetter Wang/Blob) is gated on the D-86 user response.
