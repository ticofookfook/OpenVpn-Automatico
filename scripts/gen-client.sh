#!/bin/bash
set -e

if [ $# -ne 1 ]; then
    echo "Uso: $0 NOME_CLIENTE"
    exit 1
fi

CLIENT=$1
OUTPUT_DIR="/etc/openvpn/clients"
EASYRSA_DIR="/etc/openvpn/easy-rsa"

# Buscamos primeiro o IP do host a partir do arquivo de ambiente
# Este arquivo será criado pelo script de inicialização
HOST_IP_FILE="/etc/openvpn/host_ip.txt"
if [ -f "$HOST_IP_FILE" ]; then
    HOST_IP=$(cat "$HOST_IP_FILE")
    echo "Usando IP do host obtido do arquivo: $HOST_IP"
    SERVER_IP=$HOST_IP
else
    # Método alternativo - tentar detectar a rede do host
    # Em muitas configurações, o gateway padrão da interface eth0 é o host
    GATEWAY_IP=$(ip route | grep default | grep eth0 | awk '{print $3}')
    if [ -n "$GATEWAY_IP" ]; then
        echo "Usando IP do gateway como servidor: $GATEWAY_IP"
        SERVER_IP=$GATEWAY_IP
    else
        # Obter o IP do servidor contêiner (fallback)
        SERVER_IP=$(ip addr show eth0 | grep -o 'inet [0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+' | awk '{print $2}')
        
        # Verificar se o IP foi obtido corretamente, senão usar o IP da interface docker0
        if [ -z "$SERVER_IP" ]; then
            echo "IP não encontrado em eth0, tentando docker0..."
            SERVER_IP=$(ip addr show docker0 | grep -o 'inet [0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+' | awk '{print $2}')
            
            # Se ainda não encontrar, usar um IP padrão
            if [ -z "$SERVER_IP" ]; then
                echo "IP não encontrado, usando IP padrão..."
                SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "10.8.0.1")
            fi
        fi
        
        echo "AVISO: Não foi possível determinar o IP do host. Usando IP do contêiner: $SERVER_IP"
        echo "Para conectar de fora do servidor, você precisará editar manualmente o arquivo .ovpn"
    fi
fi

echo "Usando o IP do servidor: $SERVER_IP"

# Criar certificado do cliente
cd $EASYRSA_DIR
./easyrsa --batch build-client-full $CLIENT nopass

# Criar diretório para o cliente se não existir
mkdir -p $OUTPUT_DIR/$CLIENT
# Também criar diretório de exportação
mkdir -p $OUTPUT_DIR/export

# Criar arquivo de configuração do cliente
cat > $OUTPUT_DIR/$CLIENT/$CLIENT.ovpn << EOF
client
dev tun
proto udp
remote $SERVER_IP 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
auth SHA256
verb 3
mute 20
auth-user-pass

<ca>
$(cat $EASYRSA_DIR/pki/ca.crt)
</ca>
<cert>
$(cat $EASYRSA_DIR/pki/issued/$CLIENT.crt)
</cert>
<key>
$(cat $EASYRSA_DIR/pki/private/$CLIENT.key)
</key>
EOF

# Copiar também para o diretório de exportação
cp $OUTPUT_DIR/$CLIENT/$CLIENT.ovpn $OUTPUT_DIR/export/

echo "Arquivo de configuração do cliente $CLIENT criado em $OUTPUT_DIR/$CLIENT/$CLIENT.ovpn"
echo "Uma cópia foi salva em $OUTPUT_DIR/export/$CLIENT.ovpn"
