---
gsd_state_version: 1.0
milestone: v0.2.0
milestone_name: milestone
status: executing
stopped_at: Completed 02-03-PLAN.md (Wave 3 Penta layout merge)
last_updated: "2026-04-26T20:01:13.414Z"
last_activity: 2026-04-26
progress:
  total_phases: 7
  completed_phases: 2
  total_plans: 15
  completed_plans: 11
  percent: 73
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-25 after v0.2 pivot to layout library)

**Core value:** Painting tiles with the native `TileMapLayer` API produces correct dual-grid autotiled visuals — without the user maintaining caches, terrain metadata, or 16-tile blob sets.
**Current focus:** Phase 02 — native-layouts

## Current Position

Phase: 02 (native-layouts) — EXECUTING
Plan: 4 of 7
Status: Ready to execute
Last activity: 2026-04-26

Progress: [███████░░░] 73%

> Out-of-band progress: 5 of 8 greyboxed template PNGs + the generator script shipped in commit e86036f as part of the discovery pass. Counted as TEMPLATE-01 + TEMPLATE-03 covered. The remaining 3 templates (Blob47Godot, TilesetterWang15, TilesetterBlob47) ship in Phase 3 once their slot tables are transcribed from TileBitTools.

## Performance Metrics

**Velocity:**

- Total plans completed: 5
- Average duration: —
- Total execution time: 0.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 5 | - | - |

**Recent Trend:**

- Last 5 plans: —
- Trend: —

*Updated after each plan completion*
| Phase 02 P01 | 147 | 2 tasks | 3 files |
| Phase 02 P02 | 539 | 3 tasks | 8 files |
| Phase 02 P03 | 331 | 2 tasks | 5 files |

## Accumulated Context

### Roadmap Evolution

