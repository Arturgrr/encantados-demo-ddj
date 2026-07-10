extends Polygon2D
## Uma pegada deixada no chão. Fica visível um tempo e some sozinha com
## fade-out. É puramente decorativa (sem colisão) e se destrói ao terminar.

const HOLD: float = 3.5   ## tempo totalmente visível, em segundos
const FADE: float = 2.0   ## duração do fade-out


func _ready() -> void:
	var tw := create_tween()
	tw.tween_interval(HOLD)
	tw.tween_property(self, "modulate:a", 0.0, FADE)
	tw.tween_callback(queue_free)
