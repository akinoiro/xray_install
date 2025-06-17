#!/usr/bin/env bash

# install soft
apt update && apt install -y curl openssl
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
systemctl enable xray
systemctl stop xray

# set variables
UUID=$(xray uuid)
X25519_OUTPUT=$(xray x25519)
PRIVATE_KEY=$(echo "$X25519_OUTPUT" | grep 'Private' | awk '{print $3}')
PUBLIC_KEY=$(echo "$X25519_OUTPUT" | grep 'Public' | awk '{print $3}')
while true; do
  SS_PASS=$(openssl rand -base64 16)
  if [[ "$SS_PASS" != *"/"* && "$SS_PASS" != *"+"* ]]; then
    break
  fi
done
PUBLIC_IP=$(curl -s ipinfo.io/ip)
clear
while true; do
  read -p "Введи внешний IP этого сервера (или нажми Enter, чтобы использовать ${PUBLIC_IP}): " SERVER_IP
  SERVER_IP=${SERVER_IP:-${PUBLIC_IP}}
  if ip a | grep -q "$SERVER_IP"; then
    break
  else
    echo "Ошибка: адрес не назначен ни на один сетевой интерфейс."
  fi
done
echo
while true; do
  read -p "Введи порт для VLESS (или нажми Enter, чтобы использовать рекомендуемый 443): " VLESS_PORT
  VLESS_PORT=${VLESS_PORT:-443}
  if ! [[ $VLESS_PORT =~ ^[0-9]+$ ]]; then
    echo "Ошибка: необходимо указать число."
    continue
  fi
  if ss -tln | grep -q ":$VLESS_PORT "; then
    echo "Ошибка: порт занят, укажи другой."
    continue
  fi
  break
done
echo
while true; do
  read -p "Введи адрес маскировочного домена для Reality (или нажми Enter, чтобы использовать www.yahoo.com): " SNI
  SNI=${SNI:-'www.yahoo.com'}
  OPENSSL_OUTPUT=$(timeout 3 openssl s_client -connect "$SNI":443 -brief 2>&1)
  if ! echo "$OPENSSL_OUTPUT" | grep -q "TLSv1.3"; then
    echo "Ошибка: указанный сервер должен поддерживать TLSv1.3, попробуй другой."
    continue
  fi
  break
done
echo
while true; do
  read -p "Введи порт для Shadowsocks (или нажми Enter, чтобы использовать 8888): " SS_PORT
  SS_PORT=${SS_PORT:-8888}
  if ! [[ $SS_PORT =~ ^[0-9]+$ ]]; then
    echo "Ошибка: необходимо указать число."
    continue
  fi
  if ss -tln | grep -q ":$SS_PORT "; then
    echo "Ошибка: порт занят, укажи другой."
    continue
  fi
  break
done

# prepare config file
cp ./config.json.template /usr/local/etc/xray/config.json
sed -i "s|SERVER_IP|${SERVER_IP}|g" /usr/local/etc/xray/config.json
sed -i "s|VLESS_PORT|${VLESS_PORT}|g" /usr/local/etc/xray/config.json
sed -i "s|UUID|${UUID}|g" /usr/local/etc/xray/config.json
sed -i "s|PRIVATE_KEY|${PRIVATE_KEY}|g" /usr/local/etc/xray/config.json
sed -i "s|SS_PASS|${SS_PASS}|g" /usr/local/etc/xray/config.json
sed -i "s|SS_PORT|${SS_PORT}|g" /usr/local/etc/xray/config.json
sed -i "s|SNI|${SNI}|g" /usr/local/etc/xray/config.json

# apply settings
systemctl restart xray
sleep 1
echo
if systemctl status xray | grep -q active; then
  echo "Xray статус:"
  systemctl status xray | grep Active
else
  echo "Ошибка: служба не запустилась. Попробуй указать другие домены или порты или используй предложенные значения"
  exit 1
fi

# Get connection strings
echo
echo "========================================"
echo "Строки подключения сохранены в connect.txt:"
echo
echo "VLESS:" > connect.txt
echo "vless://${UUID}@${SERVER_IP}:${VLESS_PORT}/?encryption=none&type=tcp&sni=${SNI}&fp=chrome&security=reality&alpn=h2&flow=xtls-rprx-vision&pbk=${PUBLIC_KEY}&packetEncoding=xudp" >> connect.txt
echo >> connect.txt
echo "Shadowsocks-2022:" >> connect.txt
echo "ss://2022-blake3-aes-128-gcm:${SS_PASS}@${SERVER_IP}:${SS_PORT}" >> connect.txt
cat connect.txt
echo
echo "========================================"
echo "Используй vpn-клиент Hiddify - https://github.com/hiddify/hiddify-app"
