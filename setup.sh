#!/usr/bin/env bash
set -e

# install soft
apt update && apt install -y curl openssl
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
systemctl enable xray

# set variables
xray x25519 > VLESS.TXT
UUID=$(xray uuid)
PRIVATE_KEY=$(grep 'Private' VLESS.TXT | awk '{print $3}')
PUBLIC_KEY=$(grep 'Public' VLESS.TXT | awk '{print $3}')
SS_PASS=$(openssl rand -base64 16)
SERVER_IP=$(curl -s ipinfo.io/ip)
read -p "Введите внешний IP этой VPS (или нажмите Enter, чтобы использовать ${SERVER_IP}): " SERVER_IP
SERVER_IP=${SERVER_IP:-$(curl -s ipinfo.io/ip)}
read -p "Введите адрес сервера для Reality (Или нажмите Enter, для дефолтного значения www.yahoo.com): " SNI
SNI=${SNI:-'www.yahoo.com'}
read -p "Введите порт для Shadowsocks (Или нажмите Enter, для дефолтного значения 8888): " SS_PORT
SS_PORT=${SS_PORT:-8888}
rm VLESS.TXT

# prepare config file
sed -i "s|{{SERVER_IP}}|${SERVER_IP}|g" ./config.json
sed -i "s|{{UUID}}|${UUID}|g" ./config.json
sed -i "s|{{PRIVATE_KEY}}|${PRIVATE_KEY}|g" ./config.json
sed -i "s|{{SS_PASS}}|${SS_PASS}|g" ./config.json
sed -i "s|{{SS_PORT}}|${SS_PORT}|g" ./config.json
sed -i "s|{{SNI}}|${SNI}|g" ./config.json
rm /usr/local/etc/xray/config.json
cp ./config.json /usr/local/etc/xray/config.json

# apply settings
systemctl restart xray
sleep 1
clear
echo "Статус Xray:"
systemctl status xray | grep Active

# Get connection strings
echo ""
echo "Данные для подключения сохранены в connect.txt:"
echo "VLESS:" > connect.txt
echo "vless://${UUID}@${SERVER_IP}:443/?encryption=none&type=tcp&sni=${SNI}&fp=chrome&security=reality&alpn=h2&flow=xtls-rprx-vision&pbk=${PRIVATE_KEY}&packetEncoding=xudp" >> connect.txt
echo "Shadowsocks-2022:" >> connect.txt
echo "ss://2022-blake3-aes-128-gcm:${SS_PASS}@${SERVER_IP}:${SS_PORT}" >> connect.txt
cat connect.txt
