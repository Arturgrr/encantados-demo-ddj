extends CanvasLayer
## HUD de batalha: barra grande da Cuca no topo-centro e barra menor da
## Caipora no canto inferior-esquerdo. `battle.tscn` chama bind_player() e
## bind_boss() no _ready, passando os nós dos personagens (CharacterBody2D
## com a interface de combate definida em docs/CONTRACT.md).

@onready var _boss_bar: Control = $BossBar
@onready var _player_bar: Control = $PlayerBar

func _ready() -> void:
	_boss_bar.set_label("Cuca")
	_player_bar.set_label("Caipora")

## Liga a barra da Caipora ao ator do player.
func bind_player(actor: Node) -> void:
	_bind(actor, _player_bar)

## Liga a barra da Cuca ao ator do chefe.
func bind_boss(actor: Node) -> void:
	_bind(actor, _boss_bar)

## Lê a vida inicial do ator (de forma defensiva) e conecta health_changed
## (e died(), se existir) para manter a barra atualizada em tempo real.
func _bind(actor: Node, bar: Control) -> void:
	if actor == null or not is_instance_valid(bar):
		return

	var current_health: int = actor.health if "health" in actor else 0
	var max_health: int = actor.max_health if "max_health" in actor else 1
	bar.set_health(current_health, max_health)

	if actor.has_signal("health_changed") and not actor.health_changed.is_connected(bar.set_health):
		actor.health_changed.connect(bar.set_health)

	if actor.has_signal("died") and not actor.died.is_connected(_on_actor_died):
		actor.died.connect(_on_actor_died.bind(bar))

## Esmaece a barra quando o dono morre.
func _on_actor_died(bar: Control) -> void:
	if not is_instance_valid(bar):
		return
	var tween: Tween = create_tween()
	tween.tween_property(bar, "modulate:a", 0.35, 0.6)
