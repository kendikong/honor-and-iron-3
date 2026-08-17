class_name ExtraRulesConversionContract
extends RefCounted

## Fail-loud Extra Rules conversion bar.
## Add an ability id to CONVERTED_SKILL_IDS only after extras and leftover Extra Rule keys are gone.

const CONVERTED_SKILL_IDS: Array[StringName] = [
	&"knight_defensive_formation",
]

const CLASS_IDS: Array[StringName] = [
	&"knight",
	&"bruiser",
	&"archer",
	&"lancer",
	&"mage",
	&"cleric",
	&"mercenary",
	&"monk",
	&"rogue",
	&"beast_rider",
	&"engineer",
	&"shaman",
]

const EXTRA_RULE_HOMES: Dictionary = {
	AbilityExtraRule.Id.ABSORBS_ITEMS_SCRAP: &"summon",
	AbilityExtraRule.Id.ADJACENT_DEFENSE_BONUS: &"status",
	AbilityExtraRule.Id.AIRLIFT_ALLY_ATTACK_STRENGTH: &"move_someone",
	AbilityExtraRule.Id.AIRLIFT_DROP_STEP: &"move_someone",
	AbilityExtraRule.Id.AIRLIFT_KEEP_CASTER: &"move_someone",
	AbilityExtraRule.Id.AIRLIFT_PICKUP_STEP: &"move_someone",
	AbilityExtraRule.Id.ALLIES_PIERCE: &"keyword",
	AbilityExtraRule.Id.ALLIES_RANGE_BONUS: &"status",
	AbilityExtraRule.Id.ALLOW_FRIENDLY_TARGET: &"targeting",
	AbilityExtraRule.Id.ALLY_DAMAGE_ZERO: &"status",
	AbilityExtraRule.Id.ALLY_DEF_BUFF: &"status",
	AbilityExtraRule.Id.ALLY_HEAL_ENEMY_WPN: &"heal_field",
	AbilityExtraRule.Id.ALLY_STR_PER_DEBUFF: &"status",
	AbilityExtraRule.Id.APPLY_WEAKEN_ENEMY: &"status",
	AbilityExtraRule.Id.ARRIVAL_OVERCLOCK: &"status",
	AbilityExtraRule.Id.BARBED_WIRE: &"hazard",
	AbilityExtraRule.Id.BEHIND_TARGET_STRENGTH: &"attack_field",
	AbilityExtraRule.Id.BLEED_BONUS_DAMAGE: &"attack_field",
	AbilityExtraRule.Id.BLEED_WEAPON: &"attack_field",
	AbilityExtraRule.Id.BLIND_ON_PASS_OVER: &"attack_field",
	AbilityExtraRule.Id.BLINK: &"movement_self",
	AbilityExtraRule.Id.BLOODLUST: &"status",
	AbilityExtraRule.Id.BLOODLUST_BLEED_ON_ATTACK: &"status",
	AbilityExtraRule.Id.BLOODLUST_DEF: &"status",
	AbilityExtraRule.Id.BLOODLUST_HP: &"status",
	AbilityExtraRule.Id.BLOODLUST_MOV: &"status",
	AbilityExtraRule.Id.BONE_SPEAR: &"summon",
	AbilityExtraRule.Id.BONUS_DAMAGE_PER_DEBUFF: &"attack_field",
	AbilityExtraRule.Id.BONUS_DMG_FROM_OCCUPIED: &"attack_field",
	AbilityExtraRule.Id.BONUS_DMG_PCT_MAX_HP: &"attack_field",
	AbilityExtraRule.Id.BONUS_DMG_PER_10_HP: &"attack_field",
	AbilityExtraRule.Id.BONUS_IF_TARGET_ADJACENT_TO_ALLY: &"attack_field",
	AbilityExtraRule.Id.BONUS_IF_TARGET_DEBUFFED: &"attack_field",
	AbilityExtraRule.Id.BONUS_PER_ENEMY_PASSED: &"attack_field",
	AbilityExtraRule.Id.BOSS_DAMAGE_REDUCTION: &"attack_field",
	AbilityExtraRule.Id.BOSS_FALLBACK_PURGE_SHIELD: &"attack_field",
	AbilityExtraRule.Id.BOSS_FALLBACK_VULNERABLE: &"attack_field",
	AbilityExtraRule.Id.BOUNCE_COUNT: &"attack_field",
	AbilityExtraRule.Id.BOUNCE_RANGE: &"attack_field",
	AbilityExtraRule.Id.BOUNCE_WALLS_45: &"attack_field",
	AbilityExtraRule.Id.BUFF_ON_PUSH: &"attack_field",
	AbilityExtraRule.Id.CHAKRA_BURST_DAMAGE: &"attack_field",
	AbilityExtraRule.Id.CHAKRA_BURST_SHAPE: &"attack_field",
	AbilityExtraRule.Id.CHAKRA_BURST_SIZE: &"attack_field",
	AbilityExtraRule.Id.CHAKRA_SHIFT: &"movement_self",
	AbilityExtraRule.Id.CLEANSE_TARGET: &"status",
	AbilityExtraRule.Id.CONFUSION_NEXT_TURN: &"header",
	AbilityExtraRule.Id.CONSTRUCT_DESTRUCTION_REFUND_AP: &"resource",
	AbilityExtraRule.Id.CONSTRUCT_HP_PCT: &"summon",
	AbilityExtraRule.Id.CONSTRUCT_SPAWN: &"summon",
	AbilityExtraRule.Id.CONSTRUCT_UNMITIGATED_DAMAGE: &"attack_field",
	AbilityExtraRule.Id.COST_ALL_MOVEMENT: &"header",
	AbilityExtraRule.Id.CREATE_CRATER: &"attack_field",
	AbilityExtraRule.Id.CREATION_ADJACENT_DAMAGE: &"attack_field",
	AbilityExtraRule.Id.CREATION_ADJACENT_PUSH: &"forced_movement",
	AbilityExtraRule.Id.CROSSING_BLIND: &"movement_self",
	AbilityExtraRule.Id.CROSSING_MOV_PENALTY: &"movement_self",
	AbilityExtraRule.Id.CROSSING_WEAPON_DAMAGE: &"attack_field",
	AbilityExtraRule.Id.CURSE_OF_WEAKNESS: &"status",
	AbilityExtraRule.Id.DASH_ABSORB_ELEMENT: &"movement_self",
	AbilityExtraRule.Id.DELAYED_NEXT_TURN: &"header",
	AbilityExtraRule.Id.DENSITY_SHIFT: &"movement_self",
	AbilityExtraRule.Id.DESTROY_CORPSE_ON_KILL: &"attack_field",
	AbilityExtraRule.Id.DESTROY_TERRAIN: &"attack_field",
	AbilityExtraRule.Id.DOES_NOT_CONSUME_ACTION_SLOT: &"header",
	AbilityExtraRule.Id.DRAG_REMAINING_MOVEMENT: &"forced_movement",
	AbilityExtraRule.Id.DROP_ADJACENT: &"move_someone",
	AbilityExtraRule.Id.DROP_TRAP_DAMAGE_MULTIPLIER: &"hazard",
	AbilityExtraRule.Id.DUELIST_MARK_TARGET: &"status",
	AbilityExtraRule.Id.ELEMENTAL_SURGE: &"attack_field",
	AbilityExtraRule.Id.ELEMENTAL_SURGE_AP: &"resource",
	AbilityExtraRule.Id.EMP_FRIENDLY_CONSTRUCT_HEAL: &"heal_field",
	AbilityExtraRule.Id.EMP_FRIENDLY_CONSTRUCT_OVERCLOCK: &"status",
	AbilityExtraRule.Id.EMP_GRENADE: &"attack_field",
	AbilityExtraRule.Id.ENEMY_COLLISION_STAGGER_BOTH: &"layer",
	AbilityExtraRule.Id.ENEMY_DAMAGE_ALLY_HEAL: &"heal_field",
	AbilityExtraRule.Id.ENEMY_MAG_ATK: &"attack_field",
	AbilityExtraRule.Id.ENEMY_PUSHED_MOV: &"forced_movement",
	AbilityExtraRule.Id.ENTRY_ROOT: &"status",
	AbilityExtraRule.Id.EXCLUDE_CASTER: &"targeting",
	AbilityExtraRule.Id.EXHAUST_NEXT_TURN: &"header",
	AbilityExtraRule.Id.FERAL_DRAG: &"forced_movement",
	AbilityExtraRule.Id.FLANK_RUN_ADJACENT_ENEMY_BONUS: &"attack_field",
	AbilityExtraRule.Id.FRENZY_ON_KILL_AP: &"layer",
	AbilityExtraRule.Id.GHOST_MOVE: &"keyword",
	AbilityExtraRule.Id.GRANT_AP: &"resource",
	AbilityExtraRule.Id.GRAPPLE_BIDIRECTIONAL: &"resolution_choice",
	AbilityExtraRule.Id.GRAPPLE_PASS_THROUGH_DAMAGE: &"attack_field",
	AbilityExtraRule.Id.GRAPPLE_WALL_PULL_SELF: &"movement_self",
	AbilityExtraRule.Id.HAZARD_BLIND_ON_ENTRY: &"hazard",
	AbilityExtraRule.Id.HAZARD_DURATION: &"hazard",
	AbilityExtraRule.Id.HAZARD_STATUS: &"hazard",
	AbilityExtraRule.Id.HEAL_IF_TARGETS_GTE: &"heal_field",
	AbilityExtraRule.Id.HEAL_PER_DEBUFF: &"heal_field",
	AbilityExtraRule.Id.HEX: &"status",
	AbilityExtraRule.Id.HEX_VULNERABLE: &"status",
	AbilityExtraRule.Id.HOLY_AURA: &"hazard",
	AbilityExtraRule.Id.HOLY_GROUND: &"hazard",
	AbilityExtraRule.Id.HOLY_GROUND_DEF_DOWN: &"hazard",
	AbilityExtraRule.Id.HOLY_GROUND_ZONE: &"hazard",
	AbilityExtraRule.Id.IF_TARGET_ATTACKED_CASTER_LAST_TURN_BONUS: &"attack_field",
	AbilityExtraRule.Id.IF_TARGET_ATTACKED_CASTER_LAST_TURN_STAGGER: &"attack_field",
	AbilityExtraRule.Id.IF_TARGET_STAGGERED_BONUS: &"attack_field",
	AbilityExtraRule.Id.IF_TARGET_UNACTED_STAGGER: &"attack_field",
	AbilityExtraRule.Id.IGNITE_FLAMMABLE_TERRAIN: &"hazard",
	AbilityExtraRule.Id.IGNITE_OIL: &"hazard",
	AbilityExtraRule.Id.IGNITE_OIL_AREA: &"hazard",
	AbilityExtraRule.Id.IGNORE_TARGET_MAGIC_PCT: &"attack_field",
	AbilityExtraRule.Id.IGNORE_ZOC: &"keyword",
	AbilityExtraRule.Id.INHERIT_INCOMING_ATTACKS: &"layer",
	AbilityExtraRule.Id.INNER_FIRE: &"status",
	AbilityExtraRule.Id.INNER_FIRE_SURFACE: &"hazard",
	AbilityExtraRule.Id.INTERCEPT_PUSH_ATTACKER: &"forced_movement",
	AbilityExtraRule.Id.ITEM_COLLISION_DAMAGE: &"layer",
	AbilityExtraRule.Id.ITEM_COLLISION_STR_DIV: &"layer",
	AbilityExtraRule.Id.ITEM_COLLISION_VULNERABLE: &"layer",
	AbilityExtraRule.Id.KIDNAP: &"move_someone",
	AbilityExtraRule.Id.KILL_GRANT_AP: &"layer",
	AbilityExtraRule.Id.L_SHAPE_MOVE: &"movement_self",
	AbilityExtraRule.Id.LAND_OPPOSITE_TARGET: &"movement_self",
	AbilityExtraRule.Id.LANDED_MAGIC_BONUS: &"layer",
	AbilityExtraRule.Id.LANDING_ADJACENT_PUSH: &"forced_movement",
	AbilityExtraRule.Id.LANDING_ADJACENT_PUSH_STAGGER: &"forced_movement",
	AbilityExtraRule.Id.LEAP_ABSORB_SURFACE: &"movement_self",
	AbilityExtraRule.Id.LEAVE_ELEMENTAL_SURFACE: &"hazard",
	AbilityExtraRule.Id.LIFE_LINK: &"status",
	AbilityExtraRule.Id.LIFE_LINK_REDUCTION: &"status",
	AbilityExtraRule.Id.LIGHTNING: &"resource",
	AbilityExtraRule.Id.LIMIT_ONCE_PER_TURN: &"header",
	AbilityExtraRule.Id.LINE_BREAKER: &"movement_self",
	AbilityExtraRule.Id.LINK_ALLY_ENEMY: &"status",
	AbilityExtraRule.Id.LINK_BLIND: &"status",
	AbilityExtraRule.Id.LINK_PARTNER_PICK: &"status",
	AbilityExtraRule.Id.LINK_TWO_ENEMIES: &"status",
	AbilityExtraRule.Id.LINKED_ENEMY_BLIND: &"status",
	AbilityExtraRule.Id.LINKED_ENEMY_DAMAGE: &"status",
	AbilityExtraRule.Id.MAG_HEAL: &"heal_field",
	AbilityExtraRule.Id.MAGIC_LINK_DAMAGE: &"status",
	AbilityExtraRule.Id.MANA_SHIELD: &"status",
	AbilityExtraRule.Id.MANA_SHIELD_CASTING: &"status",
	AbilityExtraRule.Id.MANTRA_PEACE_WEAKEN: &"status",
	AbilityExtraRule.Id.MANUAL_DETONATION: &"header",
	AbilityExtraRule.Id.MANUAL_DETONATION_STAGGER: &"summon",
	AbilityExtraRule.Id.MARKED_TARGET_DEFENSE: &"status",
	AbilityExtraRule.Id.MECHANICAL_BOSS_DAMAGE_WPN: &"attack_field",
	AbilityExtraRule.Id.MINE_DAMAGE: &"hazard",
	AbilityExtraRule.Id.MINE_EXPLODE: &"hazard",
	AbilityExtraRule.Id.MINE_PULL: &"forced_movement",
	AbilityExtraRule.Id.MOVE_ACTIVE_TOTEM: &"move_someone",
	AbilityExtraRule.Id.MOVE_THROUGH_ADJACENT_UNIT: &"movement_self",
	AbilityExtraRule.Id.MOVEMENT_MP_OVERRIDE: &"header",
	AbilityExtraRule.Id.NEXT_ATTACK_PIERCE: &"keyword",
	AbilityExtraRule.Id.NEXT_ATTACK_STRENGTH: &"attack_field",
	AbilityExtraRule.Id.NEXT_RANGED_ATTACK_STRENGTH: &"attack_field",
	AbilityExtraRule.Id.NEXT_SKILL_ZERO_AP: &"header",
	AbilityExtraRule.Id.NEXT_TURN: &"header",
	AbilityExtraRule.Id.OBJECT_COLLISION_STAGGER: &"layer",
	AbilityExtraRule.Id.ON_DEATH_ADJACENT_DAMAGE: &"attack_field",
	AbilityExtraRule.Id.ON_HIT_SCRAP: &"resource",
	AbilityExtraRule.Id.ON_KILL_ALL_ALLIES_HEAL: &"heal_field",
	AbilityExtraRule.Id.ON_KILL_ALL_ALLIES_SHIELD: &"shield_field",
	AbilityExtraRule.Id.ON_KILL_BOTH_AP: &"resource",
	AbilityExtraRule.Id.ON_KILL_REFRESH_MARK_ZERO_AP: &"status",
	AbilityExtraRule.Id.ON_KILL_SHIELD: &"shield_field",
	AbilityExtraRule.Id.ON_KILL_SPREAD_SILENCE_ADJACENT: &"status",
	AbilityExtraRule.Id.OVERDRIVE_INJECTION: &"status",
	AbilityExtraRule.Id.PAIN_SPIKE: &"attack_field",
	AbilityExtraRule.Id.PAIRED_ALLY_CHARGE: &"move_someone",
	AbilityExtraRule.Id.PAIRED_ALLY_STRIKE_ATK: &"move_someone",
	AbilityExtraRule.Id.PIERCE: &"keyword",
	AbilityExtraRule.Id.PIERCE_VS_BLIND: &"keyword",
	AbilityExtraRule.Id.POISON_SPREAD_ON_PUSH_COLLISION: &"layer",
	AbilityExtraRule.Id.POUNCE_LAND_ADJACENT: &"movement_self",
	AbilityExtraRule.Id.PRESERVE_FACING: &"movement_self",
	AbilityExtraRule.Id.PREVENT_STEALTH_TELEPORT: &"movement_self",
	AbilityExtraRule.Id.PREVENT_TARGET_SHIELD: &"shield_field",
	AbilityExtraRule.Id.PULL_BEFORE_ATTACK: &"forced_movement",
	AbilityExtraRule.Id.PULL_SELF_OR_TARGET: &"resolution_choice",
	AbilityExtraRule.Id.PULL_SURFACES: &"forced_movement",
	AbilityExtraRule.Id.PULL_TO_CENTER: &"forced_movement",
	AbilityExtraRule.Id.PULLBACK: &"move_someone",
	AbilityExtraRule.Id.PULLBACK_ALLY_DEF: &"move_someone",
	AbilityExtraRule.Id.PURGE_BUFFS: &"status",
	AbilityExtraRule.Id.PUSH: &"forced_movement",
	AbilityExtraRule.Id.PUSH_BOARD_ITEMS: &"forced_movement",
	AbilityExtraRule.Id.PUSH_MITIGATION_ZERO: &"forced_movement",
	AbilityExtraRule.Id.RANGE_ONE_DAMAGE_MULTIPLIER: &"attack_field",
	AbilityExtraRule.Id.REACTION_DAMAGE: &"attack_field",
	AbilityExtraRule.Id.REACTION_TERRAIN: &"hazard",
	AbilityExtraRule.Id.REDIRECT_INCOMING_DAMAGE: &"layer",
	AbilityExtraRule.Id.REFUND_SCRAP: &"resource",
	AbilityExtraRule.Id.REFUND_SCRAP_ON_CONSTRUCT_DEATH: &"resource",
	AbilityExtraRule.Id.RELOCATE_SUBJECT_ONLY: &"move_someone",
	AbilityExtraRule.Id.RELOCATE_TARGET: &"move_someone",
	AbilityExtraRule.Id.REMOVE_PUSH_MITIGATION: &"forced_movement",
	AbilityExtraRule.Id.REPOSITION_MOVEMENT_COST: &"header",
	AbilityExtraRule.Id.REPOSITION_OPPOSITE_SIDE: &"move_someone",
	AbilityExtraRule.Id.REPOSITION_RANGE: &"move_someone",
	AbilityExtraRule.Id.REVIVE_PERCENT_MAX_HP: &"heal_field",
	AbilityExtraRule.Id.REVIVE_SHIELD: &"shield_field",
	AbilityExtraRule.Id.ROCKET_LAUNCHER: &"attack_field",
	AbilityExtraRule.Id.RUN_DOWN_PASS_ADJACENT_PUSH: &"forced_movement",
	AbilityExtraRule.Id.RUN_DOWN_PUSH_BLEED_WEAPON: &"forced_movement",
	AbilityExtraRule.Id.SACRIFICE_CONSTRUCT_INSTANT: &"summon",
	AbilityExtraRule.Id.SANCTUARY: &"hazard",
	AbilityExtraRule.Id.SANCTUARY_ENEMY_PUSH: &"forced_movement",
	AbilityExtraRule.Id.SCRAP_ATTACK_BONUS: &"attack_field",
	AbilityExtraRule.Id.SCRAP_BLEED_WEAPON: &"attack_field",
	AbilityExtraRule.Id.SCRAP_MULTIPLIER: &"shield_field",
	AbilityExtraRule.Id.SCRAP_SHIELD: &"shield_field",
	AbilityExtraRule.Id.SELF_MOVE_ZERO_NEXT_TURN: &"header",
	AbilityExtraRule.Id.SHADOW_STEP: &"movement_self",
	AbilityExtraRule.Id.SHARED_DAMAGE_WPN: &"attack_field",
	AbilityExtraRule.Id.SHARED_PUSH: &"forced_movement",
	AbilityExtraRule.Id.SHIELD_CLOSEST_ALLY_PCT_DAMAGE: &"shield_field",
	AbilityExtraRule.Id.SHIELD_DEPLETION_EXPLODE: &"shield_field",
	AbilityExtraRule.Id.SKEWER: &"attack_field",
	AbilityExtraRule.Id.SLIP_PAST: &"movement_self",
	AbilityExtraRule.Id.SMOKE_ALLY_HEAL_PER_TURN: &"heal_field",
	AbilityExtraRule.Id.SMOKE_FIELD: &"hazard",
	AbilityExtraRule.Id.SMOKE_ON_START: &"hazard",
	AbilityExtraRule.Id.SMOKE_STEALTH_OUTSIDE_ATTACKERS: &"hazard",
	AbilityExtraRule.Id.SPEND_SELF_HP: &"header",
	AbilityExtraRule.Id.STAGGER_IF_DEBUFFED: &"status",
	AbilityExtraRule.Id.STAT_DEF: &"status",
	AbilityExtraRule.Id.STAT_STR: &"status",
	AbilityExtraRule.Id.STOP_ADJACENT_FIRST_ENEMY: &"movement_self",
	AbilityExtraRule.Id.STRIKE_ALL_SURFACE: &"attack_field",
	AbilityExtraRule.Id.STRIP_STEALTH: &"status",
	AbilityExtraRule.Id.SURFACE_CHAIN: &"attack_field",
	AbilityExtraRule.Id.SWAP_COLLISION_STAGGER_BOTH: &"layer",
	AbilityExtraRule.Id.SWIFT_STRIKE: &"movement_self",
	AbilityExtraRule.Id.SWITCHEROO: &"move_someone",
	AbilityExtraRule.Id.SYMPATHETIC_BOND: &"status",
	AbilityExtraRule.Id.TARGET_DAMAGED_AP: &"layer",
	AbilityExtraRule.Id.TARGET_DEF_DEBUFF: &"status",
	AbilityExtraRule.Id.TARGET_DEF_PCT_DEBUFF: &"status",
	AbilityExtraRule.Id.TARGET_DEF_PCT_DURATION: &"status",
	AbilityExtraRule.Id.TARGET_DEF_PCT_LOSS: &"status",
	AbilityExtraRule.Id.TELEPORT_VISIBLE: &"movement_self",
	AbilityExtraRule.Id.TERRAIN_ID: &"hazard",
	AbilityExtraRule.Id.TERRIFY: &"status",
	AbilityExtraRule.Id.TESLA_WALL: &"hazard",
	AbilityExtraRule.Id.TRACK_FIRST_HIT_ZERO: &"attack_field",
	AbilityExtraRule.Id.TRAMPLE_ATK: &"keyword",
	AbilityExtraRule.Id.TRAP_BLEED_WEAPON: &"hazard",
	AbilityExtraRule.Id.TRAP_COLLISION_DAMAGE_MULTIPLIER: &"hazard",
	AbilityExtraRule.Id.TRAP_DAMAGE: &"hazard",
	AbilityExtraRule.Id.TRAP_DEF_DEBUFF: &"hazard",
	AbilityExtraRule.Id.TRAP_STATUS: &"hazard",
	AbilityExtraRule.Id.TRAP_VULNERABLE: &"hazard",
	AbilityExtraRule.Id.TURRET_ATTACK: &"summon",
	AbilityExtraRule.Id.UPGRADED_PROFILE: &"header",
	AbilityExtraRule.Id.UTILITY_ONLY: &"header",
	AbilityExtraRule.Id.VAULT_OBSTACLE_OR_GAP_ONLY: &"movement_self",
	AbilityExtraRule.Id.VIOLENT_COLLISION_RECAST: &"movement_self",
	AbilityExtraRule.Id.VOODOO_LINK: &"status",
	AbilityExtraRule.Id.WALL_COLLISION_STAGGER: &"layer",
	AbilityExtraRule.Id.WITHER: &"status",
	AbilityExtraRule.Id.WRENCH_SMACK: &"attack_field",
	AbilityExtraRule.Id.WRENCH_STRENGTH_BONUS: &"attack_field",
}

