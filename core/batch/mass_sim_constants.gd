class_name MassSimConstants
extends RefCounted

## Target goals and sample thresholds from Mass Simulation Dashboard Specification.

const DEFAULT_LOG_PATH := "user://batch_results.jsonl"
const SNAPSHOT_PATH := "user://mass_sim_snapshot.json"
const WORKSPACE_PATH := "user://mass_sim_workspace.json"
const TIMELINE_PATH := "user://mass_sim_timeline.jsonl"
const CAPTURE_DIR := "res://tests/captures"
const INTERPRETATION_USER_PATH := "user://mass_sim_interpretation.json"

const SKIRMISH_PLAYER_COUNT := 4
const SKIRMISH_ENEMY_COUNT := 6
## Player units spawn with full promotion kit for balance meta (all class skills).
const SKIRMISH_PLAYER_LEVEL := 99
const SKIRMISH_ENEMY_LEVEL := 1
const SKIRMISH_PLAYER_PASSIVE_COUNT := 2

const RULES_REVISION := "1"

const MIN_SAMPLE_FULL_CONFIDENCE := 500
const MIN_SAMPLE_BASIC := 30
const MIN_CLASS_APPEARANCES := 8

const TARGET_PLAYER_WIN_PCT := 50.0
const TARGET_AVG_TURNS := 12.0
const TARGET_WHIFF_BATTLES_PCT := 15.0
const TARGET_TIMEOUT_PCT := 5.0
const TARGET_DRAW_PCT := 3.0

const WIN_RATE_MAJOR_DEV_PCT := 8.0
const WIN_RATE_CRITICAL_DEV_PCT := 15.0
const MAP_BIAS_MAJOR_DEV_PCT := 12.0
const CHAOS_ZSCORE_MAJOR := 2.0
