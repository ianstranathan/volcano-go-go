extends Area2D

"""
Interface / component for grabbing stuff
"""
class_name Grabbable

enum WeightType{
	LIGHT, MEDIUM, HEAVY
}
@export var weight: WeightType = WeightType.LIGHT
signal got_tossed( dir: Vector2)
signal got_grabbed( n: Node2D)

var grabber: Node2D = null

#func _ready() -> void:
	#assert(weight)


func can_be_grabbed():
	return (grabber == null)


func grab( _grabber: Area2D) -> Dictionary:
	grabber = _grabber
	emit_signal("got_grabbed", _grabber)
	return {"weight": weight_prop_coeff()}


func toss( v ):
	emit_signal( "got_tossed", Vector2(v * throw_dir_coeff(), 0.0))
	grabber = null


func throw_dir_coeff():
	var ret = 1.
	match weight:
		WeightType.MEDIUM:
			ret = 0.7
		WeightType.HEAVY:
			ret = 0.3
	return ret


func weight_prop_coeff() -> float:
	var ret = 1.
	match weight:
		WeightType.MEDIUM:
			ret = 0.7
		WeightType.HEAVY:
			ret = 0.3
	return ret
