---
phase: 02-native-layouts
plan: 3
subsystem: penta-layout-merge
tags: [refactor, breaking-change, merge, synthesis-wiring, enum, gdscript-const-fix]
dependency_graph:
  requires: [02-02-PLAN]
  provides: [PentaTileLayoutPenta, needs_synthesis-override, penta-layout-merged]
  affects:
    - addons/penta_tile/layouts/penta_tile_layout_penta.gd
tech_stack:
  added: []
  patterns:
    - axis-enum-branching-replaces-subclass-inheritance
    - vector2i-dict-keys-for-reliable-hashing
    - literal-int-consts-for-cross-class-const-limitation
    - bitwise-clear-for-property-hide
key_files:
  created:
    - addons/penta_tile/layouts/penta_tile_layout_penta.gd
  modified: []
  deleted:
    - addons/penta_tile/layouts/penta_tile_layout_penta_horizontal.gd
    - addons/penta_tile/layouts/penta_tile_layout_penta_horizontal.gd.uid
    - addons/penta_tile/layouts/penta_tile_layout_penta_vertical.gd
    - addons/penta_tile/layouts/penta_tile_layout_penta_vertical.gd.uid
decisions:
  - "needs_synthesis() overrides base to return true — resolves Wave 2 stub (base returned false to avoid forward type reference to PentaTileLayoutPenta)"
  - "_SLOT_* consts use literal ints (0..4) — GDScript 2 class-level const cannot reference another class's const at parse time; values documented with PentaTileSynthesis.SLOT_* comments for cross-reference"
  - "Tasks 3.1 and 3.2 committed atomically (eb19072) — merge is logically indivisible; comment fixup in follow-on commit d787bd3"
  - "Mask 9 = _ROTATE_0 anchor for OppositeCorners (PentaTile canonical); mask 6 = TRANSFORM_FLIP_H (Excalibur cross-reference documented in class doc-comment)"
  - "_validate_property uses bitwise &= ~PROPERTY_USAGE_EDITOR (canonical Godot 4.6 idiom); overwrite approach rejected per H-1 BLOCKER FIX documentation"
  - "_BITMASK_TEMPLATE_LOOKUP keys are Vector2i(axis, mode) — primitive value type with well-defined hash/equality per H-4 BLOCKER FIX"
metrics:
  duration_seconds: 331
  completed: 2026-04-26
  tasks_completed: 2
  tasks_total: 2
  files_modified: 0
  files_created: 1
  files_deleted: 4
---

# Phase 2 Plan 3: Wave 3 — Penta Layout Merge Summary

Single merged class `PentaTileLayoutPenta` (272 LOC) with `axis: Axis` (HORIZONTAL/VERTICAL) + `tile_count: TileCountMode` (AUTO/AUTO_STRIP/ONE..FIVE) enums. 16-state mask_to_atlas, `_validate_property` bitmask_template hide, mode-aware `get_fallback_tile_set()`, and `needs_synthesis() → true` override. Phase 1's two separate Penta files deleted.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 3.1 | Create penta_tile_layout_penta.gd (merged class) | eb19072 | addons/penta_tile/layouts/penta_tile_layout_penta.gd (+272 LOC) |
| 3.2 | Delete Phase 1 Penta files (horizontal + vertical + .uid sidecars) | eb19072 | 4 files deleted (-149 LOC) |
| fixup | Remove comment reference to deleted Phase 1 class name | d787bd3 | penta_tile_layout_penta.gd (-1 line) |

## LOC Delta

| File | Before | After | Delta |
|------|--------|-------|-------|
| penta_tile_layout_penta.gd | 0 (new) | 272 | +272 |
| penta_tile_layout_penta_horizontal.gd | 119 | DELETED | -119 |
| penta_tile_layout_penta_vertical.gd | 30 | DELETED | -30 |
| **Net GDScript change** | | | **+123 LOC** |

The merged class (272 LOC) is within the plan target (200-280 LOC). Phase 1's two classes totaled ~149 LOC so the net increase reflects the additional enum machinery, lookup table, `_validate_property`, and `get_fallback_tile_set()` override.

## Key Design Details

### Slot Ordering (locked Phase 2)
```
0 = IsolatedCell   (always present; OuterCorner synthesized from here via rotation)
1 = Fill
2 = Border
3 = InnerCorner
4 = OppositeCorners
```
OuterCorner is implicit — masks 1, 2, 4, 8 (single-corner cases) all return slot 0 with rotation flags (Path B per Gate 1, 02-02-PLAN.md).

### OppositeCorners Anchoring
- Mask 9 (TL+BR, "\\" diagonal) = `_ROTATE_0` — PentaTile canonical anchor
- Mask 6 (TR+BL, "/" diagonal) = `TRANSFORM_FLIP_H`
- Excalibur.js uses the opposite anchor (mask 6 as unrotated); divergence documented in class doc-comment

### _validate_property Hide
Uses `property.usage &= ~PROPERTY_USAGE_EDITOR` (bitwise-clear, H-1 fix). This preserves existing storage/READ_ONLY flags rather than overwriting with a composite constant.

