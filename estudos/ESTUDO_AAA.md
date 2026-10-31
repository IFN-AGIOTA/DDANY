# Estudo de técnicas AAA para o *Dias de um Apocalipse*

Pesquisado em 29/10/2026. Fontes: documentação da Godot, Android/Arm, palestras da GDC, livros *Game AI Pro* e
*GPU Gems*, *Game Programming Patterns*, *The Level Design Book* e blogs/fóruns de desenvolvimento. A lista completa
está no fim.

**Como usar este guia.** Antes de mexer em otimização, infectados, level design, rede ou controles, ler a seção do
assunto. Cada técnica traz o que é, o número que a fonte dá (quando dá), por que funciona e como fica no **nosso**
jogo (arquivo). As marcações:

- ✅ **já temos**: o jogo já faz isso; não refazer, só manter.
- ➜ **fazer**: ainda não temos e vale a pena.
- ⚠ **cuidado**: armadilha ou limite da nossa plataforma (Godot 4.3, renderizador Compatibility/GLES3, celular).
- *(inferência)*: conclusão minha a partir das fontes, não algo que a fonte diz.

---

## 0. Raio-x do nosso jogo (medido em 29/10/2026)

Medido com os contadores da Godot (`Performance`) no computador de teste. Ele desenha sem placa de vídeo
(software), então o **tempo** de quadro não vale para o celular; **chamadas de desenho, triângulos e nós valem**
(são iguais em qualquer aparelho).

| Lugar | Chamadas de desenho | Objetos na tela | Triângulos | Nós na cena | Nós com `_process` | Infectados |
|---|---|---|---|---|---|---|
| Base militar (início) | 195 | 231 | 179 mil | 10,7 mil | 56 | 12 |
| Centro da cidade | 249 | 287 | 260 mil | 20,6 mil | 55 | 12 |
| Centro olhando a avenida | 292 | 329 | 343 mil | 20,6 mil | 59 | 16 |

- **Chamadas de desenho:** abaixo das ~500 que um engenheiro da Arm cita como teto informal para a maioria dos
  celulares. Folga boa.
- **Triângulos:** 180–340 mil. A única referência de cena inteira das fontes é a demo *Armies* do Android: ~210 mil
  triângulos estáveis a ~30 FPS. No centro passamos disso, então **triângulos são o primeiro alvo** se o celular
  sofrer no centro (LOD, distâncias de visibilidade).
- **Nós:** 20 mil no centro. A Godot diz que a árvore de cena começa a pesar entre "milhares e dezenas de milhares"
  de nós. Os chunks já tiram da árvore o que está longe ✅, mas estamos no limite citado.
- **Quem roda todo quadro:** só 55–59 nós (16 deles são infectados). Bom.

---

## 1. Otimização (Godot Compatibility + celular)

### 1.1 Medir antes de mexer

- A regra número 1 de todas as fontes: **medir, mudar uma coisa, medir de novo**. O quadro custa o que custar o
  mais lento entre CPU e GPU; acelerar a CPU não adianta se a GPU é o gargalo. *(Godot: General optimization)*
- Ferramentas na Godot: **Profiler** (scripts e física), **Visual Profiler** (CPU e GPU da renderização, funciona
  no Compatibility, 100% = 16,67 ms), aba **Monitores** e, no editor, *View Information* (chamadas de desenho).
  *(Godot: Debugger panel)*
- ⚠ No celular o resultado muda muito de aparelho para aparelho. Testar em pelo menos um celular médio.
- ⚠ **Testar jogando 45–60 minutos**: o Android diz que o FPS costuma cair depois de 45–50 min por calor. O teste
  de 2 minutos engana. *(Android: Optimize)*
- ➜ Criar um teste automático de desempenho (como o que usei para este raio-x: `Performance.get_monitor` em lugares
  fixos) e rodar a cada versão, para ver se alguma mudança piorou chamadas de desenho, triângulos ou nós.

### 1.2 Chamadas de desenho e materiais

- Cada troca de estado e cada chamada de desenho custa CPU no driver. Agrupar mesmo material e mesma malha.
  *(Godot: GPU optimization)*
- **Poucos materiais:** 20 mil objetos com 20 mil materiais é lento; com 100 materiais é "muito mais rápido".
  `StandardMaterial3D` com as mesmas opções ligadas compartilha o shader, mesmo com cores diferentes. *(Godot)*
- **Atlas de texturas:** juntar "centenas ou milhares" de texturas em poucos atlas reduz chamadas. *(Android)*
- ✅ Já usamos MultiMesh por bloco para carros, postes, lixo, árvores e prédios (`mundo/abandono.gd`,
  `mundo/cidade.gd`), malhas juntadas por bloco (ruas, calçadas, fios) e cores por vértice em vez de material por
  peça.
- ⚠ Malha juntada não é cortada por partes: se um pedaço aparece, a malha inteira é desenhada. Por isso juntamos
  **por bloco** (250–500 m), não a cidade inteira. ✅

### 1.3 Corte, LOD e distâncias

- **Distâncias de visibilidade (visibility ranges / HLOD):** `visibility_range_begin/end` com margem. *Fade Mode =
  Disabled* é o mais barato (o fade por transparência força desenho transparente). Para fade sem transparência:
  *Distance Fade = Object Dither*. *(Godot: Visibility ranges)*
  ✅ Usamos em tudo (`mundo/abandono.gd` alcances por tipo, `PERTO_LOD`).
- **Visibility Parent (HLOD de verdade):** um nó "lote de casas" aparece de longe e, perto, esconde-se e mostra as
  casas filhas. ➜ Poderíamos usar nas fachadas e nos prédios por bloco: de longe 1 malha do quarteirão inteiro, de
  perto as peças. *(Godot)*
- **Mesh LOD automático:** a Godot gera LODs na importação de glTF (meshoptimizer). Limiar em *Rendering › Mesh LOD
  › LOD Change › Threshold Pixels* (padrão 1 px; `get_tree().root.mesh_lod_threshold`). Ele já considera o campo de
  visão. ⚠ Pode dar defeito em malha com esqueleto (infectados): conferir. ⚠ MultiMesh escolhe **um LOD só para
  todas as instâncias** (pelo ponto mais perto do AABB): por isso MultiMesh deve ser por bloco. ✅ *(Godot: Mesh LOD)*
- **Regras de LOD do Android:** cortar **50% dos triângulos a cada nível**; triângulos com menos de **10 pixels**
  de área ou fininhos e compridos são desperdício; no máximo **65.535 vértices por malha** (índices de 16 bits).
  *(Android: Geometry)* ➜ Conferir as malhas grandes juntadas (ruas, prédios por bloco) contra o limite de 65.535.
- **Oclusão:** ✅ ligada (`project.godot`) com caixas por prédio (`mundo/oclusao.gd`). ⚠ Não mover os oclusores
  durante o jogo (refaz a árvore); ligar/desligar é barato. ✅ No Compatibility o ganho é menor que no Mobile porque
  já existe pré-passe de profundidade, mas "ainda perceptível em cenas 3D complexas". *(Godot: Occlusion culling)*
- **Remover da árvore em vez de esconder:** `remove_child`/`add_child` pode ser bem mais rápido que esconder ou
  pausar. ✅ É o que `mundo/chunks.gd` faz.

### 1.4 Texturas

- ✅ ETC2/ASTC ligado (`import_etc2_astc=true`). Fonte Android: **ASTC é a melhor**, ETC2 é a reserva; ETC2 exige
  GLES 3.0 (o nosso).
- **Mipmaps em tudo que aparece em distâncias variadas** (custam +33% de memória, mas reduzem banda e melhoram o
  cache). *(Android: Textures)*
