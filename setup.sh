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
while true; do
  SS_PASS=$(openssl rand -base64 16)
  if [[ "$SS_PASS" != *"/"* && "$SS_PASS" != *"+"* ]]; then
    break
  fi
done
SERVER_IP=$(curl -s ipinfo.io/ip)
clear
read -p "Введите внешний IP этой VPS (или нажмите Enter, чтобы использовать ${SERVER_IP}): " SERVER_IP
SERVER_IP=${SERVER_IP:-$(curl -s ipinfo.io/ip)}
read -p "Введите адрес сервера для Reality (Или нажмите Enter, для дефолтного значения www.yahoo.com): " SNI
SNI=${SNI:-'www.yahoo.com'}
read -p "Введите порт для Shadowsocks (Или нажмите Enter, для дефолтного значения 8888): " SS_PORT
SS_PORT=${SS_PORT:-8888}
rm VLESS.TXT

# prepare config file
cp ./config.json.template /usr/local/etc/xray/config.json
sed -i "s|SERVER_IP|${SERVER_IP}|g" /usr/local/etc/xray/config.json
sed -i "s|UUID|${UUID}|g" /usr/local/etc/xray/config.json
sed -i "s|PRIVATE_KEY|${PRIVATE_KEY}|g" /usr/local/etc/xray/config.json
sed -i "s|SS_PASS|${SS_PASS}|g" /usr/local/etc/xray/config.json
sed -i "s|SS_PORT|${SS_PORT}|g" /usr/local/etc/xray/config.json
sed -i "s|SNI|${SNI}|g" /usr/local/etc/xray/config.json

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
echo "vless://${UUID}@${SERVER_IP}:443/?encryption=none&type=tcp&sni=${SNI}&fp=chrome&security=reality&alpn=h2&flow=xtls-rprx-vision&pbk=${PUBLIC_KEY}&packetEncoding=xudp" >> connect.txt
echo "Shadowsocks-2022:" >> connect.txt
echo "ss://2022-blake3-aes-128-gcm:${SS_PASS}@${SERVER_IP}:${SS_PORT}" >> connect.txt
cat connect.txt
