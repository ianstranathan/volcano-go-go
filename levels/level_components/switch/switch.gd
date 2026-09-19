@tool
extends Node2D

signal switch_finished

var can_move

@export var activation_normal: Vector2 = Vector2.UP
@export var transition_type: Tween.TransitionType = Tween.TRANS_LINEAR
@export var easing_type: Tween.EaseType = Tween.EASE_IN

var _coll_extents: Vector2 = Vector2(50., 50.)
@export var speed: float
enum SwitchType{
	IMMEDIATE, # -- snaps to finished
	PRESSURE,  # -- restored to position if player isn't on it
}
@export var switch_type: SwitchType = SwitchType.PRESSURE

@export var base_platform: BasePlatform
@export var coll_extents: Vector2:
	set(value):
		_coll_extents = value
		if base_platform:
			base_platform.coll_extents = value  # forward to child
			#collision_dimensions_changed.emit(value)
	get:
		if base_platform:
			return base_platform.coll_extents
		return _coll_extents

var moving_platform_component: MovingPlatformComponent
func _ready() -> void:
	if base_platform:
		base_platform.coll_extents = _coll_extents
		
	if not Engine.is_editor_hint():
		#print(speed)
		assert($BasePlatform/MovingPlatformComponent)
		moving_platform_component = $BasePlatform/MovingPlatformComponent
		moving_platform_component.movement_finished.connect( on_movement_finished )
		base_platform.get_node("MovingPlatformComponent").speed = speed
		
		# -- starting pos
		await get_tree().process_frame
		$PathFollowPlatformComponent.curve.clear_points()
		$PathFollowPlatformComponent.curve.add_point(Vector2.ZERO)
		# -- ending pos (half way down)
		$PathFollowPlatformComponent.curve.add_point( 
			Vector2(0., $BasePlatform.coll_extents.y / 2.0))
		moving_platform_component.calc_path_length()
		moving_platform_component.moving = false
		#base_platform.get_node("MovingPlatformComponent").recalculate_path_length()
		var a = $BasePlatform.get_node("Area2D")
		a.body_entered.connect( on_body_entered )
		a.body_exited.connect( on_body_exited_mkr(a) )
		
		# -- set easing on immediate, should probably expose this 
		moving_platform_component.transition_type = transition_type
		moving_platform_component.easing_type = easing_type


@onready var comparison_pos = global_position - Vector2(0., _coll_extents.y / 2.)
func on_body_entered( body ):
	if body is Player:
		# -- where the play was a frame ago
		var previous = body.global_position - body.frame_disp()
		# -- if the rel pos between the frame ago player and this switch
		# -- is pointing in the opposite direction, we're switching ( can only
		# -- happen if we're above the switch
		if (previous - comparison_pos).dot(activation_normal) <= 0.0:
			return
		moving_platform_component.set_target_time(1.0)


func on_body_exited_mkr( a: Area2D) -> Callable:
	# -- need a closure around the area to be able to say if
	# -- all players have exited area
	return func(body):
		if body is Player:
			match switch_type:
				SwitchType.IMMEDIATE:
					return
				SwitchType.PRESSURE:
					await get_tree().physics_frame
					if a.get_overlapping_bodies().is_empty():
						moving_platform_component.set_target_time(0.0)


func execute_tick(delta: float):
	$BasePlatform/MovingPlatformComponent.execute_tick(delta)
	#$BasePlatform.execute_tick(delta)


func on_movement_finished():
	if $BasePlatform/MovingPlatformComponent.time_direction > 0:
		switch_finished.emit()


# -- added for elevator
func restore_switch():
	assert(switch_type == SwitchType.IMMEDIATE)
	moving_platform_component.set_target_time(-1.0)

# -- NOTE
# -- what do you want?
# --   + should it pop up no matter what?
# --   + should it wait for the player to get off
# --     ++ let's just pop it up for now
func queue_restore() -> void:
	restore_switch()
