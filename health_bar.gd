extends ProgressBar

var target # The fighter (player or AI)

func _process(delta):
	if target:
		self.value = target.health
		self.visible = true
