#!/usr/bin/env bash
# RODA OS TESTES AUTOMÁTICOS DO JOGO (0.74). Dentro da pasta DDA_Godot_Cidade:
#   GODOT=/caminho/do/godot ferramentas/testes/rodar.sh          (todos, menos rede)
#   GODOT=... ferramentas/testes/rodar.sh rede                     (dois jogos conectados: infectados perto do amigo)
#   GODOT=... ferramentas/testes/rodar.sh rede_carro               (dois jogos conectados: amigo dirigindo)
#   GODOT=... ferramentas/testes/rodar.sh rede_save                (salvar em rede: duas sessões seguidas)
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
else
	rodar "$alvo" 1
fi
rm -rf "$DADOS"
[ $falhou = 0 ] && echo "TUDO CERTO" || echo "ALGUM TESTE FALHOU"
exit $falhou
