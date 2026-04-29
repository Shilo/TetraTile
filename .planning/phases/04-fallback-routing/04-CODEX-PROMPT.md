# Codex Cross-AI Review - PentaTile Phase 4

You are reviewing PentaTile Phase 4 after the fallback routing verification scaffold and doc-comment sweep have landed.

Per `.planning/phases/04-fallback-routing/04-CONTEXT.md` D-04-10, this is the SECOND pass of a strict-order Gemini → fix → Codex → fix workflow. The first reviewer (Gemini) has already filed findings, the implementer dispositioned them, and atomic fix-commits landed. You are reviewing the POST-Gemini-fix codebase to provide genuine "second-look" coverage. The Gemini disposition log (`04-GEMINI-REVIEW-FIX.md`) is included in your review surface — please AVOID re-filing findings already addressed there (whether `applied`, `rejected-disqualification`, or `deferred`).

Output ONLY the markdown report described below. Do not include shell commands, commentary outside the schema, or speculative next-step advice.

## Review Surface

Review these files and the relationships between them:

- `addons/penta_tile/penta_tile_map_layer.gd`
- `addons/penta_tile/penta_tile_synthesis.gd`
- `addons/penta_tile/penta_tile_atlas_slot.gd`
- `addons/penta_tile/layouts/penta_tile_layout.gd`
- `addons/penta_tile/layouts/penta_tile_layout_penta.gd`
- `addons/penta_tile/layouts/penta_tile_layout_dual_grid_16.gd`
- `addons/penta_tile/layouts/penta_tile_layout_wang_2_edge.gd`
- `addons/penta_tile/layouts/penta_tile_layout_wang_2_corner.gd`
- `addons/penta_tile/layouts/penta_tile_layout_minimal_3x3.gd`
- `addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.gd`
- `addons/penta_tile/layouts/penta_tile_layout_pixel_lab_top_down.gd`
- `addons/penta_tile/layouts/penta_tile_layout_pixel_lab_side_scroller.gd`
- `addons/penta_tile/tests/fallback_routing_test.gd`
- `addons/penta_tile/tests/run_tests.ps1`
- `.planning/phases/04-fallback-routing/04-FALLBACK-UAT.md`
- `.planning/phases/04-fallback-routing/04-DOC-SWEEP.md`
- `.planning/phases/04-fallback-routing/04-CONTEXT.md`
- `.planning/phases/04-fallback-routing/04-RESEARCH.md`
- `.planning/phases/04-fallback-routing/04-PATTERNS.md`
- `.planning/phases/04-fallback-routing/04-GEMINI-REVIEW.md`
- `.planning/phases/04-fallback-routing/04-GEMINI-REVIEW-FIX.md`
- `.planning/PROJECT.md`
- `.planning/REQUIREMENTS.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `CLAUDE.md`

## Project Identity Guardrails

PentaTile must remain visibly smaller and simpler than TileMapDual.

Reject findings or fixes that push the project toward:

1. Terrain peering metadata or terrain rule tries.
2. Multi-terrain transitions.
3. Watcher or signal-fanout systems.
4. Persistent coordinate caches.
5. A custom drawing API parallel to `set_cell()`.
6. `EditorInspectorPlugin` polish.

The useful shape of a finding is a concrete bug, doc mismatch, identity guardrail breach, or Phase 4 goal mismatch in the current codebase.

## Breaking Changes Policy

Breaking changes are always allowed because this project is pre-1.0.

Do NOT recommend:

1. Backwards-compat shims.
2. Deprecation alias code.
3. Version-detection branches.
4. Migration fallbacks.
5. Legacy template aliases.

Also do NOT recommend forward-compat machinery:

1. `version: int` fields.
2. Schema marker fields.
3. Format-version enums.
4. Speculative extension points.
5. Hooks that exist only in case a future feature needs them.

## Coined-Term Discipline

Penta is reserved exclusively for the 5-archetype tileset format used by PentaTile.

Do not suggest new generic "Penta" prefixes for unrelated subsystems. `PentaTileMapLayer`, `PentaTileLayout*`, `PentaTileSynthesis`, and `PentaTileAtlasSlot` are established names; new names like `PentaCache`, `PentaDecoder`, or `PentaToolkit` are violations unless they refer directly to the 5-archetype format.

## Deferred Or Out-Of-Scope Work

Do not file findings asking Phase 4 to implement deferred work:

- `TBT-01-DEFERRED`
- `TBT-02-DEFERRED`
- `TEMPLATE-02-DEFERRED`
- `VAR-01`
- `VAR-PIXEL-01`
- `TOP-01`
- `NONROT-01`
- `MULTITERR-01` through `MULTITERR-05`
- `TERRAIN-01`
- `RPGM-01` through `RPGM-03`
- `IMPORT-01` / `IMPORT-02`
- `TOOL-01` through `TOOL-04`
- `PERF-01` / `PERF-02`
- `DIST-01` / `DIST-02`

Do not file Phase 5 territory as Phase 4 findings:

- LOC trim or final identity audit.
- README rewrite.
- CHANGELOG.
- Demo refresh.
- `plugin.cfg` version bump.
- Git tag.
- Release zip.

Do not propose `addons/penta_tile/ATTRIBUTION.md`; D-72 and D-73 ban that artifact for this milestone.

## Locked Decisions

Respect locked decisions in `.planning/PROJECT.md`, `.planning/STATE.md`, and phase context files, including D-04-01, D-04-02, D-04-03, D-04-04, D-04-05, D-04-06, D-04-07, D-04-10, D-04-13, D-04-14, D-04-15, and D-04-16.

A finding that contradicts a locked decision should either be omitted or explicitly marked as invalid under the disqualification triggers below.

## Disqualification Triggers

Before filing a finding, scan it against these hard triggers. If one applies, do not file it as a normal finding.

1. Backwards-compat shim, deprecation alias, migration fallback, or version-detection branch.
2. Forward-compat versioning, schema marker, format-version enum, or speculative extension point.
3. Deferred feature request: TBT-01-DEFERRED, TBT-02-DEFERRED, TEMPLATE-02-DEFERRED, VAR-01, VAR-PIXEL-01, TOP-01, NONROT-01, MULTITERR, TERRAIN-01, RPGM, IMPORT, TOOL, PERF, or DIST.
4. Phase 5 territory: LOC trim, README rewrite, CHANGELOG, demo refresh, plugin.cfg bump, release zip, git tag.
5. ATTRIBUTION.md proposal or a contradiction of D-72 / D-73.
6. Coined-Term Discipline violation: "Penta" used for non-5-archetype subsystems.
7. Locked-decision contradiction: D-04-01 or any other D-XX decision is contradicted.
7a. **Already-dispositioned Gemini findings.** If you observe an issue that Gemini also flagged AND was dispositioned in `04-GEMINI-REVIEW-FIX.md` (whether applied / rejected / deferred), DO NOT re-file the finding unless your insight differs materially — in which case clearly state "Gemini also flagged this as GEMINI-XXX-NN; my finding differs because <X>."

## Severity

Use exactly these severities:

- Critical: data loss, crash, impossible-to-use Phase 4 core behavior, or severe Godot runtime break.
- High: likely bug or regression in fallback routing, transforms, saved scenes, tests, or shipped layouts.
- Medium: plausible bug, misleading docs that could cause wrong usage, or maintainability problem with real cost.
- Low: minor doc quality, naming clarity, local cleanup with limited impact.
- Info: observation that is worth recording but not urgent.

## Theme

Use exactly one theme per finding:

- Bug
- Identity
- Goal-misalignment
- Doc
- Design

## Output Schema

The markdown report MUST begin with frontmatter:

```yaml
---
phase: 04-fallback-routing
reviewer: codex
reviewed_at: <ISO timestamp>
findings:
  critical: N
  high: N
  medium: N
  low: N
  info: N
  total: N
status: clean-or-issues-found
---
```

Then provide:

```markdown
# Phase 4 Codex Review

## Summary

One concise paragraph.

## Critical
### CODEX-C-01: Title

**File:** `path:line`
**Severity:** Critical
**Theme:** Bug
**Finding:** Concrete issue.
**Suggested fix:** Concrete fix.
**Rationale:** Why this matters.
```

Repeat the same format for `High`, `Medium`, `Low`, and `Info`. Omit empty severity sections.

Finding IDs must use:

- `CODEX-C-NN`
- `CODEX-H-NN`
- `CODEX-M-NN`
- `CODEX-L-NN`
- `CODEX-I-NN`

Every finding must include `Severity`, `Theme`, `File`, `Finding`, `Suggested fix`, and `Rationale`.

If there are no findings, set `status: clean`, all counts to 0, `total: 0`, and include only a short summary explaining why the reviewed surface is clean.
