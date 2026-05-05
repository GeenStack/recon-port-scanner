#!/bin/bash

# Скрипт детального сканирования с определением версий и vulners.nse

set -e

# Параметры
IP=$1
PORTS=$2
USE_VULNERS=${3:-true}
FORCE_NO_PING=${4:-false}
LOG_DIR=${5:-/app/logs}

if [ -z "$IP" ] || [ -z "$PORTS" ]; then
    echo "Usage: $0 <IP> <ports> [use_vulners] [force_no_ping] [log_dir]"
    echo "Example: $0 192.168.1.1 80,443,8080 true false /app/logs"
    exit 1
fi

# Создание директории для логов
mkdir -p "$LOG_DIR"

# Генерация имени файла лога
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SAFE_IP=$(echo "$IP" | tr '.' '_')
LOG_PREFIX="${LOG_DIR}/${SAFE_IP}_detailed_${TIMESTAMP}"

echo "[$(date)] Starting detailed scan for $IP on ports: $PORTS"

# Базовые опции nmap
NMAP_OPTS="-sV -sC -p $PORTS"

if [ "$FORCE_NO_PING" = "true" ]; then
    NMAP_OPTS="$NMAP_OPTS -Pn"
    echo "[$(date)] Force scan without ping enabled"
fi

# Добавление vulners.nse если включено
if [ "$USE_VULNERS" = "true" ]; then
    echo "[$(date)] Vulners NSE script enabled"
    NMAP_OPTS="$NMAP_OPTS --script vulners"
fi

# Запуск nmap с детальным сканированием
echo "[$(date)] Running nmap with version detection and scripts"
nmap $NMAP_OPTS \
    -oA "${LOG_PREFIX}_nmap" \
    "$IP" \
    2>&1 | tee "${LOG_PREFIX}_nmap.log"

echo "[$(date)] Detailed scan completed for $IP"
echo "[$(date)] Results saved to ${LOG_PREFIX}_nmap.*"

# Проверка наличия результатов
if [ -f "${LOG_PREFIX}_nmap.xml" ]; then
    echo "[$(date)] XML output available: ${LOG_PREFIX}_nmap.xml"
fi

if [ -f "${LOG_PREFIX}_nmap.nmap" ]; then
    echo "[$(date)] Normal output available: ${LOG_PREFIX}_nmap.nmap"
fi
