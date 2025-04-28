FROM alpine:latest

# Instalação de pacotes necessários
RUN apk add --no-cache openvpn easy-rsa bash openssl iptables openvpn-auth-pam && \
    mkdir -p /etc/openvpn/server && \
    mkdir -p /etc/openvpn/clients && \
    mkdir -p /etc/openvpn/easy-rsa && \
    mkdir -p /var/log/openvpn

# Copiar configurações e scripts
COPY ./config/server.conf /etc/openvpn/server/
COPY ./scripts/ /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh

# Inicializar o Easy-RSA
RUN mkdir -p /etc/openvpn/easy-rsa/keys && \
    cp -r /usr/share/easy-rsa/* /etc/openvpn/easy-rsa/

# Expor a porta do OpenVPN
EXPOSE 1194/udp

# Volume para persistência de dados
VOLUME ["/etc/openvpn"]

# Comando para iniciar o serviço
CMD ["/usr/local/bin/startup.sh"]
