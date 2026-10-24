#!/usr/bin/env bash
# RODA OS TESTES AUTOMÁTICOS DO JOGO (0.74). Dentro da pasta DDA_Godot_Cidade:
#   GODOT=/caminho/do/godot ferramentas/testes/rodar.sh          (todos, menos rede)
#   GODOT=... ferramentas/testes/rodar.sh rede                     (dois jogos conectados: infectados perto do amigo)
#   GODOT=... ferramentas/testes/rodar.sh rede_carro               (dois jogos conectados: amigo dirigindo)
#   GODOT=... ferramentas/testes/rodar.sh rede_save                (salvar em rede: duas sessões seguidas)
#   GODOT=... ferramentas/testes/rodar.sh rede_turn                (0.85: amigo entra pelo retransmissor TURN)
#   TURN_CF=1 (ou cai) GODOT=... rodar.sh rede_turn                 (0.88: senha pedida à "Cloudflare"; cai = vai para a reserva)
#   GODOT=... sudo ferramentas/testes/rodar.sh rede_nat            (0.86: ligação direta atrás de NAT de mentira)
#   GODOT=... ferramentas/testes/rodar.sh teste_agua               (só um)
# Sem monitor (servidor/CI) usa xvfb-run. Cada teste imprime "falhas: N"; o script termina com erro se algum falhar.
# Os testes usam uma pasta de dados própria (não mexem no seu jogo salvo).
set -u
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/../.."
DADOS="$(mktemp -d)"
TELA=()
if [ -z "${DISPLAY:-}" ] && command -v xvfb-run >/dev/null; then TELA=(xvfb-run -a -s "-screen 0 1280x720x24"); fi
falhou=0
rodar() {   # nome, com_tela(0/1)
	local saida
	if [ "$2" = 1 ]; then
		saida=$(XDG_DATA_HOME="$DADOS/$1" timeout 600 "${TELA[@]}" "$GODOT" --rendering-driver opengl3 -s "res://ferramentas/testes/$1.gd" 2>&1)
	else
		saida=$(XDG_DATA_HOME="$DADOS/$1" timeout 300 "$GODOT" --headless -s "res://ferramentas/testes/$1.gd" 2>&1)
	fi
	echo "$saida" | grep -E "FALHA|SCRIPT ERROR" | head -20
	local n
	n=$(echo "$saida" | grep -oE "falhas: [0-9]+" | tail -1 | grep -oE "[0-9]+")
	if [ -z "$n" ]; then echo "[$1] NÃO TERMINOU"; falhou=1; return; fi
	echo "[$1] falhas: $n"
	[ "$n" = 0 ] || falhou=1
}
rodar_turn() {   # 0.85: cliente TURN em GDScript contra o retransmissor de mentira (sem tela)
	TURN_FALSO_TEMPO=60 python3 ferramentas/testes/turn_falso.py 3612 teste segredo > /dev/null 2>&1 &
	local pid=$!
	sleep 1
	DDA_TURN_PORTA=3612 rodar teste_turn 0
	kill $pid 2>/dev/null
}
alvo="${1:-todos}"
if [ "$alvo" = rede_save ]; then
	for fase in 1 2; do
		FASE=$fase XDG_DATA_HOME="$DADOS/h" timeout 240 "${TELA[@]}" "$GODOT" --rendering-driver opengl3 -s res://ferramentas/testes/rede_save_host.gd > "$DADOS/host$fase.txt" 2>&1 &
		sleep 2
		FASE=$fase XDG_DATA_HOME="$DADOS/c" timeout 240 "${TELA[@]}" "$GODOT" --rendering-driver opengl3 -s res://ferramentas/testes/rede_save_cliente.gd > "$DADOS/cli$fase.txt" 2>&1
		wait
		grep -hE "HOST[12]:|SCRIPT ERROR" "$DADOS/host$fase.txt"
		grep -hE "CLI[12]:|SCRIPT ERROR" "$DADOS/cli$fase.txt"
	done
	grep -q "fome 3[23].*tábuas 2 · porta true · pego true" "$DADOS/host2.txt" && grep -q "fome 4[34].*galão 1 · porta do host true · pego do host true" "$DADOS/cli2.txt" || falhou=1
elif [ "$alvo" = rede_carro ]; then
	XDG_DATA_HOME="$DADOS/h" timeout 300 "${TELA[@]}" "$GODOT" --rendering-driver opengl3 -s res://ferramentas/testes/rede_carro_host.gd > "$DADOS/host.txt" 2>&1 &
	sleep 2
	XDG_DATA_HOME="$DADOS/c" timeout 300 "${TELA[@]}" "$GODOT" --rendering-driver opengl3 -s res://ferramentas/testes/rede_carro_cliente.gd > "$DADOS/cli.txt" 2>&1
	wait
	grep -E "HOST:|SCRIPT ERROR" "$DADOS/host.txt"
	grep -E "CLI:|SCRIPT ERROR" "$DADOS/cli.txt"
	grep -q "estacionado guardado true" "$DADOS/host.txt" && grep -q "andou [1-9]" "$DADOS/host.txt" || falhou=1
