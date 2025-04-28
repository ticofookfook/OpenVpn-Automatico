# Docker OpenVPN Automatizado

Este projeto fornece uma solução Docker automatizada para implementar um servidor OpenVPN e gerenciar usuários de forma simples, com suporte a autenticação por certificado + usuário/senha.

## Requisitos

- Docker
- Docker Compose

## Funcionalidades

- Configuração automatizada do servidor OpenVPN
- Detecção automática do IP externo do servidor
- Criação de usuários com autenticação dupla (certificado + senha)
- Geração automática de arquivos de configuração (.ovpn) para clientes
- Rede VPN isolada (10.8.0.0/24)
- Redirecionamento de tráfego para a VPN

## Configuração Inicial

1. Clone este repositório para o seu servidor:
   ```bash
   git clone https://seu-repositorio/openvpn.git
   cd openvpn
   ```

2. Torne os scripts executáveis:
   ```bash
   chmod +x run.sh set-server-ip.sh
   ```

3. Execute o script de inicialização:
   ```bash
   ./run.sh
   ```

   Este script irá:
   - Detectar automaticamente o IP do seu servidor
   - Configurar o contêiner Docker
   - Gerar certificados e chaves necessários
   - Criar usuários iniciais (user1, user2, user3)
   - Gerar arquivos de configuração (.ovpn) para os clientes

4. Os arquivos de configuração dos clientes estarão disponíveis no diretório `./clients/`

## Gerenciamento de Usuários

### Adicionar Novos Usuários

Para adicionar novos usuários e gerar seus arquivos de configuração:

```bash
docker exec openvpn-server /usr/local/bin/add-users.sh "usuario1:senha1" "usuario2:senha2"
```

Os arquivos de configuração (.ovpn) serão gerados automaticamente no caminho:
`/etc/openvpn/clients/export/` dentro do contêiner.

### Acessar os Arquivos de Configuração

Para copiar os arquivos de configuração do contêiner para o host:

```bash
docker cp openvpn-server:/etc/openvpn/clients/export/. ./clients/
```

### Configurar Manualmente o IP do Servidor

Se o script não conseguir detectar automaticamente o IP correto do servidor, ou se você precisar alterar o IP usado nos arquivos de configuração dos clientes, utilize o script:

```bash
./set-server-ip.sh
```

Este script permite definir explicitamente o IP do servidor e regenerar os arquivos de configuração dos clientes.

## Conectando ao Servidor

### Cliente Linux

1. Instale o cliente OpenVPN:
   ```bash
   sudo apt update
   sudo apt install openvpn
   ```

2. Copie o arquivo .ovpn para o cliente e conecte:
   ```bash
   sudo openvpn --config cliente.ovpn
   ```

3. Quando solicitado, digite o nome de usuário e senha configurados.

### Cliente Windows

1. Instale o [cliente OpenVPN para Windows](https://openvpn.net/client-connect-vpn-for-windows/)
2. Importe o arquivo .ovpn
3. Quando solicitado, digite o nome de usuário e senha configurados.

### Cliente Android/iOS

1. Instale o aplicativo OpenVPN Connect
2. Importe o arquivo .ovpn
3. Quando solicitado, digite o nome de usuário e senha configurados.

## Solução de Problemas

### IP Incorreto nos Arquivos de Configuração

Se os clientes não conseguirem se conectar, pode ser necessário ajustar o endereço IP no arquivo .ovpn:

1. Verifique o IP correto do servidor:
   ```bash
   ip addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1"
   ```

2. Use o script `set-server-ip.sh` para regenerar os arquivos com o IP correto:
   ```bash
   ./set-server-ip.sh
   ```

### Problemas de Autenticação

Se ocorrerem problemas de autenticação, verifique as permissões do arquivo de senhas:

```bash
docker exec openvpn-server chmod 644 /etc/openvpn/auth/passwords
docker exec openvpn-server chown nobody:nobody /etc/openvpn/auth/passwords
```

## Estrutura do Projeto

- `config/server.conf`: Configuração do servidor OpenVPN
- `scripts/startup.sh`: Script de inicialização do servidor
- `scripts/add-users.sh`: Script para adicionar usuários
- `scripts/gen-client.sh`: Script para gerar arquivos de configuração de clientes
- `scripts/checkpw.sh`: Script para verificação de senhas
- `docker-compose.yml`: Configuração do Docker Compose
- `Dockerfile`: Imagem Docker para o servidor
- `run.sh`: Script principal para iniciar o projeto
- `set-server-ip.sh`: Script para configurar manualmente o IP do servidor

## Segurança

- Autenticação dupla: certificado + usuário/senha
- Os certificados e chaves são armazenados no volume Docker `openvpn-data`
- Algoritmos de criptografia fortes (AES-256-GCM, SHA256)
- Permissões cuidadosamente configuradas para os arquivos sensíveis

## Notas

- A primeira inicialização pode levar alguns minutos para gerar as chaves e certificados
- O servidor utiliza a porta UDP 1194 por padrão; certifique-se de que esta porta está liberada no seu firewall
- Para conectar de fora da sua rede local, configure o encaminhamento de porta no seu roteador para a porta 1194/UDP
