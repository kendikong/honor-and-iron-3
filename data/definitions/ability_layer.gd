class_name AbilityLayer
extends Resource

## Purpose: Extra effect on the same targets as its parent module (ability-data.md §5).
## Responsibilities: Hold EffectData payload + activation condition.
## Dependencies: EffectData, GameEnums.
## Lifecycle: authored on AbilityModule; immutable at runtime.

@export var effect: EffectData = null
@export var condition: GameEnums.LayerCondition = GameEnums.LayerCondition.AT_RESOLUTION

## Typed collision-layer behavior; compile into the compatibility EffectData view.
@export var object_collision_stagger: bool = false
@export var enemy_collision_stagger_both: bool = false
@export var weapon_scaled: bool = false
@export var buff_per_destroyed_object: int = 0
@export var stagger_on_collision: bool = false
@export var intercept_grant_str: int = 0
@export var push_collision_pierce: bool = false
@export var push_collision_damage: int = 0
@export var difficult_terrain_created: bool = false
@export var rooted_push_bleed_weapon: bool = false
@export var grapple_pass_through_damage: int = 0
@export var ignite_flammable_terrain: bool = false
@export var ally_damage_zero: bool = false
@export var trap_vulnerable: bool = false
@export var crossing_blind: bool = false
@export var trap_def_debuff: int = 0
@export var range_one_damage_multiplier: float = 0.0
@export var damage_multiplier: float = 0.0
@export var side_attack_only: bool = false
@export var target_after_move_adjacent: bool = false
@export var elemental_surface: bool = false
@export var reaction_terrain: StringName = &""
@export var reaction_steam_splash: bool = false
@export var reaction_steam_splash_size: int = 0
@export var reaction_steam_splash_damage: int = 0
@export var set_max_move: int = 0
@export var arcane_trail: bool = false
@export var creation_adjacent_damage: int = 0
@export var terrain_id: StringName = &""
@export var hazard_duration: int = 0
@export var counterattack_melee: bool = false
@export var counterattack_on_intercept: bool = false
@export var bleed_weapon: bool = false
@export var skip_terrain_entry_status: bool = false
@export var skip_terrain_entry_bleed: bool = false
@export var hazard_damage_bonus: int = 0
@export var trap_damage_bonus: int = 0
@export var grant_ap: int = 0
@export var next_turn: bool = false
@export var burning_splash_magic: int = 0
@export var burning_splash_shape: GameEnums.TargetShape = GameEnums.TargetShape.SINGLE
@export var pierce_if_first_zero: bool = false
@export var damage_adjacent_on_landing: bool = false
@export var require_dash_line_enemy: bool = false
@export var dash_absorb_element: bool = false
@export var collision_splash_damage: int = 0
@export var collision_splash_weaken: bool = false
@export var push_if_target_on_water: int = 0
@export var lightning_rod: bool = false
@export var construct_hp_pct: float = 0.0
@export var spawn_furthest_empty_on_line: bool = false
@export var movement_penalty: int = 0
@export var from_behind_only: bool = false
@export var hazard_blind_on_entry: bool = false
@export var poison_hazard: bool = false
@export var landing_push: int = 0
@export var status_requires_debuff: bool = false
@export var cone_all_targets: bool = false
@export var wall_collision_stagger: bool = false
@export var oil_field: bool = false


