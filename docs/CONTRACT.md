# Encantados — Contrato da Fase Final (duelo Cuca x Caipora)

Este documento define as convenções que TODAS as peças do jogo seguem para se
encaixarem sem conflito. Godot **4.7**, 2D, **pixelart, TOP-DOWN (visão de cima)**,
projeto `res://`.

> **MUDANÇA IMPORTANTE (v2):** o jogo passou de plataforma lateral para
> **top-down**. Não há mais gravidade, chão-de-plataforma nem pulo. Os dois
> personagens andam livremente em 8 direções sobre o solo da floresta.

## Cena e mundo
- Viewport (tela) padrão: **1152 x 648**.
- **Mapa MAIOR que a tela: 2304 x 1296** (o dobro em cada eixo). A câmera segue a
  Caipora, então boa parte do mapa fica fora de vista a cada instante.
- Origem do mapa em (0,0), canto inferior-direito em (2304, 1296).
- **Top-down, sem gravidade.** Ninguém cai. Os personagens ficam onde estão e se
  movem pelo input/IA. NÃO use `get_gravity()` nem `is_on_floor()`.
- **Paredes de limite** (StaticBody2D na camada 1 = World) formam a moldura do
  mapa, mantendo os personagens dentro da área jogável ~ x[60..2244], y[60..1236].
- Spawns: Caipora à esquerda-centro (x ~ 760, y ~ 648), Cuca à direita-centro
  (x ~ 1540, y ~ 648).

## Profundidade (Y-sort) e estrutura da batalha
`battle.tscn` separa fundo e mundo para o Y-sort funcionar:
- `Background` (Node2D, não y-sortado): `forest.tscn` = chão de grama (Sprite2D
  com grama repetida via region+`texture_repeat`), caminhos de **terra** (dirt)
  na arena, vaga-lumes e as **paredes de colisão**.
- `World` (Node2D, `y_sort_enabled = true`): contém `Props` (também y-sortado,
  script `props_scatter.gd`), `Caipora`, `Cuca`. Os feitiços da Cuca são
  adicionados ao `World` (via `get_parent()`), então TUDO aqui é desenhado por
  profundidade pela posição Y — o player passa ATRÁS de árvores/pedras acima dele.
- **Referência de profundidade = o PÉ (pixel de baixo).** A origem de cada coisa
  fica na base: props com `centered=false` + `offset` pra cima; Caipora e Cuca com
  `Visual` e `Collision` deslocados pra cima (`position.y` -32/-30 e -64/-60), de
  modo que `position` do nó = os pés. Assim o Y-sort compara pés com pés.
- `Atmosphere` (ColorRect, `z_index=100`): escurece o mundo por cima.

## Mundo fechado por árvores
- Arena jogável: `ARENA = x[230..2074], y[250..1046]`. As **paredes de colisão**
  de `forest.tscn` ficam nessas bordas (WallLeft dir=230, WallRight esq=2074,
  WallTop base=250, WallBottom topo=1046). `props_scatter.gd` e `forest.tscn`
  DEVEM usar os mesmos números.
- `props_scatter.gd` preenche a moldura com um anel denso de árvores, avançando
  ~40px para DENTRO da arena (`ARENA.grow(-40)`), então as árvores encostam nas
  paredes — o player bate no muro de árvores, sem vão de grama antes da parede.
- Clareira central: **círculo de terra** (`assets/extracted/dirt_circle.png`,
  borda orgânica) como Sprite2D no centro (1152,648). **Nenhuma vegetação** nasce
  dentro de `DIRT_CLEAR_RADIUS` (480) do centro — a clareira fica limpa; arbustos/
  pedras/árvores decorativas só na faixa de grama entre a terra e a borda.
- Props temáticos (covil da Cuca) em `assets/extracted/props/`, posicionados em
  `props_scatter.gd::_place_witch_props()` na grama do lado direito.
- **Colisão dos props** (em `props_scatter.gd::_add_prop`): árvores e pedras
  viram `StaticBody2D` na camada World (1). Árvore = bloquinho pequeno só no
  TRONCO (copa/folhas atravessável); pedra = shape cobrindo o corpo. Arbustos e
  itens mágicos ficam SEM colisão (atravessáveis).

