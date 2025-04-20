extends TreeNode
class_name DecisionNode

var condition_func: Callable
var true_branch: TreeNode
var false_branch: TreeNode

func init(cond: Callable, t_branch: TreeNode, f_branch: TreeNode) -> DecisionNode:
	condition_func = cond
	true_branch = t_branch
	false_branch = f_branch
	return self

func evaluate(owner: Node) -> void:
	if condition_func.call():
		true_branch.evaluate(owner)
	else:
		false_branch.evaluate(owner)
