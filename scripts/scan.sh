#!/bin/bash

# Главный скрипт оркестрации сканирования портов

set -e

# Определение директории скриптов
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Загрузка переменных окружения
if [ -f /app/.env ]; then
    export $(cat /app/.env | grep -v '^#' | xargs)
fi

# Значения по умолчанию
FAST_SCANNER=${FAST_SCANNER:-masscan}
USE_VULNERS=${USE_VULNERS:-true}
FORCE_SCAN_NO_PING=${FORCE_SCAN_NO_PING:-false}
MASSCAN_RATE=${MASSCAN_RATE:-1000}
PORT_RANGE=${PORT_RANGE:-1-65535}
LOG_DIR=${LOG_DIR:-/app/logs}
OUTPUT_DIR=${OUTPUT_DIR:-/app/output}
INPUT_DIR=${INPUT_DIR:-/app/input}

# Создание директорий
mkdir -p "$LOG_DIR" "$OUTPUT_DIR" "$INPUT_DIR"

echo "=========================================="
echo "  Recon Port Scanner"
echo "=========================================="
echo "Fast Scanner: $FAST_SCANNER"
echo "Use Vulners: $USE_VULNERS"
echo "Force No Ping: $FORCE_SCAN_NO_PING"
echo "Port Range: $PORT_RANGE"
echo "=========================================="

# Функция для извлечения IP из входных данных
extract_ips() {
    local input_file=$1
    
    if [ -f "$input_file" ]; then
        # Если это JSON файл от предыдущего этапа
        if [[ "$input_file" == *.json ]]; then
            jq -r '.ips[].ip' "$input_file" 2>/dev/null || echo ""
        else
            # Если это просто список IP
            cat "$input_file"
        fi
    fi
}

# Поиск входного файла
INPUT_FILE=""
if [ -n "$1" ]; then
    INPUT_FILE="$1"
elif [ -f "$INPUT_DIR/input.json" ]; then
    INPUT_FILE="$INPUT_DIR/input.json"
elif [ -f "$INPUT_DIR/ips.txt" ]; then
    INPUT_FILE="$INPUT_DIR/ips.txt"
else
    echo "Error: No input file specified and no default input found"
    echo "Usage: $0 <input_file>"
    echo "Input file can be:"
    echo "  - JSON file from subdomain enumeration"
    echo "  - Text file with list of IPs (one per line)"
    exit 1
fi

echo "Input file: $INPUT_FILE"

# Извлечение списка IP
IPS=$(extract_ips "$INPUT_FILE")

if [ -z "$IPS" ]; then
    echo "Error: No IPs found in input file"
    exit 1
fi

IP_COUNT=$(echo "$IPS" | wc -l)
echo "Found $IP_COUNT IPs to scan"
echo "=========================================="

# Счетчик
CURRENT=0

# Обработка каждого IP
for IP in $IPS; do
    CURRENT=$((CURRENT + 1))
    echo ""
    echo "[$CURRENT/$IP_COUNT] Processing $IP"
    echo "=========================================="
    
    # Этап 1: Быстрое сканирование портов
    echo "[Stage 1/4] Fast port scan..."
    "$SCRIPT_DIR/01_fast_scan.sh" "$IP" "$FAST_SCANNER" "$PORT_RANGE" "$FORCE_SCAN_NO_PING" "$LOG_DIR" "$MASSCAN_RATE" || {
        echo "Warning: Fast scan failed for $IP"
        continue
    }
    
    # Поиск файла с открытыми портами
    SAFE_IP=$(echo "$IP" | tr '.' '_')
    OPEN_PORTS_FILE=$(ls -t "$LOG_DIR/${SAFE_IP}_fast_"*"_open_ports.txt" 2>/dev/null | head -1)
    
    if [ ! -f "$OPEN_PORTS_FILE" ] || [ ! -s "$OPEN_PORTS_FILE" ]; then
        echo "No open ports found for $IP, skipping detailed scans"
        continue
    fi
    
    # Преобразование списка портов в формат для nmap (через запятую)
    PORTS=$(cat "$OPEN_PORTS_FILE" | tr -d ' ' | tr '\n' ',' | sed 's/,$//')
    
    if [ -z "$PORTS" ]; then
        echo "No open ports found for $IP, skipping detailed scans"
        continue
    fi
    
    echo "Open ports: $PORTS"
    
    # Этап 2: Детальное сканирование с определением версий
    echo "[Stage 2/4] Detailed scan with version detection..."
    "$SCRIPT_DIR/02_detailed_scan.sh" "$IP" "$PORTS" "$USE_VULNERS" "$FORCE_SCAN_NO_PING" "$LOG_DIR" || {
        echo "Warning: Detailed scan failed for $IP"
    }
    
    # Этап 3: Сканирование с vuln скриптами
    echo "[Stage 3/4] Vulnerability scan..."
    "$SCRIPT_DIR/03_vuln_scan.sh" "$IP" "$PORTS" "$FORCE_SCAN_NO_PING" "$LOG_DIR" || {
        echo "Warning: Vulnerability scan failed for $IP"
    }
    
    echo "Completed scanning $IP"
    echo "=========================================="
done

# Этап 4: Генерация итогового отчета
echo ""
echo "[Stage 4/4] Generating final report..."
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="$OUTPUT_DIR/port_scan_report_${TIMESTAMP}.json"

python3 "$SCRIPT_DIR/04_generate_report.py" "$LOG_DIR" "$OUTPUT_FILE" "$INPUT_FILE" || {
    echo "Error: Failed to generate report"
    exit 1
}

echo ""
echo "=========================================="
echo "  Scan Complete!"
echo "=========================================="
echo "Report: $OUTPUT_FILE"
echo "Logs: $LOG_DIR"
echo "=========================================="