## Feitiço de veneno (visual)
`poison_pool.gd`/`.tscn`: a Cuca arremessa o **frasco verde** real
(`props/potion.png`, `Sprite2D` girando no ar em arco); ao pousar, a **poça de
veneno cresce ao redor** do ponto de queda (tween de escala com overshoot). A
Cuca faz um pequeno gesto de conjuração (`cuca.gd::_cast_gesture`, esticada em
scale.y — placeholder até o sprite animado do mago).

## Câmera
- `Camera2D` é **filha da Caipora** (segue o player automaticamente), em
  `battle.tscn`. Tem `position_smoothing_enabled = true` (suavização) e **limites**
  travados no mapa: `limit_left=0, limit_top=0, limit_right=2304, limit_bottom=1296`
  para a câmera não mostrar fora do mapa nas bordas.
- O HUD é `CanvasLayer` → fica fixo na tela, não é afetado pela câmera.

## Movimento (8 direções)
- **Caipora (player):** vetor de input a partir de `move_left/right/up/down`,
  normalizado, `velocity = dir * SPEED`, `move_and_slide()`. Sem pulo.
- **Cuca (IA):** move-se em 2D para manter uma distância-alvo do player
  (aproxima se longe, recua se perto), também com `move_and_slide()`.
- **Facing** é um `Vector2` (a última direção não-nula de movimento). O visual e a
  hitbox da lança acompanham o facing. Padrão inicial: `Vector2.RIGHT`.

## Camadas de física (collision layers, índice 1-based)
Use SEMPRE `set_collision_layer_value(i, true)` / `set_collision_mask_value(i, true)`
no código, ou os bits equivalentes no `.tscn`. Valor do bit: idx1=1, idx2=2,
idx3=4, idx4=8, idx5=16.

| Índice | Nome            | Quem usa                                   |
|--------|-----------------|--------------------------------------------|
| 1      | World           | Paredes de limite da arena (StaticBody2D)  |
| 2      | PlayerBody      | Corpo da Caipora (CharacterBody2D)          |
| 3      | BossBody        | Corpo da Cuca (CharacterBody2D)             |
| 4      | PlayerHitbox    | Área da lança da Caipora (Area2D)          |
| 5      | BossHitbox      | Feitiços da Cuca (Area2D)                    |

**Colisão corpo-a-corpo (para não atravessar um ao outro):**
- Caipora: `layer` = {2}, `mask` = {1, 3}  → colide com paredes E com a Cuca.
  (bits: layer=2, mask=1+4=**5**)
- Cuca: `layer` = {3}, `mask` = {1, 2}  → colide com paredes E com a Caipora.
  (bits: layer=4, mask=1+2=**3**)
- Hitbox da lança (Area2D): `layer` = {4}, `mask` = {3} (detecta corpo da Cuca).
  (bits: layer=8, mask=4). `monitoring` LIGADO só durante o golpe.
- Feitiços da Cuca (Area2D): `layer` = {5}, `mask` = {2} (detectam a Caipora).
  (bits: layer=16, mask=2).

## Grupos
- Caipora está no grupo `"player"`.
- Cuca está no grupo `"boss"`.

## Interface de combate (OBRIGATÓRIA em Caipora e Cuca)
Cada personagem (script no nó raiz `CharacterBody2D`) DEVE expor:

```gdscript
signal health_changed(current: int, max_health: int)  # emitido ao mudar a vida
signal died()                                          # emitido ao chegar a 0

@export var max_health: int = 100
var health: int

func take_damage(amount: int) -> void:
    # reduz health (clamp 0..max_health), emite health_changed, e died() se zerar
```

- Hitboxes/feitiços causam dano assim: ao detectar o corpo alvo, se
  `body.has_method("take_damage")`, chamam `body.take_damage(dano)`.
- Cada fonte de dano deve evitar acertar o mesmo alvo várias vezes por golpe
  (guardar quem já foi atingido, cooldown de tick, ou `queue_free()` ao acertar).

