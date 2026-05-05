#!/bin/bash

# Скрипт сканирования с vuln скриптами

set -e

# Параметры
IP=$1
PORTS=$2
FORCE_NO_PING=${3:-false}
LOG_DIR=${4:-/app/logs}

if [ -z "$IP" ] || [ -z "$PORTS" ]; then
    echo "Usage: $0 <IP> <ports> [force_no_ping] [log_dir]"
    echo "Example: $0 192.168.1.1 80,443,8080 false /app/logs"
    exit 1
fi

# Создание директории для логов
mkdir -p "$LOG_DIR"

# Генерация имени файла лога
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SAFE_IP=$(echo "$IP" | tr '.' '_')
LOG_PREFIX="${LOG_DIR}/${SAFE_IP}_vuln_${TIMESTAMP}"

echo "[$(date)] Starting vulnerability scan for $IP on ports: $PORTS"

# Базовые опции nmap
NMAP_OPTS="-sV -p $PORTS --script \"(default or auth or vuln) and safe\""

if [ "$FORCE_NO_PING" = "true" ]; then
    NMAP_OPTS="$NMAP_OPTS -Pn"
    echo "[$(date)] Force scan without ping enabled"
fi

# Запуск nmap с vuln скриптами
echo "[$(date)] Running nmap with vulnerability scripts"
eval nmap $NMAP_OPTS \
    -oA "${LOG_PREFIX}_nmap" \
    "$IP" \
    2>&1 | tee "${LOG_PREFIX}_nmap.log"

echo "[$(date)] Vulnerability scan completed for $IP"
echo "[$(date)] Results saved to ${LOG_PREFIX}_nmap.*"

# Проверка наличия результатов
if [ -f "${LOG_PREFIX}_nmap.xml" ]; then
    echo "[$(date)] XML output available: ${LOG_PREFIX}_nmap.xml"
fi

if [ -f "${LOG_PREFIX}_nmap.nmap" ]; then
    echo "[$(date)] Normal output available: ${LOG_PREFIX}_nmap.nmap"
    
    # Поиск уязвимостей в выводе
    if grep -i "VULNERABLE" "${LOG_PREFIX}_nmap.nmap" > /dev/null 2>&1; then
        echo "[$(date)] WARNING: Potential vulnerabilities found!"
        grep -i "VULNERABLE" "${LOG_PREFIX}_nmap.nmap" | head -10
    fi
fi
