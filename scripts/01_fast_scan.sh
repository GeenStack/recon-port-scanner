#!/bin/bash

# Скрипт быстрого сканирования портов
# Поддерживает masscan и nmap

set -e

# Параметры
IP=$1
SCANNER=${2:-masscan}
PORT_RANGE=${3:-1-65535}
FORCE_NO_PING=${4:-false}
LOG_DIR=${5:-/app/logs}
MASSCAN_RATE=${6:-1000}

if [ -z "$IP" ]; then
    echo "Usage: $0 <IP> [scanner] [port_range] [force_no_ping] [log_dir] [masscan_rate]"
    echo "Example: $0 192.168.1.1 masscan 1-65535 false /app/logs 1000"
    exit 1
fi

# Создание директории для логов
mkdir -p "$LOG_DIR"

# Генерация имени файла лога
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SAFE_IP=$(echo "$IP" | tr '.' '_')
LOG_PREFIX="${LOG_DIR}/${SAFE_IP}_fast_${TIMESTAMP}"

echo "[$(date)] Starting fast port scan for $IP using $SCANNER"

if [ "$SCANNER" = "masscan" ]; then
    echo "[$(date)] Running masscan on $IP with rate $MASSCAN_RATE pps"
    
    # Запуск masscan
    masscan "$IP" \
        -p"$PORT_RANGE" \
        --rate="$MASSCAN_RATE" \
        -oJ "${LOG_PREFIX}_masscan.json" \
        -oL "${LOG_PREFIX}_masscan.txt" \
        2>&1 | tee "${LOG_PREFIX}_masscan.log"
    
    echo "[$(date)] Masscan completed. Results saved to ${LOG_PREFIX}_masscan.*"
    
    # Извлечение открытых портов из JSON
    if [ -f "${LOG_PREFIX}_masscan.json" ]; then
        jq -r '.[] | select(.ports) | .ports[] | .port' "${LOG_PREFIX}_masscan.json" 2>/dev/null | sort -n | uniq > "${LOG_PREFIX}_open_ports.txt" || true
    fi

elif [ "$SCANNER" = "nmap" ]; then
    echo "[$(date)] Running nmap on $IP"
    
    NMAP_OPTS="-sS -T4 -p $PORT_RANGE"
    
    if [ "$FORCE_NO_PING" = "true" ]; then
        NMAP_OPTS="$NMAP_OPTS -Pn"
        echo "[$(date)] Force scan without ping enabled"
    fi
    
    # Запуск nmap
    nmap $NMAP_OPTS \
        -oA "${LOG_PREFIX}_nmap" \
        "$IP" \
        2>&1 | tee "${LOG_PREFIX}_nmap.log"
    
    echo "[$(date)] Nmap completed. Results saved to ${LOG_PREFIX}_nmap.*"
    
    # Извлечение открытых портов
    if [ -f "${LOG_PREFIX}_nmap.gnmap" ]; then
        grep "Ports:" "${LOG_PREFIX}_nmap.gnmap" | sed 's/.*Ports: //g' | tr ',' '\n' | grep "open" | cut -d'/' -f1 | sort -n | uniq > "${LOG_PREFIX}_open_ports.txt" || true
    fi
else
    echo "Error: Unknown scanner '$SCANNER'. Use 'masscan' or 'nmap'"
    exit 1
fi

# Вывод количества найденных портов
if [ -f "${LOG_PREFIX}_open_ports.txt" ]; then
    PORT_COUNT=$(wc -l < "${LOG_PREFIX}_open_ports.txt")
    echo "[$(date)] Found $PORT_COUNT open ports on $IP"
    echo "[$(date)] Open ports list saved to ${LOG_PREFIX}_open_ports.txt"
else
    echo "[$(date)] No open ports found or error parsing results"
fi

echo "[$(date)] Fast scan completed for $IP"
