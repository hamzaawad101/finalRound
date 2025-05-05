extends Resource
class_name Graph

var state_name: String
var transitions := {}  # Dictionary<String, String>

func _init(_name: String, _transitions: Dictionary):
	state_name = _name
	transitions = _transitions
