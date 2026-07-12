extends Node2D
## Feitiço da Cuca — poção venenosa (2 fases).
## Fase 1 (arremesso): a poção voa em arco visual da `origin` até o ponto de
## queda (posição do alvo capturada uma única vez no cast). Sem dano.
## Fase 2 (poça): ao pousar, nasce uma mancha de veneno no chão que causa dano
## por tempo a quem estiver em cima, e depois some com fade-out.

const FLIGHT_DURATION: float = 0.6       ## duração do arremesso, em segundos
const ARC_HEIGHT: float = 60.0           ## altura do "pulinho" visual do frasco
const FLASK_SPIN: float = 12.0           ## giro do frasco durante o voo (rad/s)
const POOL_GROW_TIME: float = 0.35       ## a poça "cresce ao redor" ao pousar
const POOL_DURATION: float = 5.0         ## tempo que a poça fica ativa causando dano
const DAMAGE_TICK_INTERVAL: float = 0.5  ## intervalo entre ticks de dano
const DAMAGE_PER_TICK: int = 6
const FADE_DURATION: float = 0.5         ## duração do fade-out final da poça
const SLOW_REFRESH: float = 0.25         ## lentidão renovada a cada frame na poça

@onready var _visual: Node2D = $Visual
@onready var _flask: Sprite2D = $Visual/Flask
@onready var _pool: Area2D = $Pool
@onready var _damage_tick: Timer = $DamageTick
@onready var _pool_lifetime: Timer = $PoolLifetime

var _flying: bool = false
var _pool_active: bool = false
var _flight_elapsed: float = 0.0
var _start_position: Vector2 = Vector2.ZERO
var _landing_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	_damage_tick.wait_time = DAMAGE_TICK_INTERVAL
	_damage_tick.one_shot = false
	_damage_tick.timeout.connect(_on_damage_tick_timeout)

	_pool_lifetime.wait_time = POOL_DURATION
	_pool_lifetime.one_shot = true
	_pool_lifetime.timeout.connect(_on_pool_lifetime_timeout)

	# A poça só aparece/detecta depois que a poção pousar (fase 2).
	_pool.visible = false
	_pool.monitoring = false


## Ponto de entrada único chamado pela Cuca. Captura o ponto de queda uma
## única vez (posição do alvo no momento do cast, ou `origin` se o alvo já
## não for válido) e inicia a fase de arremesso a partir de `origin`.
func cast(origin: Vector2, target: Node2D) -> void:
	global_position = origin
	_start_position = origin
	_landing_position = target.global_position if is_instance_valid(target) else origin

	_flight_elapsed = 0.0
	_flying = true


func _physics_process(delta: float) -> void:
	if _flying:
		_process_flight(delta)
	elif _pool_active:
		# Enquanto a poça está ativa, quem estiver em cima fica lento (renovado
		# a cada frame → a lentidão passa pouco depois de sair da poça).
		for body in _pool.get_overlapping_bodies():
			if body.has_method("apply_slow"):
				body.apply_slow(SLOW_REFRESH)


## Interpola a posição real (root) do ponto de lançamento até o ponto de
## queda ao longo de FLIGHT_DURATION, e soma um "pulinho" parabólico apenas
## no visual (offset -Y do Polygon2D) para simular o arco de um arremesso em
## uma câmera top-down, onde não existe eixo vertical de verdade.
func _process_flight(delta: float) -> void:
	_flight_elapsed += delta
	var t: float = clampf(_flight_elapsed / FLIGHT_DURATION, 0.0, 1.0)

	global_position = _start_position.lerp(_landing_position, t)
	# Parábola normalizada: vale 0 nas pontas (t=0 e t=1) e 1 no pico (t=0.5).
	_visual.position.y = -ARC_HEIGHT * 4.0 * t * (1.0 - t)
	# Frasco girando no ar, reforçando a sensação de arremesso.
	_flask.rotation += delta * FLASK_SPIN

	if t >= 1.0:
		_flying = false
		_land()


## A poção "pousa": some o visual de voo e nasce a poça de veneno no ponto de
## queda, que passa a causar dano por tempo enquanto durar.
func _land() -> void:
	global_position = _landing_position
	_visual.visible = false

	# A poça "aparece ao redor" do ponto de queda: cresce de um ponto até o
	# tamanho cheio com um leve overshoot (a colisão acompanha a escala).
	_pool.visible = true
	_pool.scale = Vector2(0.15, 0.15)
	var grow: Tween = create_tween()
	grow.tween_property(_pool, "scale", Vector2.ONE, POOL_GROW_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_pool.monitoring = true
	_pool_active = true
	_damage_tick.start()
	_pool_lifetime.start()

	# Vidro quebrando + a poça borbulhando logo em seguida.
	Sfx.play_at(_landing_position, "glass", -6.0, 1.15, 0.08)
	Sfx.play_at(_landing_position, "slime", -6.0, 0.85, 0.08)


## A cada tick (0.5s), aplica dano a todos os corpos atualmente sobrepostos à
## poça — dano contínuo enquanto o alvo permanecer em cima, não um golpe único.
func _on_damage_tick_timeout() -> void:
	for body in _pool.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(DAMAGE_PER_TICK)


## Fim da vida útil da poça: para o dano, desliga a detecção e faz um
## fade-out antes de se destruir.
func _on_pool_lifetime_timeout() -> void:
	_damage_tick.stop()
	_pool.monitoring = false
	_pool_active = false

	var tween: Tween = create_tween()
	tween.tween_property(_pool, "modulate:a", 0.0, FADE_DURATION)
	tween.finished.connect(queue_free)
