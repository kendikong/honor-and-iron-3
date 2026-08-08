class_name UnitData
extends Resource

## Purpose: Stat/ability template for a unit. This is NOT live state; current HP,
## position, etc. live in UnitState (constitution: single source of truth).
## Responsibilities: Hold base values, ability list, and optional AI behavior.
## Dependencies: AbilityData, BehaviorData.
## Lifecycle: immutable; shared by every UnitState created from it.

@export var id: StringName = &""
@export var display_name: String = ""

@export var base_constitution: int = 2
@export var move_points: int = 3
@export var action_points: int = 1

## How this unit moves across the grid (WALK/FLY/TELEPORT).
@export var movement_type: GameEnums.MovementType = GameEnums.MovementType.WALK

## Stub: display level for the Compendium. No mechanical effect until
## unit progression is designed. Default 1 = base class / no upgrades yet.
@export var level: int = 1

## Modifier used by the Autobattler to prioritize high-value targets.
## Minions = 1.0, Elite = 2.0, Boss = 5.0+. Scales damage and kill scoring.
@export var threat_level: float = 1.0

@export var is_boss: bool = false
@export var is_construct: bool = false
@export var construct_scaling_percent: float = 0.0

@export var abilities: Array[AbilityData] = []

## Base stats that can be modified by level and gear.
@export var base_strength: int = 1
@export var base_magic: int = 1
@export var base_defense: int = 1
## Promotion-specific stat bonuses, keyed by promotion id.
@export var promotion_stat_bonuses: Dictionary = {}

## Which stat receives 75% of level-up growth (PHYSICAL=STR, MAGICAL=MAG, DEFENSE=DEF, MAX_HP=CON).
## Remaining 25% spreads to secondary stats (see UnitLevelGrowth).
@export var preferred_stat: GameEnums.StatType = GameEnums.StatType.PHYSICAL

@export var passives: Array[PassiveData] = []
## Always-active class trait. Unlike the promotion passive pool, this is never rolled.
@export var innate_passives: Array[PassiveData] = []
@export var equipped_weapon: WeaponData

## If null, the unit is player-controlled. If set, EnemyPlanner drives it.
## This is composition (a unit HAS a behavior), not inheritance.
@export var behavior: BehaviorData
