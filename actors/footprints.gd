class_name Footprints
extends RefCounted
## Helper compartilhado por Caipora e Cuca para deixar pegadas no chão.
##
## A pegada é adicionada no MESMO pai do personagem (o World y-sortado) com
## `z_index = -1`: assim ela fica sempre ABAIXO de personagens, árvores e props
## (o z_index tem prioridade sobre o Y-sort), mas ainda acima do chão, que está
## no Background.

const SCENE: PackedScene = preload("res://actors/footprint.tscn")


## Deixa uma pegada no pé de `host`, virada para `dir`.
##  `side`  -1/+1 alterna entre pé esquerdo e direito (deslocamento lateral).
##  `size`  escala da pegada (a Cuca é bem maior que a Caipora).
##  `tint`  cor/opacidade da marca.
static func drop(host: Node2D, dir: Vector2, side: int, size: float, tint: Color) -> void:
	var host_parent := host.get_parent()
	if host_parent == null or dir.length_squared() <= 0.0:
		return

	var fp := SCENE.instantiate()
	fp.color = tint
	fp.z_index = -1
	fp.scale = Vector2(size, size)
	host_parent.add_child(fp)

	# host.global_position é o PÉ do personagem (a origem fica na base).
	# Desloca de lado (perpendicular à direção) para alternar os pés.
	fp.global_position = host.global_position + dir.orthogonal() * (float(side) * 5.0 * size)
	# O polígono aponta para -Y ("cima"), então soma 90° para alinhar com `dir`.
	fp.rotation = dir.angle() + PI / 2.0
