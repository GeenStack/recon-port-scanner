# Recon Port Scanner

Инструмент для автоматизированного сканирования портов с поддержкой различных сканеров и детального анализа уязвимостей.

## Описание

Recon Port Scanner - это продолжение инструмента перечисления поддоменов. Он выполняет многоэтапное сканирование портов с использованием masscan/nmap и генерирует подробные отчеты в формате JSON.

### Этапы работы

1. **Быстрое сканирование портов** - определение открытых портов (masscan или nmap)
2. **Детальное сканирование** - определение версий сервисов и поиск уязвимостей через vulners.nse
3. **Сканирование уязвимостей** - запуск nmap скриптов `(default or auth or vuln) and safe`
4. **Генерация отчета** - создание итогового JSON отчета со всеми результатами

## Возможности

- ✅ Поддержка двух режимов быстрого сканирования: masscan и nmap
- ✅ Автоматическое определение версий сервисов
- ✅ Поиск уязвимостей через vulners.nse
- ✅ Безопасное сканирование уязвимостей
- ✅ Принудительное сканирование без ping
- ✅ Сохранение всех логов сканирования
- ✅ Итоговый отчет в формате JSON
- ✅ Поддержка входных данных от предыдущего этапа (перечисление поддоменов)
- ✅ Поддержка простого списка IP адресов
- ✅ Docker контейнеризация

## Требования

- Docker
- Docker Compose
- Привилегированный режим для работы сканеров

## Установка

```bash
# Клонирование репозитория
git clone https://github.com/GeenStack/recon-port-scanner.git
cd recon-port-scanner

# Создание .env файла
cp .env.example .env

# Редактирование настроек (опционально)
nano .env

# Сборка Docker образа
docker-compose build
```

## Настройка

Отредактируйте файл `.env` для настройки параметров сканирования:

```bash
# Выбор сканера для быстрого сканирования: masscan или nmap
FAST_SCANNER=masscan

# Использовать vulners.nse при детальном сканировании (true/false)
USE_VULNERS=true

# Принудительное сканирование узлов без пинга (true/false)
FORCE_SCAN_NO_PING=false

# Скорость сканирования masscan (пакетов в секунду)
MASSCAN_RATE=1000

# Диапазон портов для сканирования
PORT_RANGE=1-65535
```

## Использование

### Вариант 1: Использование результатов перечисления поддоменов

```bash
# Поместите JSON файл от предыдущего этапа в директорию input
cp /path/to/domain_final.json ./input/input.json

# Запуск сканирования
docker-compose run --rm port-scanner
```

### Вариант 2: Использование списка IP адресов

```bash
# Создайте файл со списком IP (один IP на строку)
cat > ./input/ips.txt << EOF
192.168.1.1
192.168.1.2
10.0.0.1
EOF

# Запуск сканирования
docker-compose run --rm port-scanner
```

### Вариант 3: Указание конкретного файла

```bash
docker-compose run --rm port-scanner /app/input/custom_file.json
```

## Структура проекта

```
recon-port-scanner/
├── Dockerfile              # Docker образ
├── docker-compose.yml      # Docker Compose конфигурация
├── docker-entrypoint.sh    # Точка входа
├── .env.example            # Пример настроек
├── .gitignore             # Git ignore файл
├── README.md              # Документация
├── scripts/               # Скрипты сканирования
│   ├── scan.sh           # Главный скрипт оркестрации
│   ├── 01_fast_scan.sh   # Быстрое сканирование портов
│   ├── 02_detailed_scan.sh # Детальное сканирование
│   ├── 03_vuln_scan.sh   # Сканирование уязвимостей
│   └── 04_generate_report.py # Генерация отчета
├── input/                 # Входные данные
├── output/                # Итоговые отчеты
└── logs/                  # Логи сканирования
```

## Формат входных данных

### JSON от перечисления поддоменов

```json
{
  "domain": "example.com",
  "scan_date": "2026-05-04T18:47:25Z",
  "ips": [
    {
      "ip": "192.168.1.1",
      "ptr": null,
      "asn": {...},
      "subdomain_count": 5,
      "subdomains": ["www.example.com", "mail.example.com"]
    }
  ]
}
```

### Простой список IP

```
192.168.1.1
192.168.1.2
10.0.0.1
```

