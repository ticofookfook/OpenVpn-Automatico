#Alterar ip
No arquivo config/server.conf, você deve alterar a linha:
server 10.8.0.0 255.255.255.0
Para a faixa de IP que você deseja, por exemplo:
server 192.168.100.0 255.255.255.0

No arquivo scripts/startup.sh, você também precisa atualizar a regra de iptables para refletir a nova rede:
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
Para:
iptables -t nat -A POSTROUTING -s 192.168.100.0/24 -o eth0 -j MASQUERADE


Após fazer essas alterações, você deve recriar o contêiner para que as mudanças tenham efeito:
docker compose down
docker volume rm openvpn-data
./run.sh


#Criar Usuario
docker exec -it openvpn-server /usr/local/bin/add-users.sh "novousuario:novasenha"

docker cp openvpn-server:/etc/openvpn/clients/export/. ./clients/