static func run_all(failures: Array[String]) -> void:
	_check_every_extra_rule_has_home(failures)
	_check_converted_skills(failures)

static func extra_rule_home(extra_id: AbilityExtraRule.Id) -> StringName:
	if extra_id == AbilityExtraRule.Id.NONE:
		return &""
	return EXTRA_RULE_HOMES.get(extra_id, &"") as StringName

static func _check_every_extra_rule_has_home(failures: Array[String]) -> void:
	var names: PackedStringArray = AbilityExtraRule.Id.keys()
	for index: int in range(1, names.size()):
		var extra_id: AbilityExtraRule.Id = index as AbilityExtraRule.Id
		if extra_rule_home(extra_id) == &"":
			failures.append("Extra Rule %s has no conversion home" % names[index])

static func _check_converted_skills(failures: Array[String]) -> void:
	for skill_id: StringName in CONVERTED_SKILL_IDS:
		var ability: AbilityData = _find_ability(skill_id)
		if ability == null:
			failures.append("CONVERTED_SKILL_IDS missing ability %s" % String(skill_id))
			continue
		_assert_skill_converted(ability, failures)

static func _assert_skill_converted(ability: AbilityData, failures: Array[String]) -> void:
	var label := String(ability.id)
	_assert_modules_converted(label, "base", ability.modules, failures)
	_assert_modules_converted(label, "upgrade", ability.upgraded_modules, failures)

static func _assert_modules_converted(
	label: String,
	profile: String,
	modules: Array[AbilityModule],
	failures: Array[String]
) -> void:
	for module: AbilityModule in modules:
		if module == null:
			continue
		if not module.extras.is_empty():
			failures.append("%s %s extras not empty" % [label, profile])
		for layer: AbilityLayer in module.layers:
			if layer == null or layer.effect == null:
				continue
			for key: Variant in layer.effect.modifiers:
				var key_text := String(key)
				if AbilityExtraRule.id_for_key(key_text) != AbilityExtraRule.Id.NONE:
					failures.append("%s %s leftover Extra Rule key %s" % [label, profile, key_text])

static func _find_ability(skill_id: StringName) -> AbilityData:
	for class_id: StringName in CLASS_IDS:
		var unit: UnitData = DataLibrary.get_unit(class_id)
		if unit == null:
			continue
		for ability: AbilityData in unit.abilities:
			if ability != null and ability.id == skill_id:
				return ability
	return null

