#!/bin/bash
# Script para verificar usuário e senha
PASSFILE="/etc/openvpn/auth/passwords"
USERNAME="$username"
PASSWORD="$password"

if grep -q "^$USERNAME:$PASSWORD$" "$PASSFILE"; then
  exit 0
else
  exit 1
fi
