# Phase 8 Research Triage

**Date:** 2026-04-29
**Input:** User-supplied comparative autotiling research.
**Purpose:** Challenge the research, verify the useful claims against primary sources, and preserve only roadmap work that fits PentaTile's identity.

## Verification Snapshot

Primary-source checks:

- TileMapDual: current README confirms the broad-scope positioning: a custom `TileMapDual` node for square/isometric/hex grids, 15-tile dual-grid authoring, optional 6-tile symmetry tooling, multiple terrains via stacked TileMapDual layers, and separate display/world spritesheets for collision/pathing data. Source: https://github.com/pablogila/TileMapDual
- TileBitTools: README confirms it is an archived Godot 4 editor plugin for terrain-bit templates and bulk editing, with built-in 3x3/2x2/blob/Wang templates, custom template saving, no hex/isometric support, and no alternative-tile support. Source: https://github.com/dandeliondino/tile_bit_tools
- Better Terrain: README confirms the relevant inspiration is editor UX and deterministic terrain replacement territory: a Terrains dock, terrain categories, decoration type, randomization control, and a replacement for Godot's terrain matching. Source: https://github.com/Portponky/better-terrain
- Godot 4.6 docs: TileMapLayer remains the correct host API for painting, line/rectangle/bucket tools, alternative tiles, scene tiles, and runtime layer internals. Source: https://docs.godotengine.org/en/4.6/tutorials/2d/using_tilemaps.html

Repo checks:

- PentaTile v0.2.0 already shipped the core dual-grid asset-reduction premise. The research's "must transition to a dual-grid mathematical model" is stale for this repo.
- PentaTile already has a 16-tile dual-grid layout, Penta 1-5 modes, Blob47Godot, PixelLab top-down/side-scroller, fallback routing, visual regression harnesses, and release packaging.
- The current backlog already contains the best-aligned features: deterministic variation, top tiles, Tilesetter layouts, PentaBake/converters, RPG Maker subtile compositor, importers, multi-terrain experiments, perf benchmarks, and Asset Library distribution.

## Challenge Results

Accepted as useful:

- Deterministic variation remains the strongest near-term product improvement. It directly unlocks PixelLab's variation banks and the original v0.2 variation pillar.
- Top-edge tiles remain useful for platformer art, but must be explicit per layout/mask; no "tile below is filled" heuristic.
- Tilesetter Wang15/Blob47 remain valuable because TileBitTools verifies there is real ecosystem demand, but implementation must use a primary source or user-provided export sample, not copy TileBitTools data.
- Editor paint preview is real UX debt, already captured as Phase 6. The low-LOC ghost-material approach remains the identity-compatible first candidate.
- Docs and examples matter more than a large editor UI. Phase 7's MkDocs + LLM-readable docs pipeline is the right place for discoverability.
- Performance work should start with benchmarks and limits, not caches. PERF-02 is the correct gate before optimization.

Corrected by focused follow-up:

- Multi-terrain was initially firewalled too broadly. The refined position is in `08-MULTI-TERRAIN-RESEARCH.md`: PentaTile may read Godot `TileData` terrain metadata as authoring/indexing input, but must keep its own deterministic `_update_cells()` solver and must not delegate generated visuals to Godot's terrain painter.

Rejected or downgraded:

- Global constraint solver/backtracking: Better Terrain territory. It conflicts with PentaTile's small hot-path identity unless the project is deliberately renegotiated.
- Grid agnosticism/hex/isometric: TileMapDual territory. Valid competitor feature, but not a PentaTile differentiator right now.
- Terrains dock/template wizard/bulk terrain-bit editor: TileBitTools/Better Terrain territory. PentaTile avoids terrain peering metadata and heavy EditorInspectorPlugin polish.
- JSON metadata/entity spawning/scriptable rule tiles: LDtk/Unity/engine-feature territory. Godot already has TileSet custom data and scene tiles; PentaTile should not become a world database.
- Persistent coordinate caches, worker-thread tile managers, and GPU infinite-world shaders: premature for demo-scale targets. Benchmark first, optimize only if data proves need.
- Backwards-compatible migration tools: rejected by project policy. PentaTile is pre-1.0 and breaks freely; CHANGELOG/release notes are the migration surface.

## Phase 8 Proposed Outcome

Phase 8 should not implement gameplay features. It should produce a verified v0.3 scope package:

1. A ranked v0.3 candidate matrix with implementation risk, identity fit, and dependency notes.
2. A cleaned backlog with explicit "accept/reject/research later" dispositions for every research suggestion.
3. A recommended first v0.3 implementation bundle, likely one of:
   - **Variation + PixelLab banks + top tiles** if the user wants visible art-quality gains.
   - **Tilesetter layouts + converter/PentaBake spike** if the user wants ecosystem/import coverage.
   - **Editor preview + docs/distribution polish** if the user wants adoption UX.
4. A scope firewall that keeps Godot terrain-solver delegation, broad rule solvers, hex/iso, and world-metadata systems out unless the project identity is intentionally renegotiated. Godot terrain metadata reads are allowed as the input format for a focused MULTITERR implementation.
