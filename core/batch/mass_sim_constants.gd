class_name MassSimConstants
extends RefCounted

## Target goals and sample thresholds from Mass Simulation Dashboard Specification.

const DEFAULT_LOG_PATH := "user://batch_results.jsonl"
const SNAPSHOT_PATH := "user://mass_sim_snapshot.json"
const WORKSPACE_PATH := "user://mass_sim_workspace.json"

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
