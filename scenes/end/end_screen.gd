extends Control
## Tela de fim (vitória/derrota). Lê Boot.last_result (autoload) no _ready e
## monta a mensagem, cor e botões de acordo com o resultado da batalha.

@onready var result_label: Label = %ResultLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var replay_button: Button = %ReplayButton
@onready var menu_button: Button = %MenuButton


func _ready() -> void:
	_apply_result()

	# Conecta por código (mais robusto do que depender da conexão no .tscn).
	if not replay_button.pressed.is_connected(_on_replay_pressed):
		replay_button.pressed.connect(_on_replay_pressed)
	if not menu_button.pressed.is_connected(_on_menu_pressed):
		menu_button.pressed.connect(_on_menu_pressed)

	replay_button.grab_focus()


## Define texto/cor da mensagem central e do subtítulo conforme
## Boot.last_result. Qualquer valor diferente de "victory" (vazio,
## desconhecido, etc.) cai no fallback seguro de derrota.
func _apply_result() -> void:
	if Boot.last_result == "victory":
		result_label.text = "Vitória!"
		result_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
		subtitle_label.text = "A Caipora derrotou a Cuca."
		Sfx.play_ui("win", -4.0)
	else:
		result_label.text = "Derrota"
		result_label.add_theme_color_override("font_color", Color(0.85, 0.3, 0.3))
		subtitle_label.text = "A Cuca venceu o duelo."
		Sfx.play_ui("lose", -4.0)


func _on_replay_pressed() -> void:
	Sfx.play_ui("click")
	get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")


func _on_menu_pressed() -> void:
	Sfx.play_ui("click")
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