- 2026-04-26: Phase 2.1 inserted after Phase 2 (single-tile-layout) — ships `PentaTileLayoutSingleTile`. Adds 5 requirements (SINGLE-01..05). Companion artifact: `.planning/research/layouts/RPG_MAKER.md` audits the RPG Maker family and recommends offline-importer path for v0.3+ — out of scope for v0.2.0.
- 2026-04-26 (later): **Architectural pivot — overlay-layer removal + unified Tetra synthesis.** The Phase 2.1 brainstorm session reframed Phase 2's Penta5 work. Instead of shipping `PentaTileLayoutPenta5Horizontal`/`Vertical` as separate classes (CONTEXT.md D-28..D-46), the existing Tetra layouts gain load-time synthesis of the 5th OppositeCorners archetype from the OuterCorner tile. The runtime `_overlay_layer` is **deleted entirely** — every v0.2 layout renders via single-layer 5-archetype dispatch. Tetra layouts auto-detect 4-vs-5 source tiles. Single-Tile (Phase 2.1) updated to slice into 5 archetypes (not 4). Adds 6 new requirements (PENTA-SYNTH-01..06), supersedes Phase 2's planned TETRA5-* IDs (which never landed in REQUIREMENTS.md). Multi-terrain Y-axis convention added to v2 backlog (MULTITERR-01..05) with explicit design-coupling note to VAR-01 (variation). Full supersession notice in `.planning/phases/02-native-layouts/02-DISCUSSION-LOG.md`. Coverage 50 → 56 requirements.
- 2026-04-26 (later): **User policy update — breaking changes always allowed.** Recorded as feedback memory + CLAUDE.md "Breaking Changes Policy (HARD RULE)" + PROJECT.md constraint update. Never write backwards-compat shims. Never defer features for compat reasons. CHANGELOG entries are the only acceptable compat work.
- 2026-04-26 (later): **Phase 2.1 collapsed back into Phase 2 — TETRA1 mode folded into the Tetra layout via auto-detect.** The unified `PentaTileLayoutPentaHorizontal`/`Vertical` classes now handle three modes (TETRA1 / TETRA4 / TETRA5) via auto-detection of the source atlas strip-axis tile count. `TileCountMode` enum (`AUTO` / `TETRA1` / `TETRA4` / `TETRA5`) provides explicit override. Single class per axis covers all modes; SINGLE-01..05 retired and PENTA-SYNTH-* expanded from 6 to 9 requirements. Phase 2.1 directory removed (was empty). Coverage 56 → 54. Total phases 7 → 6. Naming convention: enum members use `TETRA1`/`TETRA4`/`TETRA5` (UPPER_SNAKE_CASE per GDScript style); requirement IDs remain `PENTA-SYNTH-*`. Full algorithm + edge-case handling captured in Phase 2 DISCUSSION-LOG D-53..D-55.
- 2026-04-26 (later): **Phase 1.1 inserted after Phase 1: PentaTile Rename + Penta Codename Establishment (URGENT).** Project-wide rename `Tetra` → `Penta` / `penta` → `penta` (~2,398 occurrences across 86 files) before Phase 2 ships new files under the old name. Coins "Penta" as the project's tileset codename (Blob/Wang style) — a descriptive, unowned label propagated through a canonical "What is a Penta tileset?" README definition. Driver: v0.2 pivot adds a 5th archetype (OppositeCorners) and TileCountMode FIVE — the project's identity is shifting from "4-tile autotiler" to "5-archetype autotiler," so the name follows the identity. Scope (in): source code (classes, file/folder names, plugin.cfg), saved resources (.tscn/.tres/.uid + custom data layer keys `penta_role`/`penta_lock_rotation`), planning docs (.planning/**, CLAUDE.md, ROADMAP.md, README), coined-terms discipline appended to CLAUDE.md as a project invariant, **AND repo rename + git tracking** — GitHub repo rename (manual user action via UI), local origin URL update via `git remote set-url`, local directory rename `c:\Programming_Files\Shilocity\PentaTile\` → `...\PentaTile\`, paired with Claude memory directory migration `mv c--Programming-Files-Shilocity-PentaTile c--Programming-Files-Shilocity-PentaTile`. Per the no-compat policy, no deprecation aliases — clean rename, CHANGELOG the breakage. Native flexible-count layout class is `PentaTileLayoutPenta` (matches `PentaTileLayout<FormatName>` pattern). Roadmap convention: user-facing text unpadded (`Phase 1.1`, `Phase 3.5`); directory + filenames zero-padded (`01.1-...`, `01.1-CONTEXT.md`). Memory: see `project_pentatile_rename.md`. Full scope + 6-wave structure in `.planning/phases/01.1-pentatile-rename-penta-codename-establishment/01.1-CONTEXT.md`.
- 2026-04-26 (later): **Phase 1.1 (PentaTile Rename + Penta Codename Establishment) complete.** Project renamed end-to-end: GDScript classes (`PentaTile*`), addon folder (`addons/penta_tile/`), plugin.cfg, project.godot, all .tscn/.tres/.import resources, all .planning/** docs, requirement IDs (`PENTA-*` / `PENTA-SYNTH-*`), GitHub repo (`PentaTile`), local working directory, Claude memory directory. Coined "Penta" as the 5-archetype tileset codename via canonical README section ("What is a Penta tileset?") + CLAUDE.md "Coined-Term Discipline" project invariant. CHANGELOG.md created with v0.2 BREAKING entry. Phase 2 next.

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- v0.2 pivot from "expand the contract" (variation + top tiles + non-rotating) to "layout library" (8 pluggable layout Resources)
- Layout = typed `Resource` subclass (`PentaTileLayout`) hung off `PentaTileAtlasContract`, NOT a `RotationMode` enum on the contract
- Each layout exposes `template_image: Texture2D` + `fallback_tile_set: TileSet` + `description: String` for inspector preview and zero-config prototyping
- Tilesetter slot tables transcribed from TileBitTools (MIT, attributed) rather than empirically fingerprinted
- Tilesetter Wang is 15 tiles in 5×3, not 16 in 4×4 (per TBT verified slot table)
- Tilesetter Blob is 11×5 with sub-block gaps, not 7×8 (per TBT verified slot table)
- Variation, top tiles, "non-rotating" pushed to a future milestone — DualGrid16/Wang2Corner/Wang2Edge layouts cover the asymmetric-art case the user wanted
- Excalibur/jaconir/Stormcloak/OpenGameArt CR31 dropped from the layout library (no Godot adoption signal)
- Godot `MATCH_SIDES` skipped (engine semantics disputed in issue #79411)
- RPG Maker A2/A4 architecturally reserved (subtile compositor) but deferred to v0.3+
- PentaTile does NOT integrate with Godot's stock terrain peering bits (defeats v0.1's "no manual bitmask authoring" selling point)
- TileBitTools' `EditorInspectorPlugin` architecture explicitly not copied (3,800-LOC editor UI conflicts with PentaTile's "small runtime + no editor polish" identity)
- **Breaking changes always allowed and encouraged** (user policy 2026-04-26). Never write backwards-compat shims; never defer features because they would break v0.1. CHANGELOG entries are the only acceptable compat work. CLAUDE.md "Breaking Changes Policy (HARD RULE)" formalizes this; PROJECT.md constraint updated.
- **Overlay-layer removal + unified 5-archetype synthesis** (2026-04-26). All v0.2 layouts render via single-layer 5-archetype dispatch. Penta layouts auto-detect source tile counts (1/2/3/4/5) and synthesize the missing archetypes from slot 0 (IsolatedCell). `_overlay_layer`, `_paint_overlay_for_slot`, `AtlasSlot.diagonal_complement_atlas_coords`, and the planned `needs_diagonal_overlay()` virtual are all deleted. FOUR-mode regression baseline is a fresh capture (slot ordering changed; not v0.1 bit-equivalence). Phase 2 supersedes the previously-planned separate Penta5* layout classes. See `.planning/phases/02-native-layouts/02-DISCUSSION-LOG.md` SUPERSESSION rounds for D-47..D-71.
- **Multi-terrain in v2 backlog** (MULTITERR-01..05) with explicit design-coupling to VAR-01 (Y-axis variation) — both compete for atlas Y-axis interpretation; future brainstorm must resolve them together. Strip layouts (Penta, Single-Tile / Penta ONE) use Y-as-terrain; block layouts (DualGrid16, Wang*, PixelLab) need a different mechanism (likely multiple atlas sources).
- **Architectural simplification sweep** (2026-04-26 third pivot): `PentaTileAtlasContract` deleted entirely (had a speculative `version: int` no consumer read; per the no-forward-compat policy, deleted). `layout: PentaTileLayout` lives directly on `PentaTileMapLayer`. `PentaTileLayoutPentaHorizontal`+`Vertical` merged into `PentaTileLayoutPenta` with `axis: Axis` and `tile_count: TileCountMode` (`AUTO`/`ONE`/`FOUR`/`FIVE`) enums. `template_image` renamed `bitmask_template`; `fallback_tile_set` hidden from inspector (codegen via `get_fallback_tile_set()`); `decoder_image` deleted. Templates restructured to `templates/[layout_name]/{atlas.png, bitmask.png}` per layout. PIXLAB-03 variation-bank pick moved to v2 backlog as VAR-PIXEL-01. Phase 1 still listed Complete but its CONTRACT-* / PENTA-01..03 / PREVIEW-01 / LAYOUT-03/04 are all reworked in Phase 2 — Phase 1 is partially superseded. Coverage 54 → 53 reqs.
- **No-forward-compat policy** added 2026-04-26 alongside the existing no-backwards-compat rule. CLAUDE.md "Breaking Changes Policy (HARD RULE)" now covers BOTH directions: never write compat shims AND never speculate about forward versioning (`version: int` fields, schema markers, speculative extension points). Both rules captured in `feedback_breaking_changes.md` Claude memory.
- **Five-mode progressive Penta design — locked** (2026-04-26 fourth pivot). Penta now supports five `tile_count` modes (`ONE`/`TWO`/`THREE`/`FOUR`/`FIVE`) plus `AUTO` (dimension-only) and `AUTO_STRIP` (per-strip detection). New slot ordering: `0=IsolatedCell, 1=Fill, 2=Border, 3=InnerCorner, 4=OppositeCorners`. **OuterCorner is implicit** — synthesized from slot 0's corners across all modes; never has a dedicated slot. Border at slot 2 (before InnerCorner at slot 3) prioritizes visual frequency over fill-percentage ordering — Border is the most visible archetype after Fill. Rationale: each step from ONE to FIVE adds one more explicit archetype slot, sacrificing quality for less authoring time. Single PNG per layout serves as BOTH inspector preview AND fallback TileSet source (no atlas/bitmask split). Templates folder deleted; bundled PNGs co-locate next to layout `.gd` files. Penta has 10 PNGs in `penta_tile_layout_penta/` subfolder; single-variant layouts use flat siblings. Coverage 53 → 56 reqs (added PENTA-SYNTH-10/11/12). Full design + decision history in `.planning/phases/02-native-layouts/02-DISCUSSION-LOG.md` FOURTH SUPERSESSION block.
- template_image renamed to bitmask_template on PentaTileLayout base class (LAYOUT-03/PREVIEW-01); no @export_storage compat shim per CLAUDE.md HARD RULE
- get_fallback_tile_set() virtual stub returns null in Wave 1; Wave 2 fills body with TileSet construction from bitmask_template (LAYOUT-06)
- PentaTileSynthesis utility class ships as RefCounted (@tool); synthesis path uses needs_synthesis() virtual to avoid forward type reference to PentaTileLayoutPenta (Wave 3)
- Tasks 2.2 and 2.3 combined into one atomic commit (b6349fa) — synthesis wiring required touching penta_tile_layout.gd (needs_synthesis virtual) which was already in the atomic sweep
- _DEFAULT_LAYOUT singleton deleted atomically with _resolve_layout rewrite in same commit per CONTEXT.md D-68 constraint
- needs_synthesis() overrides base to return true in PentaTileLayoutPenta — resolves Wave 2 stub for synthesis branch in PentaTileMapLayer
- _SLOT_* consts use literal ints in PentaTileLayoutPenta — GDScript 2 class-level const cannot reference another class's const at parse time
- Phase 1 PentaTileLayoutPentaHorizontal + Vertical merged into single PentaTileLayoutPenta with axis + tile_count enums (Wave 3 complete)

### Pending Todos

None yet.

### Blockers/Concerns

- **Phase 3 TBT slot-table transcription:** the load-bearing data work for Phase 3. Each `.tres` from TBT needs to be read and translated into a mask-to-slot table; mistakes here corrupt rendering for that layout. Mitigated by visual regression on the demo for each shipped layout.
- **Demo scene rebinding in Wave 2:** `addons/penta_tile/demo/penta_tile_demo.tscn` references `contracts/default_horizontal.tres` and sets `atlas_contract = ExtResource(...)`. Both get deleted in Phase 2 Wave 2. The demo will fail to load between waves unless updated atomically with the contract deletion. Wave 2 acceptance criterion: "demo loads cleanly after contract deletion."
- **Phase 1 verification suite (`01-VERIFICATION.md` 26/26 tests) references `atlas_contract` and the old class names** (`PentaTileLayoutPentaHorizontal` / `Vertical`). Phase 2 Wave 1 must migrate these tests to the new `layout: PentaTileLayout` + `PentaTileLayoutPenta(axis=...)` API. Don't let the planner assume Phase 1 tests just keep passing.
- **ONE-mode sub-region anchoring (PENTA-SYNTH-05) is the riskiest synthesis path.** Spikes 001-003 covered decoder feasibility, NOT synthesis-from-a-single-source-tile. The geometric spec — "where in slot 0 do the corners / edges / fill live, and how are sub-rects extracted?" — is not yet answered. Recommend inserting a Spike 004 before plan execution OR pinning down the anchoring math during plan-phase.
- **Collision-polygon transform math (PENTA-SYNTH-06)** for synthesis is non-trivial: copying a source-tile collision polygon to a synthesized OppositeCorners tile requires applying a rotation/flip transform to a `Vector2[]` of polygon vertices. Worth a sketch in the plan before executor hits it.
- **`_DEFAULT_LAYOUT` static singleton** in `penta_tile_map_layer.gd:193-198` allocates `PentaTileLayoutPentaHorizontal.new()` — a class being deleted in Wave 3. LAYER-02 implies the default-layout path goes away, but no wave explicitly handles it. Wave 2 should call out the cleanup as a non-skippable task.
- **Phase 2 scope is now ~2× original Phase 2** (31 of 56 reqs, 15 success criteria, ~7 waves). Worth deciding upfront in plan-phase whether Phase 2 needs a sub-wave structure or a Phase 2.0/2.5 split. Estimated LOC will significantly exceed the prior ~911 figure (more like 1300-1500). Identity guardrail audit recommended at end of Phase 2.

## Deferred Items

Items acknowledged and carried forward as v2 requirements (see REQUIREMENTS.md v2 section):

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Variation | Y-axis variation via `TileData.probability` (VAR-01) | future milestone | 2026-04-25 (v0.2 pivot) |
| Top Tiles | Designated top-edge visuals (TOP-01) | future milestone | 2026-04-25 (v0.2 pivot) |
| RPG Maker | Subtile compositor for A2/A4 (RPGM-01/02) | v0.3+ | 2026-04-25 |
| External Editors | Tiled `.tsx` / LDtk `.ldtk` rule importers (IMPORT-01/02) | v0.3+ | 2026-04-25 |
| Tooling | PentaBake / Wang→PentaTile converter (TOOL-01/02) | v2 | 2026-04-25 |
| Multi-terrain | Outer transition tiles (TERRAIN-01) | v2 | 2026-04-25 |
| Performance | Shader fallback / large-map benchmarks (PERF-01/02) | v2 | 2026-04-25 |
| Distribution | Asset Library / GUT test suite (DIST-01/02) | v2 | 2026-04-25 |

## Session Continuity

Last session: 2026-04-26T20:01:13.408Z
Stopped at: Completed 02-03-PLAN.md (Wave 3 Penta layout merge)
Resume file: None

**Completed Phase:** 01 (Contract Skeleton + Penta Layouts) — 5/5 plans, 14/14 requirements, 26/26 automated tests PASS — 2026-04-26
**Completed Phase:** 01.1 (PentaTile Rename + Penta Codename Establishment) — 3/3 plans, 0 formal REQ-IDs (rename phase), demo loads cleanly under new name, git remote tracks PentaTile origin — 2026-04-26
**Next Phase:** 02 (Native Layouts) — DualGrid16, Wang2Edge, Wang2Corner, Minimal3x3 (subclass adds; single-grid pipeline already wired by Phase 1's D-06)

**Planned Phase:** 02 (native-layouts) — 7 plans — 2026-04-26T18:54:39.523Z
