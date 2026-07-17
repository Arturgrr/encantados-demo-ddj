extends CanvasLayer
## Caixa de diálogo: mostra uma sequência de falas (quem fala + o texto), uma
## por vez, com efeito de máquina de escrever. Avança no clique/Espaço/Enter —
## o primeiro toque completa o texto na hora, o seguinte passa para a próxima
## fala. Ao terminar a última, some e emite `finished`.
##
## Uso:
##   dialogue.play([{ "speaker": "Cuca", "text": "...", "color": Color(...) }, ...])
##   await dialogue.finished

signal finished

## Velocidade da digitação, em caracteres por segundo.
const CHARS_PER_SEC: float = 45.0

## Retrato de cada personagem, por nome de quem fala: { "Cuca": Texture2D, ... }.
## Quem usa a caixa preenche isto (a caixa em si não conhece os personagens).
## Se o nome não estiver aqui, o retrato simplesmente não aparece.
var portraits: Dictionary = {}

@onready var _panel: Control = $Panel
@onready var _speaker: Label = %Speaker
@onready var _text: Label = %Text
@onready var _hint: Label = %Hint
@onready var _portrait: TextureRect = %Portrait

var _lines: Array = []
var _index: int = 0
var _typing: bool = false
var _tween: Tween


func _ready() -> void:
	_panel.visible = false
	set_process_unhandled_input(false)


## Inicia a sequência de falas. Cada item é um Dictionary com "speaker",
## "text" e (opcional) "color" para o nome de quem fala.
func play(lines: Array) -> void:
	if lines.is_empty():
		finished.emit()
		return
	_lines = lines
	_index = 0
	_panel.visible = true
	set_process_unhandled_input(true)
	_show_line()


func _show_line() -> void:
	var line: Dictionary = _lines[_index]
	var speaker := str(line.get("speaker", ""))
	_speaker.text = speaker
	_speaker.add_theme_color_override("font_color", line.get("color", Color.WHITE))
	_text.text = str(line.get("text", ""))
	_hint.visible = false

	# Retrato de quem está falando (some se não houver um para esse nome).
	var face: Texture2D = portraits.get(speaker, null)
	_portrait.texture = face
	_portrait.visible = face != null

	# Digita o texto revelando os caracteres aos poucos.
	_text.visible_ratio = 0.0
	_typing = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	var duration: float = maxf(0.2, float(_text.text.length()) / CHARS_PER_SEC)
	_tween.tween_property(_text, "visible_ratio", 1.0, duration)
	_tween.tween_callback(_on_line_typed)


func _on_line_typed() -> void:
	_typing = false
	_hint.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	var advance := event.is_action_pressed("attack") or event.is_action_pressed("ui_accept")
	if not advance:
		return
	get_viewport().set_input_as_handled()

	if _typing:
		# Ainda digitando: completa o texto na hora.
		if _tween != null and _tween.is_valid():
			_tween.kill()
		_text.visible_ratio = 1.0
		_on_line_typed()
		return

	_index += 1
	if _index >= _lines.size():
		_finish()
	else:
		_show_line()


func _finish() -> void:
	_panel.visible = false
	set_process_unhandled_input(false)
	finished.emit()
