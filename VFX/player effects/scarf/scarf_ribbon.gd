extends MeshInstance2D
## Journey-style ribbon scarf.
##
## NODE TYPE: MeshInstance2D (replaces Line2D). Assign a ShaderMaterial that uses
## scarf_ribbon.gdshader to the `material` slot. Everything else is built in code.
##
## Pipeline per simulation step (fixed rate, anchor interpolated across sub-steps):
##   1. Position-Verlet integration with aerodynamic lift/drag against a local air
##      velocity (global wind * gusts + divergence-free curl turbulence).
##   2. Soft constraints: velocity blending, bend (angular) damping, weak straightening,
##      then PBD distance constraints (alternating sweep direction).
##   3. Torsion chain: per-particle twist angle + twist velocity, driven by wind shear,
##      flow vorticity, curvature velocity, aerodynamic alignment torque and player turns.
## Every frame the ribbon mesh is rebuilt (real cross-section projection, so camber and
## twist change the silhouette) and tangent/twist data is uploaded to a float texture
## that the shader reads in vertex() and uses for per-pixel normals.

@export_category("Anchor")
@export var target_anchor: Marker2D
@export var initial_direction: Vector2 = Vector2.LEFT
## If the anchor moves farther than this in one physics frame, the scarf is reset.
@export var teleport_distance: float = 600.0

@export_category("Ribbon Geometry")
@export_range(4, 64) var particle_count: int = 24
@export var segment_length: float = 9.0
@export var ribbon_width: float = 16.0
## Width multiplier along the length (x = 0 head .. 1 tip). A default is created if empty.
@export var width_curve: Curve
## Half-angle (radians) of the cross-section arc. 0 = flat, ~0.8 = nicely rounded.
## Also sent to the shader so geometry and shading agree.
@export_range(0.0, 1.5) var camber: float = 0.8
@export_range(2, 9) var cross_segments: int = 5

@export_category("Simulation")
@export var simulation_hz: float = 120.0
@export var max_steps_per_frame: int = 6
@export var solver_iterations: int = 4
@export var gravity: Vector2 = Vector2(0.0, 55.0)
## Passive viscous drag (1/s). Most damping comes from the aerodynamics.
@export var linear_drag: float = 0.6

@export_category("Aerodynamics")
@export var wind: Vector2 = Vector2(25.0, -8.0)
## acceleration = 0.5 * air_density * coefficient * |u_rel|^2
@export var air_density: float = 0.03
@export var skin_drag: float = 0.15
@export var form_drag: float = 1.2
## Flat plate theory gives lift_coefficient ~ form_drag / 2. Higher = more fluttery.
@export var lift_coefficient: float = 1.1
## Fraction of the ribbon that "catches" 2D crossflow when it is flat to the screen (twist 0).
@export_range(0.0, 1.0) var min_twist_catch: float = 0.4
@export var max_aero_accel: float = 2500.0

@export_category("Ambient Air")
## Peak speed (px/s) of the stacked curl-noise air currents.
@export var turbulence_strength: float = 60.0
## Base spatial frequency in rad/px (0.03 ~ 210 px wavelength).
@export var turbulence_scale: float = 0.03
@export var turbulence_speed: float = 0.8
@export_range(1, 4) var turbulence_octaves: int = 3
@export var turbulence_lacunarity: float = 2.1
@export var turbulence_gain: float = 0.5
## Slow global gusting of the base wind (0 = none).
@export_range(0.0, 1.5) var gust_amount: float = 0.5
@export var gust_period: float = 5.0

@export_category("Softness")
## Rate (1/s) at which each particle's velocity blends toward its parent's.
@export var velocity_blend_rate: float = 10.
## Rate (1/s) at which relative angular motion between segments is damped.
@export var angular_damping: float = 3.0
## Very weak straightening (1/s^2). Fades to ~30% toward the tip.
@export var bend_stiffness: float = 12.0