- **Filtro bilinear** é o melhor equilíbrio; trilinear gasta "muito mais banda"; anisotrópico acima de **2x** é
  "extremamente caro". O filtro de textura pode ser **até metade da energia da GPU**. *(Android)* ✅ 1.01: no celular
  a anisotropia para em 2x (`menu/aplicar_opcoes.gd` `aniso_efetivo`), qualquer que seja a opção.
- **No máximo ~5 texturas por material** no celular; trocar rugosidade/metal por constantes; juntar mapas de um
  canal numa textura só (AO no vermelho, rugosidade no verde, metal no azul; o detalhe mais importante no verde).
  *(Android: Materials/Textures)*
- **Mapas normais com moderação** em aparelhos fracos; de longe, desligar normal map nas versões LOD. *(Godot/Android)*
- ⚠ A maioria dos Android não suporta **textura comprimida com transparência**: preferir texturas opacas. Limite
  de **4096×4096** no celular. *(Godot: 3D rendering limitations)*

### 1.5 Transparência e overdraw

- Transparente é **sempre** mais caro que opaco, e camadas de transparência empilhadas são o pior caso.
  *(Android/Godot)*
- Preferir **Alpha Scissor** (recorte) a mistura (blend) em folhas, grades, cercas. *(Godot)*
- ✅ A luneta nova (0.99.2) usa uma passada só e lê a imagem reduzida (mipmap) para desfocar: barato.
- ➜ Conferir o mato (`mundo/mato.gd`), a fumaça e a névoa do gás: são transparências grandes na tela, o tipo de
  coisa que mais pesa em celular (tile-based). *(inferência)*

### 1.6 Shaders

- Somar, subtrair e multiplicar são baratos; **divisão, sin, cos, pow, log, tan são caros**. *(Android: Materials)*
- Há muito mais pixels que vértices: o que puder, calcular no **vertex shader**. *(Android)*
- ⚠ **Engasgo de shader:** os "ubershaders" e a pré-compilação da Godot 4.4+ **não existem no Compatibility**. A
  solução oficial para o Compatibility é **mostrar cada material pelo menos um quadro durante o carregamento**.
  *(Godot: Pipeline compilations)* ✅ É o que a nossa tela de carregamento faz em "Preparando a vista" (a cidade
  aparece em 12 lotes debaixo da tela, 0.99.1). ➜ Faltam os materiais que só aparecem depois: efeitos de tiro,
  sangue, explosão, luneta, roupas e armas raras. Dá para mostrá-los um quadro, escondidos, na mesma etapa.

### 1.7 Luz e sombras

- Luz em tempo real, várias sombras e GI são "especialmente caros" no celular. Sombra pesa mais que luz: desligar
  sombra do maior número possível de luzes e objetos, e usar mapas de sombra menores. *(Godot: 3D performance/GPU)*
- ✅ Objetos pequenos já não fazem sombra (`cast_shadow = OFF` em lixo, placas, fios, armas na mão...).
- ➜ Se o celular sofrer: luzes dos locais especiais sem sombra (só o sol faz sombra) e sombra do sol com alcance
  curto.

### 1.8 CPU e GDScript

- GDScript é lento **nos seus próprios laços**; chamadas da engine rodam na mesma velocidade em qualquer linguagem.
  *(Godot: CPU optimization)*
- **Tipar as variáveis** (`var x := 1.0`, `Array[int]`, `func f(a: float) -> float`): com tipo conhecido, a Godot usa
  instruções otimizadas. *(Godot: Static typing)* ✅ O código já é quase todo tipado.
- **Arrays empacotados** (`PackedFloat32Array`, `PackedVector3Array`) para dados de muitos agentes (estrutura de
  arrays). ✅ Usamos nas malhas e na horda.
- ⚠ `get_nodes_in_group()` cria um Array novo a cada chamada: **não chamar todo quadro**. *(Game Programming
  Patterns + Godot)* ➜ Hoje `npc/hospitais.gd` (`npcs_hospital`) e `jogador/sobrevivencia.gd` (`fogueiras`) chamam
  dentro do `_process`. Guardar a lista e atualizar só quando muda (ou checar a cada 0,5 s).
- Guardar referências (`@onready`, variáveis) em vez de `get_node` em laço. *(Godot)*
- Comparar inteiros é mais rápido que comparar textos: estados como `enum`, não `String`. *(Godot: Data preferences)*

### 1.9 Física

- Formas de colisão simples (caixa, cápsula), nunca a malha do desenho. ✅
- Tirar da física o que está longe (ou reciclar). ✅ A colisão só existe perto do jogador (`mundo/colisao_mundo.gd`)
  e os infectados de longe andam sem física.
- **60 Hz** é o recomendado; 30 ou 20 Hz economizam CPU mas tremem, a não ser com interpolação. *(Godot: CPU)*

### 1.10 Threads (carregar em segundo plano)

- A árvore de cena **não** é thread-safe: montar o pedaço fora da árvore numa thread e pôr com
  `add_child.call_deferred`. Usar **uma** thread de carregamento só (várias podem corromper recursos
  compartilhados). Criar textura ou mexer em `Image` numa thread força sincronizar com a renderização (trava).
  *(Godot: Thread-safe APIs)*
- ✅ 0.99.1: `ResourceLoader.load_threaded_request` lê os modelos grandes do disco em segundo plano durante o
  carregamento (`main.gd PRE_CARREGAR`).

### 1.11 Ritmo de quadros, calor e bateria

- Escolher **30 ou 60 FPS** e manter. Numa tela de 60 Hz: 60/30/20. Em telas de 90 Hz: 90/60/**45**/30. Cair para 45
  é mais suave que cair para 30. **Não desenhar mais rápido que o alvo**: numa tela de 120 Hz, um jogo a 60 não
  ganha nada com 120, só gasta bateria. *(Android: Frame pacing / Power)* ✅ O celular já fica em no máximo 60
  (`menu/aplicar_opcoes.gd`). ➜ Oferecer 45 nas Opções (hoje: sem limite/30/60?).
- "Quadros curtos seguidos de longos" são percebidos como engasgo: melhor 45 estável que 60 oscilando. *(Android)*
- **Calor:** o Android tem `PowerManager.getThermalHeadroom()` (0 = frio, 1 = grave; consultar no máximo a cada 10
  s). Perto de 0,85, baixar resolução da cena ou o FPS. *(Android: ADPF Thermal)* ⚠ Na Godot 4.3 isso exige plugin
  Android. ➜ Alternativa sem plugin *(inferência)*: **resolução dinâmica** pela média do tempo de quadro (se passa
  do alvo por alguns segundos, baixa `scaling_3d_scale` um degrau; se sobra folga, sobe). **Nunca baixar a
  resolução da interface**, só a da cena 3D. *(Android)*

### 1.12 Mundo aberto: streaming

*(o que a Epic e a Guerrilla fazem está na seção 1.13)*

- ✅ Cidade em chunks de 500 m (`mundo/chunks.gd`), colisão só perto, prédios viram interior perto
  (`mundo/interiores.gd`), carregamento em fatias com a tela (0.99.1), modelos lidos em segundo plano.
- Regra geral de todas as fontes: **orçamento por quadro**. Trabalho que não cabe em ~2–4 ms vai sendo feito aos
  poucos (como fizemos no carregamento). ➜ Aplicar o mesmo durante o jogo: abrir prédio (interior), abrir local
  especial e reaparecer loot deveriam ser fatiados, porque são os engasgos que o jogador sente andando pela cidade.
  *(inferência a partir de Godot/Epic)*

### 1.13 Mundo aberto: como a Epic e a Guerrilla fazem streaming

Fontes: documentação do *World Partition* e do *HLOD* da Unreal Engine 5; palestra da Guerrilla *Streaming the
World of Horizon Zero Dawn* (GDC 2017; só a página da palestra pôde ser lida); blog do Arseny Kapoulkine (zeux.io).