func compile_runtime_modifiers() -> Dictionary:
	var modifiers: Dictionary = {}
	if object_collision_stagger:
		modifiers["object_collision_stagger"] = 1
	if enemy_collision_stagger_both:
		modifiers["enemy_collision_stagger_both"] = 1
	if weapon_scaled:
		modifiers["weapon_scaled"] = 1
	if buff_per_destroyed_object != 0:
		modifiers["buff_per_destroyed_object"] = buff_per_destroyed_object
	if stagger_on_collision:
		modifiers["stagger_on_collision"] = 1
	if intercept_grant_str != 0:
		modifiers["intercept_grant_str"] = intercept_grant_str
	if push_collision_pierce:
		modifiers["push_collision_pierce"] = true
	if push_collision_damage != 0:
		modifiers["push_collision_damage"] = push_collision_damage
	if difficult_terrain_created:
		modifiers["difficult_terrain_created"] = true
	if rooted_push_bleed_weapon:
		modifiers["rooted_push_bleed_weapon"] = true
	if grapple_pass_through_damage != 0:
		modifiers["grapple_pass_through_damage"] = grapple_pass_through_damage
	if ignite_flammable_terrain:
		modifiers["ignite_flammable_terrain"] = true
	if ally_damage_zero:
		modifiers["ally_damage_zero"] = true
	if trap_vulnerable:
		modifiers["trap_vulnerable"] = true
	if crossing_blind:
		modifiers["crossing_blind"] = true
	if trap_def_debuff != 0:
		modifiers["trap_def_debuff"] = trap_def_debuff
	if not is_zero_approx(range_one_damage_multiplier):
		modifiers["range_one_damage_multiplier"] = range_one_damage_multiplier
	if not is_zero_approx(damage_multiplier):
		modifiers["damage_multiplier"] = damage_multiplier
	if side_attack_only:
		modifiers["side_attack_only"] = true
	if target_after_move_adjacent:
		modifiers["target_after_move_adjacent"] = true
	if elemental_surface:
		modifiers["elemental_surface"] = true
	if reaction_terrain != StringName():
		modifiers["reaction_terrain"] = reaction_terrain
	if reaction_steam_splash:
		modifiers["reaction_steam_splash"] = true
	if reaction_steam_splash_size != 0:
		modifiers["reaction_steam_splash_size"] = reaction_steam_splash_size
	if reaction_steam_splash_damage != 0:
		modifiers["reaction_steam_splash_damage"] = reaction_steam_splash_damage
	if set_max_move != 0:
		modifiers["set_max_move"] = set_max_move
	if arcane_trail:
		modifiers["arcane_trail"] = true
	if creation_adjacent_damage != 0:
		modifiers["creation_adjacent_damage"] = creation_adjacent_damage
	if terrain_id != StringName():
		modifiers["terrain_id"] = terrain_id
	if hazard_duration != 0:
		modifiers["hazard_duration"] = hazard_duration
	if counterattack_melee:
		modifiers["counterattack_melee"] = true
	if counterattack_on_intercept:
		modifiers["counterattack_on_intercept"] = true
	if bleed_weapon:
		modifiers["bleed_weapon"] = true
	if skip_terrain_entry_status:
		modifiers["skip_terrain_entry_status"] = true
	if skip_terrain_entry_bleed:
		modifiers["skip_terrain_entry_bleed"] = true
	if hazard_damage_bonus != 0:
		modifiers["hazard_damage_bonus"] = hazard_damage_bonus
	if trap_damage_bonus != 0:
		modifiers["trap_damage_bonus"] = trap_damage_bonus
	if grant_ap != 0:
		modifiers["grant_ap"] = grant_ap
	if next_turn:
		modifiers["next_turn"] = true
	if burning_splash_magic != 0:
		modifiers["burning_splash_magic"] = burning_splash_magic
	if burning_splash_shape != GameEnums.TargetShape.SINGLE:
		modifiers["burning_splash_shape"] = burning_splash_shape
	if pierce_if_first_zero:
		modifiers["pierce_if_first_zero"] = true
	if damage_adjacent_on_landing:
		modifiers["damage_adjacent_on_landing"] = true
	if require_dash_line_enemy:
		modifiers["require_dash_line_enemy"] = true
	if dash_absorb_element:
		modifiers["dash_absorb_element"] = true
	if collision_splash_damage != 0:
		modifiers["collision_splash_damage"] = collision_splash_damage
	if collision_splash_weaken:
		modifiers["collision_splash_weaken"] = true
	if push_if_target_on_water != 0:
		modifiers["push_if_target_on_water"] = push_if_target_on_water
	if lightning_rod:
		modifiers["lightning_rod"] = true
	if not is_zero_approx(construct_hp_pct):
		modifiers["construct_hp_pct"] = construct_hp_pct
	if spawn_furthest_empty_on_line:
		modifiers["spawn_furthest_empty_on_line"] = true
	if movement_penalty != 0:
		modifiers["movement_penalty"] = movement_penalty
	if from_behind_only:
		modifiers["from_behind_only"] = true
	if hazard_blind_on_entry:
		modifiers["hazard_blind_on_entry"] = true
	if poison_hazard:
		modifiers["poison_hazard"] = true
	if landing_push != 0:
		modifiers["landing_push"] = landing_push
	if status_requires_debuff:
		modifiers["status_requires_debuff"] = true
	if cone_all_targets:
		modifiers["cone_all_targets"] = true
	if wall_collision_stagger:
		modifiers["wall_collision_stagger"] = true
	if oil_field:
		modifiers["oil_field"] = true
	return modifiers


