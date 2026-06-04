#!/bin/bash
set -e # Мгновенная остановка скрипта при любой ошибке

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

DIR_WEBHOOK="dev-ccs-vault-webhook-webhook-tls"
DIR_VAULT="ccs-vault-tls"
DIR_NEW=".new"

OLD_TLS_CRT="$DIR_WEBHOOK/tls.crt"
OLD_SERVER_CRT="$DIR_VAULT/server.crt"

echo -e "${YELLOW}=== Генератор сертификатов (Strict Mode) ===${NC}"

# 1. Проверка исходников
if [ ! -f "$OLD_TLS_CRT" ]; then echo -e "${RED}[ОШИБКА] Не найден $OLD_TLS_CRT${NC}"; exit 1; fi
if [ ! -f "$OLD_SERVER_CRT" ]; then echo -e "${RED}[ОШИБКА] Не найден $OLD_SERVER_CRT${NC}"; exit 1; fi

# 2. Парсинг данных
echo "Парсим старые сертификаты..."

# Извлекаем Issuer из Vault (чистим от префикса 'issuer=' и лишних пробелов)
RAW_ISSUER=$(openssl x509 -in "$OLD_SERVER_CRT" -noout -issuer | sed 's/^issuer=[[:space:]]*//')
# Если OpenSSL выдает формат 'O = BanzaiCloud, CN = ...', конвертируем его в '/O=BanzaiCloud/CN=...'
if [[ "$RAW_ISSUER" != /* ]]; then
    CA_SUBJ="/$(echo "$RAW_ISSUER" | sed 's/, /\//g' | sed 's/ = /=/g')"
else
    CA_SUBJ="$RAW_ISSUER"
fi

# Парсим Vault
CN_VAULT=$(openssl x509 -in "$OLD_SERVER_CRT" -noout -subject | sed -n 's/.*CN[ =]*\([^,]*\).*/\1/p' | sed 's/^[[:space:]]*//')
SAN_VAULT=$(openssl x509 -in "$OLD_SERVER_CRT" -noout -ext subjectAltName | grep -v "Subject Alternative Name" | sed -e 's/^[[:space:]]*//' -e 's/IP Address:/IP:/g')

# Парсим Webhook
CN_WEBHOOK=$(openssl x509 -in "$OLD_TLS_CRT" -noout -subject | sed -n 's/.*CN[ =]*\([^,]*\).*/\1/p' | sed 's/^[[:space:]]*//')
SAN_WEBHOOK=$(openssl x509 -in "$OLD_TLS_CRT" -noout -ext subjectAltName | grep -v "Subject Alternative Name" | sed -e 's/^[[:space:]]*//' -e 's/IP Address:/IP:/g')

# Проверка, что критичные данные не пустые
if [ -z "$CA_SUBJ" ] || [ -z "$CN_VAULT" ] || [ -z "$SAN_VAULT" ]; then
    echo -e "${RED}[ОШИБКА] Не удалось извлечь CN или SAN из сертификата Vault! Проверь файл.${NC}"; exit 1
fi

echo -e "----------------------------------------"
echo -e "${GREEN}Клон Issuer:${NC} $CA_SUBJ"
echo -e "${GREEN}Vault CN:${NC} $CN_VAULT"
echo -e "${GREEN}Vault SAN:${NC} $SAN_VAULT"
echo -e "${GREEN}Webhook CN:${NC} $CN_WEBHOOK"
echo -e "${GREEN}Webhook SAN:${NC} $SAN_WEBHOOK"
echo -e "----------------------------------------"

# 3. Подготовка директории
rm -rf "$DIR_NEW"
mkdir -p "$DIR_NEW"
cd "$DIR_NEW"

# Функция очистки временных конфигов при выходе
trap 'rm -f server.cnf webhook.cnf server.csr tls.csr ca.srl' EXIT

# 4. Генерация
echo "1/3 Генерация Root CA (10 лет)..."
openssl genrsa -out ca.key 2048 2>/dev/null
openssl req -x509 -new -nodes -key ca.key -subj "$CA_SUBJ" -days 3650 -out ca.crt 2>/dev/null

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

openssl genrsa -out server.key 2048 2>/dev/null
openssl req -new -key server.key -config server.cnf -out server.csr 2>/dev/null
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 3650 -extfile server.cnf -extensions v3_req 2>/dev/null

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

openssl genrsa -out tls.key 2048 2>/dev/null
openssl req -new -key tls.key -config webhook.cnf -out tls.csr 2>/dev/null
openssl x509 -req -in tls.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out tls.crt -days 3650 -extfile webhook.cnf -extensions v3_req 2>/dev/null

# 5. Проверка результата
cd ..
REQUIRED_FILES=("$DIR_NEW/ca.crt" "$DIR_NEW/ca.key" "$DIR_NEW/server.crt" "$DIR_NEW/server.key" "$DIR_NEW/tls.crt" "$DIR_NEW/tls.key")
for f in "${REQUIRED_FILES[@]}"; do
    if [ ! -s "$f" ]; then
        echo -e "${RED}[КРИТИЧЕСКАЯ ОШИБКА] Файл $f не создан или пуст!${NC}"
        exit 1
    fi
done

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}[УСПЕХ] Все 6 файлов успешно сгенерированы!${NC}"
echo -e "Они лежат в папке ${YELLOW}$DIR_NEW${NC}:"
ls -lh $DIR_NEW | awk '{print $5, $9}' | grep -v "^ "