**Como funciona lá**
- **Carregar ≠ ativar.** Cada célula do mundo tem estados separados: *carregada* (na memória, invisível, parada) e
  *ativada* (na cena, desenhando, rodando). O raio de carregar é maior que o de ativar, então quando o jogador chega
  a célula já está pronta e só precisa "ligar", que é barato. *(Epic: World Partition)*
- **Uma grade só.** A Epic recomenda poucas grades: cada grade extra multiplica o trabalho de decidir o que carregar.
  Exemplo dela: células de 256 m com raio de carregamento de 768 m (o padrão é 512 m). *(Epic)*
- **Prioridade por importância.** A ordem de carregar segue a distância **e** o ângulo da câmera: o que está na frente
  vem antes do que está atrás. *(Epic)*
- **Limite de carregamentos ao mesmo tempo** (`MaxLoadingLevelStreamingCells`): nunca abrir tudo de uma vez, para o
  jogo não engasgar quando o jogador corre ou vira rápido. *(Epic)*
- **Nunca travar o jogo esperando.** Se a célula não chegou a tempo, o jogo continua com a versão simplificada (HLOD)
  no lugar. Só se trava em teleporte. *(Epic)*
- **Teleporte em 4 passos:** (1) pedir as células do destino, (2) esperar ficarem prontas (com tela de carregamento
  se precisar), (3) mover o jogador, (4) só então soltar as células da origem. *(Epic)*
- **Objetos que dependem um do outro vão juntos** (uma porta e o prédio dela, um interruptor e a luz): a célula
  carrega o grupo inteiro, para nunca aparecer metade. *(Epic)*
- **HLOD em camadas** (*Hierarchical LOD*): de longe, muitos objetos viram **uma malha só**.
  - *Instancing*: a vegetação de longe vira instâncias no LOD mais baixo.
  - *Merged Mesh*: junta várias malhas numa, mantendo o visual.
  - *Simplified Mesh*: refaz a forma por fora. Usa um *Merge Distance* que **fecha portas e janelas**, porque de longe
    não se vê o interior.
  - A troca é por **tamanho na tela (pixels)**, não por metros, e malhas iguais são agrupadas antes de juntar.
  *(Epic: HLOD)*
- **Só refazer o que mudou:** a versão "de longe" de cada célula é gerada uma vez e só refeita quando a célula muda.
  *(Epic)*
- **Botões de diagnóstico:** ligar/desligar o HLOD e desenhar a grade com as células e estados na tela é o primeiro
  passo para achar engasgo de streaming. *(Epic)*
- **Celular:** o espaço para dados por objeto é pequeno (uniform buffer de 16 KB e push constants de 128 B em muitas
  GPUs de celular), então juntar objetos e mandar menos dados por desenho vale mais lá do que no PC. *(zeux.io)*

**O que já temos**
- ✅ `mundo/chunks.gd`: chunks de 500 m, raio pela "Distância de visão" (`RAIO_AUTO`), **folga** de 1 chunk antes de
  descarregar (`FOLGA`, evita liga-desliga na borda) e **limite por quadro** (`OPS_POR_QUADRO := 90`).
- ✅ `mundo/interiores.gd`: abre a 42 m e fecha a 62 m (folga), no máximo 5 abertos.
- ✅ Teleporte seguro (0.99.3): o jogador espera o chão aparecer e o `chunks.forcar` prepara o destino.
- ✅ Na tela de carregamento, os modelos são lidos em segundo plano (`load_threaded_request`).
- ✅ MultiMesh já dividido por blocos: árvores e mato por bloco em `mundo/cidade.gd`, carros/lixo/postes em blocos
  de 250 m em `mundo/abandono.gd`, prédios por bloco (`_mm_predios`). É o que a Epic faz com a vegetação.
- ✅ A fila do `_refazer_fila` já carrega **o mais perto primeiro**.

**O que aplicar** ➜ *(minha leitura para o nosso caso)*
1. **Separar ligar de carregar.** Hoje um chunk é "na cena" ou "fora". Criar um anel do meio onde o chunk fica
   **preparado mas escondido** (ativar ~1 chunk ao redor; preparar ~2). Assim, cruzar a borda só liga coisas prontas.
2. **Orçamento em milissegundos, não em operações.** Trocar `OPS_POR_QUADRO` por "até ~1,5 ms por quadro", medido
   com `Time.get_ticks_usec` (o mesmo jeito do `cidade.pausa()`). No celular lento, 90 operações podem passar de 4 ms.
3. **Ordem por importância.** Hoje a fila ordena só pela distância; somar o ângulo da câmera para os chunks **na
   frente** virem antes dos de trás (com a mesma distância).
4. **Interior como filho do chunk.** O interior de um prédio sai e volta junto com o chunk dele, nunca separado.
5. **Teleporte da Epic completo.** O 0.99.3 já espera o chão; falta **segurar a origem** até o destino estar pronto
   (útil ao trocar de servidor ou entrar num local especial).
6. **HLOD em 3 níveis** para quarteirões e fachadas: perto, a malha completa; médio, a fachada juntada; longe, um
   bloco simples sem janelas. Na Godot 4.3 isso é `visibility_range_begin/end` com `visibility_parent`
   (ver 1.3), com a troca pela distância calculada para dar o tamanho certo na tela.
7. **Overlay de diagnóstico** (só para nós, escondido nas opções de desenvolvedor): grade dos chunks com cores por
   estado, quantos ligaram neste quadro, quanto tempo levou e um botão para desligar o HLOD.

---

## 2. Infectados e IA

### 2.1 O Diretor de IA do *Left 4 Dead* (ritmo)

Fonte: Michael Booth (Valve), *The AI Systems of Left 4 Dead*, 2009.

**A ideia:** o jogo mede a "intensidade emocional" de cada jogador e controla a população de infectados para criar
**picos e vales**, como as rodadas de Counter-Strike (silêncio tenso + combate curto e imprevisível). "Combate
constante cansa; parado demais é chato."

**Como mede a intensidade de cada jogador:**
- sobe quando ele leva dano (proporcional ao dano), cai incapacitado, é puxado/jogado de um lugar alto, ou quando um
  infectado morre perto dele (quanto mais perto, mais sobe);
- cai sozinha com o tempo, **mas não cai enquanto há infectados atacando**;
- vale a maior intensidade do grupo.

**As quatro fases:**
1. **Crescendo:** população cheia de ameaças até a intensidade passar do pico.
2. **Pico:** continua cheio por **3–5 s** depois do pico.
3. **Esfriando:** para de criar ameaças e espera a luta atual terminar sozinha.
4. **Alívio:** população mínima por **30–45 s** (ou até o grupo andar bastante), depois volta ao 1.

Na população mínima: nada de errantes novos, nada de horda, nada de especial novo. **Chefes não são afetados**.
O próprio Booth: "o algoritmo ajusta o ritmo, não a dificuldade" (a frequência dos picos, não a força).

**População procedural ("imprevisibilidade estruturada"):**
- **Active Area Set:** o conjunto de áreas em volta do grupo. Entrando nele, cria os infectados que a área "tem"
  (um número guardado por área); saindo, apaga e devolve o número. Assim "centenas de inimigos com poucas
  entidades". ✅ **É exatamente a nossa horda virtual** (`inimigos/horda.gd`: grupos virtuais que viram infectados
  de verdade perto, até `max_ativos`).
- O número da área **zera quando algum jogador a vê** e no alívio. ➜ No nosso jogo: não fazer infectado "nascer"
  na frente do jogador (já evitamos?) e não nascer nada novo durante o alívio.
- **Hordas (mobs) de 20–30** a cada **90–180 s** (Normal), **75% vindas de trás** do grupo (porque errantes e
  especiais costumam estar na frente). O tamanho começa pequeno e cresce com o tempo para não ficar repetitivo.
