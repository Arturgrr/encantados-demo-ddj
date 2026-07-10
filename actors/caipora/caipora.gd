extends CharacterBody2D
## Caipora — guerreira menor e ágil, controlada pelo jogador. TOP-DOWN: anda em
## 8 direções (sem gravidade nem pulo) e luta com uma lança (ataque corpo-a-corpo
## de curto alcance, na direção para onde está virada).

signal health_changed(current: int, max_health: int)
signal died()

@export var max_health: int = 100
var health: int

const MOVE_SPEED: float = 240.0
const ATTACK_DAMAGE: int = 12
const ATTACK_DURATION: float = 0.18
const ATTACK_COOLDOWN: float = 0.35
const HITBOX_OFFSET: float = 40.0
## Desaceleração do empurrão (knockback), em px/s². Quanto maior, mais curto.
const KNOCKBACK_DECAY: float = 1100.0
## Multiplicador de velocidade enquanto lenta (ex.: pisando no veneno).
const SLOW_FACTOR: float = 0.5

## Spritesheets de caminhada (grade de 6 colunas). Cada direção tem seu próprio
## número de frames e sua própria linha dos "pés" (medida nos sheets), usada
## para ancorar o sprite no chão. Oeste/noroeste/sudoeste são o espelho.
const WALK := {
	"n": {"tex": preload("res://actors/caipora/Walking/norte.png"),
		"frames": 8, "cell_w": 480.0, "cell_h": 640.0, "feet": 526.0, "scale": 0.165},
	"ne": {"tex": preload("res://actors/caipora/Walking/nordeste.png"),
		"frames": 7, "cell_w": 480.0, "cell_h": 640.0, "feet": 534.0, "scale": 0.165},
	"e": {"tex": preload("res://actors/caipora/Walking/leste.png"),
		"frames": 7, "cell_w": 480.0, "cell_h": 640.0, "feet": 544.0, "scale": 0.165},
	"se": {"tex": preload("res://actors/caipora/Walking/sudeste.png"),
		"frames": 10, "cell_w": 480.0, "cell_h": 640.0, "feet": 550.0, "scale": 0.165},
	"s": {"tex": preload("res://actors/caipora/Walking/sul.png"),
		"frames": 8, "cell_w": 480.0, "cell_h": 640.0, "feet": 574.0, "scale": 0.165},
}
const WALK_FPS: float = 10.0

## ATAQUE com a lança. Cada direção tem um número de frames diferente (6 a 12),
## então NÃO usamos fps fixo: o fps de cada uma é calculado como
## frames/ATTACK_ANIM_TIME, e todas duram exatamente o mesmo tempo.
##
## `feet` aqui é a MEDIANA do fundo de cada frame, não o fundo da folha: nos
## últimos quadros a lança crava no chão e passa ABAIXO dos pés, o que puxaria
## a personagem para dentro do chão se usássemos o fundo da imagem.
## `scale` é o MESMO da caminhada (não normalizado por altura), senão ela
## encolheria ao levantar a lança.
const ATTACK := {
	"n": {"tex": preload("res://actors/caipora/ATTACK/norte.png"),
		"frames": 6, "cell_w": 480.0, "cell_h": 640.0, "feet": 564.0, "scale": 0.165},
	"ne": {"tex": preload("res://actors/caipora/ATTACK/nordeste.png"),
		"frames": 7, "cell_w": 480.0, "cell_h": 640.0, "feet": 534.0, "scale": 0.165},
	"e": {"tex": preload("res://actors/caipora/ATTACK/leste.png"),
		"frames": 7, "cell_w": 480.0, "cell_h": 640.0, "feet": 545.0, "scale": 0.165},
	"se": {"tex": preload("res://actors/caipora/ATTACK/sudeste.png"),
		"frames": 8, "cell_w": 480.0, "cell_h": 640.0, "feet": 538.0, "scale": 0.165},
	"s": {"tex": preload("res://actors/caipora/ATTACK/sul.png"),
		"frames": 12, "cell_w": 480.0, "cell_h": 640.0, "feet": 578.0, "scale": 0.165},
}
## Duração da animação de ataque — igual para TODAS as direções. Casa com o
## cooldown, então a animação termina exatamente quando ela pode atacar de novo.
const ATTACK_ANIM_TIME: float = 0.35