### _BITMASK_TEMPLATE_LOOKUP
10-entry dict with `Vector2i(axis, mode)` keys covering all 5 modes × 2 axes. Vector2i chosen for reliable hash/equality semantics (H-4 fix). Keys point to `res://addons/penta_tile/layouts/penta_tile_layout_penta/<mode>_<axis>.png` — PNGs materialize in Wave 5.

### get_fallback_tile_set() Mode-Aware Sizing
```gdscript
tile_w = tex.get_width() / mode_count   # HORIZONTAL
tile_h = tex.get_height()               # single strip → full height per tile
# or
tile_w = tex.get_width()                # single strip → full width per tile
tile_h = tex.get_height() / mode_count  # VERTICAL
```
No hardcoded `Vector2i(16, 16)`. Returns null in Wave 3-5 intermediate state (PNGs not yet present).

### needs_synthesis() Override
Overrides `PentaTileLayout.needs_synthesis() → false` (base class Wave 2 stub) to return `true`. This enables `PentaTileMapLayer._ensure_synthesized_tile_set` to branch without a forward type reference to `PentaTileLayoutPenta`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] GDScript 2 cross-class const limitation**
- **Found during:** Task 3.1 — IDE reported "Identifier PentaTileSynthesis not declared" + "Assigned value for const isn't a constant expression" for all five `_SLOT_*` constants
- **Root cause:** GDScript 2 class-level `const` declarations are resolved at parse time, before the class_name symbol table is populated by other files. `PentaTileSynthesis.SLOT_ISOLATED_CELL` etc. are not available at parse time when used in a `const` declaration in a different file.
- **Fix:** Replaced cross-class const references with literal int values (0, 1, 2, 3, 4) with comment annotations referencing the `PentaTileSynthesis.SLOT_*` source. Added a comment explaining the GDScript 2 parse-time limitation so future maintainers don't reintroduce the pattern.
- **Files modified:** `addons/penta_tile/layouts/penta_tile_layout_penta.gd`
- **Commit:** eb19072

**2. [Rule 2 - Missing] Comment reference to deleted class name**
- **Found during:** Task 3.2 verification — `grep -r 'PentaTileLayoutPentaHorizontal' addons/` returned 1 hit in a comment
- **Fix:** Reworded `mask_to_atlas` comment from "Migrated from Phase 1's PentaTileLayoutPentaHorizontal.mask_to_atlas" to "Slot indices remapped from Phase 1's horizontal layout" — migration context preserved without the deleted class name
- **Files modified:** `addons/penta_tile/layouts/penta_tile_layout_penta.gd`
- **Commit:** d787bd3

## Inspector Verification (deferred to Wave 6 checkpoint)

The plan calls for opening a fresh `.tres` in the Godot 4.6 editor to confirm:
- `axis` dropdown (HORIZONTAL/VERTICAL) visible
- `tile_count` dropdown (AUTO/AUTO_STRIP/ONE..FIVE) visible
- `description` field visible
- `bitmask_template` NOT visible (hidden via `_validate_property`)

This manual verification is deferred to Wave 6's editor checkpoint per the plan's note that `_validate_property` changes require Godot editor open to confirm.

## Known Stubs

| Stub | File | Detail | Resolution |
|------|------|--------|------------|
| `get_fallback_tile_set()` returns null for all modes | penta_tile_layout_penta.gd | PNGs for `_BITMASK_TEMPLATE_LOOKUP` paths don't exist yet | Wave 5 ships the 10 PNGs |
| `tile_count == AUTO/AUTO_STRIP` defaults to FOUR | penta_tile_layout_penta.gd | Runtime detection not wired; fallback uses FOUR | Wave 6 wires AUTO/AUTO_STRIP detection |

## Threat Flags

None. No new network endpoints, auth paths, file access patterns, or schema changes. The `_BITMASK_TEMPLATE_LOOKUP` PNG paths use `res://` under the addon folder — resolved by Godot's sandboxed resource loader (T-02-04 accepted disposition from plan threat model).

## Self-Check: PASSED

- `addons/penta_tile/layouts/penta_tile_layout_penta.gd` exists, 272 lines, contains `class_name PentaTileLayoutPenta`, `extends PentaTileLayout`, `enum Axis`, `enum TileCountMode`, `_BITMASK_TEMPLATE_LOOKUP`, `_validate_property`, `get_fallback_tile_set`, `needs_synthesis`
- `addons/penta_tile/layouts/penta_tile_layout_penta_horizontal.gd` — confirmed absent
- `addons/penta_tile/layouts/penta_tile_layout_penta_vertical.gd` — confirmed absent
- No `PentaTileLayoutPentaHorizontal` or `PentaTileLayoutPentaVertical` references survive in `addons/`
- No `Vector2i(16, 16)` hardcoded in the new file
- `property.usage &= ~PROPERTY_USAGE_EDITOR` present (H-1 fix); no overwrite pattern
- `Vector2i(Axis.HORIZONTAL/VERTICAL, ...)` keys in lookup (H-4 fix)
- `Path B locked` comment on 4 outer-corner masks (M-2 fix)
- Commits eb19072 and d787bd3 verified in git log