elif [ "$alvo" = rede_nat ]; then
	# 0.86: ligação direta atrás de roteadores de mentira (precisa de root + iproute2/iptables): cone e simétrico
	for tipo in cone simetrico; do
		GODOT="$GODOT" ferramentas/testes/rede_nat.sh $tipo | grep -E "CLI: via|amigo entrou|TUDO|ALGUM"
		GODOT="$GODOT" true
	done | tee "$DADOS/nat.txt"
	grep -q "TUDO CERTO (cone)" "$DADOS/nat.txt" && grep -q "TUDO CERTO (simetrico)" "$DADOS/nat.txt" || falhou=1
elif [ "$alvo" = rede_turn ]; then
	# 0.85: amigo entra pelo RETRANSMISSOR (TURN de mentira: ferramentas/testes/turn_falso.py, sem internet)
	TURN_FALSO_TEMPO=200 python3 ferramentas/testes/turn_falso.py 3611 teste segredo > "$DADOS/turn.txt" 2>&1 &
	pid_turn=$!
	sleep 1
	export DDA_TURN="127.0.0.1:3611:teste:segredo" DDA_ARQ="$DADOS/relay.txt"
	# 0.88: TURN_CF=1 pede a senha à API da Cloudflare de mentira (cf_falso.py); TURN_CF=cai: a API recusa e usa a reserva
	if [ -n "${TURN_CF:-}" ]; then
		python3 ferramentas/testes/cf_falso.py 8787 teste segredo > "$DADOS/cf.txt" 2>&1 &
		export DDA_CF_API="http://127.0.0.1:8787"
		[ "${TURN_CF:-}" = cai ] && DDA_TURN="127.0.0.1:3611:cf:errada;127.0.0.1:3611:teste:segredo" || DDA_TURN="127.0.0.1:3611:cf:abc"
	fi
	XDG_DATA_HOME="$DADOS/h" timeout 180 "${TELA[@]}" "$GODOT" --rendering-driver opengl3 -s res://ferramentas/testes/rede_turn_host.gd > "$DADOS/host.txt" 2>&1 &
	pid_host=$!
	sleep 2
	XDG_DATA_HOME="$DADOS/c" timeout 180 "${TELA[@]}" "$GODOT" --rendering-driver opengl3 -s res://ferramentas/testes/rede_turn_cliente.gd > "$DADOS/cli.txt" 2>&1
	wait $pid_host 2>/dev/null
	kill $pid_turn 2>/dev/null
	[ -n "${TURN_CF:-}" ] && { pkill -f cf_falso.py; grep -E "CF:" "$DADOS/cf.txt"; grep -q "CF: .*-> ok" "$DADOS/cf.txt" || [ "${TURN_CF:-}" = cai ] || falhou=1; }
	grep -E "HOST:|SCRIPT ERROR" "$DADOS/host.txt"
	grep -E "CLI:|SCRIPT ERROR" "$DADOS/cli.txt"
	grep -E "ALLOCATE|PERMISS|CANAL|SENHA" "$DADOS/turn.txt" | sort | uniq -c | head
	grep -q "amigo pelo retransmissor: true" "$DADOS/host.txt" && grep -q "CLI: ligado true · semente 77" "$DADOS/cli.txt" && grep -q "vê o host true" "$DADOS/cli.txt" || falhou=1
elif [ "$alvo" = rede ]; then
	XDG_DATA_HOME="$DADOS/h" timeout 240 "${TELA[@]}" "$GODOT" --rendering-driver opengl3 -s res://ferramentas/testes/rede_amigo_host.gd > "$DADOS/host.txt" 2>&1 &
	sleep 2
	XDG_DATA_HOME="$DADOS/c" timeout 240 "${TELA[@]}" "$GODOT" --rendering-driver opengl3 -s res://ferramentas/testes/rede_amigo_cliente.gd > "$DADOS/cli.txt" 2>&1
	wait
	grep -E "HOST:|SCRIPT ERROR" "$DADOS/host.txt"
	grep -E "CLI:|SCRIPT ERROR" "$DADOS/cli.txt"
	grep -q "com física: [1-9]" "$DADOS/host.txt" && grep -q "cópias de infectados perto: [1-9]" "$DADOS/cli.txt" || falhou=1
elif [ "$alvo" = todos ]; then
	rodar compilar_tudo 0
	rodar teste_loot_volta 0
	rodar teste_jogo 1
	rodar teste_agua 1
	rodar teste_portas 1
	rodar teste_tiro_locais 1
	rodar teste_veiculos 1
	rodar teste_luz_locais 1
	rodar teste_locais_novos 1
	rodar teste_infectados_colisao 1
	rodar teste_infectados_paredes 1
	rodar teste_escadas_moveis 1
	rodar teste_camera_paredes 1
	rodar teste_ombro 1
	rodar teste_bunkers 1
	rodar teste_graficos 1
	rodar_turn
else
	rodar "$alvo" 1
fi
rm -rf "$DADOS"
[ $falhou = 0 ] && echo "TUDO CERTO" || echo "ALGUM TESTE FALHOU"
exit $falhou