@export_category("Torsion")
## Torsional wave stiffness along the ribbon (1/s^2).
@export var twist_coupling: float = 220.0
@export var twist_damping: float = 3.0
@export var twist_restore: float = 6.0
@export var max_twist_velocity: float = 25.0
## Resting helical pitch: radians of twist added per segment.
@export var rest_twist_per_segment: float = 0.22
## Amplitude (radians) of a slowly travelling twist wave that is always present.
@export var ambient_twist: float = 0.5
## Torque from d(crosswind)/d(length).
@export var shear_torque: float = 2.0
## Torque from the vorticity of the turbulent field.
@export var vorticity_torque: float = 3.0
## Torque from curvature velocity (whipping bends roll the ribbon).
@export var curvature_torque: float = 1.5
## Torque that rolls the plate broadside to crossflow.
@export var aero_align_torque: float = 2.0
## Head twist impulse from the player changing travel direction.
@export var player_turn_twist: float = 6.0
@export var head_bank_max: float = 1.2
@export var head_bank_speed: float = 220.0
@export var head_spring: float = 30.0
@export var head_damping: float = 8.0

const MAX_WAVES := 8
const ALIGN_REF_SPEED := 150.0

# --- particle state -------------------------------------------------------------------
var _pos := PackedVector2Array()
var _prev := PackedVector2Array()
var _vel := PackedVector2Array()
var _tan := PackedVector2Array()
var _air := PackedVector3Array()      # xy = air velocity, z = flow vorticity
var _air_n := PackedFloat32Array()    # ambient air velocity along ribbon normal
var _rel_n := PackedFloat32Array()    # air relative to particle, along ribbon normal
var _twist := PackedFloat32Array()
var _twist_vel := PackedFloat32Array()
var _twist_acc := PackedFloat32Array()
var _curvature := PackedFloat32Array()

# --- render state ---------------------------------------------------------------------
var _mesh: ArrayMesh
var _verts := PackedVector2Array()
var _uvs := PackedVector2Array()
var _indices := PackedInt32Array()
var _data_img: Image
var _data_tex: ImageTexture

# --- misc state -----------------------------------------------------------------------
var _wave_dir := PackedVector2Array()
var _wave_phase := PackedFloat32Array()
var _time: float = 0.0
var _accumulator: float = 0.0
var _last_anchor: Vector2 = Vector2.ZERO
var _player_velocity: Vector2 = Vector2.ZERO
var _turn_rate: float = 0.0


func _ready() -> void:
	# World-space simulation: detach from the parent transform so vertices are world coords.
	top_level = true
	global_transform = Transform2D.IDENTITY
	# Run after the player so the anchor is up to date.
	process_physics_priority = 100

	if width_curve == null:
		width_curve = Curve.new()
		width_curve.add_point(Vector2(0.0, 0.65))
		width_curve.add_point(Vector2(0.2, 1.0))
		width_curve.add_point(Vector2(0.85, 1.0))
		width_curve.add_point(Vector2(1.0, 0.6))

	if not (material is ShaderMaterial):
		push_warning("Scarf: assign a ShaderMaterial using scarf_ribbon.gdshader to `material`.")

	_setup_turbulence()
	rebuild()


## Rebuilds all buffers and resets the simulation. Called automatically when
## particle_count / cross_segments change or the anchor teleports.
func rebuild() -> void:
	var n := particle_count
	var m := cross_segments

	_pos.resize(n)
	_prev.resize(n)
	_vel.resize(n)
	_tan.resize(n)
	_air.resize(n)
	_air_n.resize(n)
	_rel_n.resize(n)
	_twist.resize(n)
	_twist_vel.resize(n)
	_twist_acc.resize(n)
	_curvature.resize(n)

	var anchor := global_position
	if target_anchor:
		anchor = target_anchor.global_position
	_last_anchor = anchor
	_player_velocity = Vector2.ZERO
	_turn_rate = 0.0
	_accumulator = 0.0

	var dir := initial_direction.normalized()
	if dir.length_squared() < 0.5:
		dir = Vector2.LEFT

	for i in range(n):
		var p := anchor + dir * (segment_length * float(i))
		_pos[i] = p
		_prev[i] = p
		_vel[i] = Vector2.ZERO
		_tan[i] = dir
		_air[i] = Vector3.ZERO
		_air_n[i] = 0.0
		_rel_n[i] = 0.0
		_twist[i] = rest_twist_per_segment * float(i)
		_twist_vel[i] = 0.0
		_twist_acc[i] = 0.0
		_curvature[i] = 0.0

	# Mesh topology (static): n rows x m columns.
	_verts.resize(n * m)
	_uvs.resize(n * m)
	_indices.clear()
	for i in range(n):
		for j in range(m):
			_uvs[i * m + j] = Vector2(float(i) / float(n - 1), float(j) / float(m - 1))
	for i in range(n - 1):
		for j in range(m - 1):
			var a := i * m + j
			var b := a + 1
			var c := a + m
			var d := c + 1
			_indices.append_array(PackedInt32Array([a, c, b, b, c, d]))

	_mesh = ArrayMesh.new()
	mesh = _mesh

	# Data texture: row 0 = (tangent.x, tangent.y, sin(twist), cos(twist))
	#               row 1 = (twist velocity, curvature, 0, 0)
	_data_img = Image.create(n, 2, false, Image.FORMAT_RGBAF)
	_data_tex = ImageTexture.create_from_image(_data_img)
	var mat := material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("ribbon_data", _data_tex)

	_update_render()