func ingest_runtime_key(key: String, value: Variant) -> void:
	match key:
		"object_collision_stagger":
			object_collision_stagger = bool(value)
		"enemy_collision_stagger_both":
			enemy_collision_stagger_both = bool(value)
		"weapon_scaled":
			weapon_scaled = bool(value)
		"buff_per_destroyed_object":
			buff_per_destroyed_object = int(value)
		"stagger_on_collision":
			stagger_on_collision = bool(value)
		"intercept_grant_str":
			intercept_grant_str = int(value)
		"push_collision_pierce":
			push_collision_pierce = bool(value)
		"push_collision_damage":
			push_collision_damage = int(value)
		"difficult_terrain_created":
			difficult_terrain_created = bool(value)
		"rooted_push_bleed_weapon":
			rooted_push_bleed_weapon = bool(value)
		"grapple_pass_through_damage":
			grapple_pass_through_damage = int(value)
		"ignite_flammable_terrain":
			ignite_flammable_terrain = bool(value)
		"ally_damage_zero":
			ally_damage_zero = bool(value)
		"trap_vulnerable":
			trap_vulnerable = bool(value)
		"crossing_blind":
			crossing_blind = bool(value)
		"trap_def_debuff":
			trap_def_debuff = int(value)
		"range_one_damage_multiplier":
			range_one_damage_multiplier = float(value)
		"damage_multiplier":
			damage_multiplier = float(value)
		"side_attack_only":
			side_attack_only = bool(value)
		"target_after_move_adjacent":
			target_after_move_adjacent = bool(value)
		"elemental_surface":
			elemental_surface = bool(value)
		"reaction_terrain":
			reaction_terrain = StringName(value)
		"reaction_steam_splash":
			reaction_steam_splash = bool(value)
		"reaction_steam_splash_size":
			reaction_steam_splash_size = int(value)
		"reaction_steam_splash_damage":
			reaction_steam_splash_damage = int(value)
		"set_max_move":
			set_max_move = int(value)
		"arcane_trail":
			arcane_trail = bool(value)
		"creation_adjacent_damage":
			creation_adjacent_damage = int(value)
		"terrain_id":
			terrain_id = StringName(value)
		"hazard_duration":
			hazard_duration = int(value)
		"counterattack_melee":
			counterattack_melee = bool(value)
		"counterattack_on_intercept":
			counterattack_on_intercept = bool(value)
		"bleed_weapon":
			bleed_weapon = bool(value)
		"skip_terrain_entry_status":
			skip_terrain_entry_status = bool(value)
		"skip_terrain_entry_bleed":
			skip_terrain_entry_bleed = bool(value)
		"hazard_damage_bonus":
			hazard_damage_bonus = int(value)
		"trap_damage_bonus":
			trap_damage_bonus = int(value)
		"grant_ap":
			grant_ap = int(value)
		"next_turn":
			next_turn = bool(value)
		"burning_splash_magic":
			burning_splash_magic = int(value)
		"burning_splash_shape":
			burning_splash_shape = int(value)
		"pierce_if_first_zero":
			pierce_if_first_zero = bool(value)
		"damage_adjacent_on_landing":
			damage_adjacent_on_landing = bool(value)
		"require_dash_line_enemy":
			require_dash_line_enemy = bool(value)
		"dash_absorb_element":
			dash_absorb_element = bool(value)
		"collision_splash_damage":
			collision_splash_damage = int(value)
		"collision_splash_weaken":
			collision_splash_weaken = bool(value)
		"push_if_target_on_water":
			push_if_target_on_water = int(value)
		"lightning_rod":
			lightning_rod = bool(value)
		"construct_hp_pct":
			construct_hp_pct = float(value)
		"spawn_furthest_empty_on_line":
			spawn_furthest_empty_on_line = bool(value)
		"movement_penalty":
			movement_penalty = int(value)
		"from_behind_only":
			from_behind_only = bool(value)
		"hazard_blind_on_entry":
			hazard_blind_on_entry = bool(value)
		"poison_hazard":
			poison_hazard = bool(value)
		"landing_push":
			landing_push = int(value)
		"status_requires_debuff":
			status_requires_debuff = bool(value)
		"cone_all_targets":
			cone_all_targets = bool(value)
		"wall_collision_stagger":
			wall_collision_stagger = bool(value)
		"oil_field":
			oil_field = bool(value)
