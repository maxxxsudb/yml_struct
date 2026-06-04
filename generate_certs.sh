#!/bin/bash

# Отключаем автоконвертацию путей в Git Bash на Windows
export MSYS_NO_PATHCONV=1

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

DIR_WEBHOOK="dev-ccs-vault-webhook-webhook-tls"
DIR_VAULT="ccs-vault-tls"
DIR_NEW=".new"

OLD_TLS_CRT="$DIR_WEBHOOK/tls.crt"
OLD_SERVER_CRT="$DIR_VAULT/server.crt"

echo -e "${YELLOW}=== Генератор сертификатов (Универсальный парсер) ===${NC}"

if [ ! -f "$OLD_TLS_CRT" ]; then echo -e "${RED}[ОШИБКА] Не найден $OLD_TLS_CRT${NC}"; exit 1; fi
if [ ! -f "$OLD_SERVER_CRT" ]; then echo -e "${RED}[ОШИБКА] Не найден $OLD_SERVER_CRT${NC}"; exit 1; fi

echo "Парсим старые сертификаты..."

# Отключаем тихое убийство скрипта, чтобы видеть реальные проблемы
set +e 

# 1. Извлекаем Issuer
RAW_ISSUER=$(openssl x509 -in "$OLD_SERVER_CRT" -noout -issuer 2>/dev/null | sed 's/^issuer=//' | sed 's/^[ \t]*//')
if [[ "$RAW_ISSUER" != /* ]]; then
    CLEAN_SUBJ=$(echo "$RAW_ISSUER" | sed 's/[ \t]*=[ \t]*/=/g' | sed 's/, /\//g')
    CA_SUBJ="/$CLEAN_SUBJ"
else
    CA_SUBJ="$RAW_ISSUER"
fi

# 2. Парсим CN
CN_VAULT=$(openssl x509 -in "$OLD_SERVER_CRT" -noout -subject 2>/dev/null | sed -n 's/.*CN[ =]*\([^,]*\).*/\1/p' | sed 's/^[ \t]*//')
CN_WEBHOOK=$(openssl x509 -in "$OLD_TLS_CRT" -noout -subject 2>/dev/null | sed -n 's/.*CN[ =]*\([^,]*\).*/\1/p' | sed 's/^[ \t]*//')

# 3. Парсим SAN через универсальный текстовый вывод (работает везде)
SAN_VAULT=$(openssl x509 -in "$OLD_SERVER_CRT" -noout -text 2>/dev/null | awk '/X509v3 Subject Alternative Name/ {getline; print}' | sed 's/IP Address:/IP:/g' | sed 's/^[ \t]*//' | tr -d '\r' | tr -d '\n')
SAN_WEBHOOK=$(openssl x509 -in "$OLD_TLS_CRT" -noout -text 2>/dev/null | awk '/X509v3 Subject Alternative Name/ {getline; print}' | sed 's/IP Address:/IP:/g' | sed 's/^[ \t]*//' | tr -d '\r' | tr -d '\n')

# Включаем строгий режим обратно для генерации файлов
set -e

echo -e "----------------------------------------"
echo -e "${GREEN}Итоговый Subject CA:${NC} '$CA_SUBJ'"
echo -e "${GREEN}Vault CN:${NC} '$CN_VAULT'"
echo -e "${GREEN}Vault SAN:${NC} '$SAN_VAULT'"
echo -e "${GREEN}Webhook CN:${NC} '$CN_WEBHOOK'"
echo -e "${GREEN}Webhook SAN:${NC} '$SAN_WEBHOOK'"
echo -e "----------------------------------------"

# Защита от создания кривых сертификатов
if [ -z "$SAN_VAULT" ] || [ -z "$SAN_WEBHOOK" ]; then
    echo -e "${RED}[КРИТИЧЕСКАЯ ОШИБКА] Домены (SAN) не извлеклись! Генерация остановлена.${NC}"
    exit 1
fi

rm -rf "$DIR_NEW"
mkdir -p "$DIR_NEW"
cd "$DIR_NEW"

trap 'rm -f server.cnf webhook.cnf server.csr tls.csr ca.srl' EXIT

echo "1/3 Генерация Root CA (10 лет)..."
openssl genrsa -out ca.key 2048
openssl req -x509 -new -nodes -key ca.key -subj "$CA_SUBJ" -days 3650 -out ca.crt

echo "2/3 Генерация Vault server.crt..."
cat <<EOF > server.cnf
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
prompt = no
[req_distinguished_name]
CN = $CN_VAULT
[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment, serverAuth
subjectAltName = $SAN_VAULT
EOF

openssl genrsa -out server.key 2048
openssl req -new -key server.key -config server.cnf -out server.csr
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 3650 -extfile server.cnf -extensions v3_req

echo "3/3 Генерация Webhook tls.crt..."
cat <<EOF > webhook.cnf
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
prompt = no
[req_distinguished_name]
CN = $CN_WEBHOOK
[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment, serverAuth
subjectAltName = $SAN_WEBHOOK
EOF

openssl genrsa -out tls.key 2048
openssl req -new -key tls.key -config webhook.cnf -out tls.csr
openssl x509 -req -in tls.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out tls.crt -days 3650 -extfile webhook.cnf -extensions v3_req

cd ..
echo -e "${GREEN}[УСПЕХ] Все файлы собраны в .new${NC}"
ls -1 .new
