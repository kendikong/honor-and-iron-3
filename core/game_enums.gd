class_name GameEnums
extends RefCounted

## Purpose: Central home for shared enums so systems compare typed values, never
## strings (constitution: "Enums over strings").
## Responsibilities: Define cross-system enumerations only. No logic, no state.
## Dependencies: none.
## Lifecycle: never instantiated; used purely as a namespace.

enum Team {
	PLAYER,
	ENEMY,
	NEUTRAL,
}

enum StatType {
	NONE,
	PHYSICAL, # Scales with Strength
	MAGICAL,  # Scales with Magic
	DEFENSE,  # Scales with Defense
	MAX_HP,   # Scales with Max HP
	MISSING_HP, # Scales with (Max HP - Current HP)
	CURRENT_HP, # Scales with Current HP
}


enum Facing {
	NORTH,
	EAST,
	SOUTH,
	WEST,
}

## How abilities resolve their affected coordinates.
enum TargetShape {
	SINGLE,       ## Just the target tile
	AOE_SQUARE,   ## Square array of tiles centered on target (e.g. 3x3)
	AOE_CROSS,    ## Cross-shaped array expanding X tiles from center
	ARC,          ## 3-tile sweep perpendicular to the attack direction
	CONE,         ## Expanding cone outward from caster
	LINE,         ## Straight line from caster (e.g., SKEWER)
	AOE_DIAMOND,  ## Manhattan distance based diamond/circle
}

## How a unit traverses the grid. WALK = standard pathfinding; FLY = ignores
## terrain blocking; TELEPORT = warp to any unoccupied tile (no path needed).
enum MovementType {
	WALK,
	FLY,
	TELEPORT,
}

## A combat primitive. Abilities are lists of these; systems interpret them.
enum EffectType {
	DAMAGE,
	PUSH,
	PULL,
	SWAP,
	HEAL,
	ARMOR_UP,
	EXPLODE,   ## AoE damage to ALL units on the 4 cardinal tiles + actor (self-destruct).
	SPAWN,     ## Create a minion at the target tile from behavior.spawn_unit.
	ADD_STATUS, ## Apply a temporary status effect to the target.
	ADD_STATUS_SELF, ## Apply a temporary status effect to the actor.
	REMOVE_STATUS, ## Remove a temporary status effect from the target.
	DAMAGE_SELF, ## Deals unmitigated damage to the actor.
	RANGED_EXPLODE, ## AoE damage to target tile and all adjacent tiles.
	CLEANSE, ## Instantly remove all negative debuffs
	PURGE, ## Instantly remove all positive buffs and shields
	DASH,  ## Instantly move caster in a direction and apply effects to collided/passed targets
	DESTROY_OBSTACLE, ## Instantly destroy an obstacle/trap on the target tile
	TELEPORT_CASTER, ## Move caster to the target tile
	CHANGE_TERRAIN, ## Change the terrain of the target tile
	REFUND_AP_ON_CC, ## Refund AP if target already has ROOT or STUN
}

## Types of temporary statuses that can be applied to units.
enum StatusType {
	STAT_BUFF_STR,
	STAT_BUFF_MP,
	STAT_BUFF_ACC,
	STAT_BUFF_MAG,
	STAT_BUFF_DEF,
	STAT_BUFF_MOV,
	STAT_DEBUFF_DEF,
	STAT_DEBUFF_ACC,
	STAT_DEBUFF_MOV,
	ELECTRIFIED,
	WEAK_TRAP,
	# Phase 2 Statuses
	BURN,
	BLEED,
	POISON,
	WEAKEN,
	VULNERABLE,
	STUN,
	ROOT,
	SILENCE,
	TAUNT,
	BLIND,
	PACIFY,
	FEAR,
	CONFUSION,
	# Traits applied as buffs
	PIERCE,
	GHOST,
	TRAMPLE,
	STEALTH,
	INTERCEPT,
	MARK,
	STURDY,
	INVULNERABLE,
	AIRBORNE,
	CANTO,
	RUNNING,
	POLYMORPH,
	RETALIATION_PROTOCOL,
	RETALIATION_INFINITE_RANGE, ## Phalanx [+]: Retaliation Protocol counters at any range this turn.
	INDOMITABLE_WILL,
	THORNS,
	IRON_GRIP_DEBUFF,
}

