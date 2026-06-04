#!/bin/bash

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}=== Интерактивный патчер (V3 - Safe Sed) ===${NC}"

# Функция подтверждения
confirm() {
    read -r -p "$(echo -e "${YELLOW}$1 [y/N]: ${NC}")" response
    case "$response" in
        [yY]) return 0 ;;
        *) return 1 ;;
    esac
}

# 1. Чтение и кодирование сертификата
if [ ! -f "ca.crt" ]; then
    echo -e "${RED}[ОШИБКА] Файл ca.crt не найден.${NC}"
    exit 1
fi

CA_B64=$(cat ca.crt | base64 | tr -d '\n' | tr -d '\r')
if [ $? -ne 0 ] || [ -z "$CA_B64" ]; then
    echo -e "${RED}[ОШИБКА] Не удалось закодировать ca.crt в base64.${NC}"
    exit 1
fi
echo -e "${GREEN}[OK] ca.crt прочитан и закодирован.${NC}"

# 2. Поиск вебхука
echo "Ищу конфигурацию вебхука..."
WEBHOOK_NAME=$(kubectl get mutatingwebhookconfiguration -o name | grep vault | awk -F/ '{print $2}' | head -n 1)

if [ $? -ne 0 ] || [ -z "$WEBHOOK_NAME" ]; then
    echo -e "${RED}[ОШИБКА] MutatingWebhookConfiguration со словом 'vault' не найден.${NC}"
    exit 1
fi
echo -e "${GREEN}[НАЙДЕНО] Целевой вебхук: $WEBHOOK_NAME${NC}"

TIMESTAMP=$(date +%F_%H-%M-%S)
BACKUP_FILE="${WEBHOOK_NAME}_backup_${TIMESTAMP}.yaml"
PATCHED_FILE="${WEBHOOK_NAME}_patched_${TIMESTAMP}.yaml"

# 3. Бэкап
if confirm "Шаг 1: Выгрузить конфигурацию в файл $BACKUP_FILE?"; then
    kubectl get mutatingwebhookconfiguration "$WEBHOOK_NAME" -o yaml > "$BACKUP_FILE"
    if [ $? -ne 0 ]; then
        echo -e "${RED}[КРИТИЧЕСКАЯ ОШИБКА] Сбой при выгрузке YAML. Остановка.${NC}"
        exit 1
    fi
    echo -e "${GREEN}[OK] Бэкап сохранен.${NC}"
else
    echo -e "${RED}Отмена. Выход.${NC}"
    exit 0
fi

# 4. Анализ вхождений ДО замены
OLD_COUNT=$(grep -c "caBundle:" "$BACKUP_FILE")
if [ "$OLD_COUNT" -eq 0 ]; then
    echo -e "${RED}[ОШИБКА] В файле $BACKUP_FILE не найдено ни одной строки 'caBundle:'. Нечего менять.${NC}"
    exit 1
fi

echo -e "----------------------------------------"
echo -e "Анализ файла: найдено ${YELLOW}$OLD_COUNT${NC} строк(и) 'caBundle:' для замены."
echo -e "----------------------------------------"

# 5. Патч через sed
if confirm "Шаг 2: Пропатчить эти $OLD_COUNT строк(и) локально через sed?"; then
    # Используем | как разделитель, чтобы слэши в base64 не сломали команду
    sed "s|caBundle: .*|caBundle: $CA_B64|g" "$BACKUP_FILE" > "$PATCHED_FILE"
    if [ $? -ne 0 ]; then
        echo -e "${RED}[КРИТИЧЕСКАЯ ОШИБКА] Сбой при выполнении sed. Остановка.${NC}"
        exit 1
    fi
    
    # Проверка после замены
    NEW_COUNT=$(grep -c "caBundle:" "$PATCHED_FILE")
    if [ "$OLD_COUNT" -ne "$NEW_COUNT" ]; then
        echo -e "${RED}[ОШИБКА] Количество строк изменилось (было $OLD_COUNT, стало $NEW_COUNT). sed отработал криво.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}[OK] Файл $PATCHED_FILE готов. Структура сохранена, замены выполнены.${NC}"
else
    echo -e "${RED}Отмена. Выход.${NC}"
    exit 0
fi

# 6. Накат в кластер
if confirm "Шаг 3: ВНИМАНИЕ! Накатить $PATCHED_FILE в кластер (kubectl apply)?"; then
    kubectl apply -f "$PATCHED_FILE"
    if [ $? -ne 0 ]; then
        echo -e "${RED}[КРИТИЧЕСКАЯ ОШИБКА] Kube API отклонил файл. Остановка.${NC}"
        exit 1
    fi
    echo -e "${GREEN}[УСПЕХ] Конфигурация в кластере обновлена!${NC}"
else
    echo -e "${RED}Отмена. Файл подготовлен, но В КЛАСТЕР НЕ ЗАЛИТ.${NC}"
    exit 0
fi