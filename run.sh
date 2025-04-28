#!/bin/bash

# Script para iniciar o contêiner e criar usuários iniciais

# Detectar o IP do servidor host para uso nos arquivos de configuração dos clientes
HOST_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1" | head -n 1)
if [ -n "$HOST_IP" ]; then
    echo "Detectado IP do servidor: $HOST_IP"
    # Descomentando e configurando a variável OVPN_SERVER_IP no docker-compose.yml
    sed -i "s/#environment:/environment:/" docker-compose.yml
    sed -i "s/#  - OVPN_SERVER_IP=.*/  - OVPN_SERVER_IP=$HOST_IP/" docker-compose.yml
    echo "Configurado IP do servidor no docker-compose.yml"
else
    echo "AVISO: Não foi possível detectar automaticamente o IP do servidor."
    echo "Os arquivos .ovpn podem precisar ser editados manualmente após a geração."
fi

# Limpar contêineres anteriores
echo "Parando contêineres anteriores..."
docker compose down

# Remover volumes para um início limpo
echo "Removendo volumes antigos..."
docker volume rm openvpn-data 2>/dev/null || true

# Reconstruir a imagem do Docker para garantir as alterações
echo "Construindo a imagem Docker..."
docker compose build

# Construir e iniciar o contêiner
echo "Iniciando o contêiner OpenVPN..."
docker compose up -d

echo "Aguardando a inicialização do servidor OpenVPN..."
echo "Isso pode levar até 3 minutos na primeira execução..."

# Aguardar até que o contêiner esteja realmente rodando
CONTADOR=0
MAX_TENTATIVAS=30
while [ $CONTADOR -lt $MAX_TENTATIVAS ]; do
    ESTADO=$(docker inspect -f '{{.State.Status}}' openvpn-server 2>/dev/null)
    if [ "$ESTADO" = "running" ]; then
        echo "Contêiner OpenVPN está rodando!"
        # Aguardar mais um tempo para garantir que tudo está configurado
        sleep 10
        break
    fi
    echo "Aguardando o contêiner iniciar... (tentativa $CONTADOR de $MAX_TENTATIVAS)"
    sleep 10
    CONTADOR=$((CONTADOR+1))
done

if [ $CONTADOR -eq $MAX_TENTATIVAS ]; then
    echo "ERRO: O contêiner não iniciou corretamente após várias tentativas."
    echo "Verifique os logs com: docker logs openvpn-server"
    exit 1
fi

# Garantir que o arquivo de senhas tenha as permissões corretas
echo "Configurando permissões para o arquivo de senhas..."
docker exec openvpn-server chmod 644 /etc/openvpn/auth/passwords
docker exec openvpn-server chown nobody:nobody /etc/openvpn/auth/passwords

# Se conseguimos detectar o IP do host, enviá-lo para o contêiner
if [ -n "$HOST_IP" ]; then
    echo "Definindo IP do host no contêiner..."
    docker exec openvpn-server bash -c "echo '$HOST_IP' > /etc/openvpn/host_ip.txt"
fi

# Lista de usuários iniciais a serem criados com suas senhas
USUARIOS=("user1:senha1" "user2:senha2" "user3:senha3")

# Criar os usuários - sem o -it para evitar problemas em ambientes não interativos
echo "Criando usuários..."
docker exec openvpn-server /usr/local/bin/add-users.sh "${USUARIOS[@]}"

# Esperar um pouco para garantir que os arquivos de configuração foram gerados
sleep 5

# Verificar se os arquivos existem no contêiner
echo "Verificando arquivos dentro do contêiner..."
FILES_IN_CONTAINER=$(docker exec openvpn-server ls -la /etc/openvpn/clients/export/)
echo "$FILES_IN_CONTAINER"

# Copiar os arquivos de configuração para uma pasta local
echo "Copiando arquivos de configuração para ./clients"
mkdir -p ./clients
docker cp openvpn-server:/etc/openvpn/clients/export/. ./clients/

# Verificar se os arquivos foram copiados
if [ -z "$(ls -A ./clients 2>/dev/null)" ]; then
    echo "AVISO: Não foi possível copiar os arquivos de configuração."
    
    # Tente uma alternativa - copiar os arquivos individualmente
    echo "Tentando método alternativo de cópia..."
    USER_FILES=$(docker exec openvpn-server find /etc/openvpn/clients -name "*.ovpn")
    for FILE in $USER_FILES; do
        FILENAME=$(basename "$FILE")
        echo "Copiando $FILENAME..."
        docker cp "openvpn-server:$FILE" "./clients/$FILENAME"
    done
    
    if [ -z "$(ls -A ./clients 2>/dev/null)" ]; then
        echo "Ainda não foi possível copiar os arquivos. Verifique o contêiner manualmente."
    else
        echo "Arquivos copiados com sucesso usando método alternativo!"
    fi
else
    echo "Configuração concluída! Os arquivos .ovpn estão disponíveis no diretório ./clients"
fi

# Mostrar o status do contêiner
echo "Status do contêiner OpenVPN:"
docker ps -f name=openvpn-server

# Mostrar informações úteis para conexão
echo ""
echo "==== INFORMAÇÕES DO SERVIDOR OPENVPN ===="
if [ -n "$HOST_IP" ]; then
    echo "Endereço IP do servidor: $HOST_IP"
else
    echo "Endereço IP do servidor: <Não foi possível detectar automaticamente>"
    echo "Para conectar de fora da rede local, edite os arquivos .ovpn e altere a linha 'remote X.X.X.X 1194'"
fi
echo "Porta: 1194/UDP"
echo "Para conectar, use os arquivos .ovpn na pasta ./clients com qualquer cliente OpenVPN"
echo "Credenciais: user1/senha1, user2/senha2, user3/senha3"

# Exibir conteúdo das configurações geradas
echo ""
echo "Arquivo de configuração gerado (exemplo):"
if [ -f "./clients/user1.ovpn" ]; then
    grep "remote" "./clients/user1.ovpn"
fi
