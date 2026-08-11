## Shared grid math for the floating-island world.
## 1 tile = TILE_SIZE metres; standard levels are DEFAULT_GRID_SIZE² tiles
## (dungeon/boss arenas use 16×16). Height is an integer level 0–7 where
## HEIGHT_STEP metres separate levels. Convention (matches TiledTerrain):
## height 1 → y = 0 (player ground level); height 0 is the sunken void rim.
class_name IslandGrid

const TILE_SIZE := 2.0
const DEFAULT_GRID_SIZE := 32
const HEIGHT_STEP := 1.0

## World-space XZ → tile coordinate. The grid is centred on the origin:
## tile (0,0) starts at (−half, −half) where half = grid_size × TILE_SIZE / 2.
static func world_to_tile(pos: Vector3, grid_size: int = DEFAULT_GRID_SIZE) -> Vector2i:
	var half := grid_size * TILE_SIZE * 0.5
	return Vector2i(
		int(floor((pos.x + half) / TILE_SIZE)),
		int(floor((pos.z + half) / TILE_SIZE)))

## Tile coordinate → world-space centre of that tile at the given height level.
static func tile_to_world(tile: Vector2i, height: int = 1, grid_size: int = DEFAULT_GRID_SIZE) -> Vector3:
	var half := grid_size * TILE_SIZE * 0.5
	return Vector3(
		tile.x * TILE_SIZE - half + TILE_SIZE * 0.5,
		tile_height_world(height),
		tile.y * TILE_SIZE - half + TILE_SIZE * 0.5)

## Integer height level → world y (height 1 = y 0).
static func tile_height_world(h: int) -> float:
	return (h - 1) * HEIGHT_STEP

## Snap an arbitrary world position to the centre of its tile.
static func snap_to_tile_center(pos: Vector3, height: int = 1, grid_size: int = DEFAULT_GRID_SIZE) -> Vector3:
	return tile_to_world(world_to_tile(pos, grid_size), height, grid_size)
