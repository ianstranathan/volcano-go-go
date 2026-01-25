extends Node

class_name MovementOverrideComponent

signal movement_override_started
signal movement_override_finished

func start():
	movement_override_started.emit()

func finish():
	movement_override_finished.emit()