- **Especiais** em intervalos sorteados, sempre num lugar **que ninguém está vendo**, apropriado ao tipo (o lento
  nasce na frente, o que puxa nasce em cima).
- **Chefes:** a cada N metros do caminho; os eventos "Tank, Witch e nada" são **embaralhados**, sem repetir o mesmo
  seguido.
- **Armas e itens:** o designer marca vários lugares possíveis; o Diretor escolhe quais existem. "Previsível onde
  pode estar, imprevisível o que tem."

➜ **Proposta para nós (alto impacto, mexe em `inimigos/vagos.gd`/`horda.gd`, arquivo novo `inimigos/diretor.gd`):**
- intensidade por jogador como acima (dano, cair, infectado morrendo perto, ser agarrado);
- fases crescendo/pico/esfriando/alívio controlando: quantos virtuais viram reais, se uma horda é mandada atrás do
  jogador e quando;
- hordas a cada 90–180 s **quando o jogador está fora de casa/base**, vindas de trás e de onde ele não vê;
- no alívio, a cidade "respira": som ambiente calmo, nada novo nasce perto.
- Em rede: o host calcula a maior intensidade entre os jogadores (como o L4D com 4 jogadores).

### 2.2 Percepção: os infectados do *The Last of Us*

Fonte: Mark Botta (Naughty Dog), *Infected AI in The Last of Us* (*Game AI Pro 2*, cap. 33).

- **Sons lógicos:** a IA não "ouve" o áudio de verdade; o jogo emite eventos de som com raio definido pelo designer
  (tiro, passo, garrafa quebrando). ✅ Nós fazemos igual (`vagos.barulho(pos, raio)`).
- Os infectados ouvem **~6 vezes melhor** que os humanos, e **ouvem pior quando estão distraídos/sem saber de
  você** (deixa o jogador ser furtivo e planejar). ➜ Multiplicador de audição por estado (vagando ×0,6, alerta ×1,
  caçando ×1,3) *(números meus)*.
- **Oclusão:** a cada som, raios de cada infectado até a fonte; parede no meio abafa; totalmente bloqueado = não
  ouve. ✅ Temos o "círculo de audição abafado" (`vago.gd ouvir`, `ABAFADO`).
- **Passos: o raio do som cresce com a velocidade do jogador** (aproximar rápido de longe, devagar de perto). ✅
  Temos (agachado 2,5 · andando 7 · trote 14 · correndo 20 m).
- **Avisar antes de pegar:** ao começar a ouvir, o infectado entra num estado **agitado** visível, dando ao jogador
  a chance de reagir antes de ser descoberto. "Comunicar a intenção é vital": eles cortaram ideias que o jogador não
  entendia. ➜ Um gemido/virada de cabeça de "desconfiado" antes de perseguir.
