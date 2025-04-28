#!/bin/bash
set -e

# Verificar se é a primeira inicialização
if [ ! -f /etc/openvpn/easy-rsa/pki/ca.crt ]; then
    echo "Primeira inicialização - Configurando certificados..."
    cd /etc/openvpn/easy-rsa/
    
    # Configurar o Easy-RSA
    cat > vars << EOF
set_var EASYRSA_REQ_COUNTRY "BR"
set_var EASYRSA_REQ_PROVINCE "SP"
set_var EASYRSA_REQ_CITY "Sao Paulo"
set_var EASYRSA_REQ_ORG "Minha Organizacao"
set_var EASYRSA_REQ_EMAIL "admin@exemplo.com"
set_var EASYRSA_REQ_OU "TI"
set_var EASYRSA_KEY_SIZE 2048
set_var EASYRSA_ALGO rsa
set_var EASYRSA_CA_EXPIRE 3650
set_var EASYRSA_CERT_EXPIRE 3650
set_var EASYRSA_BATCH "yes"
set_var EASYRSA_REQ_CN "OpenVPN-CA"
EOF

    # Criar a CA e o certificado do servidor de forma não interativa
    ./easyrsa init-pki
    ./easyrsa --batch build-ca nopass
    ./easyrsa --batch gen-dh
    ./easyrsa --batch build-server-full server nopass
    
    # Criar o certificado de revogação
    ./easyrsa --batch gen-crl
    
    echo "Configuração inicial completa!"
fi

# Criar diretório para autenticação
mkdir -p /etc/openvpn/auth
touch /etc/openvpn/auth/passwords
chmod 600 /etc/openvpn/auth/passwords

# Tentar obter o endereço IP do host a partir da variável de ambiente
HOST_IP=${OVPN_SERVER_IP:-}

# Se HOST_IP não foi definido via ambiente, tentar outras formas de descobrir
if [ -z "$HOST_IP" ]; then
    # Tentar obter do arquivo /etc/hosts (em muitos casos, o hostname 'host.docker.internal' aponta para o host)
    HOST_DOCKER_INTERNAL=$(grep host.docker.internal /etc/hosts 2>/dev/null | awk '{print $1}')
    if [ -n "$HOST_DOCKER_INTERNAL" ]; then
        HOST_IP=$HOST_DOCKER_INTERNAL
    else
        # Obter o gateway da interface eth0 (geralmente o IP do host)
        HOST_IP=$(ip route | grep default | grep eth0 | awk '{print $3}' || echo "")
        if [ -z "$HOST_IP" ]; then
            # Último recurso - usar o primeiro IP de ens* ou eth*
            HOST_IP=$(ip -4 addr show scope global | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1 || echo "")
        fi
    fi
fi

# Se ainda não conseguimos descobrir o IP, usar o contêiner IP (não ideal, mas é um fallback)
if [ -z "$HOST_IP" ]; then
    HOST_IP=$(ip -4 addr show eth0 | grep -o 'inet [0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+' | awk '{print $2}')
    echo "AVISO: Não foi possível determinar o IP do host, usando IP do contêiner: $HOST_IP"
    echo "Para conectar remotamente, talvez seja necessário editar manualmente os arquivos .ovpn"
else
    echo "Usando IP do host para configurações de cliente: $HOST_IP"
fi

# Salvar o IP do host em um arquivo para ser usado pelo script gen-client.sh
echo "$HOST_IP" > /etc/openvpn/host_ip.txt

# Configurar iptables para permitir o tráfego VPN
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE

# Criar diretório para os arquivos de configuração dos clientes
mkdir -p /etc/openvpn/clients/export

# Garantir que o arquivo de senhas tenha as permissões corretas
chmod 644 /etc/openvpn/auth/passwords
chown nobody:nobody /etc/openvpn/auth/passwords

# Iniciar o OpenVPN
echo "Iniciando o OpenVPN..."
exec openvpn --config /etc/openvpn/server/server.conf
