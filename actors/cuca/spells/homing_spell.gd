extends Area2D
## Feitiço da Cuca — projétil mágico perseguidor.
## Nos primeiros HOMING_DURATION segundos de voo, a direção curva suavemente
## em direção ao alvo (perseguição); depois disso a direção fica congelada e
## o projétil segue reto até acertar ou expirar. Cena top-down: não há
## gravidade, o movimento é todo manual (posição somada a cada frame físico).

const SPEED: float = 320.0
const DAMAGE: int = 15
const LIFETIME: float = 4.0
const HOMING_DURATION: float = 1.0
const MAX_TURN_RATE: float = 4.0 # rad/s — limita a curva por frame para a perseguição parecer suave, não um "teleporte" de direção

var _direction: Vector2 = Vector2.RIGHT
var _target: Node2D = null
var _homing_time_left: float = HOMING_DURATION
var _life_left: float = LIFETIME
var _hit: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


## Interface obrigatória (contrato): a Cuca chama isto logo após instanciar a
## cena. Guardamos o alvo apenas como referência — toda leitura futura passa
## por is_instance_valid(), pois o alvo (Caipora) pode ser liberado a
## qualquer momento (ex.: morte, troca de cena).
func cast(origin: Vector2, target: Node2D) -> void:
	global_position = origin
	_target = target

	if is_instance_valid(_target):
		var to_target: Vector2 = _target.global_position - origin
		_direction = to_target.normalized() if to_target.length_squared() > 0.0 else Vector2.RIGHT
	else:
		_direction = Vector2.RIGHT

	rotation = _direction.angle()
	# Disparo do projétil mágico (grave, para soar mágico e não sci-fi).
	Sfx.play_at(origin, "laser", -8.0, 0.55, 0.06)


func _physics_process(delta: float) -> void:
	if _hit:
		return

	# Fase de perseguição: dura só os primeiros HOMING_DURATION segundos e só
	# faz sentido enquanto o alvo existir. Depois disso (tempo esgotado OU
	# alvo sumiu) a direção fica congelada e o feitiço passa a voar reto.
	if _homing_time_left > 0.0:
		if is_instance_valid(_target):
			_turn_towards_target(delta)
		_homing_time_left -= delta

	global_position += _direction * SPEED * delta
	rotation = _direction.angle()

	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()


## Gira _direction em direção ao alvo, limitando a velocidade angular a
## MAX_TURN_RATE rad/s (curva suave por frame, não um "snap" instantâneo).
func _turn_towards_target(delta: float) -> void:
	var to_target: Vector2 = _target.global_position - global_position
	if to_target.length_squared() <= 0.0:
		return
	var desired: Vector2 = to_target.normalized()

	var angle_to_desired: float = _direction.angle_to(desired)
	var max_step: float = MAX_TURN_RATE * delta
	var step: float = clampf(angle_to_desired, -max_step, max_step)
	_direction = _direction.rotated(step)


## Ao tocar um corpo (esperado: Caipora, via layer/mask do contrato), causa
## dano uma única vez e se destrói.
func _on_body_entered(body: Node) -> void:
	if _hit:
		return
	if body.has_method("take_damage"):
		_hit = true
		body.take_damage(DAMAGE)
		queue_free()