- **Distrações:** o infectado reage ao estímulo, não deduz quem jogou: **garrafa/tijolo atirado puxa todos para onde
  caiu**. Isso tornou garrafas "tão valiosas quanto armas". ➜ **Arremessar garrafa vazia/tijolo** (o item "garrafa
  vazia" já existe) para fazer barulho onde cair. Grande ganho de jogabilidade, custo baixo.
- Cuidado com o equilíbrio: o coquetel molotov atraía todos para o fogo; **limitaram quantos o fogo afeta**. A
  granada de fumaça **cega e ensurdece** dentro da nuvem.
- **Respirar perto:** um "som lógico de respiração" de alcance curtíssimo, sem áudio, para o infectado notar alguém
  parado colado nele. ✅ Parecido com o nosso "cheiro 3,5 m".

### 2.3 Comportamento

- **"Primeiro não ser burro, depois ser esperto."** Muita inteligência é atribuída a quem simplesmente não anda contra
  a parede. *(Botta)* ➜ Prioridade: corrigir infectado preso em quina/porta/carro antes de inventar comportamento
  novo.
- **Habilidades por prioridade:** cada tipo tem uma lista (pegando fogo > caçar > procurar > seguir > dormir >
  vagar); testa da maior para a menor; **a última sempre vale** (vagar), senão o personagem trava. *(Botta)* ✅ Nossa
  máquina de estados tem o vagar de reserva.
- **Procurar depois de perder o jogador:** vasculha esconderijos perto do último lugar visto, de um jeito frenético
  (escolhe a animação que revela mais "células não vistas" e evita repetir). Não é exaustivo: desiste e volta a
  vagar. *(Botta)* ✅ Temos memória e investigação; ✅ 1.01: depois de te perder ele ainda olha 2-3 lugares perto,
  para o lado em que você foi, olhando menos tempo em cada um (`inimigos/vago.gd` `_proximo_vasculhar`).
- **Seguir:** quem não viu o jogador mas vê outro infectado correndo **vai atrás dele** (sem saber o motivo); o que
  viu chega primeiro. *(Botta)* ✅ Parecido com a nossa "manada 14 m".
- **Dormir:** infectado parado com sentidos reduzidos, que se mexe se você passa rápido ou perto demais (aviso), e
  acorda bravo com barulho alto. Bom para "sentinelas" em pontos de passagem. *(Botta)* ✅ Temos "fingindo de morto";
  ➜ "dormindo" em grupos dentro de prédios seria um bom acréscimo.
- **Tudo por dados, nunca "se for o tipo X" no código.** Todos os infectados do TLOU são uma classe só; o tipo é um
  conjunto de habilidades e números. Isso também deu os níveis de dificuldade de graça (limiares de reação por
  tipo). *(Botta)* ✅ Nosso `inimigos/regras_infectados.gd` segue essa linha.
- **Ações do *Left 4 Dead*:** cada ação tem `OnStart/Update/OnEnd/OnSuspend/OnResume`, e só muda de ação
  devolvendo uma transição (`ChangeTo`, `SuspendFor`, `Done`) **com uma frase do motivo** ("o jogador que eu caçava
  morreu"). As frases ajudam muito a depurar. *(Booth)* ➜ Guardar o "motivo" da última troca de estado de cada
  infectado e mostrar num modo de depuração.
- **Caminho reativo:** em vez de seguir o caminho exato, ir para um ponto "mais à frente" do caminho com desvio
  local de obstáculos; fica fluido, barato de recalcular e combina com o andar em bando. **Escalar** obstáculos por
  traços de colisão (achar teto, beirada, altura) e escolher a animação de escalada mais próxima. *(Booth)*

### 2.4 Muitos infectados (desempenho da IA)

- ✅ **LOD de IA:** longe e sem caçar, a lógica roda 1 a cada 4 quadros; animação: perto todo quadro, 25–50 m a cada
  2, mais longe a cada 4, fora da câmera a cada 8, além de 145 m nada (`inimigos/vago.gd`). É o que a Epic faz com o
  *Animation Budget Allocator*.
- **Orçamento em milissegundos, não em quantidade** *(Epic, Animation Budget Allocator)*: 1 ms por quadro para as
  animações; acima do orçamento, os menos importantes atualizam mais devagar (até 1 a cada 10 quadros), com
  histerese (piora acima de 1,5× o orçamento, melhora só abaixo de 1,25×) e no máximo 4 trocas por quadro; no máximo
  ~4 fora da tela com atualização cheia. ➜ Trocar o limite fixo de 22 infectados por "22 no máximo, mas menos se o
  quadro estiver pesado".
- **"Importância" (significance)** = distância + está na tela + fez barulho + está atacando. Os mais importantes
  recebem o orçamento primeiro. *(Epic: Significance Manager)*
- **Campo de fluxo (flow field)** *(Fieldrunners 2, Game AI Pro cap. 24)*: em vez de cada um calcular seu caminho,
  um mapa de setas para o destino (Dijkstra a partir do alvo) que **todos usam**; custo constante não importa
  quantos; "milhares de unidades em celular". Bom quando muitos vão para o mesmo lugar (uma horda indo atrás do
  jogador ou de um barulho). Junto com separação/alinhamento/coesão de bando. ✖ 1.01: feito e MEDIDO (grade de 4 m,
  244 m em volta do destino, só prédios e água bloqueiam, cálculo espalhado em 1 ms por quadro) e tirado: com 24
  infectados indo a um ponto no centro, 6 sementes, ficou igual a sem ele (presos 12 contra 13, chegaram 8 contra 9,
  falta somada 3105 contra 3329 m). Quem empaca empaca em carro e barreira perto do destino, que o campo não vê; dar
  a volta no quarteirão quase nunca é o problema. Volta a valer se um dia os infectados forem atrás de você de longe
  por dentro da cidade (aí o caminho dá muitas voltas).
- **Comparar distâncias ao quadrado** (sem raiz) e grade/quadtree para achar vizinhos. *(Fieldrunners)* ✅ Usamos
  grade (`CEL_PREDIO`, `_pred_hash`).
- **Simplificar o modelo, não o algoritmo** *(Project Highrise, "1000 NPCs a 60 FPS")*: reduziram 15.000 células para
  100 nós com 400 ligações, e "aí a escolha do algoritmo nem importa mais". Ações em fila "de olho fechado": só
  reavaliam o mundo quando acaba a fila ou algo falha. "Quanto mais NPCs, mais simples cada um deve ser."
  *(inferência)* Os sobreviventes do hospital (`npc/`) podem seguir rotinas por horário assim.

### 2.5 Muitos infectados na tela (desenho)

- *(GPU Gems 3, cap. 2)* **Instancing com animação em textura:** as matrizes de cada osso, em cada quadro de cada
  animação, gravadas numa textura; cada instância diz qual animação e qual quadro; o vertex shader lê os ossos da
  textura. Resultado na época: ~10.000 personagens, 160 chamadas de desenho em vez de 59.726. Variação sem custo:
  cor por instância, peças trocadas (cabeça, roupa) que usam o mesmo esqueleto.
- Para nós *(inferência)*: manter os ~20 perto com esqueleto de verdade e desenhar os de **longe** (horda virtual
  visível, 50–200 m) como um MultiMesh com animação em textura (andando/parado). Hoje a horda virtual não aparece de
  longe; isso deixaria a cidade "cheia" sem custo de IA. ⚠ Projeto grande (ferramenta para gravar a textura, shader
  próprio); ⚠ testar se o Compatibility aceita a textura em ponto flutuante.

### 2.6 Os mutados (lore) como "especiais"

Pela Bíblia da Lore (2.7): o **infectado comum** é lento, tropeça, avança em massa, geme e anda só no chão, atraído
por barulho e cheiro. O **mutado** corre e salta como animal, escala paredes de contêineres, salta entre telhados,
fareja sangue de longe e faz o estalo rápido de dentes.

- Isso casa com o modelo de "especiais" do L4D e do TLOU: **raros, com papel próprio e sempre anunciados por som**
  (o estalo), nascendo onde o jogador não vê.
- ✅ **Conferido no código:** o padrão já é "Lentos" (`menu/config.gd z_vel`), fiel à lore; "Misturado" é só uma
  opção. Na 1.00 a "corrida" veio dos mutados (especiais raros, `inimigos/diretor.gd`).

---

## 3. Level design

Fontes principais: *The Level Design Book*, Scott Rogers (lições da Disneylândia), Don Carson (storytelling dos
parques temáticos), entrevista de Shaver (80.lv).

### 3.1 Guiar o jogador sem interface

- **Marcos ("weenies"):** a Disney organiza cada área em volta de um marco grande e visível de longe (o castelo).
  Um marco precisa ser **útil e relevante**; prédio decorativo no horizonte não orienta ninguém. *(LDB, Disney)*
  ✅ 1.06: as 4 igrejas (torre de ~41 m com a cruz, cúpula verde) e a prefeitura (cúpula com relógios e bandeira) são
  marcos vistos de longe (a casca de longe tem a torre, a cúpula e os telhados) e são úteis: loot próprio, o
  campanário para vigiar e o sino que puxa a horda.
- **"Onde estou?" em 15 segundos:** se o jogador não responde isso nos primeiros 15 s, já está perdido. *(Carson)*
- **Luz:** iluminar mais forte as saídas e portas importantes que os espaços secundários; portas bem iluminadas
  ajudam a ler o caminho. Um feixe de luz num objeto vale mais que uma sala cheia de detalhe. *(LDB, Carson)*
- **Cor com significado:** reservar uma cor para uma coisa só (ex.: só barris explosivos são vermelhos). *(LDB)*
- **Placas e marcadores:** o livro estima a eficácia (estimativas, não ciência): som 15%, composição 35%,
  luz/cor 40%, placas no mundo 40%, storytelling 50%, **itens e inimigos como migalhas 80%**, **ameaças ativas 93%**,
  barreiras 95–98%. Marcador na tela deve ser **opcional** para quem gosta de explorar. *(LDB, Shaver)*
- **Barreiras com motivo:** "ponha um carro ou entulho no caminho!", não parede invisível; grade/cerca para "dá para
  ver mas não dá para passar". *(Shaver)* ✅ Nossos carros, barreiras de concreto e entulho já fazem isso.

### 3.2 Estrutura do mundo aberto

- **Loops:** dar sensação de não-linear; becos sem saída frustram. **Hub que muda a cada visita** (senão vira ir e
  voltar). Voltar a um lugar e encontrá-lo **mudado** comunica tempo passando. *(LDB, Carson)*
- **Verticalidade:** no máximo **3 planos de piso** por área; descer é mais "pesado" que subir (compromete); escadas
  a 30–35°, patamar a cada 12–16 degraus. *(LDB)*
- **Portões (gating):** mostrar a fechadura antes da chave. *(LDB)* ✅ O cartão do bunker funciona assim (a porta é
  vista antes do cartão).

### 3.3 Combate contra hordas (espaço de encontro)

- **Mirante antes do combate:** deixar o jogador ver o perigo antes de se comprometer (entrada de mão única, inimigos
  sem saber). "A coisa mais perto de uma luta justa." *(LDB: Encounter)* ✅ 1.06: o campanário das igrejas e o
  terraço da prefeitura são mirantes (dá para ver o adro/praça antes de descer).
- **Contra hordas corpo a corpo** *(LDB, estudo do Undead Burg do Dark Souls)*: um **funil** (escada, rua estreita)
  que estica a horda em fila; uma **pista para recuar**; e **pelo menos uma saída que não fique atrás da horda**.
  Nunca prender o jogador numa arena sem saída com uma horda.
- **Poucos tipos de inimigo por vez:** 1 tipo = descanso, 2 = normal, 3 = complexo, 5+ = carnificina. *(LDB)*
- **Cobertura:** alta ≥ 1,75 m, baixa 1,0–1,25 m; "menos cobertura é melhor" (cobertura esconde a luta); baixa é
  melhor que alta. *(LDB: Cover, Uncharted 4/Gears)*

### 3.4 Contar história com o cenário

- Responder "**o que aconteceu aqui?**": porta arrombada, marcas de explosão, carro batido, rastro de sangue (o rastro
  também guia: ~50%). *(LDB, Carson)*
- **A casa como retrato do dono.** *(LDB, estudo de Thief)* ✅ 1.06: a igreja virou abrigo (colchões, doações, mural de
  recados, porta barrada com bancos) e a prefeitura conta a evacuação (quadro do comando de crise, posto do Exército,
  faixas "DIRIJAM-SE AO SUL").
- **Legibilidade antes de tudo:** no *The Last of Us Part II*, **hera cobrindo = prédio fechado; hera arrancada =
  aberto**. "Tudo na arte do cenário tem função de leitura." *(LDB)* ➜ **Para nós:** um sinal visual único e
  consistente para prédio que dá para entrar (porta entreaberta + luz/lixo na frente) e para o que não dá (tábuas,
  portão de aço). Hoje ~76% dos prédios entram; o jogador precisa saber quais sem testar.
- Um "objeto herói" por área, não em qualquer lugar. *(LDB)*

### 3.5 Loot

- O loot tem 3 camadas: munição/armas, estado do jogador (vida, comida), progressão. O valor de um item depende do
  estado: com 99% de vida ninguém pega curativo de 25%. *(LDB)*
- **Migalhas:** itens vistos de longe puxam o jogador (~80%). Pôr recompensa no mirante atrai para ele. *(LDB)*
- **Item "de graça" no meio da arena parece armadilha.** *(LDB)*
- Orçamento de recompensa por trecho; o lugar possível é do designer, o que tem é sorteado. *(LDB + L4D)* ✅ É o que
  `mundo/loot_mundo.gd` faz (tabelas por móvel e local, sorteio guardado).

### 3.6 Ritmo e testes

- **Alternar altos e baixos**; começar calmo; o encontro mais intenso não precisa ser o último. *(LDB: Pacing)* (e o
  Diretor de IA da seção 2.1 faz isso sozinho.)
- **Medidas do jogador primeiro** (altura dos olhos, largura de porta ≥ 2× a do jogador, corredor ≥ 2×, altura do
  pulo). Fazer um "zoológico de medidas": um mapa de teste com toda porta, escada e janela. *(LDB: Metrics)*
- **Testar cedo e sempre**, de preferência com gente de fora, e registrar mapa de calor de mortes. *(LDB: Playtesting)*

---

## 4. Código e arquitetura

Fonte: *Game Programming Patterns* (Robert Nystrom) + boas práticas da Godot 4.3.

| Padrão | Para quê | Nós |
|---|---|---|
| **Pool de objetos** | Reusar em vez de criar/apagar (tiros, sangue, cápsulas, sons, corpos). Ao reusar, reinicializar tudo; ao devolver, soltar referências. Definir o que fazer quando esgota (ignorar, tirar o menos visível...). | ✅ em parte (infectados da horda); ➜ efeitos de tiro e sons |
| **Partição espacial** | Grade com células ≥ maior raio de busca; "quem está perto?" sem comparar todos com todos. | ✅ prédios, horda |
| **Dirty flag** | Recalcular só quando o dado de origem muda (peso do inventário, estatísticas). | ✅ em vários lugares |
| **Update method + escalonar** | Não pôr `_process` em cada coisa; um gerente com um laço; quem pensa caro, pensa a cada K quadros (`(i + quadro) % K == 0`). | ✅ infectados de longe |
| **Fila de eventos** | Juntar pedidos repetidos no mesmo quadro (vários tiros do mesmo som → um som mais alto) e não travar quem pediu. | ✅ 1.01: barulho para a IA (`vagos.gd` `_fila_barulho`) |
| **Observer (sinais)** | Para avisos raros ("morreu", "pegou item"); **não** emitir sinal por entidade por quadro; desconectar ao sair. | ✅ |
| **Estado** | `enum` + `match`, não texto; pilha para interrupções que voltam ao que era ("tropeçou → volta a caçar"). | ✅ |
| **Autoload** | Só para sistemas que cuidam dos próprios dados (config, conta, rede, música); um autoload não deve mexer nos dados de outro. | ✅ |

12 regras para o nosso código (adaptadas do relatório):
1. O que existe aos milhares é **dado** (arrays), não nó; vira nó só perto do jogador. ✅ horda, MultiMesh.
2. Nada de `_process` por entidade para simulação; um gerente por sistema.
3. Pensamento caro escalonado em baldes.
4. Uma grade espacial por tipo de consulta, guardando IDs, não nós.
5. Mundo estático em MultiMesh por bloco; só o interativo vira nó.
6. Pool para o que nasce e morre muito.
7. Quatro vias de comunicação: chamar para baixo, sinal para avisos raros, fila para muitos eventos por quadro,
   leitura direta dos arrays do gerente.
8. Dependências passadas pelo pai (`ligar(...)`), não procuradas. ✅ É o nosso padrão `ligar()`.
9. Valor derivado com dirty flag.
10. Estados como inteiros.
11. Higiene nos laços quentes: tipos, sem alocar Array por quadro, sem `get_nodes_in_group` por quadro.
12. Orçamento por sistema em ms e testes longos para vazamento de memória.

---

## 5. Rede (multijogador)

Fontes: Glenn Fiedler (*Gaffer on Games*), Gabriel Gambetta, documentação da Godot.

- **Interpolação de estados:** os outros são desenhados um pouco no passado, entre dois estados recebidos.
  **Atraso ≈ 3× o intervalo entre envios + 1–2 quadros de folga**, para aguentar 2 pacotes perdidos seguidos. A 10
  envios/s: ~350 ms; a 30: ~150 ms; a 60: ~85 ms. *(Fiedler)* ✅ Temos interpolação com `ATRASO`
  (`rede/jogador_remoto.gd`) e 15 envios/s (`rede/sessao_rede.gd`). ✅ 1.01: o atraso se adapta: 120 ms numa rede
  boa, sobe até 300 ms quando os pacotes chegam fora do ritmo (3 × o "jitter" medido); sem pacote novo, o boneco
  continua pela velocidade por até 0,2 s (e os infectados do cliente por até 0,15 s) em vez de parar seco.
- **Interpolação cúbica (Hermite) com velocidade** tira o "pulsar" da linear em taxas baixas. *(Fiedler)*
- **Predição do próprio jogador + reconciliação:** o cliente aplica a própria entrada na hora, guarda as não
  confirmadas e, quando o servidor responde, volta ao estado dele e reaplica o resto. *(Gambetta)* ⚠ Nós mandamos a
  **posição** (o cliente manda onde está), o que é simples mas deixa trapacear (teleporte). ➜ No mínimo, o host
  **validar**: recusar posição que andou mais que velocidade máxima × tempo + folga. *(Fiedler, Gambetta)*
- **Compensação de atraso no tiro:** o host "volta no tempo" para o instante que o atirador viu (histórico de ~1 s
  das posições), limitado (ex.: 200 ms). Efeito colateral aceito: "às vezes leva tiro logo depois de se esconder".
  *(Gambetta)*
- **Banda:** quantizar (posição em ~1 cm, giro em 8 bits ⇒ ~6 bytes por infectado), mandar só o que mudou, e **só o
  que está perto de cada jogador** (área de interesse), com **acumulador de prioridade** (quem não coube no pacote
  sobe na fila do próximo). *(Fiedler)*
- **Canais:** estado (posições) = não confiável, só o mais novo; eventos (dano, morte, pegar item, chat) = confiável,
  em canal separado para não travar o estado. Na Godot, o padrão do `@rpc` é não confiável. *(Fiedler, Godot)*
- Host é um **celular**: pode ir para segundo plano, esquentar, trocar de rede. *(inferência)* Planejar o que
  acontece quando o host cai.

---

## 6. Sensação de jogo e controles

Fontes: Steve Swink (*Game Feel*), guia de acessibilidade do Android. (As fontes de números de tremor de tela e
mira assistida não estavam acessíveis; esses valores ficam para testar jogando.)

- **"Jardim mágico":** um lugar de teste com paredes, objetos e alvos de vários tamanhos para afinar andar, mirar e
  atirar **antes** de fazer conteúdo; o momento a momento tem que ser bom sozinho. *(Swink)* ✅ O estande de tiro na
  base militar é isso.
- **Lista de sinais por acerto/morte** (movimento, imagem, som, vibração), ordenada pelo que mais importa; fazer os 2–3
  primeiros. "Polimento é um buraco sem fundo." *(Swink)* ✅ 1.01: imagem (o ✕, já existia), som (baque de acerto,
  mais seco na cabeça/abate) e vibração mais forte no abate.
- **Alvos de toque de pelo menos 48 dp**, com a área de toque maior que o desenho do botão. *(Android)* ✅ 1.01: a
  área de toque tem no mínimo 48 dp pelo dpi da tela e, quando duas se encostam, vale a mais perto
  (`jogador/controles.gd` `raio_toque`).
- **Nada só por gesto:** atirar, recarregar e mirar sempre com botão. *(Android)* ✅
- **Contraste:** texto ≥ 4,5:1 e ícones ≥ 3:1 contra o fundo; texto ≥ 12 sp. Cena de zumbi é poluída: pôr uma
  placa/contorno atrás. *(Android)*
- **Vibração** no acerto, na morte e na munição baixa, com opção de desligar. *(Android)* ✅ (opção Vibração).
- **Tremor de tela e "soco" de FOV** com opção de desligar (enjoo). *(Swink + inferência)*
- **Perfis de sensibilidade separados** por toque, controle e mouse. *(Swink)* ✅ (toque e mouse já são separados).

---

## 7. Plano de ação (por prioridade)

Impacto e esforço estimados por mim; cada item cita a seção acima. **Todos os 16 foram feitos na versão 1.00**
(o que mudou em cada um está no `LEIA-ME.txt`, bloco ATUALIZAÇÃO 1.00).

| # | O quê | Por quê | Esforço | Onde |
|---|---|---|---|---|
| 1 ✅ | **Diretor de IA** (intensidade, crescendo/pico/esfriando/alívio, hordas de trás a cada 90–180 s) | Maior ganho de jogabilidade: ritmo de tensão e alívio, o que fez o L4D ser rejogável (2.1) | Médio | novo `inimigos/diretor.gd` + `vagos.gd`/`horda.gd` |
| 2 ✅ | **Arremessar garrafa/tijolo** para distrair | Furtividade e estratégia; "tão valioso quanto uma arma" no TLOU (2.2) | Baixo | `inventario/`, `armas/`, `vagos.barulho` |
| 3 ✅ | **Estado "desconfiado"** (já existia desde a 0.65; 1.00: audição pelo estado) antes de perseguir (gemido, virar a cabeça) | O jogador entende o que vai acontecer (2.2) | Baixo | `inimigos/vago.gd` |
| 4 ✅ | **Sinal visual de prédio que dá para entrar** (portas de aço no térreo de quem não entra) | Legibilidade; o jogador não testa porta por porta (3.4) | Médio | `mundo/cidade.gd`/`fachadas.gd` |
| 5 ✅ | **Orçamento de infectados em ms** (menos reais quando o quadro pesa) | Estabilidade no celular (2.4) | Médio | `inimigos/vagos.gd` |
| 6 ✅ | **Validar no host** (feito como validação do DANO: distância, dano máximo, pedidos por segundo) | Anti-trapaça básica (5) | Baixo | `rede/sessao_rede.gd` |
| 7 ✅ | **Teste automático de desempenho** a cada versão | Não piorar sem perceber (1.1) | Baixo | `ferramentas/testes/` |
| 8 ✅ | Pré-aquecer os materiais que aparecem depois (tiro, sangue, explosão) na "Preparando a vista" | Engasgo no primeiro tiro (1.6) | Baixo | `main.gd`/`tela_carregamento.gd` |
| 9 ✅ | Fatiar "abrir prédio/local" (+ colisão sem nós; achado: móveis mudavam a cada abertura) durante o jogo | Engasgos andando pela cidade (1.12) | Médio | `mundo/interiores.gd`, `locais.gd` |
| 10 ✅ | Opção de **45 FPS** e **resolução dinâmica** (já existiam; 1.00: celular trava em 45 sozinho) | Calor e bateria em sessões longas (1.11) | Baixo/Médio | `menu/opcoes.gd`, `aplicar_opcoes.gd` |
| 11 ✅ | Mutados como **especiais raros** (escalam, saltam, estalo de dentes) | Fiel à lore e cria picos de tensão (2.6) | Alto | `inimigos/` (e decidir o padrão de velocidade) |
| 12 ✅ | Infectados de longe como **MultiMesh animado** (silhuetas-cartaz, não animação em textura) | Cidade cheia sem custo de IA (2.5) | Alto | novo sistema |
| 13 ✅ | Infectados **dormindo** em grupos dentro de prédios | Encontros furtivos variados (2.3) | Baixo | `vago.gd`, `interiores.gd` |
| 14 ✅ | `get_nodes_in_group` fora do `_process` | Pequeno ganho de CPU (1.8) | Baixo | `npc/hospitais.gd`, `jogador/sobrevivencia.gd` |
| 15 ✅ | HLOD: feito nos móveis dos interiores (a medição mostrou que o peso estava lá, não nas fachadas) | Menos triângulos de longe (0, 1.3, 1.13) | Médio | `mundo/fachadas.gd`, `cidade.gd` |
| 16 ✅ | Chunks com estado **preparado** (a cidade já fica toda na memória) + orçamento em **ms** + frente da câmera primeiro | Cruzar a borda do chunk sem engasgo (1.13) | Médio | `mundo/chunks.gd` |

**Segunda leva (1.01)**: o que ainda estava com ➜ nas seções acima.

| # | O quê | Resultado | Onde |
|---|---|---|---|
| 17 ✅ | **Vasculhar** depois de perder o jogador (2.2) | 2-3 lugares a mais perto, para o lado em que ele foi | `inimigos/vago.gd` |
| 18 ✖ | **Campo de fluxo** para contornar quarteirões (2.4) | Medido sem ganho e tirado (ver 2.4) | — |
| 19 ✅ | **Fila de barulhos** (4) | Barulhos juntos no mesmo quadro viram um | `inimigos/vagos.gd` |
| 20 ✅ | **Atraso da rede que se adapta** + seguir pela velocidade sem pacote (5) | 120-300 ms pelo jitter medido | `rede/jogador_remoto.gd`, `inimigos/vago.gd` |
| 21 ✅ | **Anisotropia ≤ 2x** no celular (1.4) | Qualquer que seja a opção | `menu/aplicar_opcoes.gd` |
| 22 ✅ | **Área de toque ≥ 48 dp** (6) | Pelo dpi da tela; o mais perto ganha | `jogador/controles.gd` |
| 23 ✅ | **Sinais de acerto** (6): som + vibração no abate | O ✕ já existia | `armas/armas.gd`, `armas/sons_armas.gd` |
| 24 ✅ | Item de arremesso **na mão** ao mirar | Era a limitação da 1.00 | `armas/arremesso.gd`, `jogador/modelo_sobrevivente.gd` |
| — | Conferidos sem mudança: transparências (capim/folhas já em recorte), sombras (só o sol) | | |
| — | Ficam para depois: validar a POSIÇÃO no host (falsos positivos com carro/teleporte do jogo), compressão dos pacotes dos infectados (a banda não é problema hoje), predição + reconciliação | | |

---

## 8. Fontes

**Otimização e Godot**
- [Godot 4.3: General optimization](https://docs.godotengine.org/en/4.3/tutorials/performance/general_optimization.html) · [CPU](https://docs.godotengine.org/en/4.3/tutorials/performance/cpu_optimization.html) · [GPU](https://docs.godotengine.org/en/4.3/tutorials/performance/gpu_optimization.html) · [3D performance](https://docs.godotengine.org/en/4.3/tutorials/performance/optimizing_3d_performance.html) · [MultiMesh](https://docs.godotengine.org/en/4.3/tutorials/performance/using_multimesh.html) · [Servers](https://docs.godotengine.org/en/4.3/tutorials/performance/using_servers.html) · [Thread-safe APIs](https://docs.godotengine.org/en/4.3/tutorials/performance/thread_safe_apis.html) · [Occlusion culling](https://docs.godotengine.org/en/4.3/tutorials/3d/occlusion_culling.html) · [Visibility ranges](https://docs.godotengine.org/en/4.3/tutorials/3d/visibility_ranges.html) · [Mesh LOD](https://docs.godotengine.org/en/4.3/tutorials/3d/mesh_lod.html) · [Static typing](https://docs.godotengine.org/en/4.3/tutorials/scripting/gdscript/static_typing.html) · [Pipeline compilations](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html)
- [Android: Optimize](https://developer.android.com/games/optimize) · [Frame pacing](https://developer.android.com/games/sdk/frame-pacing) · [ADPF](https://developer.android.com/games/optimize/adpf) · [Thermal](https://developer.android.com/games/optimize/adpf/thermal) · [Textures](https://developer.android.com/games/optimize/textures) · [Geometry](https://developer.android.com/games/optimize/geometry) · [Materials](https://developer.android.com/games/optimize/materials) · [Power](https://developer.android.com/games/optimize/power)
- [Arm Community: overhead of the driver (~500 chamadas)](https://community.arm.com/support-forums/f/graphics-gaming-and-vr-forum/48848/overhead-of-the-driver) · [Arm Mali best practices (anúncio)](https://developer.arm.com/community/arm-community-blogs/b/mobile-graphics-and-gaming-blog/posts/new-developer-guide-arm-mali-application-developer-best-practices)
- Streaming: [Epic: World Partition](https://dev.epicgames.com/documentation/en-us/unreal-engine/world-partition-in-unreal-engine) · [Epic: World Partition HLOD](https://dev.epicgames.com/documentation/en-us/unreal-engine/world-partition---hierarchical-level-of-detail-in-unreal-engine) · [Guerrilla: Streaming the World of Horizon Zero Dawn](https://www.guerrilla-games.com/read/Streaming-the-World-of-Horizon-Zero-Dawn) · [Advances in Real-Time Rendering 2017](https://advances.realtimerendering.com/s2017/index.html) · [zeux.io (Arseny Kapoulkine)](https://zeux.io/)
- [GameDev.net: por que a luneta PiP é cara](https://gamedev.net/forums/topic/717272-why-are-picture-in-picture-scopes-in-games-such-an-expensive-effect-they-seem-like-they-could-be-easily-optimised)

**IA e multidões**
- [Michael Booth, The AI Systems of Left 4 Dead (PDF)](https://steamcdn-a.akamaihd.net/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf) · [Valve publications](https://www.valvesoftware.com/en/publications)
- [Mark Botta, Infected AI in The Last of Us (Game AI Pro 2)](http://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter33_Infected_AI_in_The_Last_of_Us.pdf)
- [Graham Pentheny, Efficient Crowd Simulation for Mobile Games (Game AI Pro)](http://www.gameaipro.com/GameAIPro/GameAIPro_Chapter24_Efficient_Crowd_Simulation_for_Mobile_Games.pdf)
- [Robert Zubek, 1000 NPCs at 60 FPS (Game AI Pro 3)](http://www.gameaipro.com/GameAIPro3/GameAIPro3_Chapter34_1000_NPCs_at_60_FPS.pdf)
- [Behavior trees for AI: how they work (dev do Project Zomboid)](https://www.gamedeveloper.com/programming/behavior-trees-for-ai-how-they-work)
- [Epic: Significance Manager](https://dev.epicgames.com/documentation/en-us/unreal-engine/significance-manager-in-unreal-engine) · [Animation Budget Allocator](https://dev.epicgames.com/documentation/en-us/unreal-engine/animation-budget-allocator-in-unreal-engine)
- [GDC 2018: AI e Freak-O-System de Days Gone](https://gdconf.com/article/study-the-ai-and-freak-o-system-of-sony-s-days-gone-at-gdc-2018/)
- [GPU Gems 3, cap. 2: Animated Crowd Rendering](https://developer.nvidia.com/gpugems/gpugems3/part-i-geometry/chapter-2-animated-crowd-rendering) · [cap. 21: True Impostors](https://developer.nvidia.com/gpugems/gpugems3/part-iv-image-effects/chapter-21-true-impostors) · [Unity Animation Instancing](https://github.com/Unity-Technologies/Animation-Instancing)

**Level design**
- [The Level Design Book](https://book.leveldesignbook.com/) (layout, blockout, metrics, wayfinding, combat, encounter, cover, pacing, lighting, env-art, storytelling, estudos)
- [Don Carson: Environmental Storytelling](https://www.gamedeveloper.com/design/environmental-storytelling-creating-immersive-3d-worlds-using-lessons-learned-from-the-theme-park-industry)
- [80.lv: Dealing with navigation & players' behavior (Shaver)](https://80.lv/articles/dealing-with-navigation-players-behavior/)
- [Scott Rogers: lições da Disneylândia (resumo)](https://boingboing.net/2009/03/27/gamedesign-lessons-f.html)

**Código**
- [Game Programming Patterns](https://gameprogrammingpatterns.com/) (object pool, spatial partition, dirty flag, update method, event queue, data locality, observer, state, component, service locator)
- Godot 4.3 best practices: [Scene organization](https://docs.godotengine.org/en/4.3/tutorials/best_practices/scene_organization.html) · [Autoloads](https://docs.godotengine.org/en/4.3/tutorials/best_practices/autoloads_versus_internal_nodes.html) · [Node alternatives](https://docs.godotengine.org/en/4.3/tutorials/best_practices/node_alternatives.html) · [Notifications](https://docs.godotengine.org/en/4.3/tutorials/best_practices/godot_notifications.html) · [Data preferences](https://docs.godotengine.org/en/4.3/tutorials/best_practices/data_preferences.html)

**Rede**
- Glenn Fiedler: [What every programmer needs to know](https://gafferongames.com/post/what_every_programmer_needs_to_know_about_game_networking/) · [Snapshot interpolation](https://gafferongames.com/post/snapshot_interpolation/) · [Snapshot compression](https://gafferongames.com/post/snapshot_compression/) · [State synchronization](https://gafferongames.com/post/state_synchronization/)
- Gabriel Gambetta: [Client-server](https://www.gabrielgambetta.com/client-server-game-architecture.html) · [Prediction](https://www.gabrielgambetta.com/client-side-prediction-server-reconciliation.html) · [Entity interpolation](https://www.gabrielgambetta.com/entity-interpolation.html) · [Lag compensation](https://www.gabrielgambetta.com/lag-compensation.html)
- [Godot 4.3: High-level multiplayer](https://docs.godotengine.org/en/4.3/tutorials/networking/high_level_multiplayer.html)

**Sensação de jogo e acessibilidade**
- [Steve Swink: Game Feel, the secret ingredient](https://www.gamedeveloper.com/design/game-feel-the-secret-ingredient)
- [Android: Accessibility](https://developer.android.com/design/ui/mobile/guides/foundations/accessibility)
- [GDC 2018: Embracing Push Forward Combat in DOOM (resumo)](https://gdcvault.com/play/1024940/Embracing-Push-Forward-Combat-in)

**O que não foi possível ler** (bloqueado ou só para membros): o guia completo da Arm e o da Qualcomm, as páginas de
rede da Valve, o artigo de GOAP do F.E.A.R., a palestra da Saber sobre zumbis de *World War Z*, o artigo de
impostores octaédricos (Fortnite) e o "Art of Screenshake". Os números dessas áreas ficam para medir jogando.
