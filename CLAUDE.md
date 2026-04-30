# PentaTile — Claude Code Project Guide

## Project

PentaTile is a dual-grid autotiling addon for **Godot 4.6** built around a single public node, `PentaTileMapLayer`, that subclasses `TileMapLayer`. Users paint with the native `set_cell()` / `erase_cell()` API and the addon generates dual-grid visuals automatically through `_update_cells()`.

The current codebase is v0.1.0 (4-tile binary atlas: Fill, Inner Corner, Border, Outer Corner). The active milestone is **v0.2.0 — "Layout Library + Preview Fallback"** which ships a library of pluggable `PentaTileLayout` Resources covering every popular Godot autotiling atlas convention (Penta, DualGrid16, Wang2Edge, Wang2Corner, Min3x3, TBT-decoded Blob/Wang, PixelLab, plus a Single-Tile prototyping layout). The original v0.2 pillars (Y-axis variation, top tiles, non-rotating tilesets) deferred to v2 backlog. See `.planning/ROADMAP.md` for current phases.

## Stack

- **Engine:** Godot 4.6.x stable, Windows (executable: `C:\Programming_Files\Godot\Godot_v4.6.2-stable_win64.exe`)
- **Language:** GDScript 2 (`@tool`, `class_name`, typed `Array[Resource]`, `@export_group`)
- **No third-party deps.** No C#, no GDExtension, no GUT — pure Godot native.
- **Distribution:** GitHub releases only (no Asset Library this milestone), tagged `vX.Y.Z` (no `-pre`/`-alpha`/`-dev` suffixes).

