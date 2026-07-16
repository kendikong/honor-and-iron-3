class_name EcologyAmbientParticles
extends Node2D

## GPUParticles2D — peak-bright motes that shrink and dim over life, scattered full map.

const TILE_PX: int = 16

var _pollen: GPUParticles2D
var _spores: GPUParticles2D
var _dandelion: GPUParticles2D
var _map_size_px: Vector2 = Vector2.ZERO
var _enabled: bool = false
var _profile: BiomeProfile = BiomeProfile.for_variant(1)


func _ready() -> void:
	_pollen = _make_rising_emitter(
		"pollen",
		PixelTextureFactory.soft_glow(8, Color(1.0, 0.98, 0.62, 1.0)),
		56, 6.0, 10.0,
	)
	_spores = _make_rising_emitter(
		"spores",
		PixelTextureFactory.soft_glow(8, Color(0.94, 0.90, 0.76, 1.0)),
		44, 4.5, 8.0,
	)
	_dandelion = _make_rising_emitter(
		"dandelion",
		PixelTextureFactory.soft_glow(5, Color(1.0, 1.0, 1.0, 1.0)),
		32, 3.5, 6.5,
	)
	add_child(_pollen)
	add_child(_spores)
	add_child(_dandelion)
	set_process(false)


func apply_biome_profile(profile: BiomeProfile) -> void:
	_profile = profile if profile != null else BiomeProfile.for_variant(1)
	_apply_particle_tints()


func sync_map(size_cells: Vector2i, enabled: bool) -> void:
	_enabled = enabled
	_map_size_px = Vector2(size_cells) * float(TILE_PX)
	var half: Vector2 = _map_size_px * 0.5
	position = half
	for node: GPUParticles2D in [_pollen, _spores, _dandelion]:
		node.emitting = enabled
		node.visible = enabled
		node.position = Vector2.ZERO
		node.amount_ratio = 1.0
		var mat: ParticleProcessMaterial = node.process_material as ParticleProcessMaterial
		if mat != null:
			mat.emission_box_extents = Vector3(half.x, half.y, 1.0)
	visible = enabled
	set_process(enabled)


	set_process(enabled)
	_apply_particle_tints()


func _apply_particle_tints() -> void:
	if _pollen == null:
		return
	var tint: Color = _profile.particle_tint
	var pollen_col: Color = tint
	var spore_col: Color = Color(tint.r * 0.94, tint.g * 0.92, tint.b * 0.78, 1.0)
	var dandelion_col: Color = Color(
		lerpf(tint.r, 1.0, 0.35),
		lerpf(tint.g, 1.0, 0.35),
		lerpf(tint.b, 1.0, 0.35),
		1.0,
	)
	_tint_emitter(_pollen, pollen_col)
	_tint_emitter(_spores, spore_col)
	_tint_emitter(_dandelion, dandelion_col)


func _tint_emitter(node: GPUParticles2D, color: Color) -> void:
	var mat: ParticleProcessMaterial = node.process_material as ParticleProcessMaterial
	if mat != null:
		mat.color = color


func _process(_delta: float) -> void:
	if not _enabled:
		return
	var wind_x: float = 0.06
	if WindBus.process_mode != Node.PROCESS_MODE_DISABLED:
		wind_x = WindBus.direction.x * 0.12
	for node: GPUParticles2D in [_pollen, _spores, _dandelion]:
		var mat: ParticleProcessMaterial = node.process_material as ParticleProcessMaterial
		if mat == null:
			continue
		mat.direction = Vector3(wind_x, -1.0, 0.0).normalized()


func _make_rising_emitter(
	name: String,
	texture: Texture2D,
	amount: int,
	velocity_min: float,
	velocity_max: float,
) -> GPUParticles2D:
	var node: GPUParticles2D = GPUParticles2D.new()
	node.name = name
	node.amount = amount
	node.lifetime = 8.0
	node.preprocess = 6.0
	node.explosiveness = 0.0
	node.randomness = 0.45
	node.fixed_fps = 0
	node.interpolate = true
	node.texture = texture
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.particle_flag_disable_z = true
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(64.0, 64.0, 1.0)
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 22.0
	mat.initial_velocity_min = velocity_min
	mat.initial_velocity_max = velocity_max
	mat.gravity = Vector3(0.0, -2.0, 0.0)
	mat.damping_min = 0.05
	mat.damping_max = 0.18
	mat.scale_min = 0.66
	mat.scale_max = 1.22
	mat.color = Color(1.0, 1.0, 1.0, 1.0)
	mat.color_ramp = _life_brightness_ramp()
	mat.scale_curve = _life_scale_curve()
	node.process_material = mat
	return node


func _life_brightness_ramp() -> GradientTexture1D:
	var gradient: Gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.add_point(0.14, Color(1.0, 1.0, 1.0, 1.0))
	gradient.add_point(0.38, Color(1.0, 1.0, 1.0, 0.42))
	gradient.add_point(0.52, Color(1.0, 1.0, 1.0, 0.12))
	gradient.add_point(0.62, Color(1.0, 1.0, 1.0, 0.0))
	gradient.add_point(1.0, Color(1.0, 1.0, 1.0, 0.0))
	var ramp: GradientTexture1D = GradientTexture1D.new()
	ramp.gradient = gradient
	return ramp


func _life_scale_curve() -> CurveTexture:
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.18, 0.88))
	curve.add_point(Vector2(0.38, 0.58))
	curve.add_point(Vector2(0.52, 0.32))
	curve.add_point(Vector2(0.62, 0.14))
	curve.add_point(Vector2(1.0, 0.08))
	var tex: CurveTexture = CurveTexture.new()
	tex.curve = curve
	return tex
