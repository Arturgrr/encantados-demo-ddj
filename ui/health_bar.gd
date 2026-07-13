extends Control
## Barra de vida reutilizável (pixelart): moldura escura + trilho + faixa de
## preenchimento que encolhe conforme a vida. Redimensionável: os filhos usam
## anchors relativos ao Control raiz, então a mesma cena serve para a barra
## grande da Cuca e a barra pequena da Caipora — quem instancia só ajusta o
## tamanho/posição do Control raiz (anchors/offsets) e a cor de preenchimento.

## Cor da faixa de preenchimento (vida atual). Sobrescreva no nó instanciado.
@export var bar_color: Color = Color(0.8, 0.15, 0.15)
## Cor da moldura externa (bem escura, quase preta).
@export var border_color: Color = Color(0.05, 0.05, 0.05)
## Cor do trilho vazio, atrás do preenchimento.
@export var track_color: Color = Color(0.12, 0.1, 0.1)
## Espessura da moldura, em pixels.
@export var border_width: int = 4

@onready var _label: Label = $Label
@onready var _border: ColorRect = $Border
@onready var _track: ColorRect = $Track
@onready var _fill: ColorRect = $Track/Fill

var _current: int = 1
var _max_health: int = 1

func _ready() -> void:
	# Aplica a espessura da moldura inset-ando o trilho dentro dela.
	_track.offset_left = border_width
	_track.offset_top = border_width
	_track.offset_right = -border_width
	_track.offset_bottom = -border_width
	_border.color = border_color
	_track.color = track_color
	_fill.color = bar_color
	_refresh_fill()

## Define o texto do nome do lutador (ex.: "Cuca", "Caipora").
func set_label(text: String) -> void:
	if is_instance_valid(_label):
		_label.text = text

## Atualiza o preenchimento da barra. Faz clamp em 0..max_health e evita
## divisão por zero quando max_health <= 0.
func set_health(current: int, max_health: int) -> void:
	_max_health = max_health if max_health > 0 else 1
	_current = clampi(current, 0, _max_health)
	_refresh_fill()

func _refresh_fill() -> void:
	if not is_instance_valid(_fill):
		return
	var ratio: float = float(_current) / float(_max_health)
	# O fill preenche uma fração horizontal do trilho via anchor (responsivo:
	# acompanha o tamanho do Control raiz sem precisar recalcular pixels).
	_fill.anchor_right = ratio
	_fill.offset_right = 0.0