func _needs_rebuild() -> bool:
	return _pos.size() != particle_count or _verts.size() != particle_count * cross_segments


func _physics_process(delta: float) -> void:
	if target_anchor == null:
		return
	if _needs_rebuild():
		rebuild()

	var anchor_now := target_anchor.global_position
	if anchor_now.distance_to(_last_anchor) > teleport_distance:
		rebuild()
		return

	# Player kinematics (smoothed) -> turn rate used to kick head torsion.
	var safe_delta := maxf(delta, 0.0001)
	var raw_vel := (anchor_now - _last_anchor) / safe_delta
	var new_vel := _player_velocity.lerp(raw_vel, 0.4)
	if new_vel.length() > 40.0 and _player_velocity.length() > 40.0:
		var turn := _player_velocity.angle_to(new_vel) / safe_delta
		_turn_rate = lerpf(_turn_rate, clampf(turn, -25.0, 25.0), 0.35)
	else:
		_turn_rate = lerpf(_turn_rate, 0.0, 0.25)
	_player_velocity = new_vel

	# Fixed-rate sub-stepping with anchor interpolation (no stair-stepping).
	var step_dt := 1.0 / maxf(simulation_hz, 30.0)
	_accumulator += delta
	var steps := int(_accumulator / step_dt)
	_accumulator -= float(steps) * step_dt
	steps = mini(steps, max_steps_per_frame)
	for k in range(steps):
		var a := float(k + 1) / float(steps)
		_simulate_step(step_dt, _last_anchor.lerp(anchor_now, a))

	_last_anchor = anchor_now
	_update_render()


# =========================================================================================
#  Simulation
# =========================================================================================

func _simulate_step(dt: float, anchor_pos: Vector2) -> void:
	_time += dt
	var n := particle_count

	# 1. Pin the head and snapshot per-step displacements.
	_prev[0] = _pos[0]
	_pos[0] = anchor_pos
	for i in range(n):
		_vel[i] = _pos[i] - _prev[i]
	_update_tangents()

	# 2. Sample the air at every particle (wind * gust + curl turbulence).
	var gust := 1.0
	if gust_amount > 0.0:
		var g1 := sin(_time * TAU / maxf(gust_period, 0.1))
		var g2 := sin(_time * TAU / maxf(gust_period * 0.37, 0.05) + 1.3)
		gust = 1.0 + gust_amount * (0.6 * g1 + 0.4 * g2)
	var base_wind := wind * gust
	for i in range(n):
		var a := _air_at(_pos[i])
		_air[i] = Vector3(base_wind.x + a.x, base_wind.y + a.y, a.z)

	# 3. Integrate free particles.
	var drag_k := exp(-linear_drag * dt)
	var bend_k := 1.0 - exp(-angular_damping * dt)
	var blend_k := 1.0 - exp(-velocity_blend_rate * dt)
	var inv_last := 1.0 / float(maxi(n - 1, 1))

	for i in range(1, n):
		var v := _vel[i]
		var parent_v := _vel[i - 1]

		# Velocity blending: the tail drifts with its parent -> coherent, silky motion.
		v = v.lerp(parent_v, blend_k)

		# Angular damping: remove a fraction of the velocity perpendicular to the segment,
		# measured relative to the parent. Kills rubber-band oscillation, keeps flow.
		var seg := _pos[i] - _pos[i - 1]
		var seg_len := seg.length()
		if seg_len > 0.0001:
			var d := seg / seg_len
			var rel := v - parent_v
			var perp := rel - d * rel.dot(d)
			v -= perp * bend_k

		v *= drag_k

		# Aerodynamics against the local air.
		var air := Vector2(_air[i].x, _air[i].y)
		var u_rel := air - v / dt
		var acc := gravity + _aero_accel(u_rel, _tan[i], _twist[i], dt)

		# Weak straightening, fading toward the tip.
		if i >= 2:
			var dir_prev := (_pos[i - 1] - _pos[i - 2]).normalized()
			var target := _pos[i - 1] + dir_prev * segment_length
			var stiff := bend_stiffness * (1.0 - 0.7 * float(i) * inv_last)
			acc += (target - _pos[i]) * stiff

		_prev[i] = _pos[i]
		_pos[i] += v + acc * (dt * dt)

	# 4. Distance constraints (PBD). Head is pinned. Alternate sweep direction.
	for iter in range(solver_iterations):
		for k in range(n - 1):
			var i := k
			if iter % 2 == 1:
				i = n - 2 - k
			var delta_pos := _pos[i + 1] - _pos[i]
			var dist := delta_pos.length()
			if dist < 0.0001:
				continue
			var err := (dist - segment_length) / dist
			if i == 0:
				_pos[1] -= delta_pos * err
			else:
				_pos[i] += delta_pos * (0.5 * err)
				_pos[i + 1] -= delta_pos * (0.5 * err)

	# 5. Torsion from the final configuration.
	_update_tangents()
	_update_torsion(dt)