## Comportamento da Cuca (puramente à distância)
A Cuca **NÃO tem golpe corpo-a-corpo**. Ela é uma lutadora de longo alcance:
- **Movimento:** tenta manter afastamento do player — recua se ele chega perto
  (`< MIN_DISTANCE` ~300), aproxima se ele foge (`> MAX_DISTANCE` ~460), e deriva
  de lado na faixa ideal.
- **Feitiços:** **alterna entre os 3 em ordem** (rotação, garantindo que os três
  apareçam), em intervalos aleatórios (~2.4 a 3.6 s), **independentemente da
  distância** ao player. Toda a lógica fica em `cuca.gd`.

## Feitiços da Cuca (3 tipos) — CONTRATO DOS SUBAGENTES
Cada feitiço é uma cena **auto-contida** em `res://actors/cuca/spells/`. A Cuca
instancia a cena, adiciona na cena de batalha e chama **um único método**:

```gdscript
func cast(origin: Vector2, target: Node2D) -> void
```
- `origin` = posição global de onde a Cuca conjura (perto das mãos dela).
- `target` = o nó da Caipora (CharacterBody2D no grupo `"player"`). PODE ser
  liberado/inválido a qualquer momento → **sempre** proteja com
  `is_instance_valid(target)` antes de ler `target.global_position`.
- O feitiço gerencia o próprio ciclo de vida (`queue_free()` ao terminar).
- A Area2D de dano fica em `layer`={5} (bit 16), `mask`={2} (bit 2), detectando o
  corpo da Caipora por `body_entered`/sobreposição.
- Ao acertar, chama `body.take_damage(dano)` se `body.has_method("take_damage")`.

Os três feitiços (arquivos e comportamento):

1. **`homing_spell.tscn` / `homing_spell.gd`** — projétil mágico.
   - Persegue o alvo (curva suave em direção a ele) nos **primeiros 2 segundos**;
     depois **congela a direção** e segue reto até sumir/acertar.
   - Dano ~**15**. Some ao acertar ou após um lifetime (~4 s).

2. **`poison_pool.tscn` / `poison_pool.gd`** — poção venenosa.
   - A poção **voa** da `origin` até a posição do alvo no momento do cast e, ao
     "pousar", vira uma **poça de veneno** no chão (círculo/mancha).
   - A poça **permanece ~5 s** e causa dano por tempo (~**6 a cada 0.5 s**) a quem
     estiver em cima. Telegrafe visualmente (mancha esverdeada translúcida).

3. **`rising_spikes.tscn` / `rising_spikes.gd`** — espinhos do chão.
   - Uma **fileira de espinhos** que sobe do chão avançando em linha **em direção
     à Caipora** (direção calculada no cast). Cada espinho aparece com um pequeno
     atraso em sequência (telegrafia: marca no chão → espinho sobe).
   - Dano ~**20** por espinho (cada alvo só toma de cada espinho uma vez). Some
     depois de ~1.5 s.

**Feito pela integração (cuca.gd), NÃO pelos subagentes:** escolha de qual
feitiço lançar, intervalo entre lançamentos (com variação aleatória) e o gate de
distância mínima. Os subagentes só entregam as 3 cenas com `cast()` funcionando.

## Janela / tela cheia
- Viewport 1152x648, `window/size/resizable=true`, stretch `canvas_items` +
  aspect `expand`. O botão de maximizar (Windows) e o de tela cheia (macOS)
  funcionam nativamente — o conteúdo reescala junto.
- Atalho extra: **F11** (ou Cmd/Ctrl+F), tratado em `boot.gd::_unhandled_input`
  via `DisplayServer.window_set_mode`.

## Diálogos (`ui/dialogue_box.tscn`)
CanvasLayer (layer 10) com efeito de máquina de escrever.
```gdscript
dialogue.play([{ "speaker": "Cuca", "text": "...", "color": Color(...) }, ...])
await dialogue.finished
```
Avança no clique/Espaço/Enter (1º toque completa o texto, o 2º passa a fala).
**Retratos:** `dialogue.portraits = { "Cuca": Texture2D, ... }` (por nome de quem
fala; sem entrada = sem retrato). `battle.gd` monta os dois com `AtlasTexture`
recortando rosto+peito das poses paradas viradas para o SUL (`Idle/sul.png`) —
não duplica imagem, é só uma região (`RECORTE_CUCA` / `RECORTE_CAIPORA`).
As falas do duelo (abertura + um final para cada resultado) ficam em
`battle.gd` (`FALAS_INICIO`, `FALAS_VITORIA`, `FALAS_DERROTA`). Durante as falas
`battle.gd::_set_actors_active(false)` desliga o `_physics_process` das duas
lutadoras, então ninguém anda/ataca/conjura.

