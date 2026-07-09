extends Node
## Autoload "Boot": registra as ações de input e configurações globais no startup.
##
## Mantemos o InputMap em código (e não no project.godot) porque fica muito mais
## fácil de ler, revisar e versionar. Roda a cada abertura do jogo e é seguro
## contra duplicatas (verifica antes de adicionar).
##
## Top-down: 8 direções (up/down/left/right). O ataque também aceita o botão
## ESQUERDO do mouse, além das teclas.
##
## Também guarda o resultado da última batalha ("victory"/"defeat") para a tela
## de fim ler — change_scene_to_file não passa argumentos entre cenas.

var last_result: String = ""

func _ready() -> void:
	_ensure_action_keys(&"move_left", [KEY_A, KEY_LEFT])
	_ensure_action_keys(&"move_right", [KEY_D, KEY_RIGHT])
	_ensure_action_keys(&"move_up", [KEY_W, KEY_UP])
	_ensure_action_keys(&"move_down", [KEY_S, KEY_DOWN])
	_ensure_action_keys(&"attack", [KEY_J, KEY_SPACE, KEY_ENTER, KEY_X])
	# O ataque também dispara no clique esquerdo do mouse.
	_ensure_action_mouse(&"attack", MOUSE_BUTTON_LEFT)
	# Tela cheia: F11 (Windows/Linux) e F (com Cmd/Ctrl, hábito no macOS).
	_ensure_action_keys(&"fullscreen", [KEY_F11])


## Alterna janela <-> tela cheia. O botão de maximizar/tela cheia do próprio
## sistema (Windows e macOS) já funciona sozinho porque a janela é
## redimensionável e o stretch do projeto reescala o conteúdo; isto aqui é só
## um atalho de teclado a mais.
func _unhandled_input(event: InputEvent) -> void:
	var toggle := event.is_action_pressed("fullscreen")
	# Cmd+F no macOS / Ctrl+F no resto.
	if not toggle and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F and (event.meta_pressed or event.ctrl_pressed):
			toggle = true
	if not toggle:
		return
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	get_viewport().set_input_as_handled()

## Cria a ação (se ainda não existir) e associa as teclas físicas informadas.
func _ensure_action_keys(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)

## Associa um botão do mouse a uma ação já existente (ou cria a ação).
func _ensure_action_mouse(action: StringName, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
