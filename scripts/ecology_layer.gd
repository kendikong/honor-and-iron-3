class_name EcologyLayer
extends Node2D

## Phase 7 ecology channel — ambient particles + sparse actors (opportunism step 4).

const _Butterfly = preload("res://scripts/butterfly_actor.gd")
const _Fish = preload("res://scripts/fish_actor.gd")
const _Frog = preload("res://scripts/frog_actor.gd")
const _Leaf = preload("res://scripts/falling_leaf_actor.gd")
const _Particles = preload("res://scripts/ecology_ambient_particles.gd")

const TILE_PX: int = 16
const MAX_BUTTERFLIES_BASE: int = 2
const MAX_BUTTERFLIES_FLORA: int = 5
const MAX_LEAVES: int = 4
const MAX_FROGS: int = 2
const MAX_FISH: int = 2

const _C = preload("res://scripts/mana_seed_constants.gd")

var _particles: EcologyAmbientParticles
var _grid: PlayerGrid
var _hints: Dictionary = {}
var _map_seed: int = 1
var _actors_enabled: bool = false
var _particles_enabled: bool = false
var _readability: ReadabilityEnforcer = ReadabilityEnforcer.new()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	z_as_relative = false
	z_index = _C.Z_ECOLOGY
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_particles = _Particles.new()
	_particles.name = "AmbientParticles"
	add_child(_particles)


func sync(
	grid: PlayerGrid,
	hints: Dictionary,
	map_seed: int,
	particles_on: bool,
	actors_on: bool,
	biome_profile: BiomeProfile = null,
) -> void:
	_grid = grid
	_hints = hints if hints != null else {}
	_map_seed = map_seed
	_particles_enabled = particles_on
	_actors_enabled = actors_on
	_rng.seed = map_seed + 4409
	_readability.reset()
	_clear_actors()
	if grid == null:
		_particles.sync_map(Vector2i.ZERO, false)
		visible = false
		return
	_particles.apply_biome_profile(biome_profile)
	_particles.sync_map(Vector2i(grid.width, grid.height), particles_on)
	if actors_on:
		_spawn_actors_from_hints()
	visible = particles_on or actors_on
	set_process(actors_on)


func readability() -> ReadabilityEnforcer:
	return _readability


func _clear_actors() -> void:
	for child: Node in get_children():
		if child == _particles:
			continue
		child.queue_free()


func _spawn_actors_from_hints() -> void:
	var flora_cells: Array = _hints.get("flora_cells", [])
	var butterfly_entries: Array = _sorted_butterfly_entries(_hints.get("butterfly_weights", []))
	var leaf_entries: Array = _hints.get("leaf_weights", [])
	var frog_entries: Array = _hints.get("frog_weights", [])
	var fish_entries: Array = _hints.get("fish_weights", [])

	var max_butterflies: int = MAX_BUTTERFLIES_FLORA if flora_cells.size() > 0 else MAX_BUTTERFLIES_BASE
	var b_count: int = 0
	for entry: Variant in butterfly_entries:
		if b_count >= max_butterflies:
			break
		if not bool(entry.get("flora", false)):
			continue
		var anchor: Vector2i = entry.get("anchor", Vector2i.ZERO)
		var flora_center: Vector2i = entry.get("flora_center", anchor) as Vector2i
		var actor: ButterflyActor = _Butterfly.new()
		actor.setup(anchor, _map_seed + b_count * 17, flora_cells, flora_center)
		add_child(actor)
		b_count += 1

	var f_count: int = 0
	for entry: Variant in frog_entries:
		if f_count >= MAX_FROGS:
			break
		if entry.get("weight", 0.0) < _rng.randf():
			continue
		var shore: Vector2i = entry.get("anchor", Vector2i.ZERO)
		var frog: FrogActor = _Frog.new()
		frog.setup(_grid, shore, _map_seed + f_count * 53)
		add_child(frog)
		f_count += 1

	var fi_count: int = 0
	for entry: Variant in fish_entries:
		if fi_count >= MAX_FISH:
			break
		if entry.get("weight", 0.0) < _rng.randf():
			continue
		var pond: Vector2i = entry.get("anchor", Vector2i.ZERO)
		var fish: FishActor = _Fish.new()
		fish.setup(_grid, pond, _map_seed + fi_count * 67)
		add_child(fish)
		fi_count += 1

	var l_count: int = 0
	for entry: Variant in leaf_entries:
		if l_count >= MAX_LEAVES:
			break
		var tree: Vector2i = entry.get("anchor", Vector2i.ZERO)
		if entry.get("weight", 0.0) < _rng.randf():
			continue
		var ground: Vector2i = _find_leaf_ground(tree)
		if ground.x < 0:
			continue
		var leaf: FallingLeafActor = _Leaf.new()
		leaf.setup(tree, ground, _map_seed + l_count * 23)
		add_child(leaf)
		l_count += 1


func _sorted_butterfly_entries(entries: Array) -> Array:
	var flora_first: Array = []
	var other: Array = []
	for entry: Variant in entries:
		if bool(entry.get("flora", false)):
			flora_first.append(entry)
		else:
			other.append(entry)
	flora_first.append_array(other)
	return flora_first


func _find_leaf_ground(tree: Vector2i) -> Vector2i:
	if _grid == null:
		return Vector2i(-1, -1)
	for off: Vector2i in [Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(0, 2)]:
		var n: Vector2i = tree + off
		if not _in_bounds(n):
			continue
		var tid: int = _grid.get_cell(n)
		if tid == TileId.Type.GRASS or tid == TileId.Type.DIRT:
			return n
	return Vector2i(-1, -1)


func _in_bounds(pos: Vector2i) -> bool:
	return _grid != null and pos.x >= 0 and pos.y >= 0 and pos.x < _grid.width and pos.y < _grid.height