## Fluxo de telas (Menu → Batalha → Fim)
- **Cena principal do projeto** = `res://scenes/menu/main_menu.tscn` (o jogo abre
  no menu, não direto na luta).
- **Menu** (`main_menu.tscn` / `main_menu.gd`): título "Encantados", botão **Jogar**
  que chama `get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")`.
- **Batalha** (`battle.gd`): escuta `died()` dos dois lutadores. Quando a **Cuca**
  morre → vitória; quando a **Caipora** morre → derrota. Guarda o resultado em
  `Boot.last_result` (String `"victory"` ou `"defeat"`) e, após um pequeno atraso
  (~1.2 s para a morte ser visível), troca para `res://scenes/end/end_screen.tscn`.
- **Fim** (`end_screen.tscn` / `end_screen.gd`): lê `Boot.last_result` no `_ready`
  e mostra "Vitória!" ou "Derrota". Botões: **Jogar de novo** (→ battle) e **Menu**
  (→ main_menu).
- O autoload `Boot` expõe `var last_result: String = ""` para transportar o
  resultado entre as cenas (change_scene não passa argumentos diretamente).

## HUD (inalterado)
`battle_hud.tscn` (CanvasLayer) expõe:
```gdscript
func bind_player(actor: Node) -> void  # conecta em actor.health_changed (Caipora)
func bind_boss(actor: Node) -> void    # idem para a Cuca
```
`battle.tscn` chama `bind_player`/`bind_boss` no `_ready`.

## Sprites dos personagens (caminhada + parado + ataque, 8 direções)
Os sprites REAIS já estão integrados (os `Polygon2D` placeholder continuam nas
cenas, mas ocultos). Cada personagem tem 5 spritesheets de caminhada em
`actors/<nome>/Walking|WALKING/` e 5 poses paradas em `actors/<nome>/Idle/`:
`norte, nordeste, leste, sudeste, sul`. A Caipora também tem 5 folhas de ataque
em `actors/caipora/ATTACK/` (dict `ATTACK` + prefixo `atk_`).
- **Ataque sincronizado:** as folhas têm de 6 a 12 frames. `WalkSprites.add_set`
  aceita `duration` — o fps de cada direção vira `frames/duration`, então TODAS
  duram o mesmo tempo (`ATTACK_ANIM_TIME` = 0.35 s, igual ao cooldown). Sem loop.
- `_attack_anim_timer` (0.35 s) é separado de `_attack_timer` (0.18 s, a janela
  de dano): a animação continua depois que a hitbox fecha.
- **Pés no ataque:** use a MEDIANA do fundo de cada frame, não o fundo da folha —
  nos últimos quadros a lança crava no chão e passa abaixo dos pés. E mantenha o
  `scale` igual ao da caminhada (0.165), senão ela encolhe ao levantar a lança.
- **Idle:** as poses vieram com FUNDO ROSA e foram recortadas por chroma key
  (script no scratchpad; critério por MATIZ: `s = (min(R,B)-G)/min(R,B)`, com
  trava de brilho mínimo para não comer contornos escuros nem o cabelo vermelho).
  Os originais com rosa seguem em `actors/<nome>/*.png` (não usados).
- Cada conjunto (WALK/IDLE) tem sua própria **escala e linha dos pés POR DIREÇÃO**
  (as poses têm alturas diferentes) — normalizadas para Caipora ~81px e Cuca
  ~176px. Andando → `WALK`; parada → animação `idle_<dir>`.
- **Oeste/noroeste/sudoeste = espelho** (flip_h) de leste/nordeste/sudeste.
- Os sheets são uma grade de **6 colunas** (frames em ordem, linha a linha), mas
  CADA direção tem seu próprio nº de frames, tamanho de célula e linha dos "pés"
  (medidos com script). Tudo fica no dicionário `WALK` de `caipora.gd`/`cuca.gd`.
