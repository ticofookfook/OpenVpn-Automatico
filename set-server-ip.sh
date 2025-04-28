#!/bin/bash

# Script para definir explicitamente o IP do servidor OpenVPN

# Obter o IP da máquina host
HOST_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1" | head -n 1)

if [ -z "$HOST_IP" ]; then
    echo "Erro: Não foi possível detectar automaticamente o IP do servidor."
    echo "Por favor, insira o IP manualmente:"
    read -p "IP do servidor: " HOST_IP
    
    if [ -z "$HOST_IP" ]; then
        echo "Nenhum IP fornecido. Abortando."
        exit 1
    fi
fi

echo "Usando o IP do servidor: $HOST_IP"

# Definir o IP no contêiner
docker exec -it openvpn-server bash -c "echo '$HOST_IP' > /etc/openvpn/host_ip.txt"
echo "IP do servidor configurado com sucesso!"

# Perguntar se deseja recriar os arquivos de configuração dos clientes
read -p "Deseja recriar os arquivos de configuração dos clientes com o novo IP? (s/n): " RECREATE

if [ "$RECREATE" = "s" ] || [ "$RECREATE" = "S" ]; then
    echo "Recriando arquivos de configuração dos clientes..."
    
    # Obter a lista de usuários existentes
    USERS=$(docker exec openvpn-server cat /etc/openvpn/auth/passwords | cut -d: -f1 | sort | uniq)
    
    for USER in $USERS; do
        echo "Recriando configuração para $USER..."
        docker exec openvpn-server /usr/local/bin/gen-client.sh "$USER"
    done
    
    # Copiar os arquivos para a pasta local
    echo "Copiando arquivos de configuração para ./clients"
    mkdir -p ./clients
    docker cp openvpn-server:/etc/openvpn/clients/export/. ./clients/
    
    echo "Arquivos de configuração recriados com sucesso!"
    echo "Os novos arquivos .ovpn estão disponíveis no diretório ./clients"
fi

echo "Pronto! O servidor OpenVPN agora está configurado para usar o IP $HOST_IP"
