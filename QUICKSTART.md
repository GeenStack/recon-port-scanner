# Быстрый старт

## Установка и первый запуск

### 1. Клонирование репозитория

```bash
git clone https://github.com/GeenStack/recon-port-scanner.git
cd recon-port-scanner
```

### 2. Настройка

```bash
# Создать .env файл
cp .env.example .env

# Отредактировать настройки (опционально)
nano .env
```

### 3. Подготовка входных данных

**Вариант A: Использование результатов от recon-subdomains-enumeration**

```bash
# Скопировать JSON файл в директорию input
cp /path/to/domain_final.json ./input/input.json
```

**Вариант B: Создание списка IP адресов**

```bash
# Создать файл со списком IP
cat > ./input/ips.txt << EOF
192.168.1.1
192.168.1.2
10.0.0.1
EOF
```

### 4. Запуск сканирования

```bash
# Сборка образа
docker-compose build

# Запуск сканирования
docker-compose run --rm port-scanner
```

### 5. Просмотр результатов

```bash
# Итоговый отчет
cat output/port_scan_report_*.json | jq

# Логи сканирования
ls -lh logs/
```

## Примеры использования

### Быстрое сканирование с masscan (по умолчанию)

```bash
docker-compose run --rm port-scanner
```

### Сканирование с nmap

```bash
# Изменить в .env: FAST_SCANNER=nmap
docker-compose run --rm port-scanner
```

### Сканирование топ 1000 портов

```bash
# Изменить в .env: PORT_RANGE=--top-ports 1000
docker-compose run --rm port-scanner
```

### Сканирование без vulners

```bash
# Изменить в .env: USE_VULNERS=false
docker-compose run --rm port-scanner
```

### Принудительное сканирование без ping

```bash
# Изменить в .env: FORCE_SCAN_NO_PING=true
docker-compose run --rm port-scanner
```

## Интеграция с recon-subdomains-enumeration

```bash
# Шаг 1: Перечисление поддоменов
cd ../recon-subdomains-enumeration
docker-compose run --rm subdomain-enum example.com

# Шаг 2: Копирование результатов
cp output/example.com_final.json ../recon-port-scanner/input/input.json

# Шаг 3: Сканирование портов
cd ../recon-port-scanner
docker-compose run --rm port-scanner
```

## Структура результатов

```
recon-port-scanner/
├── output/
│   └── port_scan_report_20260505_065000.json  # Итоговый отчет
└── logs/
    ├── 192_168_1_1_fast_20260505_065000_masscan.json
    ├── 192_168_1_1_detailed_20260505_065100_nmap.xml
    └── 192_168_1_1_vuln_20260505_065200_nmap.xml
```

## Советы

1. **Для больших диапазонов портов** используйте masscan
2. **Для точного сканирования** используйте nmap
3. **При проблемах с доступностью хостов** включите `FORCE_SCAN_NO_PING=true`
4. **Для быстрого сканирования** уменьшите диапазон портов
5. **Всегда сохраняйте логи** для последующего анализа

## Устранение проблем

### Ошибка прав доступа

```bash
# Убедитесь, что Docker запущен с правами root
sudo docker-compose run --rm port-scanner
```

### Masscan не находит порты

```bash
# Уменьшите скорость сканирования в .env
MASSCAN_RATE=100
```

### Nmap зависает

```bash
# Включите принудительное сканирование
FORCE_SCAN_NO_PING=true
```
