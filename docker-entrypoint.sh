#!/bin/bash

# Docker entrypoint script

set -e

echo "Starting Recon Port Scanner..."

# Если передан аргумент, используем его как входной файл
if [ -n "$1" ]; then
    exec /app/scripts/scan.sh "$1"
else
    # Иначе ищем входной файл в /app/input
    exec /app/scripts/scan.sh
fi
