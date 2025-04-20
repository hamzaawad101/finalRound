extends TreeNode
class_name ActionNode

var action_func: Callable

func init(_action_func: Callable) -> ActionNode:
	action_func = _action_func
	return self

func evaluate(owner: Node) -> void:
	action_func.call()
