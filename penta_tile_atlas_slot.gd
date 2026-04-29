@tool
## A single atlas-slot record. Returned by PentaTileLayout.mask_to_atlas
## and consumed by PentaTileMapLayer._paint_with_slot.
class_name PentaTileAtlasSlot
extends Resource

## The (x, y) coords of the slot in the [Class TileSetAtlasSource] grid.
## Read by [method PentaTileMapLayer._paint_with_slot].
@export var atlas_coords: Vector2i = Vector2i.ZERO

## Render-time transforms applied via [Class TileSetAtlasSource]'s
## [constant TileSetAtlasSource.TRANSFORM_FLIP_H],
## [constant TileSetAtlasSource.TRANSFORM_FLIP_V], and
## [constant TileSetAtlasSource.TRANSFORM_TRANSPOSE] flags OR'd together. Shares
## one int with [member alternative_tile] per [b]Critical Pitfall #1[/b]; combine
## via [method PentaTileLayout._pack_alternative].
@export var transform_flags: int = 0

## Alt-tile id in the source's alternative grid. MUST be < 4096; the upper bits
## are reserved for [member transform_flags] per [b]Critical Pitfall #1[/b].
@export var alternative_tile: int = 0