## Poses PARADAS (uma imagem por direção, 1086x1448, com o fundo rosa já
## removido por chroma key). Como cada pose tem uma altura de personagem
## diferente, a escala é por direção para todas darem ~81px na tela (igual à
## caminhada). Oeste/noroeste/sudoeste também são espelho.
const IDLE := {
	"n": {"tex": preload("res://actors/caipora/Idle/norte.png"),
		"frames": 1, "cell_w": 1086.0, "cell_h": 1448.0, "feet": 1204.0, "scale": 0.0782},
	"ne": {"tex": preload("res://actors/caipora/Idle/nordeste.png"),
		"frames": 1, "cell_w": 1086.0, "cell_h": 1448.0, "feet": 1181.0, "scale": 0.0819},
	"e": {"tex": preload("res://actors/caipora/Idle/leste.png"),
		"frames": 1, "cell_w": 1086.0, "cell_h": 1448.0, "feet": 1232.0, "scale": 0.0772},
	"se": {"tex": preload("res://actors/caipora/Idle/sudeste.png"),
		"frames": 1, "cell_w": 1086.0, "cell_h": 1448.0, "feet": 1219.0, "scale": 0.0810},
	"s": {"tex": preload("res://actors/caipora/Idle/sul.png"),
		"frames": 1, "cell_w": 1086.0, "cell_h": 1448.0, "feet": 1237.0, "scale": 0.0773},
}

var _dead: bool = false
## Direção para onde a Caipora está virada (última direção de movimento não-nula).
## Começa apontando para a direita. Usada para posicionar a hitbox da lança.
var _facing: Vector2 = Vector2.RIGHT

var _attacking: bool = false
var _attack_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _hit_targets: Array = []
## Tempo restante da ANIMAÇÃO de ataque. É separado de _attack_timer (a janela
## de dano, mais curta): o golpe continua sendo desenhado depois que a hitbox
## já fechou.
var _attack_anim_timer: float = 0.0

## Velocidade extra de empurrão (decai até zero). Somada ao movimento normal.
var _knockback: Vector2 = Vector2.ZERO
## Enquanto > 0, a Caipora anda mais devagar (SLOW_FACTOR). Renovado por fontes
## de lentidão (veneno) a cada frame que a afetam.
var _slow_timer: float = 0.0

## Animação atual (chave de WALK/IDLE), para só trocar quando mudar.
var _cur_anim: String = ""

## Pegadas: distância percorrida desde a última, e qual pé sai agora.
const STEP_DISTANCE: float = 30.0
const FOOT_SIZE: float = 1.0
const FOOT_COLOR := Color(0.14, 0.09, 0.05, 0.45)
var _step_accum: float = 0.0
var _step_side: int = 1

@onready var _visual: Node2D = $Visual
@onready var _sprite: AnimatedSprite2D = $Visual/Sprite
@onready var _spear_hitbox: Area2D = $SpearHitbox


func _ready() -> void:
	add_to_group("player")
	health = max_health
	health_changed.emit(health, max_health)

	_sprite.sprite_frames = WalkSprites.build(WALK, WALK_FPS)
	WalkSprites.add_set(_sprite.sprite_frames, IDLE, 1.0, "idle_")
	# duration > 0 → todas as direções do ataque duram o mesmo tempo; sem loop,
	# o golpe toca uma vez só.
	WalkSprites.add_set(_sprite.sprite_frames, ATTACK, 0.0, "atk_", ATTACK_ANIM_TIME, false)
	_update_sprite(false)

	_spear_hitbox.monitoring = false
	_update_hitbox_transform()
	if not _spear_hitbox.body_entered.is_connected(_on_spear_hitbox_body_entered):
		_spear_hitbox.body_entered.connect(_on_spear_hitbox_body_entered)


func _physics_process(delta: float) -> void:
	if _dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _slow_timer > 0.0:
		_slow_timer -= delta
	# O empurrão decai suavemente até zerar.
	_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)

	# O ataque é checado ANTES do movimento: se o golpe começa agora, ela já
	# trava neste mesmo frame (senão daria um passo antes de travar).
	if Input.is_action_just_pressed("attack") and not _attacking and _cooldown_timer <= 0.0:
		_start_attack()
	var attacking := _attack_anim_timer > 0.0

	# Vetor de input em 8 direções, normalizado para não andar mais rápido na
	# diagonal.
	var input_dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	var speed := MOVE_SPEED
	if _slow_timer > 0.0:
		speed *= SLOW_FACTOR

	# Durante o golpe ela fica plantada no lugar e não muda de direção — o
	# ataque se compromete com o lado em que começou. O empurrão (knockback)
	# continua valendo, então ainda dá pra ser jogada para trás no meio do golpe.
	var move := Vector2.ZERO
	if input_dir.length() > 0.0 and not attacking:
		input_dir = input_dir.normalized()
		_facing = input_dir
		move = input_dir * speed
	velocity = move + _knockback

	var moving := move.length() > 0.0
	_update_hitbox_transform()
	_update_sprite(moving)
	_update_footprints(delta, moving)
	_process_attack_timers(delta)

	move_and_slide()


## Deixa uma pegada a cada STEP_DISTANCE percorridos, alternando os pés.
func _update_footprints(delta: float, moving: bool) -> void:
	if not moving:
		# Parada: prepara para o próximo passo sair logo ao voltar a andar.
		_step_accum = STEP_DISTANCE * 0.6
		return
	_step_accum += velocity.length() * delta
	if _step_accum < STEP_DISTANCE:
		return
	_step_accum = 0.0
	_step_side = -_step_side
	Footprints.drop(self, _facing, _step_side, FOOT_SIZE, FOOT_COLOR)
	Sfx.play_at(global_position, "footstep", -10.0, 1.0, 0.12)


