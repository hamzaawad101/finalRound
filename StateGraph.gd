extends Resource
class_name StateGraph

var nodes: Dictionary = {}

func add_node(node: Graph):
	nodes[node.state_name] = node

func get_next_state(current_state: String, conditions: Dictionary) -> String:
	var node: Graph = nodes.get(current_state, null)
	if node == null:
		return "idle" # fallback

	for condition in node.transitions.keys():
		if condition != "default" and conditions.get(condition, false):
			return node.transitions[condition]

	return node.transitions.get("default", "idle")
