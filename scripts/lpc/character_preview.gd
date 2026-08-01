class_name CharacterPreview
extends Node2D

## Standalone preview node: rolls a new character from a catalog + profile,
## applies it to 4 CharacterActors (one for each direction), and toggles walk/idle.

const CYCLE_WALK_SECS: float  = 2.0   # seconds spent active
const CYCLE_IDLE_SECS: float  = 1.5   # seconds spent idling

var _actors: Array[CharacterActor] = []
var _timer: float = 0.0
var _walking: bool = true
var last_recipe: CharacterRecipe

var current_action: String = "walk"

signal recipe_applied(report: Dictionary)


func _ready() -> void:
	for i in 4:
		var actor = CharacterActor.new()
		actor.name = "PreviewActor_" + str(i)
		add_child(actor)
		_actors.append(actor)


func _process(delta: float) -> void:
	if _actors[0].get_layer_count() == 0:
		return
	_timer -= delta
	if _timer <= 0.0:
		_toggle_state()


func set_action(action: String) -> void:
	current_action = action
	_walking = true
	_timer = CYCLE_WALK_SECS
	_update_actors_state()


func roll_and_apply(
	catalog: LpcCatalog,
	profile: CharacterGenProfile,
	class_id: String = "",
) -> void:
	var recipe: CharacterRecipe = CharacterRoller.roll(catalog, profile, -1, class_id)
	last_recipe = recipe
	var report: Dictionary = {}
	for i in range(_actors.size()):
		var r = _actors[i].apply_recipe(recipe)
		if i == 0:
			report = r
	report["seed"] = profile.seed
	recipe_applied.emit(report)
	
	_walking = true
	_timer = CYCLE_WALK_SECS
	_update_actors_state()


func _toggle_state() -> void:
	_walking = not _walking
	_timer = CYCLE_WALK_SECS if _walking else CYCLE_IDLE_SECS
	_update_actors_state()


func _update_actors_state() -> void:
	var config = LpcConstants.ACTIONS.get(current_action)
	var dirs: Array = config[2] if config != null else LpcConstants.DIRS
	
	for i in range(_actors.size()):
		var actor = _actors[i]
		if i < dirs.size():
			actor.visible = true
			var dir = dirs[i]
			actor.set_facing(StringName(current_action + "_" + dir))
			actor.set_walking(_walking)
			# Spread them out horizontally, centered. We add a visual offset of +40 
			# because the Godot SubViewportContainer appears to clip the left side slightly.
			var total = dirs.size()
			actor.position.x = (i - (total - 1) / 2.0) * 55.0 + 40.0
		else:
			actor.visible = false

func set_item_visibility(item_id: String, visible: bool) -> void:
	for actor in _actors:
		actor.set_item_visibility(item_id, visible)
