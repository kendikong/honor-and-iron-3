class_name AIProfile
extends Resource

## Purpose: Defines the base weights and class synergy modifiers for the Commander Autobattler AI.
## Responsibilities: Holds the base weight configuration for a specific role (e.g. Vanguard, Sentinel).
## Dependencies: None.
## Lifecycle: immutable; instantiated as .tres files and assigned to UnitData.behavior (or read by AI).

@export var profile_name: String = "Standard"
@export var description: String = "Balanced AI profile."

@export_group("Context Weights")
@export var base_lethality_weight: float = 1.0
@export var base_survivability_weight: float = 1.0
@export var base_position_weight: float = 1.0
@export var weight_lethality_aggro_scale: float = 3.0
@export var weight_surv_base_scale: float = 4.0
@export var weight_healer_absence_scale: float = 1.8
@export var weight_density_swarm_scale: float = 1.5
@export var pruning_survivability_threshold: float = 0.4

@export_group("Fast-Pass Search Weights")
@export var search_damage_weight: float = 4.0
@export var search_healing_weight: float = 4.0
@export var search_distance_weight: float = 3.0
@export var search_fortitude_weight: float = 3.0
@export var search_cohesion_weight: float = 3.0
@export var search_ap_tax: float = 1.0
@export var search_perturbation_offset: float = 0.25

@export_group("Objective Lethality & Survivability Weights")
@export var lethality_threat_scale: float = 0.15
@export var surv_squishy_numerator: float = 20.0

@export_group("Objective Positional & Cohesion Weights")
@export var cohesion_nearest_ally_weight: float = 0.4
@export var cohesion_team_center_weight: float = 0.6
@export var cohesion_safe_distance: float = 2.0
@export var cohesion_excess_dist_penalty: float = 0.2
@export var position_hazard_penalty: float = 30.0
@export var position_sweet_spot_bonus: float = 20.0
@export var position_item_magnetism: float = 5.0

@export_group("Future Potential Weights")
@export var potential_stat_point_weight: float = 10.0
@export var potential_stat_specialization_scale: float = 0.1
@export var potential_dot_weight: float = 2.0
@export var potential_resource_weight: float = 30.0
@export var potential_construct_hp_weight: float = 2.0
@export var potential_construct_atk_weight: float = 10.0
@export var potential_aura_bonus: float = 20.0
@export var potential_hazard_tile_weight: float = 10.0
@export var potential_hazard_proximity_scale: float = 2.5

@export_group("Penalties & Tie-Breakers")
@export var penalty_ap_tax: float = 0.1
@export var penalty_limited_use_base: float = 50.0
@export var penalty_displacement_loop: float = 50.0
@export var penalty_mov_tax: float = 0.1

## Search depth slider: K = slider_value + 1 (so slider=1 -> K=2, slider=2 -> K=3, etc.)
## Minimum effective K is 2. Exposed in Developer Settings UI.
@export_range(1, 6) var search_depth_slider: int = 2
