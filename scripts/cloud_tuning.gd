class_name CloudTuning
extends RefCounted

## Persisted cloud-shadow scalars â†’ GPU field + CPU body receive (shared math).

const STRENGTH_MIN: float = 0.15
const STRENGTH_MAX: float = 1.0
const STRENGTH_DEFAULT: float = 0.90

const SCALE_TILES_MIN: float = 8.0
const SCALE_TILES_MAX: float = 96.0
const SCALE_TILES_DEFAULT: float = 10.0

const COVERAGE_MIN: float = 0.0
const COVERAGE_MAX: float = 1.0
const COVERAGE_DEFAULT: float = 0.50

const EDGE_SOFTNESS_MIN: float = 0.01
const EDGE_SOFTNESS_MAX: float = 0.18
const EDGE_SOFTNESS_DEFAULT: float = 0.05

const MASK_STEPS_MIN: float = 2.0
const MASK_STEPS_MAX: float = 16.0
const MASK_STEPS_DEFAULT: float = 10.0

const SHAPE_MIX_MIN: float = 0.0
const SHAPE_MIX_MAX: float = 1.0
const SHAPE_MIX_DEFAULT: float = 0.50

const SHAPE_SCALE_MIN: float = 1.0
const SHAPE_SCALE_MAX: float = 3.0
const SHAPE_SCALE_DEFAULT: float = 1.20

const PERSIST_KEYS: PackedStringArray = [
	"cloud_shadow_strength",
	"cloud_scale_tiles",
	"cloud_coverage",
	"cloud_edge_softness",
	"cloud_mask_steps",
	"cloud_shape_mix",
	"cloud_shape_scale",
]

static var _runtime: Dictionary = {}


static func clamp_all(settings: EffectsSettings) -> void:
	if settings == null:
		return
	settings.cloud_shadow_strength = clampf(
		settings.cloud_shadow_strength, STRENGTH_MIN, STRENGTH_MAX,
	)
	settings.cloud_scale_tiles = clampf(
		settings.cloud_scale_tiles, SCALE_TILES_MIN, SCALE_TILES_MAX,
	)
	settings.cloud_coverage = clampf(
		settings.cloud_coverage, COVERAGE_MIN, COVERAGE_MAX,
	)
	settings.cloud_edge_softness = clampf(
		settings.cloud_edge_softness, EDGE_SOFTNESS_MIN, EDGE_SOFTNESS_MAX,
	)
	settings.cloud_mask_steps = clampf(
		settings.cloud_mask_steps, MASK_STEPS_MIN, MASK_STEPS_MAX,
	)
	settings.cloud_shape_mix = clampf(
		settings.cloud_shape_mix, SHAPE_MIX_MIN, SHAPE_MIX_MAX,
	)
	settings.cloud_shape_scale = clampf(
		settings.cloud_shape_scale, SHAPE_SCALE_MIN, SHAPE_SCALE_MAX,
	)


static func apply_defaults(settings: EffectsSettings) -> void:
	if settings == null:
		return
	settings.cloud_shadow_strength = STRENGTH_DEFAULT
	settings.cloud_scale_tiles = SCALE_TILES_DEFAULT
	settings.cloud_coverage = COVERAGE_DEFAULT
	settings.cloud_edge_softness = EDGE_SOFTNESS_DEFAULT
	settings.cloud_mask_steps = MASK_STEPS_DEFAULT
	settings.cloud_shape_mix = SHAPE_MIX_DEFAULT
	settings.cloud_shape_scale = SHAPE_SCALE_DEFAULT
	clamp_all(settings)


static func load_scalar(cfg: ConfigFile, key: String, fallback: float) -> float:
	return float(cfg.get_value("effects", key, fallback))


static func sync_runtime(settings: EffectsSettings = null) -> void:
	_runtime = shader_params(settings)