## Flat-plate lift/drag. u_rel = air velocity relative to the particle.
func _aero_accel(u_rel: Vector2, t: Vector2, twist: float, dt: float) -> Vector2:
	var speed := u_rel.length()
	if speed < 0.001:
		return Vector2.ZERO
	var u_dir := u_rel / speed
	var n2 := Vector2(-t.y, t.x)

	var un := u_dir.dot(n2)            # signed sin(angle of attack)
	var sin_a := absf(un)
	var cos_a := absf(u_dir.dot(t))

	# A twisted ribbon presents more of its face to in-plane crossflow.
	var catch_factor := lerpf(min_twist_catch, 1.0, absf(sin(twist)))
	var q := 0.5 * air_density * speed * speed * catch_factor

	var cd := skin_drag + form_drag * sin_a * sin_a
	var cl := lift_coefficient * 2.0 * sin_a * cos_a

	var n_side := n2 * signf(un)       # plate normal facing the incoming flow
	var lift_dir := (n_side - u_dir * n_side.dot(u_dir)).normalized()

	var a := u_dir * (cd * q) + lift_dir * (cl * q)

	# Stability: never let one step overshoot the relative velocity, and cap magnitude.
	var a_len := a.length()
	var limit := minf(max_aero_accel, speed / dt * 0.9)
	if a_len > limit:
		a *= limit / a_len
	return a


## Stacked curl noise. Stream function psi = sum (A/f) sin(f d.p + w t + phi)
## velocity = (dpsi/dy, -dpsi/dx)  -> divergence free, swirly, cheap and analytic.
## Returns (u.x, u.y, vorticity).
func _air_at(p: Vector2) -> Vector3:
	var u := Vector2.ZERO
	var vort := 0.0
	var waves := mini(turbulence_octaves * 2, MAX_WAVES)
	var amp := turbulence_strength * 0.7
	var freq := turbulence_scale
	var spd := turbulence_speed
	for k in range(waves):
		var d := _wave_dir[k]
		var ph := d.dot(p) * freq + _time * spd + _wave_phase[k]
		u += Vector2(d.y, -d.x) * (amp * cos(ph))
		vort += amp * freq * sin(ph)
		if k % 2 == 1:
			amp *= turbulence_gain
			freq *= turbulence_lacunarity
			spd *= 1.35
	return Vector3(u.x, u.y, vort)


func _setup_turbulence() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_wave_dir.resize(MAX_WAVES)
	_wave_phase.resize(MAX_WAVES)
	for k in range(MAX_WAVES):
		var ang := float(k) * 2.399963 + rng.randf_range(-0.3, 0.3)  # golden-angle spread
		_wave_dir[k] = Vector2.from_angle(ang)
		_wave_phase[k] = rng.randf() * TAU


func _update_tangents() -> void:
	var n := particle_count
	for i in range(n):
		var a := _pos[maxi(i - 1, 0)]
		var b := _pos[mini(i + 1, n - 1)]
		var d := b - a
		if d.length_squared() > 0.000001:
			_tan[i] = d.normalized()