## Escolhe a animação pela direção que a Caipora está olhando (espelhando para
## as direções oeste): andando usa WALK, parada usa a pose IDLE. Cada conjunto
## tem sua própria escala e linha dos pés, aplicadas ao trocar de animação —
## os pés sempre caem na origem do nó (que é o que o Y-sort usa).
func _update_sprite(moving: bool) -> void:
	var info := WalkSprites.dir_for(_facing)
	var key: String = info[0]
	_sprite.flip_h = info[1]

	# Prioridade: atacando > andando > parada.
	var attacking := _attack_anim_timer > 0.0
	var set_dict: Dictionary
	var anim: String
	if attacking:
		set_dict = ATTACK
		anim = "atk_" + key
	elif moving:
		set_dict = WALK
		anim = key
	else:
		set_dict = IDLE
		anim = "idle_" + key

	if anim != _cur_anim:
		# Trocou de animação: reposiciona/reescala e (re)começa do primeiro quadro.
		_cur_anim = anim
		var d: Dictionary = set_dict[key]
		_sprite.offset.y = float(d["cell_h"]) * 0.5 - float(d["feet"])
		_sprite.scale = Vector2(float(d["scale"]), float(d["scale"]))
		_sprite.animation = anim
		_sprite.frame = 0
		# Ataque e caminhada animam; parada é um quadro só.
		if attacking or moving:
			_sprite.play(anim)
		else:
			_sprite.stop()
		return

	# Mesma animação de antes: só acerta o estado de reprodução. Não mexemos
	# enquanto ataca — assim o golpe não reinicia ao chegar no último quadro
	# (ele não tem loop e termina junto com _attack_anim_timer).
	if attacking:
		return
	if moving and not _sprite.is_playing():
		_sprite.play(anim)
	elif not moving and _sprite.is_playing():
		_sprite.stop()


## Coloca a hitbox da lança à frente da Caipora, na direção para onde ela olha,
## e rotaciona para acompanhar (assim o retângulo do golpe aponta pra frente).
func _update_hitbox_transform() -> void:
	# +Y para cima (-30) porque a origem da Caipora fica no PÉ (para o Y-sort):
	# assim a hitbox da lança fica na altura do corpo, não no chão.
	_spear_hitbox.position = _facing * HITBOX_OFFSET + Vector2(0.0, -30.0)
	_spear_hitbox.rotation = _facing.angle()


func _process_attack_timers(delta: float) -> void:
	if _attacking:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_end_attack()
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
	if _attack_anim_timer > 0.0:
		_attack_anim_timer -= delta


func _start_attack() -> void:
	_attacking = true
	_attack_timer = ATTACK_DURATION
	_cooldown_timer = ATTACK_COOLDOWN
	_hit_targets.clear()
	_attack_anim_timer = ATTACK_ANIM_TIME
	_spear_hitbox.monitoring = true
	Sfx.play_at(global_position, "spear", -4.0, 1.0, 0.1)


func _end_attack() -> void:
	_attacking = false
	_spear_hitbox.monitoring = false


func _on_spear_hitbox_body_entered(body: Node) -> void:
	if not _attacking:
		return
	if body in _hit_targets:
		return
	if body.has_method("take_damage"):
		_hit_targets.append(body)
		body.take_damage(ATTACK_DAMAGE)


## Reduz a vida (clamp 0..max_health), emite health_changed e, se zerar,
## emite died() uma única vez.
func take_damage(amount: int) -> void:
	if _dead:
		return
	health = clampi(health - amount, 0, max_health)
	health_changed.emit(health, max_health)
	_flash_damage()
	Sfx.play_at(global_position, "hurt", -2.0, 1.15, 0.1)
	if health <= 0:
		_die()


## Aplica um empurrão (usado pelos espinhos da Cuca): define a velocidade de
## knockback, que decai sozinha nos próximos frames.
func apply_knockback(impulse: Vector2) -> void:
	if _dead:
		return
	_knockback = impulse


## Deixa a Caipora lenta por `duration` segundos. Fontes contínuas (veneno)
## chamam a cada frame; usamos o maior valor para renovar enquanto ela ficar
## na área, e a lentidão passa pouco depois de sair.
func apply_slow(duration: float) -> void:
	if _dead:
		return
	_slow_timer = maxf(_slow_timer, duration)


## Pisca em vermelho ao tomar dano: acende o parâmetro `flash` do shader e faz
## ele voltar a 0 com um tween rápido.
func _flash_damage() -> void:
	var mat := _visual.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("flash", 1.0)
	var tw := create_tween()
	tw.tween_property(mat, "shader_parameter/flash", 0.0, 0.22)


func _die() -> void:
	if _dead:
		return
	_dead = true
	velocity = Vector2.ZERO
	# Encerra a caminhada e fica parada na pose da direção atual.
	_update_sprite(false)
	died.emit()
