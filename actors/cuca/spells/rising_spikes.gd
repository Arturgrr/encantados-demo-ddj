extends Node2D
## Feitiço da Cuca — fileira de espinhos que sobem do chão avançando em
## direção à Caipora. No cast() a direção é calculada UMA única vez (fixa
## pelo resto da vida do feitiço) e a sequência inteira é agendada de uma só
## vez com SceneTreeTimers: cada espinho "entra na fila" com um atraso
## crescente (telegrafia → sobe → fica cravado → recolhe), criando a
## sensação de que os espinhos correm pelo chão. Cada espinho é montado por
## código como uma Area2D filha (Polygon2D triangular + CollisionShape2D) —
## não há sub-cenas nem scripts extras.

const SPIKE_COUNT: int = 6
const SPACING: float = 55.0          # distância entre espinhos consecutivos na fileira
const SPAWN_INTERVAL: float = 0.12   # atraso entre a "vez" de um espinho e a do próximo
const TELEGRAPH_TIME: float = 0.2    # marca no chão exibida antes do espinho subir
const RISE_TIME: float = 0.15        # duração da animação de subida (scale.y 0 -> 1)
const ACTIVE_TIME: float = 1.0       # janela em que a hitbox fica ativa (subindo + cravado)
const RECEDE_TIME: float = 0.1       # duração da animação de recolhida (scale.y 1 -> 0)
const DAMAGE: int = 5                 # cada espinho dá pouco dano (a fileira acerta vários)
const KNOCKBACK_FORCE: float = 266.0 # empurrão aplicado ao alvo, na direção da fileira
# Tempo de vida total da cena inteira, contado a partir do instante em que o
# ÚLTIMO espinho da fileira começa a subir (cobre ACTIVE_TIME + RECEDE_TIME
# com folga antes do queue_free() final).
const FINAL_LIFETIME_AFTER_LAST_RISE: float = 1.5

const SPIKE_COLOR: Color = Color(0.25, 0.22, 0.2)
const TELEGRAPH_COLOR: Color = Color(0.05, 0.05, 0.05, 0.5)

var _direction: Vector2 = Vector2.RIGHT


## Interface obrigatória (contrato): a Cuca chama isto logo após instanciar a
## cena. A direção é calculada UMA vez aqui a partir de origin -> alvo e fica
## congelada; a fileira de espinhos não persegue movimentos futuros da
## Caipora, só avança em linha reta na direção calculada no momento do cast.
func cast(origin: Vector2, target: Node2D) -> void:
	global_position = origin

	if is_instance_valid(target):
		var to_target: Vector2 = target.global_position - origin
		_direction = to_target.normalized() if to_target.length_squared() > 0.0 else Vector2.RIGHT
	else:
		_direction = Vector2.RIGHT

	# Agenda a sequência inteira de uma vez só: o espinho i "entra na fila"
	# em t = i * SPAWN_INTERVAL segundos após o cast, produzindo o efeito de
	# fileira que corre pelo chão em direção ao alvo.
	for i in range(SPIKE_COUNT):
		var local_pos: Vector2 = _direction * (SPACING * float(i + 1))
		var is_last: bool = i == SPIKE_COUNT - 1
		var spawn_delay: float = float(i) * SPAWN_INTERVAL
		get_tree().create_timer(spawn_delay).timeout.connect(
			_begin_telegraph.bind(local_pos, is_last)
		)


## Fase 1 (telegrafia): mostra por TELEGRAPH_TIME uma marca escura e
## translúcida no chão, no ponto onde o espinho vai nascer, antes dele
## efetivamente subir.
func _begin_telegraph(local_pos: Vector2, is_last: bool) -> void:
	var mark := Polygon2D.new()
	mark.polygon = PackedVector2Array([
		Vector2(-12, -5), Vector2(12, -5), Vector2(9, 6), Vector2(-9, 6)
	])
	mark.color = TELEGRAPH_COLOR
	mark.position = local_pos
	add_child(mark)

	get_tree().create_timer(TELEGRAPH_TIME).timeout.connect(func() -> void:
		mark.queue_free()
		_rise_spike(local_pos, is_last)
	)


## Fase 2 (subida): cria o espinho (Area2D + visual triangular + colisão) e
## anima scale.y de 0 -> 1 para simular ele emergindo do chão. A hitbox fica
## com monitoring ligado durante toda a janela ACTIVE_TIME (subindo e depois
## cravado); ao fim, desliga o monitoring e anima o recolhimento.
func _rise_spike(local_pos: Vector2, is_last: bool) -> void:
	var area := Area2D.new()
	area.position = local_pos
	area.scale.y = 0.0
	area.set_meta("hit", false)

	# Camadas do contrato: BossHitbox (índice 5) detectando PlayerBody
	# (índice 2). Zera os bits antes, pois Area2D novo nasce com
	# collision_layer/mask = 1 por padrão.
	area.collision_layer = 0
	area.collision_mask = 0
	area.set_collision_layer_value(5, true)
	area.set_collision_mask_value(2, true)

	var triangle: PackedVector2Array = PackedVector2Array([
		Vector2(-9, 0), Vector2(9, 0), Vector2(0, -40)
	])

	var visual := Polygon2D.new()
	visual.polygon = triangle
	visual.color = SPIKE_COLOR
	area.add_child(visual)

	var collision := CollisionShape2D.new()
	var shape := ConvexPolygonShape2D.new()
	shape.points = triangle
	collision.shape = shape
	area.add_child(collision)

	area.body_entered.connect(_on_spike_body_entered.bind(area))
	add_child(area)

	area.monitoring = true

	# Som da pedra rompendo o chão (baixo: são 6 espinhos em sequência).
	Sfx.play_at(area.global_position, "spike", -12.0, 1.0, 0.15)

	var rise_tween: Tween = create_tween()
	rise_tween.tween_property(area, "scale:y", 1.0, RISE_TIME)

	# Depois de ACTIVE_TIME (contado a partir do início da subida), desliga a
	# hitbox e recolhe o espinho de volta ao chão.
	get_tree().create_timer(ACTIVE_TIME).timeout.connect(func() -> void:
		if not is_instance_valid(area):
			return
		area.monitoring = false
		var recede_tween: Tween = create_tween()
		recede_tween.tween_property(area, "scale:y", 0.0, RECEDE_TIME)
		recede_tween.tween_callback(area.queue_free)
	)

	# O último espinho da fileira é quem dispara a limpeza da cena inteira.
	if is_last:
		get_tree().create_timer(FINAL_LIFETIME_AFTER_LAST_RISE).timeout.connect(queue_free)


## Cada espinho só pode acertar a Caipora uma única vez. Como este callback é
## compartilhado por todas as instâncias de espinho, o "já acertou" é
## guardado via metadata na própria Area2D (recebida por bind), não numa
## variável de instância do feitiço.
func _on_spike_body_entered(body: Node, area: Area2D) -> void:
	if not is_instance_valid(area) or area.get_meta("hit", false):
		return
	if body.has_method("take_damage"):
		area.set_meta("hit", true)
		body.take_damage(DAMAGE)
		# Empurra o alvo na direção em que a fileira avança (para longe da Cuca).
		if body.has_method("apply_knockback"):
			body.apply_knockback(_direction * KNOCKBACK_FORCE)