func _update_torsion(dt: float) -> void:
	var n := particle_count
	var inv_seg := 1.0 / maxf(segment_length, 0.001)

	# Pass 1: flow in the ribbon's frame + curvature velocity.
	for i in range(n):
		var n2 := Vector2(-_tan[i].y, _tan[i].x)
		var air := Vector2(_air[i].x, _air[i].y)
		var vel_ps := (_pos[i] - _prev[i]) / dt
		_air_n[i] = air.dot(n2)
		_rel_n[i] = (air - vel_ps).dot(n2)

	# Pass 2: angular accelerations (computed for all before integrating any).
	for i in range(n):
		var theta := _twist[i]
		var acc := 0.0

		if i == 0:
			# Head banks into the crossflow and gets kicked when the player changes direction.
			var target := head_bank_max * clampf(_rel_n[0] / head_bank_speed, -1.0, 1.0)
			acc = head_spring * (target - theta) - head_damping * _twist_vel[0] \
				+ _turn_rate * player_turn_twist
		else:
			var next_t := theta
			if i < n - 1:
				next_t = _twist[i + 1]
			# Torsional wave propagation along the ribbon (free end at the tip).
			acc = twist_coupling * (_twist[i - 1] - 2.0 * theta + next_t)

			# Restoring pull toward a gentle helical rest pose + ambient travelling wave.
			var u := float(i) / float(n - 1)
			var rest := rest_twist_per_segment * float(i) \
				+ ambient_twist * u * sin(float(i) * 0.45 - _time * 1.7)
			acc += twist_restore * (rest - theta)

			# Wind shear: change of crosswind along the length.
			acc += shear_torque * (_air_n[i] - _air_n[i - 1]) * inv_seg

			# Flow vorticity at this particle.
			acc += vorticity_torque * _air[i].z

			# Curvature velocity: bends whipping through the ribbon roll it.
			var kappa := 0.0
			if i < n - 1:
				kappa = (_pos[i] - _pos[i - 1]).angle_to(_pos[i + 1] - _pos[i])
			var kappa_vel := (kappa - _curvature[i]) / dt
			_curvature[i] = kappa
			acc += curvature_torque * clampf(kappa_vel, -30.0, 30.0)

			# Aerodynamic alignment: plate rolls toward broadside in a strong crossflow.
			var strength := clampf(absf(_rel_n[i]) / ALIGN_REF_SPEED, 0.0, 1.0)
			acc += aero_align_torque * strength * sin(2.0 * theta)

		_twist_acc[i] = acc

	# Pass 3: semi-implicit Euler.
	var damp := exp(-twist_damping * dt)
	for i in range(n):
		var w := (_twist_vel[i] + _twist_acc[i] * dt) * damp
		w = clampf(w, -max_twist_velocity, max_twist_velocity)
		_twist_vel[i] = w
		_twist[i] += w * dt


# =========================================================================================
#  Rendering
# =========================================================================================

func _update_render() -> void:
	var n := particle_count
	var m := cross_segments
	var inv_last := 1.0 / float(maxi(n - 1, 1))
	var flat := camber < 0.001

	for i in range(n):
		var t := _tan[i]
		var n2 := Vector2(-t.y, t.x)
		var s := sin(_twist[i])
		var c := cos(_twist[i])
		var hw := ribbon_width * 0.5 * width_curve.sample_baked(float(i) * inv_last)

		for j in range(m):
			var v := lerpf(-1.0, 1.0, float(j) / float(m - 1))
			var phi := v * camber
			var across := hw * v
			var bulge := 0.0
			if not flat:
				across = hw * sin(phi) / camber
				bulge = hw * (1.0 - cos(phi)) / camber
			# Ribbon frame:  B = c*n2 + s*Z (width)   N = c*Z - s*n2 (surface normal)
			# Edges of the arc are pulled back along -N, so screen offset along n2 is:
			var off := c * across + s * bulge
			_verts[i * m + j] = _pos[i] + n2 * off

		_data_img.set_pixel(i, 0, Color(t.x, t.y, s, c))
		_data_img.set_pixel(i, 1, Color(_twist_vel[i], _curvature[i], 0.0, 0.0))

	_data_tex.update(_data_img)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_INDEX] = _indices
	_mesh.clear_surfaces()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat := material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("camber", camber)
		mat.set_shader_parameter("ribbon_length", segment_length * float(n - 1))
