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
	TRAMPLE, ## Pass-through move: ATK X on enemies moved through; no displacement; end on open tile.
	BULLDOZE, ## Pass-through move: collision base X + PUSH X sideways; axial push when landing on target.
	MOVE, ## Skill-driven non-instant movement. Walk physics; respects collision unless combined with TRAMPLE/BULLDOZE.
	PUSH_STAGGER_ON_COLLISION, ## Modifier: PUSH applies STAGGER if the target collides.
	PULL_VULNERABLE_ON_ADJACENT, ## Modifier: PULL applies VULNERABLE if the target lands adjacent to caster.
	PUSH_CHAIN_COLLISION, ## Modifier: PUSH causes chain collisions (Bowling Charge).
	MOVE_INTO_AND_PUSH, ## Caster moves to target tile; target is pushed away in the same direction.
	THROW_BEHIND, ## Target is picked up and placed in the empty tile directly behind the caster.
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

	STAGGER,
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
	INDOMITABLE_WILL_UPGRADED, ## Same as INDOMITABLE_WILL, but grants +2 STR on expiration or shield break.
	THORNS,
	IRON_GRIP_DEBUFF,
}

static func is_buff(status: StatusType) -> bool:
	match status:
		StatusType.STAT_BUFF_STR, StatusType.STAT_BUFF_MP, StatusType.STAT_BUFF_ACC, StatusType.STAT_BUFF_MAG, StatusType.STAT_BUFF_DEF, StatusType.STAT_BUFF_MOV, StatusType.PIERCE, StatusType.GHOST, StatusType.TRAMPLE, StatusType.STEALTH, StatusType.INTERCEPT, StatusType.STURDY, StatusType.INVULNERABLE, StatusType.AIRBORNE, StatusType.CANTO, StatusType.RUNNING, StatusType.RETALIATION_PROTOCOL, StatusType.RETALIATION_INFINITE_RANGE, StatusType.INDOMITABLE_WILL, StatusType.INDOMITABLE_WILL_UPGRADED, StatusType.THORNS:
			return true
	return false

static func is_debuff(status: StatusType) -> bool:
	match status:
		StatusType.STAT_DEBUFF_DEF, StatusType.STAT_DEBUFF_ACC, StatusType.STAT_DEBUFF_MOV, StatusType.ELECTRIFIED, StatusType.WEAK_TRAP, StatusType.BURN, StatusType.BLEED, StatusType.POISON, StatusType.WEAKEN, StatusType.VULNERABLE, StatusType.STAGGER, StatusType.ROOT, StatusType.SILENCE, StatusType.TAUNT, StatusType.BLIND, StatusType.PACIFY, StatusType.FEAR, StatusType.CONFUSION, StatusType.POLYMORPH, StatusType.MARK, StatusType.IRON_GRIP_DEBUFF:
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
## Legacy mirror of PlannerGroup for UNIVERSAL_* system actions; prefer planner_group on AbilityData.
enum AbilityKind {
	CLASS_SKILL,      ## AP cost; consumes action slot; Action column.
	MOVEMENT_SKILL,   ## MP cost; pre-move only; does not consume action slot.
	UNIVERSAL_RUN,    ## AP + extended movement (Run); pre-move column.
	UNIVERSAL_WAIT,   ## Exhaust marker (not shown in skill list).
}

## Timeline column for class-library cards (ability-data.md §1). Replaces AbilityKind for authored skills.
enum PlannerGroup {
	ACTION,    ## Action column; AP; consumes action slot; may contain ON_PRE/ON_POST modules.
	PRE_MOVE,  ## Pre-Move column; MP; basic positioning; no action slot.
}

## Header cost primary/secondary resource (ability-data.md §1 cost block).
enum CostResource {
	NONE,
	AP,
	MP,
	HP,
}

## Header cost modifiers (ability-data.md §1).
enum CostModifier {
	NONE,
	ZERO_IF_ADJACENT_ENEMIES_GTE_N,
}

## When a module runs inside an ACTION skill (ability-data.md §2.1).
enum ModulePhase {
	ON_ACTION,
	ON_PRE,
	ON_POST,
}

## Motion destination mode when primary effect is motion (ability-data.md §2.2).
enum MotionMode {
	NONE,
	TO_EMPTY_TILE,
	TO_TARGET_UNIT,
	ADJACENT_TO_TARGET,
	BEHIND_TARGET,
	VAULT_OVER,
	INTO_OCCUPIED_PUSH,
	BACKWARDS,
	SLIDE_TARGET_OPPOSITE,
	ALLY_STEP,
}

## How a module obtains its aim (ability-data.md §2.5).
enum AimBinding {
	NEW_AIM,
	SAME_AS_MODULE_N,
	RULE_PICK,
}

## Range measurement origin (ability-data.md §3).
enum RangeOrigin {
	ACTOR,
	LAST_TARGETED_TILE,
	LAST_TARGETED_UNIT_TILE,
}

## Module gate — whether the module runs (ability-data.md §2.7).
enum ModuleGate {
	ALWAYS,
	IF_KILL,
	IF_DAMAGE_DEALT,
	IF_COLLIDED,
	IF_ADJACENT_ENEMY,
	IF_ADJACENT_ALLY,
	IF_ISOLATED,
	IF_NO_MOVE_THIS_TURN,
}

## Layer activation condition (ability-data.md §5).
enum LayerCondition {
	AT_RESOLUTION,
	WHEN_DAMAGE_DEALT,
	WHEN_MOVED_THROUGH_ENEMY,
	ON_COLLISION,
	ON_CHAIN_COLLISION,
	ON_KILL,
	ON_LAND,
	PER_TILE_MOVED,
	PER_TARGET_HIT,
	IF_ALREADY_ADJACENT,
	IF_FROM_BEHIND,
}

## Bundled keyword packages on a motion/damage module (ability-data.md §6).
enum AbilityKeywordId {
	NONE,
	TRAMPLE,
	BULLDOZE,
	GHOST,
	PIERCE,
	CANTO,
}

## Who may be selected when using an ability (legacy single-choice; synced from targeting_flags).
enum TargetingMode {
	SELF,
	ALLY_UNIT,
	ENEMY_UNIT,
	ANY_UNIT,
	TILE,
	DASH_LINE,
	ALLY_OR_SELF,
}

## Bitmask for ability targeting — editor checkboxes; combine freely.
enum TargetingFlags {
	SELF = 1,
	ALLY = 2,
	ENEMY = 4,
	TILE = 8,
	DASH_LINE = 16,
}

## How planning UI commits an ability (cursor, timeline, commit slots share this).
enum PlanningCommitFlow {
	IMMEDIATE,       ## One click commits the full action.
	AWAITING_TARGET, ## Two-phase: first click arms awaiting_target; second finalizes.
}

## Awaiting-target phase label category (maps to icons in PlanningIcons).
enum PlanningAwaitingPhase {
	GENERIC,
	MOVEMENT_ENDPOINT,
	TARGET_PICK,
}

## Default presentation anim when presentation_key is empty.
enum PresentationAnim {
	AUTO,
	ATTACK,
	SPELL,
	WALK,
	RUN,
	SUPER_RUN,
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