static func is_buff(status: StatusType) -> bool:
	match status:
		StatusType.STAT_BUFF_STR, StatusType.STAT_BUFF_MP, StatusType.STAT_BUFF_ACC, StatusType.STAT_BUFF_MAG, StatusType.STAT_BUFF_DEF, StatusType.STAT_BUFF_MOV, StatusType.PIERCE, StatusType.GHOST, StatusType.TRAMPLE, StatusType.STEALTH, StatusType.INTERCEPT, StatusType.STURDY, StatusType.INVULNERABLE, StatusType.AIRBORNE, StatusType.CANTO, StatusType.RUNNING, StatusType.RETALIATION_PROTOCOL, StatusType.RETALIATION_INFINITE_RANGE, StatusType.INDOMITABLE_WILL, StatusType.THORNS:
			return true
	return false

static func is_debuff(status: StatusType) -> bool:
	match status:
		StatusType.STAT_DEBUFF_DEF, StatusType.STAT_DEBUFF_ACC, StatusType.STAT_DEBUFF_MOV, StatusType.ELECTRIFIED, StatusType.WEAK_TRAP, StatusType.BURN, StatusType.BLEED, StatusType.POISON, StatusType.WEAKEN, StatusType.VULNERABLE, StatusType.STUN, StatusType.ROOT, StatusType.SILENCE, StatusType.TAUNT, StatusType.BLIND, StatusType.PACIFY, StatusType.FEAR, StatusType.CONFUSION, StatusType.POLYMORPH, StatusType.MARK, StatusType.IRON_GRIP_DEBUFF:
			return true
	return false

## What a single timeline entry does.
## When a MOVE/FACE resolves relative to the unit's action: before or after ability.
enum MoveTiming {
	PRE_ACTION = 1,
	POST_ACTION = 2,
}

enum ActionType {
	MOVE,
	ABILITY,
	FACE,
}

## How an ability is classified for economy, timeline column, and validation.
enum AbilityKind {
	CLASS_SKILL,      ## AP cost; consumes action slot; Action column.
	MOVEMENT_SKILL,   ## MP cost; pre-move only; does not consume action slot.
	UNIVERSAL_RUN,    ## AP + extended movement (Run); pre-move column.
	UNIVERSAL_WAIT,   ## Exhaust marker (not shown in skill list).
}

## Who may be selected when using an ability.
enum TargetingMode {
	SELF,
	ALLY_UNIT,
	ENEMY_UNIT,
	ANY_UNIT,
	TILE,
	DASH_LINE,
}

## Default presentation anim when presentation_key is empty.
enum PresentationAnim {
	AUTO,
	ATTACK,
	SPELL,
	MOVE,
	NONE,
}

## Deterministic, ordered record of something that happened during simulation.
## Presentation animates these; the simulation never reads them back.
enum SimEventType {
	UNIT_MOVED,
	UNIT_PUSHED,
	UNIT_DAMAGED,
	UNIT_DIED,
	UNIT_FACED,
	COLLISION,
	ACTION_FAILED,
	ENEMY_PHASE_BEGAN,
	TURN_ENDED,
	UNIT_HEALED,
	UNIT_ARMORED,
	ABILITY_USED,
	COUNTER_ATTACK, ## Retaliation strike before damage (Stand Ground, etc.).
	UNIT_SPAWNED,   ## A minion/construct was created.
	UNIT_EXPLODED,  ## AoE detonation occurred (bomber).
	STATUS_APPLIED, ## A status effect was applied to a unit.
	STATUS_REMOVED, ## A status effect wore off or was removed.
	MATH_TELEMETRY,
	TERRAIN_CHANGED,
	TRAMPLE_HIT,    ## A TRAMPLE unit stepped through an enemy.
}