static func shader_params(settings: EffectsSettings = null) -> Dictionary:
	var strength: float = STRENGTH_DEFAULT
	var scale_tiles: float = SCALE_TILES_DEFAULT
	var coverage: float = COVERAGE_DEFAULT
	var edge_soft: float = EDGE_SOFTNESS_DEFAULT
	var mask_steps: float = MASK_STEPS_DEFAULT
	var shape_mix: float = SHAPE_MIX_DEFAULT
	var shape_scale: float = SHAPE_SCALE_DEFAULT
	if settings != null:
		clamp_all(settings)
		strength = settings.cloud_shadow_strength
		scale_tiles = settings.cloud_scale_tiles
		coverage = settings.cloud_coverage
		edge_soft = settings.cloud_edge_softness
		mask_steps = settings.cloud_mask_steps
		shape_mix = settings.cloud_shape_mix
		shape_scale = settings.cloud_shape_scale
	var mask_center: float = lerpf(0.60, 0.46, coverage)
	var half_edge: float = edge_soft * 0.5
	return {
		"cloud_shadow_strength": strength,
		"cloud_scale_tiles": scale_tiles,
		"cloud_mask_low": mask_center - half_edge,
		"cloud_mask_high": mask_center + half_edge,
		"cloud_mask_steps": mask_steps,
		"cloud_shape_mix": shape_mix,
		"cloud_shape_scale": shape_scale,
	}


static func push_shader_uniforms(mat: ShaderMaterial, settings: EffectsSettings = null) -> void:
	if mat == null:
		return
	var params: Dictionary = shader_params(settings)
	for key: Variant in params:
		mat.set_shader_parameter(String(key), params[key])


static func strength(settings: EffectsSettings = null) -> float:
	if settings != null:
		return clampf(settings.cloud_shadow_strength, STRENGTH_MIN, STRENGTH_MAX)
	return float(_runtime.get("cloud_shadow_strength", STRENGTH_DEFAULT))


static func mask_low() -> float:
	return float(_runtime.get("cloud_mask_low", 0.505))


static func mask_high() -> float:
	return float(_runtime.get("cloud_mask_high", 0.555))


static func mask_steps() -> float:
	return float(_runtime.get("cloud_mask_steps", MASK_STEPS_DEFAULT))


static func scale_tiles() -> float:
	return float(_runtime.get("cloud_scale_tiles", SCALE_TILES_DEFAULT))


static func shape_mix() -> float:
	return float(_runtime.get("cloud_shape_mix", SHAPE_MIX_DEFAULT))


static func shape_scale() -> float:
	return float(_runtime.get("cloud_shape_scale", SHAPE_SCALE_DEFAULT))


static func tuning_signature(settings: EffectsSettings = null) -> int:
	return hash(shader_params(settings).values())


static func format_slider_value(spec: Dictionary, value: float) -> String:
	var fmt: String = str(spec.get("fmt", "%.2f"))
	if fmt == "int":
		return str(int(round(value)))
	return fmt % value


static func panel_slider_specs() -> Array[Dictionary]:
	return [
		{
			"kind": "slider",
			"key": "cloud_shadow_strength",
			"label": "Strength (how dark patches are)",
			"min": STRENGTH_MIN,
			"max": STRENGTH_MAX,
			"step": 0.01,
			"fmt": "%.2f",
		},
		{
			"kind": "slider",
			"key": "cloud_scale_tiles",
			"label": "Patch size (tiles across â€” higher = larger clouds)",
			"min": SCALE_TILES_MIN,
			"max": SCALE_TILES_MAX,
			"step": 1.0,
			"fmt": "int",
		},
		{
			"kind": "slider",
			"key": "cloud_coverage",
			"label": "Coverage / density (higher = more shadow on map)",
			"min": COVERAGE_MIN,
			"max": COVERAGE_MAX,
			"step": 0.01,
			"fmt": "%.2f",
		},
		{
			"kind": "slider",
			"key": "cloud_edge_softness",
			"label": "Edge softness (higher = fuzzier blob edges)",
			"min": EDGE_SOFTNESS_MIN,
			"max": EDGE_SOFTNESS_MAX,
			"step": 0.005,
			"fmt": "%.3f",
		},
		{
			"kind": "slider",
			"key": "cloud_mask_steps",
			"label": "Edge pixel steps (lower = harder, chunkier outline)",
			"min": MASK_STEPS_MIN,
			"max": MASK_STEPS_MAX,
			"step": 1.0,
			"fmt": "int",
		},
		{
			"kind": "slider",
			"key": "cloud_shape_mix",
			"label": "Shape blend (layer mix â€” changes blob character)",
			"min": SHAPE_MIX_MIN,
			"max": SHAPE_MIX_MAX,
			"step": 0.01,
			"fmt": "%.2f",
		},
		{
			"kind": "slider",
			"key": "cloud_shape_scale",
			"label": "Shape detail scale (higher = more broken-up patches)",
			"min": SHAPE_SCALE_MIN,
			"max": SHAPE_SCALE_MAX,
			"step": 0.01,
			"fmt": "%.2f",
		},
	]
