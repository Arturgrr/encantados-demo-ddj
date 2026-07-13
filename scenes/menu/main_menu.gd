extends Control
## Tela inicial do jogo. Mostra o título "Encantados" e o botão "Jogar",
## que leva para a cena de batalha.

@onready var jogar_button: Button = %JogarButton


func _ready() -> void:
	# Dá foco ao botão Jogar para permitir iniciar com Enter/Espaço/D-pad.
	jogar_button.grab_focus()

	# Conecta por código (mais robusto do que depender da conexão no .tscn).
	if not jogar_button.pressed.is_connected(_on_jogar_pressed):
		jogar_button.pressed.connect(_on_jogar_pressed)


func _on_jogar_pressed() -> void:
	Sfx.play_ui("click")
	get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")