## Формат выходных данных

Итоговый отчет сохраняется в `output/port_scan_report_YYYYMMDD_HHMMSS.json`:

```json
{
  "scan_date": "2026-05-05T10:30:00Z",
  "scan_info": {
    "tool": "recon-port-scanner",
    "version": "1.0.0"
  },
  "hosts": [
    {
      "ip": "192.168.1.1",
      "log_files": {
        "fast_scan": ["192_168_1_1_fast_20260505_103000_masscan.json"],
        "detailed_scan": ["192_168_1_1_detailed_20260505_103100_nmap.xml"],
        "vuln_scan": ["192_168_1_1_vuln_20260505_103200_nmap.xml"]
      },
      "ports": [
        {
          "port": "80",
          "protocol": "tcp",
          "state": "open",
          "service": {
            "name": "http",
            "product": "nginx",
            "version": "1.18.0"
          },
          "scripts": [
            {
              "id": "http-title",
              "output": "Welcome Page"
            }
          ]
        }
      ],
      "scan_summary": {
        "total_ports_found": 5,
        "open_ports": 5,
        "filtered_ports": 0,
        "closed_ports": 0
      }
    }
  ]
}
```

## Логи сканирования

Для каждого хоста и каждого этапа сканирования создаются отдельные файлы логов:

- `{IP}_fast_{timestamp}_masscan.json` - результаты masscan
- `{IP}_fast_{timestamp}_masscan.txt` - текстовый лог masscan
- `{IP}_fast_{timestamp}_open_ports.txt` - список открытых портов
- `{IP}_detailed_{timestamp}_nmap.xml` - XML результаты детального скана
- `{IP}_detailed_{timestamp}_nmap.nmap` - текстовый результат детального скана
- `{IP}_vuln_{timestamp}_nmap.xml` - XML результаты скана уязвимостей
- `{IP}_vuln_{timestamp}_nmap.nmap` - текстовый результат скана уязвимостей

## Примеры использования

### Быстрое сканирование с nmap

```bash
# Изменить в .env
FAST_SCANNER=nmap

docker-compose run --rm port-scanner
```

### Сканирование без vulners

```bash
# Изменить в .env
USE_VULNERS=false

docker-compose run --rm port-scanner
```

### Принудительное сканирование без ping

```bash
# Изменить в .env
FORCE_SCAN_NO_PING=true

docker-compose run --rm port-scanner
```

### Сканирование только топ 1000 портов

```bash
# Изменить в .env
PORT_RANGE=--top-ports 1000

docker-compose run --rm port-scanner
```

## Безопасность

⚠️ **ВАЖНО**: Этот инструмент предназначен только для легального тестирования безопасности собственных систем или систем, на сканирование которых у вас есть явное разрешение.

- Всегда получайте письменное разрешение перед сканированием
- Используйте только в контролируемых средах
- Соблюдайте законы вашей страны
- Не используйте для несанкционированного доступа

## Производительность

### Masscan
- Очень быстрый (до 10 млн пакетов/сек)
- Рекомендуется для больших диапазонов портов
- Требует root привилегий

### Nmap
- Более медленный, но более точный
- Лучше для небольших диапазонов
- Больше возможностей настройки

## Устранение неполадок

### Ошибка "Permission denied"

Убедитесь, что контейнер запущен в привилегированном режиме:

```yaml
privileged: true
cap_add:
  - NET_ADMIN
  - NET_RAW
```

### Masscan не находит порты

Попробуйте уменьшить скорость сканирования:

```bash
MASSCAN_RATE=100
```

### Nmap зависает на хостах

Включите принудительное сканирование без ping:

```bash
FORCE_SCAN_NO_PING=true
```

## Интеграция с другими инструментами

### Использование с recon-subdomains-enumeration

```bash
# Шаг 1: Перечисление поддоменов
cd recon-subdomains-enumeration
docker-compose run --rm subdomain-enum example.com

# Шаг 2: Копирование результатов
cp output/example.com_final.json ../recon-port-scanner/input/input.json

# Шаг 3: Сканирование портов
cd ../recon-port-scanner
docker-compose run --rm port-scanner
```

## Лицензия

MIT License

## Автор

GeenStack

## Поддержка

Если у вас возникли проблемы или вопросы, создайте issue в репозитории GitHub.