- `actors/walk_sprites.gd` (`class_name WalkSprites`) monta o `SpriteFrames` em
  runtime (AtlasTexture por célula) e converte direção → [animação, flip_h].
- **Ancoragem pelos pés:** `Visual/Sprite` usa `centered` + `offset.y = cell_h/2 -
  feet` (setado por direção), então os pés caem na origem do nó — que é o que o
  Y-sort usa. NÃO espelhe via `Visual.scale.x` (usa-se `flip_h` do sprite).

## Tamanhos (proporção pedida: Cuca = 2x Caipora)
- Caipora: sprite ~81 px de altura (`SPRITE_SCALE = 0.165`); colisão raio 14 / altura 60.
- Cuca: sprite ~176 px (o dobro; `SPRITE_SCALE = 0.275`); colisão raio 26 / altura 120.

## Áudio (autoload `Sfx` = `scripts/sfx.gd`)
Packs **CC0 do Kenney** em `res://assets/audio/` (rpg-audio, impact-sounds,
ui-audio, music-jingles, sci-fi-sounds). O `Sfx` mapeia CHAVES → lista de
variações do mesmo som; sorteia uma e varia o pitch (evita repetição robótica).
- `Sfx.play_at(pos, chave, db, pitch, pitch_var)` → som posicionado no mundo
  (AudioStreamPlayer2D one-shot, some sozinho ao terminar).
- `Sfx.play_ui(chave, db)` → sem posição (menu/jingles), sobrevive à troca de cena.
- Quase tudo usa os packs do Kenney. Do Mixkit ficaram só DOIS sons, em
  `assets/audio/custom/`: `spear` (golpe da lança) e `glass` (poção arremessada/
  quebrando). Tentamos trocar os outros por sons do Mixkit e o resultado ficou
  pior — **os do Kenney soam melhor neste jogo**; não repetir a troca.
- Chaves: `footstep, spear, hurt, throw, glass, slime, spike, cast, laser, click,
  win, lose`. Mesma chave com pitch diferente distingue os personagens (a Cuca
  usa `footstep`/`hurt` com pitch grave, ~0.6/0.75).
- **IMPORTANTE:** ao adicionar áudio novo, rode `godot --headless --path <proj>
  --import` (o `--quit-after` encerra o scan antes de importar tudo e o som
  simplesmente não carrega).

## Controles (registrados pelo autoload `scripts/boot.gd`)
- `move_left`  = A / ←
- `move_right` = D / →
- `move_up`    = W / ↑
- `move_down`  = S / ↓
- `attack`     = J / Enter / X / **botão ESQUERDO do mouse**

## Formato de arquivo `.tscn` (IMPORTANTE)
- Use `format=3`.
- **NÃO** escreva o atributo `uid=` (nem no header `gd_scene` nem em `ext_resource`).
  O Godot gera os UIDs sozinho na primeira importação.
- Referencie scripts: `[ext_resource type="Script" path="res://.../x.gd" id="1_x"]`
  e no nó: `script = ExtResource("1_x")`.
- Instancie sub-cenas: `[ext_resource type="PackedScene" path="res://.../y.tscn" id="2_y"]`
  e o nó: `[node name="Y" parent="." instance=ExtResource("2_y")]`.
- `load_steps` = (nº de ext_resource + sub_resource) + 1. Na dúvida, pode omitir.

## Estrutura de pastas
```
res://
  actors/caipora/   caipora.tscn, caipora.gd
  actors/cuca/      cuca.tscn, cuca.gd
  actors/cuca/spells/  homing_spell.*, poison_pool.*, rising_spikes.*
  ui/               health_bar.*, battle_hud.*
  scenes/menu/      main_menu.tscn, main_menu.gd
  scenes/battle/    battle.tscn, battle.gd
  scenes/end/       end_screen.tscn, end_screen.gd
  environment/      forest.tscn (top-down, mapa 2304x1296)
  scripts/          boot.gd (autoload)
  docs/             CONTRACT.md
```
