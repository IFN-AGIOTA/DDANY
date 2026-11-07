#!/bin/bash
# DIAS DE UM APOCALIPSE · SEU RETRANSMISSOR PRÓPRIO (coturn) NA ORACLE CLOUD (Always Free) · 0.87
# Cole este arquivo INTEIRO em "Script de inicialização" (cloud-init) ao criar a máquina Ubuntu (passo a passo no
# LEIA-ME_ORACLE.txt). Ele roda sozinho na 1ª vez que a máquina liga: instala o coturn, abre as portas do firewall
# da própria máquina e deixa o retransmissor ligado (volta sozinho se a máquina reiniciar).
# O jogo usa este servidor primeiro e a Metered de reserva (rede/turn.cfg [turn_proprio]).
USUARIO="dda"
SENHA="__SENHA__"                 # a mesma que vai em rede/turn.cfg [turn_proprio] senha
PORTA=3478

export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q coturn iptables-persistent curl

IP_INT=$(hostname -I | awk '{print $1}')
IP_PUB=$(curl -s --max-time 10 https://api.ipify.org || curl -s --max-time 10 https://ifconfig.me)

cat > /etc/turnserver.conf <<CONF
# gerado por instalar_turn.sh (Dias de um Apocalipse)
listening-port=$PORTA
listening-ip=$IP_INT
relay-ip=$IP_INT
external-ip=$IP_PUB/$IP_INT
realm=dda
lt-cred-mech
user=$USUARIO:$SENHA
fingerprint
no-tls
no-dtls
no-cli
min-port=49152
max-port=65535
# segurança: o retransmissor só leva dados para a internet (nunca para a rede interna da Oracle)
no-multicast-peers
denied-peer-ip=0.0.0.0-0.255.255.255
denied-peer-ip=10.0.0.0-10.255.255.255
denied-peer-ip=100.64.0.0-100.127.255.255
denied-peer-ip=127.0.0.0-127.255.255.255
denied-peer-ip=169.254.0.0-169.254.255.255
denied-peer-ip=172.16.0.0-172.31.255.255
denied-peer-ip=192.168.0.0-192.168.255.255
# limites (a máquina grátis aguenta folgado umas 10 partidas ao mesmo tempo)
total-quota=60
user-quota=60
stale-nonce=600
log-file=/var/log/turnserver.log
simple-log
CONF

sed -i 's/^#\?TURNSERVER_ENABLED=.*/TURNSERVER_ENABLED=1/' /etc/default/coturn 2>/dev/null || true

# a imagem Ubuntu da Oracle bloqueia tudo menos o SSH no firewall da própria máquina: libera o retransmissor
iptables -I INPUT 1 -p udp --dport $PORTA -j ACCEPT
iptables -I INPUT 1 -p tcp --dport $PORTA -j ACCEPT
iptables -I INPUT 1 -p udp --dport 49152:65535 -j ACCEPT
netfilter-persistent save

systemctl enable coturn
systemctl restart coturn
echo "turn:$IP_PUB:$PORTA (usuario $USUARIO)" > /root/DDA_RETRANSMISSOR.txt