Key Godot APIs in use:
- `TileMapLayer._update_cells(coords, forced_cleanup)` — the single autotile egress point
- `TileSetAtlasSource` + `alternative_tile` int packing (`TRANSFORM_FLIP_H=4096 | FLIP_V=8192 | TRANSPOSE=16384` OR'd with low-bit alt-IDs)
- `TileData.probability` — read-only weights for variation (Godot does NOT auto-pick at `set_cell` time; the addon runs its own deterministic-hash `rand_weighted` inside `_update_cells`)
- `TileSet.custom_data_layers` — for per-tile flags like `penta_role` and `penta_lock_rotation`

## MCP Tools

This project has MCP (Model Context Protocol) tools available. Always prefer these over manual approaches when applicable:

- **Godot MCP** — `godot_*` tools for launching the editor, running the project, getting debug output, creating/modifying scenes, exporting resources, and managing UIDs. Use these for any Godot editor or runtime interaction.
- **Context7 MCP** — `context7_resolve-library-id` + `context7_query-docs` for looking up up-to-date documentation and code examples from any library/framework. Use this when you need API docs, usage patterns, or examples for third-party libraries.

## Layout

```
addons/penta_tile/
  plugin.cfg
  penta_tile_map_layer.gd          # core PentaTileMapLayer node
  penta_tile_synthesis.gd          # synthesis machinery for Penta layouts
  penta_tile_atlas_slot.gd         # slot resource (atlas_coords + transform_flags)
  layouts/                         # PentaTileLayout base + subclasses + co-located fallback PNGs
    penta_tile_layout.gd           # base PentaTileLayout
    penta_tile_layout_penta.gd     # merged Penta family (axis × tile_count enums)
    penta_tile_layout_dual_grid_16.gd
    penta_tile_layout_wang_2_edge.gd
    penta_tile_layout_wang_2_corner.gd
    penta_tile_layout_minimal_3x3.gd
    penta_tile_layout_penta/       # Penta variants' bundled PNGs (5 modes × 2 axes)
  demo/
    penta_tile_demo.tscn           # main demo scene (entry point)
    demo_runtime_painter.gd        # left-click paint, right-click erase, drag-paint
    penta_layout_*.tres            # demo layout resources
brand/                             # project icon + logo (referenced by project.godot + @icon)
tools/
  _generate_bitmasks.py            # internal tooling — regenerates bundled bitmask PNGs
  mkdocs_hooks.py                  # MkDocs build hooks
tests/                             # determinism harness + visual regression tests
docs/                              # MkDocs source site
.planning/                         # GSD planning artifacts (committed to git)
  PROJECT.md                       # what we're building, why, constraints
  REQUIREMENTS.md                  # v1 REQ-IDs + v2 deferred + Out of Scope
  ROADMAP.md                       # 5-phase plan with success criteria
  STATE.md                         # current position, decisions, blockers
  config.json                      # workflow config (interactive, standard, parallel, opus quality)
  research/                        # SUMMARY.md + STACK/FEATURES/ARCHITECTURE/PITFALLS
  codebase/                        # v0.1 snapshot from /gsd-map-codebase (refresh planned end of v0.2)
```

## GSD Workflow

This project uses Get Shit Done (GSD) for structured execution. The phases of v0.2.0 are:

1. **Contract Skeleton + Penta Layouts** ✅ DONE (partially superseded by Phase 2). Phase 1 originally shipped `PentaTileAtlasContract` + `PentaTileLayout` base + `AtlasSlot` + separate `PentaTileLayoutPentaHorizontal` / `PentaTileLayoutPentaVertical` classes. Phase 2 deleted the contract and merged the H/V pair into `PentaTileLayoutPenta`. Phase 1 artifacts archived under `.planning/phases/01-contract-skeleton-penta-layouts/`; the only Phase 1 outputs that survived intact are the `PentaTileLayout` base virtual surface + `AtlasSlot`.
2. **Native Layouts** — DualGrid16, Wang2Edge, Wang2Corner, Min3x3 + Penta layouts gain load-time synthesis of the 5th `OppositeCorners` archetype (drops the runtime overlay layer entirely).
2.1 **Single-Tile Layout (Prototyping)** — `PentaTileLayoutSingleTile` slices ONE source image into 5 archetypes at load time.
3. **TileBitTools-Sourced Layouts** — Blob47Godot, TilesetterWang15, TilesetterBlob47 with attribution.
3.5 **PixelLab Layouts + Variation-Bank Wiring** — PixelLabTopDown + PixelLabSideScroller (8×8 atlas, internal variation banks).
4. **Fallback Routing** — `tile_set == null` → `layout.get_fallback_tile_set()`.
5. **Demo Refresh + Documentation + Release** — updated demo, README, CHANGELOG, `v0.2.0` tag.

Authoritative source: `.planning/ROADMAP.md` (this list is a summary, not the spec).

**Workflow commands:**
- `/gsd-progress` — current position, next action
- `/gsd-plan-phase N` — plan a phase before executing it
- `/gsd-discuss-phase N` — clarify approach before planning
- `/gsd-execute-phase N` — execute the planned phase
- `/gsd-verify-work` — UAT against requirements after a phase
- `/gsd-help` — full command list

The active config is in `.planning/config.json`: interactive mode, standard granularity, parallel plan execution, "quality" model profile (Opus for research/roadmap), with research/plan-check/verifier all enabled.

## Identity Guardrails

The PROJECT.md identity constraint is **"PentaTile prioritizes quality over raw size."** When making implementation decisions, reject:

- Watcher / signal-fanout systems (TileMapDual's leaks/crashes are cited evidence)
- Persistent coordinate caches (demo-scale doesn't need them)
- Custom drawing API parallel to `set_cell()` (defeats the v0.1 native-API win)
- `EditorInspectorPlugin` polish (typed `@export` + `@export_group` is enough)

LOC and surface-area metrics are tracked as data points, not as decision gates. The correct tile on screen matters more than the fewest lines of code.

## Quality Bar

**"Works in my game."** No formal test suite (GUT) this milestone. Visual regression on the demo is the primary verification mechanism. Demo-scale only (~100–1k cells); no large-map perf benchmarks.

## Breaking Changes Policy (HARD RULE)

**Breaking changes are always allowed. Always.** This project is pre-1.0 and the audience is the author's own games. The same rule applies in BOTH temporal directions — no backwards-compat AND no forward-compat speculation.

### No backwards compatibility

- **Never** write backwards-compatibility shims, deprecation aliases, version-detection branches, or migration fallbacks to preserve v0.1 behavior.
- **Never** defer or scope-down a feature/refactor because it would break existing code or saved scenes.
- **Never** keep an obsolete code path "for compatibility" — delete it.
- When the new design is better, ship it. Document the breakage in CHANGELOG and release notes; that is the only acceptable "compat" work.

### No forward compatibility / speculative versioning

- **Never** add `version: int` fields to Resources for "future migration."
- **Never** add `version` markers, schema-version constants, format-version enums, or `if version < N:` branches.
- **Never** add hooks, virtual methods, abstract slots, or extension points "in case a future feature needs them."
- **Never** keep a property exposed in the inspector "in case someone wants to override it later."
- If a future migration genuinely needs versioning, that future feature can add it then. YAGNI applies hardest to versioning machinery.

### Both rules together

This project ships breaking changes freely and never speculates about the future. CHANGELOG entries and release notes are the only acceptable "compat" work in either direction. These rules OVERRIDE any default Claude Code instinct to preserve existing behavior, add fallbacks, or future-proof against hypothetical scenarios.

If a refactor reveals breaking changes mid-implementation, do not stop to ask — note them in the commit message and proceed. Discuss only when the user invites a design conversation, not to gate breakage approval.

## Critical Pitfalls (from research)

When implementing v0.2.0 features, watch for:

1. **`alternative_tile` bit packing** — alt-ID and `TRANSFORM_FLIP_*` flags share one int; always OR them together via `_pack_alternative()`; assert `alt_id < 4096`.
2. **Variation determinism** — never `randi()`. Always `RandomNumberGenerator.seed = hash(Vector4i(coord.x, coord.y, atlas_coords.x, atlas_coords.y) + variation_seed)` then `rand_weighted()`. Otherwise `rebuild()` shimmers.
3. **Resource property renames orphan saved scenes silently** — Godot 4.6 has no automatic property-rename migration. Use `@export_storage` shadow + `__migrate__()` two-step pattern; CHANGELOG every rename.
4. **Setter loops + `Resource.changed` storms** — idempotence guard (`if value == layout: return`), disconnect-before-reconnect on `Resource.changed`, ride the existing `_queue_rebuild` deferred coalescer.
5. **Non-rotating tileset table** — 16 runtime entries GENERATED from the rotating table at layout-load time. Never hand-write 64 entries. Mask 0 special-cased on the FIRST line of the paint function.
6. **Top-tile assignment must be EXPLICIT per-mask on the layout** — never inferred via "tile below is filled" heuristics. Auto-detection bakes platformer assumptions into the addon. (Top tiles are v2 backlog; this guidance applies when that work lands.)
7. **`TileMapLayer.visible = false` cleanup behavior** — already mitigated in v0.1 via `self_modulate.a` on the logic layer. Don't regress.
8. **Single-grid layouts only render LOGIC-painted cells** — `_paint_via_layout` skips non-logic-painted cells (cardinal neighbors of painted cells get marked affected so they re-render when their neighbor changes, but they must NOT paint their own tile, otherwise the painted region visually extends by a full cell). Dual-grid renders all affected display cells (perimeter cells fill INNER quadrants that fall inside the painted logic pixel bounds).
9. **`mask=0` is NOT "erase" for single-grid logic-painted cells** — the universal mask=0 short-circuit only applies to dual-grid. Single-grid logic-painted cells with mask=0 (isolated 1×1, 1×N lines in Wang2Corner where no diagonals exist) MUST dispatch to a default atlas slot. All 3 single-grid layouts (Wang2Edge, Wang2Corner, Min3x3) handle this in `mask_to_atlas`.
10. **Penta authored slots need canonical-silhouette enforcement** — Penta dispatches with rotation flags (TRANSPOSE | FLIP_H | FLIP_V) at render time. Stray opaque pixels in an artist's "cut" quadrant (e.g., orange outline at col 8 of slot 3's TR cut) get rotation-mapped INTO adjacent painted cells, producing visible bleed. `PentaTileSynthesis._apply_canonical_silhouette` zeroes pixels outside each archetype's expected opaque region during authored-slot extraction (FOUR/FIVE modes). Synthesized slots (ONE/TWO/THREE modes' synth 1-4) compose from slot 0's BL quadrant and fit the silhouette by construction.

Full pitfall analysis is in `.planning/research/PITFALLS.md`.

## Test Methodology (Phase 2 UAT lessons)

Phase 2 UAT cycled through 6+ commits chasing the same class of visual bug because tests verified my mental model of dispatch, not the user's rendered output. Lessons hard-won:

1. **Compose the rendered canvas in tests, don't just check dispatch.** Source-atlas pixel checks pass while rotation-bleed bugs persist. Build a virtual canvas by blitting each painted cell's `(atlas_coord, transform)` at its world position, then assert structural invariants on the composed image (opaque-pixel bbox, hole emptiness, no out-of-bounds pixels). Canonical examples: `tests/comprehensive_bitmask_test.gd` and `penta_ground_hollow_test.gd`.
2. **Test pattern × layout matrix, not single-pattern.** A 12×8 rectangle exercises a forgiving subset of masks. Always loop `[1×1, 1×2, 2×1, 2×2, 3×3, 5×5, line_h_5, line_v_5, L_shape, T_shape, plus_shape, hollow_ring, 3_isolated]` × `[Penta, DualGrid16, Wang2Edge, Wang2Corner, Min3x3]`. Lines and isolated cells exposed `mask=0` regressions that the rectangle never hit.
3. **Test the user's actual fixture, not just bundled greyboxes.** Bundled greyboxes have clean cut quadrants; artist artwork (`penta_tile_ground.tres`) has stray pixels in cut regions that only surface bugs when paired with rotation. `penta_ground_hollow_test.gd` is the template.
4. **Save rendered output as PNG and inspect when in doubt.** UI bugs need eyeball verification — `Image.save_png("user://...")` then read via `Read` tool. The Min3x3 corner-cut and Penta orange-line bugs both became obvious only after I looked at the rendered PNG.
5. **Verify the test catches the regression.** Stash the fix, rerun, confirm failure. A test that doesn't fail on broken code isn't measuring what we think.
6. **Trace the full pipeline before patching.** `_paint_via_layout` → `_synthesize_slot_image` → `_extract_tile_image` → atlas blit → render-time transform. The actual bug usually lives at a stage I haven't read. Cascading regressions (each fix breaks something else) mean the mental model is wrong — stop, reread, reset.

The 17 tests in `tests/run_tests.ps1` are baseline coverage; new layouts/features should add their own pattern × fixture combinations following these rules.

## Coined-Term Discipline

**"Penta" is reserved exclusively for the 5-archetype tileset format used by PentaTile.** This is a project invariant — never use "Penta" for anything else, or the term loses descriptive meaning.

- Use **PentaTile** for the project name, public class prefixes (`PentaTileMapLayer`, `PentaTileLayout*`, `PentaTileSynthesis`, `PentaTileAtlasSlot`), file/folder names (`addons/penta_tile/`, `penta_tile_map_layer.gd`), the plugin id, and demo scene names. The project happens to share its name with its native layout family — that coincidence is load-bearing for the codename to land.
- Use **Penta** as a generic codename in phrases like "a Penta tileset," "the Penta layout family," "Penta archetypes," "Penta slot order." Never coin "Penta" prefixes for unrelated subsystems (e.g., do NOT introduce `PentaCache`, `PentaDecoder`, `PentaToolkit` for things that aren't the 5-archetype format).
- The labeled archetype diagram in `README.md` § What is a Penta tileset? is **load-bearing** for codename propagation — without the picture-with-named-archetypes, the codename cannot spread (the Boris-the-Brave precedent for "Blob": classification stuck because the diagram was canonical).
- When introducing the term to a new reader (docs, CHANGELOG, release notes), link or excerpt from the canonical README definition rather than re-explaining inline. Single source of truth keeps the term stable.

Canonical "What is a Penta tileset?" definition lives in `README.md`.

## Coding Conventions

- Class names: PascalCase (`PentaTileMapLayer`, `PentaTileLayout`, `PentaTileSynthesis`)
- Public methods: `snake_case` without leading underscore (`rebuild()`, `set_cell()`)
- Private methods: `_snake_case` (`_resolve_slot()`, `_pick_alternative()`)
- Constants: `_UPPER_SNAKE_CASE` (private, `_FILL`, `_ROTATE_90`)
- Enum members: `UPPER_CASE` (`HORIZONTAL`, `NON_ROTATING`)
- Export properties: `snake_case` (`atlas_source_id`, `layout`)
- File names: snake_case matching class name (`penta_tile_map_layer.gd` → `PentaTileMapLayer`)

## Next Step

Run `/gsd-progress` to see current position. v0.2.0 shipped; v0.3 development active — terrain/variation spike complete (Phase 9), multi-terrain implementation in discuss (Phase 10).
