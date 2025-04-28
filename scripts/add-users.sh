#!/bin/bash
set -e

# Verificar se tem argumentos
if [ $# -eq 0 ]; then
    echo "Uso: $0 usuario1:senha1 [usuario2:senha2] [usuario3:senha3] ..."
    exit 1
fi

# Diretório para exportar os arquivos de configuração dos clientes 
EXPORT_DIR="/etc/openvpn/clients/export"
mkdir -p $EXPORT_DIR

# Arquivo de senhas
PASSWORD_FILE="/etc/openvpn/auth/passwords"
mkdir -p /etc/openvpn/auth

# Criar configuração para cada usuário especificado
for USER_PASS in "$@"
do
    # Separar usuário e senha
    USER=$(echo $USER_PASS | cut -d: -f1)
    PASS=$(echo $USER_PASS | cut -d: -f2)
    
    if [ -z "$USER" ] || [ -z "$PASS" ]; then
        echo "ERRO: Formato inválido para $USER_PASS. Use o formato usuario:senha"
        continue
    fi
    
    echo "Gerando configuração para $USER..."
    
    # Adicionar usuário e senha ao arquivo de senhas
    echo "$USER:$PASS" >> $PASSWORD_FILE
    
    # Chamar o script de geração de cliente
    /usr/local/bin/gen-client.sh $USER
    
    # Copiar a configuração para o diretório de exportação
    cp /etc/openvpn/clients/$USER/$USER.ovpn $EXPORT_DIR/
    
    echo "Configuração para $USER concluída. Arquivo disponível em: $EXPORT_DIR/$USER.ovpn"
done

echo "Todos os arquivos de configuração foram gerados com sucesso!"
