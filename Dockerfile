FROM ubuntu:22.04

# Установка переменных окружения
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# Обновление системы и установка базовых пакетов
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    nmap \
    masscan \
    git \
    wget \
    curl \
    jq \
    libpcap-dev \
    && rm -rf /var/lib/apt/lists/*

# Установка Python библиотек
RUN pip3 install --no-cache-dir \
    python-nmap \
    xmltodict

# Создание рабочих директорий
WORKDIR /app
RUN mkdir -p /app/scripts /app/logs /app/output /app/input

# Установка vulners.nse скрипта для nmap
RUN cd /usr/share/nmap/scripts/ && \
    wget https://raw.githubusercontent.com/vulnersCom/nmap-vulners/master/vulners.nse && \
    nmap --script-updatedb

# Копирование скриптов
COPY scripts/ /app/scripts/
COPY docker-entrypoint.sh /app/

# Установка прав на выполнение
RUN chmod +x /app/scripts/*.sh /app/scripts/*.py /app/docker-entrypoint.sh

# Точка входа
ENTRYPOINT ["/app/docker-entrypoint.sh"]
